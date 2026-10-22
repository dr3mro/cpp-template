# docs - build the Doxygen documentation website
#
# Usage:
#   cx docs
#
# Runs `cmake --workflow --preset docs` (configure, then the docs target,
# including the diagrams when Graphviz is installed) and prints the path of
# the generated page, docs/index.html.

_cx_run(${CMAKE_COMMAND} --workflow --preset docs)
if(NOT CX_RUN_RESULT EQUAL 0)
    _cx_fail("the docs workflow failed")
endif()
set(_page "${CX_ROOT}/docs/index.html")
if(EXISTS "${_page}")
    _cx_say("Documentation: ${_page}")
else()
    _cx_say("The docs workflow finished, but ${_page} does not exist "
            "(is Doxygen installed?)")
endif()
