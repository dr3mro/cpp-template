# clean - remove the compiled files of a preset, or everything generated
#
# Usage:
#   cx clean [preset]
#   cx clean --all
#
# Without --all it runs the preset's `clean` target: the compiled files go,
# the settings (CMakeCache.txt) stay. With --all it runs
# cmake -P cmake/DistClean.cmake, which removes build/, docs/ and
# vcpkg_installed/ completely.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
if(NOT _targets STREQUAL "")
    _cx_fail("cx clean takes a preset, not a target")
endif()
if(CX_ALL)
    _cx_run(${CMAKE_COMMAND} -P "${CX_ROOT}/cmake/DistClean.cmake")
    if(NOT CX_RUN_RESULT EQUAL 0)
        _cx_fail("the full clean failed")
    endif()
    return()
endif()
if(NOT EXISTS "${CX_ROOT}/build/${_preset}/CMakeCache.txt")
    _cx_say("build/${_preset} is not configured; nothing to clean.")
    return()
endif()
_cx_build("${_preset}" "clean" _result)
if(NOT _result EQUAL 0)
    _cx_fail("clean failed for preset '${_preset}'")
endif()
