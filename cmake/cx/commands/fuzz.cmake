# fuzz - build the fuzzers and run them for a bounded time
#
# Usage:
#   cx fuzz [--seconds N]
#
# Configures the fuzz preset (with -D<NAME>_FUZZ_SECONDS=N when --seconds is
# given), builds the fuzz binaries and runs the `fuzz-run` target. libFuzzer
# is clang-only, so the preset does not exist on Windows.

foreach(_word IN LISTS CX_WORDS)
    _cx_fail("cx fuzz takes no preset or target words, only --seconds N "
             "(got '${_word}')")
endforeach()

_cx_project_name(_name "")
string(TOUPPER "${_name}" _upper)
if(CX_SECONDS_DEFINED)
    if(NOT CX_SECONDS MATCHES "^[0-9]+$" OR CX_SECONDS EQUAL 0)
        _cx_fail("--seconds needs a positive whole number")
    endif()
    set(CX_CONFIGURE_EXTRA "-D${_upper}_FUZZ_SECONDS=${CX_SECONDS}")
    _cx_configure(fuzz _result)
else()
    _cx_ensure_configured(fuzz _result)
endif()
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'fuzz'")
endif()
_cx_build(fuzz fuzz-run _result)
if(NOT _result EQUAL 0)
    _cx_fail("fuzz-run failed")
endif()
