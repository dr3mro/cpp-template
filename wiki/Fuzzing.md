# Fuzzing

This guide explains what fuzzing is, how to run the fuzzer that ships with the
template, and how to find and fix a real bug with it. It takes about 15 minutes.

## What fuzzing is

A fuzzer calls one of your functions millions of times with generated input. It
starts from a few sample inputs (the *corpus*), mutates them (flips bits, inserts
bytes, splices inputs together) and keeps any mutation that reaches new code. Over
time it explores paths you never wrote a test for.

On its own, a fuzzer only notices crashes. This project builds fuzzers with
AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan), so it also stops on
bugs that would otherwise pass silently: buffer overflows, use-after-free, signed
integer overflow, out-of-bounds array indexes and similar memory errors.

Fuzzing is most useful on code that reads **untrusted input**: file and network
parsers, protocol decoders, command-line and config parsing, deserialisers, and
anything that takes user text. Many real-world security vulnerabilities are found
this way.

This project uses [libFuzzer](https://llvm.org/docs/LibFuzzer.html), which is
built into LLVM's clang.

## One-time setup

The `fuzz` preset needs LLVM's clang, because Apple's Xcode clang does not include
libFuzzer.

```bash
# macOS
brew install llvm

# Ubuntu / Debian
sudo apt install clang llvm libclang-rt-dev
```

The preset finds Homebrew LLVM automatically; you don't need to change `PATH`.

## Step 1: run the example fuzzer

`fuzz/fuzz_greeter.cpp` fuzzes the template's `Greeter` class. Build and run it:

```bash
cmake --preset fuzz && cmake --build --preset fuzz
cmake --build --preset fuzz --target fuzz-run
```

In Zed, run **task: spawn** → `fuzz run` instead.

`fuzz-run` runs every fuzzer for 10 seconds. The output looks like this:

```text
Fuzzing fuzz_greeter for 10s...
#13      INITED cov: 280 ft: 394 corp: 9/78b exec/s: 0 rss: 33Mb
#131072  pulse  cov: 280 ft: 394 corp: 9/78b lim: 1330 exec/s: 65536 rss: 77Mb
#417473  DONE   cov: 280 ft: 394 corp: 9/78b lim: 4096 exec/s: 69578 rss: 167Mb
Done 417473 runs in 11 second(s)
```

What the columns mean:

| Field | Meaning |
| --- | --- |
| `#417473` | Number of inputs tried so far |
| `cov` | Code edges covered; when it stops growing, the fuzzer has explored what it can reach |
| `corp: 9/78b` | Interesting inputs kept (9 inputs, 78 bytes in total) |
| `exec/s` | Inputs per second |
| `NEW` | A line marked `NEW` means an input reached new code and was added to the corpus |

`Done ... runs` with no error means nothing crashed.

To fuzz for longer, set the time per fuzzer when configuring (replace `MYAPP`
with your project's prefix in upper case):

```bash
cmake --preset fuzz -DMYAPP_FUZZ_SECONDS=300
cmake --build --preset fuzz --target fuzz-run
```

## Step 2: find a real bug

Let's add a small function with a classic bug and let the fuzzer find it.

**2a. Add the code.** Create `include/myapp/io/parse_age.hpp`:

```cpp
#pragma once

#include <string_view>

namespace myapp::io
{
    /** @brief Parse an age such as "42". */
    int ParseAge(std::string_view text);
} // namespace myapp::io
```

and `src/myapp/io/parse_age.cpp`:

```cpp
#include "myapp/io/parse_age.hpp"

#include <cstddef>
#include <string_view>

namespace myapp::io
{
    int ParseAge(std::string_view text)
    {
        char buffer[4] = {};
        for (std::size_t i = 0; i < text.size(); ++i)
        {
            buffer[i] = text[i]; // BUG: no check that i < 4
        }
        return buffer[0] - '0';
    }
} // namespace myapp::io
```

A unit test with `"42"` passes, so this bug is easy to miss.

**2b. Write a fuzz target.** Create `fuzz/fuzz_parse_age.cpp`. Every file named
`fuzz/fuzz_*.cpp` becomes a fuzzer automatically:

```cpp
#include "myapp/io/parse_age.hpp"

#include <cstddef>
#include <cstdint>
#include <string_view>

// libFuzzer calls this once per generated input.
extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    const std::string_view text{reinterpret_cast<const char*>(data), size};
    myapp::io::ParseAge(text);
    return 0; // always 0; anything else is reserved by libFuzzer
}
```

**2c. Add a seed input.** Each fuzzer reads its starting inputs from a folder
named after it in `fuzz/corpus/`. Without one it still runs (CMake prints a
reminder), but it starts from nothing and is much slower to reach deep code.
Put one or more valid examples in it:

```bash
mkdir -p fuzz/corpus/fuzz_parse_age
printf '42' > fuzz/corpus/fuzz_parse_age/two_digits
```

Seed folders are read when CMake configures, which the next command does.
The "Working with the corpus" section below explains how to choose
good seeds.

**2d. Run it.**

```bash
cmake --preset fuzz && cmake --build --preset fuzz
cmake --build --preset fuzz --target fuzz-run
```

The fuzzer finds the bug within a few dozen inputs:

```text
src/myapp/io/parse_age.cpp:13:13: runtime error: index 4 out of bounds for type 'char[4]'
==303==ERROR: AddressSanitizer: stack-buffer-overflow on address 0x7fa30e407544
WRITE of size 1 at 0x7fa30e407544 thread T0
    [64, 68) 'buffer' (line 10) <== Memory access at offset 68 overflows this variable
SUMMARY: AddressSanitizer: stack-buffer-overflow src/myapp/io/parse_age.cpp:13:23 in myapp::io::ParseAge
...
artifact_prefix='./'; Test unit written to ./crash-58b60c148b3e57010a4f4742fd44741389c328f4
```

How to read it:

- **`stack-buffer-overflow ... WRITE of size 1`**: the bug type. The program wrote
  past the end of a stack array.
- **`'buffer' (line 10)`**: the variable that overflowed.
- **`SUMMARY: ... parse_age.cpp:13`**: the line that did it.
- **`Test unit written to ./crash-...`**: the exact input that triggers the bug.
  With `fuzz-run` it lands in `build/fuzz/fuzz/`.

## Step 3: reproduce, fix and keep the bug fixed

**Reproduce it.** Run the fuzzer on the crash file instead of a corpus folder. It
replays that one input:

```bash
./build/fuzz/fuzz_parse_age build/fuzz/fuzz/crash-58b60c14...
```

To see what the input was, use `xxd build/fuzz/fuzz/crash-58b60c14...`. Here it is
just 5 or more bytes, more than the 4-byte buffer holds.

You can also debug it: run the same command under `lldb`, or put a breakpoint in
`ParseAge` and start the fuzz binary with the crash file as its argument.

**Fix the code.**

```cpp
int ParseAge(std::string_view text)
{
    char buffer[4] = {};
    const std::size_t count = text.size() < sizeof(buffer) ? text.size() : sizeof(buffer);
    for (std::size_t i = 0; i < count; ++i)
    {
        buffer[i] = text[i];
    }
    return buffer[0] - '0';
}
```

Rebuild, then replay the crash file again. It should now print
`Executed ... in N ms` with no error.

**Keep it fixed.** Copy the crash input into the seed corpus so every future
`fuzz-run` (and CI) retries it first:

```bash
cp build/fuzz/fuzz/crash-58b60c14... fuzz/corpus/fuzz_parse_age/regression_overflow
```

It's also worth adding a normal doctest case for the same input in
`tests/test_parse_age.cpp`, so `ctest` catches the bug even without fuzzing.

## Working with the corpus

The **corpus** is the fuzzer's collection of interesting inputs. There are two
kinds, kept in different places on purpose:

| Folder | Who writes it | Committed? | What it holds |
| --- | --- | --- | --- |
| `fuzz/corpus/fuzz_<name>/` | you | yes | **seeds**: a few hand-picked examples, plus regression inputs for bugs you fixed |
| `build/fuzz/fuzz-corpus/fuzz_<name>/` | the fuzzer | no | every new input that reached new code during `fuzz-run` |

`fuzz-run` passes both folders to each fuzzer. It reads the seeds and writes
new finds only into the build folder, so your committed seeds never change
behind your back.

### Adding seed inputs

A seed is just a file whose bytes are exactly what `LLVMFuzzerTestOneInput`
receives. The file name doesn't matter; use one that says what it is.

```bash
# text input
printf 'hello world' > fuzz/corpus/fuzz_<name>/simple_text

# empty input (an important edge case)
: > fuzz/corpus/fuzz_<name>/empty

# a real sample file, such as a config file or a packet capture
cp ~/samples/config.ini fuzz/corpus/fuzz_<name>/real_config

# raw bytes, written as hex
printf '\x00\xff\x10hello' > fuzz/corpus/fuzz_<name>/binary_header
```

If your fuzz target splits the input (the template's `fuzz_greeter.cpp` uses
the first byte to pick a salutation and the rest as the name), the seed must
follow the same layout. This seed means "salutation number 1, name Bob":

```bash
printf '\x01Bob' > fuzz/corpus/fuzz_greeter/hi_bob_seed
```

Good seeds are:

- **small**: a few bytes to a few KB. Smaller inputs run faster, and the fuzzer
  grows them as needed;
- **valid**: real examples of what your code expects, so the fuzzer starts
  deep inside the "happy path" instead of at the first input check;
- **varied**: one example of each feature or format variant (each command,
  each record type, ...), not ten copies of the same thing;
- **few**: 5 to 50 files is plenty. The fuzzer finds the rest.

After adding seeds, reconfigure once (`cmake --preset fuzz`) if the folder is
new, then run `fuzz-run`.

### Growing the corpus over time

After a long fuzzing session, the build folder holds inputs that reach code
your seeds don't. Merge the best of them into the committed seeds, keeping
only inputs that add coverage:

```bash
mkdir -p /tmp/merged
./build/fuzz/fuzz_<name> -merge=1 /tmp/merged \
    fuzz/corpus/fuzz_<name> build/fuzz/fuzz-corpus/fuzz_<name>
rm -rf fuzz/corpus/fuzz_<name> && mv /tmp/merged fuzz/corpus/fuzz_<name>
git add fuzz/corpus/fuzz_<name>
```

`-merge=1` writes to the first folder a minimal set of inputs that covers
everything the other folders cover, so the committed corpus stays small.

### Keeping fixed bugs fixed

Whenever the fuzzer finds a crash, copy the crash file into the seeds (Step 3
shows this). Every later `fuzz-run`, locally and in CI, retries it first.
Before committing a large crash input, shrink it:

```bash
./build/fuzz/fuzz_<name> -minimize_crash=1 -runs=10000 \
    -exact_artifact_path=fuzz/corpus/fuzz_<name>/regression_short crash-<hash>
```

### Dictionaries for structured input

For formats with keywords (JSON, HTTP, a command language), a dictionary helps
the fuzzer produce valid-looking input quickly. Write one keyword per line:

```text
# fuzz/fuzz_<name>.dict
"GET"
"POST"
"Content-Length:"
"\x0D\x0A"
```

Inside the quotes, only three escapes are allowed: a backslash, a double
quote, and a byte written as backslash-x plus two hex digits. That is why the
line break above is written as two hex bytes.

and pass it when running the fuzzer directly:
`./build/fuzz/fuzz_<name> -dict=fuzz/fuzz_<name>.dict build/fuzz/fuzz-corpus/fuzz_<name> fuzz/corpus/fuzz_<name>`.

## Writing good fuzz targets

- **Fuzz one entry point per target.** Call the function that receives outside
  input (`Parse`, `Decode`, `Load`), not the whole program.
- **Never exit or throw out of `LLVMFuzzerTestOneInput`.** If your code throws on
  bad input, catch the exception inside the target, because rejecting bad input is
  correct behaviour, not a bug.
- **Keep it fast and deterministic.** No network, no sleeping, no global state that
  changes between runs, no randomness. Thousands of runs per second is normal.
- **Check invariants, not just crashes.** `fuzz_greeter.cpp` calls `std::abort()`
  if a greeting doesn't end with `'!'`. Round-trip checks are especially powerful:
  `assert(Decode(Encode(x)) == x)`.
- **Split the input when a function needs several values.** Use the first byte as an
  option or index and the rest as data, like `fuzz_greeter.cpp` does. LLVM's
  `FuzzedDataProvider` (from the header `fuzzer/FuzzedDataProvider.h`) does this for
  integers, strings and booleans.
- **Give it good seeds.** A few small, valid examples (a real config file, a sample
  packet) help it reach deep code much faster than starting from nothing.

## Useful libFuzzer options

Pass these when running a fuzz binary directly:

```bash
./build/fuzz/fuzz_parse_age build/fuzz/fuzz-corpus/fuzz_parse_age fuzz/corpus/fuzz_parse_age \
    -max_total_time=600 -max_len=256 -jobs=4 -workers=4
```

| Option | What it does |
| --- | --- |
| `-max_total_time=N` | Stop after N seconds |
| `-max_len=N` | Largest input to generate (bytes) |
| `-runs=N` | Stop after N inputs |
| `-jobs=N -workers=N` | Run N fuzzing processes in parallel |
| `-dict=file` | Feed known keywords (e.g. `"GET"`, `"<html>"`) for structured formats |
| `-minimize_crash=1 <crash-file>` | Shrink a crash input to the smallest one that still crashes |
| `-merge=1 out_dir in_dir...` | Combine corpora, keeping only inputs that add coverage |

The first folder you pass is where new interesting inputs are saved;
`fuzz-run` uses `build/fuzz/fuzz-corpus/<name>/` for this, and only reads from
`fuzz/corpus/<name>/`, so your committed seeds never change by themselves.

## How it's wired up

- **`fuzz` preset**: a Debug build with LLVM clang, `MYAPP_BUILD_FUZZERS=ON` and
  the tests turned off.
- **`cmake/Sanitizers.cmake`**: when `MYAPP_BUILD_FUZZERS` is on, compiles all
  the code with `-fsanitize=fuzzer-no-link,address,undefined`, so the fuzzer
  gets coverage feedback and ASan/UBSan catch memory errors and undefined
  behaviour.
- **`fuzz/CMakeLists.txt`**: builds every `fuzz/fuzz_*.cpp` against the project
  library and adds `-fsanitize=fuzzer` (libFuzzer's own `main()`) to those binaries
  only.
- **`fuzz-run` target**: runs each fuzzer for `MYAPP_FUZZ_SECONDS` (default 10),
  with `build/fuzz/fuzz-corpus/<name>/` as the writable corpus and
  `fuzz/corpus/<name>/` as the seeds.
- **CI**: the `fuzz` job in `.github/workflows/ci.yml` runs every fuzzer on each
  push, so a regression input you commit to the corpus is retried automatically.

## Next steps

- Read the [libFuzzer documentation](https://llvm.org/docs/LibFuzzer.html).
- Try fuzzing a real parser: [Google's fuzzing tutorials](https://github.com/google/fuzzing)
  include exercises with known bugs to find.
- When a project is open source, [OSS-Fuzz](https://github.com/google/oss-fuzz) can
  run these same fuzz targets for free, around the clock.
