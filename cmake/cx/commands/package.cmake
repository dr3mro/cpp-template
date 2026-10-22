# package - build the release preset and make an archive with CPack
#
# Usage:
#   cx package
#
# Configures and builds the release preset, runs the `package` target (CPack),
# and prints the archive it wrote: a .tar.gz on macOS and Linux, a .zip on
# Windows.

foreach(_word IN LISTS CX_WORDS)
    _cx_fail("cx package takes no preset or target words (got '${_word}')")
endforeach()
_cx_ensure_configured(release _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset 'release'")
endif()
_cx_build(release package _result)
if(NOT _result EQUAL 0)
    _cx_fail("the package target failed")
endif()
_cx_build_dir(release _dir)
file(GLOB _archives "${_dir}/*.tar.gz"
     "${_dir}/*.zip")
if(_archives)
    list(SORT _archives)
    list(GET _archives -1 _archive)
    _cx_say("Package: ${_archive}")
else()
    _cx_say("CPack finished, but no archive was found in ${_dir}.")
endif()
