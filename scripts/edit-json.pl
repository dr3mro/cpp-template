#!/usr/bin/env perl
# A tiny JSON reader and writer that mimics Python's json.dumps(indent=2):
# the keys keep the order of the file and the output is indented with two
# spaces. JSON::PP is in the core of Perl, but it sorts the keys and puts a
# space before the colon, so the files would not come out the same.
#
# Usage: edit-json.pl <file> <array-key> <entry-key> <value>...
#
# Removes the entries of the array <array-key> whose <entry-key> is one of
# the given values, and writes the file back. An empty <array-key> means the
# file itself is the array.
use strict;
use warnings;

my ($path, $array_key, $entry_key, @unwanted) = @ARGV;
die "usage: edit-json.pl <file> <array-key> <entry-key> <value>...\n"
    unless @ARGV >= 3;

# ---- read ------------------------------------------------------------------
open my $in, '<:raw', $path or die "cannot read $path: $!\n";
my $text = do { local $/; <$in> };
close $in;

# ---- parse -----------------------------------------------------------------
my $pos = 0;

sub skip_space {
    $pos++ while $pos < length($text) && substr($text, $pos, 1) =~ /[\s]/;
}

sub parse_value {
    skip_space();
    my $char = substr($text, $pos, 1);
    return parse_object() if $char eq '{';
    return parse_array()  if $char eq '[';
    return parse_string() if $char eq '"';
    if (substr($text, $pos, 4) eq 'true')  { $pos += 4; return { type => 'true' } }
    if (substr($text, $pos, 5) eq 'false') { $pos += 5; return { type => 'false' } }
    if (substr($text, $pos, 4) eq 'null')  { $pos += 4; return { type => 'null' } }
    my $start = $pos;
    $pos++ while $pos < length($text) && substr($text, $pos, 1) =~ /[-+0-9.eE]/;
    return { type => 'number', value => substr($text, $start, $pos - $start) };
}

sub parse_object {
    $pos++;    # {
    my @pairs;
    skip_space();
    if (substr($text, $pos, 1) eq '}') { $pos++; return { type => 'object', pairs => \@pairs } }
    while (1) {
        skip_space();
        my $key = parse_string();
        skip_space();
        $pos++;    # :
        push @pairs, [ $key, parse_value() ];
        skip_space();
        my $char = substr($text, $pos, 1);
        $pos++;
        last if $char eq '}';
    }
    return { type => 'object', pairs => \@pairs };
}

sub parse_array {
    $pos++;    # [
    my @items;
    skip_space();
    if (substr($text, $pos, 1) eq ']') { $pos++; return { type => 'array', items => \@items } }
    while (1) {
        push @items, parse_value();
        skip_space();
        my $char = substr($text, $pos, 1);
        $pos++;
        last if $char eq ']';
    }
    return { type => 'array', items => \@items };
}

sub parse_string {
    $pos++;    # the opening quote
    my $out = '';
    while (1) {
        my $char = substr($text, $pos, 1);
        $pos++;
        last if $char eq '"';
        if ($char eq '\\') {
            my $escape = substr($text, $pos, 1);
            $pos++;
            if    ($escape eq 'n') { $out .= "\n" }
            elsif ($escape eq 't') { $out .= "\t" }
            elsif ($escape eq 'r') { $out .= "\r" }
            elsif ($escape eq 'b') { $out .= "\b" }
            elsif ($escape eq 'f') { $out .= "\f" }
            elsif ($escape eq 'u') {
                my $code = hex(substr($text, $pos, 4));
                $pos += 4;
                $out .= chr($code);
            }
            else { $out .= $escape }
        }
        else {
            $out .= $char;
        }
    }
    return $out;
}

skip_space();
my $document = parse_value();

# ---- remove the entries -----------------------------------------------------
my %unwanted = map { $_ => 1 } @unwanted;

sub entry_is_unwanted {
    my ($item) = @_;
    return 0 unless $item->{type} eq 'object';
    for my $pair (@{ $item->{pairs} }) {
        next unless $pair->[0] eq $entry_key;
        my $value = $pair->[1];
        my $name = ref($value) ? '' : $value;
        return $unwanted{$name} ? 1 : 0;
    }
    return 0;
}

if ($array_key eq '') {
    die "the file $path is not an array\n" unless $document->{type} eq 'array';
    my @kept = grep { !entry_is_unwanted($_) } @{ $document->{items} };
    $document->{items} = \@kept;
}
else {
    my $array;
    for my $pair (@{ $document->{pairs} }) {
        $array = $pair->[1] if $pair->[0] eq $array_key;
    }
    die "no array \"$array_key\" in $path\n" unless $array && $array->{type} eq 'array';
    my @kept = grep { !entry_is_unwanted($_) } @{ $array->{items} };
    $array->{items} = \@kept;
}

# ---- write ------------------------------------------------------------------
sub dump_string {
    my ($value) = @_;
    my $out = '"';
    for my $char (split //, $value) {
        my $code = ord($char);
        if    ($char eq '"')  { $out .= '\\"' }
        elsif ($char eq '\\') { $out .= '\\\\' }
        elsif ($char eq "\n") { $out .= '\\n' }
        elsif ($char eq "\r") { $out .= '\\r' }
        elsif ($char eq "\t") { $out .= '\\t' }
        elsif ($char eq "\b") { $out .= '\\b' }
        elsif ($char eq "\f") { $out .= '\\f' }
        elsif ($code < 0x20)   { $out .= sprintf('\\u%04x', $code) }
        elsif ($code > 0x7e)   { $out .= sprintf('\\u%04x', $code) }
        else                  { $out .= $char }
    }
    return $out . '"';
}

sub dump_value {
    my ($value, $level) = @_;
    return dump_string($value) unless ref($value);
    my $type = $value->{type};
    return 'true'  if $type eq 'true';
    return 'false' if $type eq 'false';
    return 'null'  if $type eq 'null';
    return $value->{value} if $type eq 'number';
    if ($type eq 'object') {
        return '{}' unless @{ $value->{pairs} };
        my $pad = '  ' x ($level + 1);
        my $items = join ",\n", map {
            $pad . dump_string($_->[0]) . ': ' . dump_value($_->[1], $level + 1)
        } @{ $value->{pairs} };
        return "{\n$items\n" . ('  ' x $level) . '}';
    }
    if ($type eq 'array') {
        return '[]' unless @{ $value->{items} };
        my $pad = '  ' x ($level + 1);
        my $items = join ",\n", map { $pad . dump_value($_, $level + 1) } @{ $value->{items} };
        return "[\n$items\n" . ('  ' x $level) . ']';
    }
    return dump_string($value);
}

open my $out, '>:raw', $path or die "cannot write $path: $!\n";
print $out dump_value($document, 0), "\n";
close $out;
