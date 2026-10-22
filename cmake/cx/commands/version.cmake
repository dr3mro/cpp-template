# version - print the cx version and the project's version
#
# Usage:
#   cx version
#
# The project version is read from the VERSION file, the same file CMake and
# the generated version.hpp use.

foreach(_word IN LISTS CX_WORDS)
    _cx_fail("cx version takes no arguments (got '${_word}')")
endforeach()
_cx_project_name(_name "")
_cx_project_version(_version)
if(_version STREQUAL "")
    set(_version "unknown")
endif()
_cx_say("cx ${CX_VERSION}")
_cx_say("${_name} ${_version}")
