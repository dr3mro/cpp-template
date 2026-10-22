# help - list the commands, or show one command's usage
#
# Usage:
#   cx help
#   cx help <command>
#
# With no argument it prints every command and its one-line summary. With a
# command name it prints that command's full comment block: what it does, its
# usage, and its own options. The summaries come from the command files, so a
# new file under cmake/cx/commands/ appears here without any other change.

set(_for "${CX_HELP_FOR}")
if(_for STREQUAL "" AND CX_WORDS)
    list(GET CX_WORDS 0 _for)
    list(LENGTH CX_WORDS _word_count)
    if(_word_count GREATER 1)
        _cx_fail("cx help takes one command name")
    endif()
endif()

_cx_command_names(_commands)
if(NOT _for STREQUAL "")
    if(NOT _for IN_LIST _commands)
        list(JOIN _commands ", " _text)
        _cx_fail("unknown command '${_for}'.\nCommands: ${_text}")
    endif()
    _cx_command_header("${_for}" _header)
    _cx_say("${_header}")
    return()
endif()

set(_max 4)
foreach(_command IN LISTS _commands)
    string(LENGTH "${_command}" _length)
    if(_length GREATER _max)
        set(_max "${_length}")
    endif()
endforeach()

set(_text "cx ${CX_VERSION} - project commands\n\n")
string(APPEND _text "Usage: cx <command> [preset] [target...] [options] [-- args]\n\n")
string(APPEND _text "Commands:\n")
foreach(_command IN LISTS _commands)
    _cx_command_header("${_command}" _header)
    string(FIND "${_header}" "\n" _at)
    if(_at EQUAL -1)
        set(_summary "${_header}")
    else()
        string(SUBSTRING "${_header}" 0 ${_at} _summary)
    endif()
    string(LENGTH "${_command}" _length)
    math(EXPR _pad "${_max} - ${_length}")
    string(REPEAT " " ${_pad} _spaces)
    string(APPEND _text "  ${_command}${_spaces}  ${_summary}\n")
endforeach()
string(APPEND _text "\nOptions for every command:\n")
string(APPEND _text "  --preset <name>   the same as the plain preset word\n")
string(APPEND _text "  --release         the release preset (like cargo)\n")
string(APPEND _text "  --arch <name>     x64, arm64 or x86 (default: this machine's architecture)\n")
string(APPEND _text "  -v, --verbose     verbose build (-V for ctest)\n")
string(APPEND _text "  -h, --help        this list, or one command's usage\n")
string(APPEND _text "\nPresets may be plain words too: cx build release, cx test nosan.\n")
_cx_say("${_text}")
