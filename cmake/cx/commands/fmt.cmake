# fmt - format the sources, or check that they are formatted
#
# Usage:
#   cx fmt
#   cx fmt --check
#
# Runs the release preset's `format` target (clang-format -i) or, with
# --check, the `format-check` target, which fails on a file that is not
# formatted. The targets only exist when clang-format 20+ was found at
# configure time; configure's warning says how to install it.

set(_target format)
if(CX_CHECK)
    set(_target format-check)
endif()
_cx_ensure_configured(release _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'release'")
endif()
_cx_build(release "${_target}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("${_target} failed")
endif()
