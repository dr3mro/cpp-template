# leaks - run the program under Apple's leaks tool (macOS only)
#
# Usage:
#   cx leaks [preset] [-- program args]
#   cx leaks -- Amr
#
# Builds the preset (debug-nosan unless another is named), then runs
#   leaks -quiet -atExit -- build/<os>/<preset>/<name> [program args]
# The program's path and name come from the build, so nothing is typed by hand.
# leaks exits with 1 when it finds a leak, and cx reports that as a failure.
# Use a preset without AddressSanitizer: leaks cannot inspect an ASan build.

if(NOT CMAKE_HOST_APPLE)
    _cx_fail("cx leaks needs macOS: Apple's leaks tool only exists there.\n"
             "On Linux, LeakSanitizer runs in the debug preset (cx test).")
endif()

set(_default nosan)
foreach(_word IN LISTS CX_WORDS)
    _cx_exact_preset("${_word}" _is_preset)
    _cx_alias("${_word}" _alias_preset _alias_extra _alias_ok)
    if(_is_preset OR _alias_ok)
        set(_default "")
    endif()
endforeach()
if(NOT _default STREQUAL "")
    list(APPEND CX_WORDS "${_default}")
endif()
_cx_resolve("${CX_WORDS}" _preset _targets _extra)
if(NOT _targets STREQUAL "")
    _cx_fail("cx leaks takes a preset, not targets (got '${_targets}')")
endif()
set(CX_CONFIGURE_EXTRA "${_extra}")

_cx_program_path("${_preset}" _program _is_app)
if(NOT _is_app)
    _cx_fail("this is a library project: there is no program to check.\n"
             "Run the tests with `cx test` instead.")
endif()
_cx_ensure_configured("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
_cx_build("${_preset}" "" _result)
if(NOT _result EQUAL 0)
    _cx_fail("build failed for preset '${_preset}'")
endif()
if(NOT EXISTS "${_program}")
    _cx_fail("the program was not built: ${_program}")
endif()

# The build signs Debug programs with get-task-allow (cmake/DebugEntitlements.cmake);
# without it leaks says the process "is not debuggable".
_cx_run(leaks -quiet -atExit -- "${_program}" ${CX_PASSTHROUGH})
if(NOT CX_RUN_RESULT EQUAL 0)
    _cx_fail("leaks reported a problem for '${_program}' (exit code ${CX_RUN_RESULT})")
endif()
