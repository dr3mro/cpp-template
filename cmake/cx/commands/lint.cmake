# lint - run clang-tidy and cmake-lint
#
# Usage:
#   cx lint
#
# Runs the `tidy` target on debug-nosan (the preset it belongs to) and the
# `cmake-lint` target on release. Both run even when the first one finds
# something, and the command fails if either does.

find_program(_cmake_lint NAMES cmake-lint)
if(NOT _cmake_lint)
    _cx_fail("cmake-lint was not found; install it with "
             "'pipx install cmakelang==0.6.13 && pipx inject cmakelang pyyaml' "
             "and add its bin folder to PATH")
endif()

set(_failed OFF)
_cx_ensure_configured(debug-nosan _result)
if(_result EQUAL 0)
    _cx_refind(debug-nosan _result RUN_CLANG_TIDY CLANG_TIDY)
endif()
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'debug-nosan'")
endif()
_cx_build(debug-nosan tidy _result)
if(NOT _result EQUAL 0)
    set(_failed ON)
endif()
_cx_ensure_configured(release _result)
if(_result EQUAL 0)
    _cx_refind(release _result CMAKE_LINT)
endif()
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'release'")
endif()
_cx_build(release cmake-lint _result)
if(NOT _result EQUAL 0)
    set(_failed ON)
endif()
if(_failed)
    _cx_fail("lint found problems")
endif()
