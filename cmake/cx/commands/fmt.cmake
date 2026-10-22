# fmt - format the sources, or check that they are formatted
#
# Usage:
#   cx fmt
#   cx fmt --check
#
# Runs the release preset's `format` target (clang-format -i) or, with
# --check, the `format-check` target, which fails on a file that is not
# formatted. The targets only exist when clang-format 21+ was found at
# configure time; configure's warning says how to install it.

set(_target format)
if(CX_CHECK)
    set(_target format-check)
endif()
_cx_ensure_configured(release _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'release'")
endif()

# The format targets exist only when the configure found clang-format 21+.
# Without them the build stops with an unhelpful "unknown target", so say what
# is missing instead. The cache holds the copy the configure used.
_cx_project_name(_name "")
string(TOUPPER "${_name}" _upper)
_cx_build_dir(release _dir)
set(_cache "${_dir}/CMakeCache.txt")
if(EXISTS "${_cache}")
    file(STRINGS "${_cache}" _line REGEX "^${_upper}_CLANG_FORMAT:[^=]*=")
    if(_line)
        string(REGEX REPLACE "^[^=]*=" "" _path "${_line}")
        set(_version "")
        if(NOT _path MATCHES "-NOTFOUND$")
            execute_process(COMMAND "${_path}" --version
                            OUTPUT_VARIABLE _version
                            OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
        endif()
        if(_version STREQUAL "")
            _cx_fail("the ${_target} target needs clang-format 21+, but the "
                     "configure found no clang-format")
        endif()
        if(_version MATCHES "version ([0-9]+)" AND CMAKE_MATCH_1 LESS 21)
            _cx_fail("the ${_target} target needs clang-format 21+, but the "
                     "configure found ${_path} (${_version})")
        endif()
    endif()
endif()

_cx_build(release "${_target}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("${_target} failed")
endif()
