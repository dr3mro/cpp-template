# coverage - run the tests and write the coverage report
#
# Usage:
#   cx coverage
#
# Runs `cmake --workflow --preset coverage-report` (configure the coverage
# preset, run the tests under LLVM coverage, then write the HTML report) and
# prints the path of build/coverage/html/index.html.

_cx_run(${CMAKE_COMMAND} --workflow --preset coverage-report)
if(NOT CX_RUN_RESULT EQUAL 0)
    _cx_fail("the coverage workflow failed")
endif()
set(_report "${CX_ROOT}/build/coverage/html/index.html")
if(EXISTS "${_report}")
    _cx_say("Coverage report: ${_report}")
else()
    _cx_say("The coverage workflow finished, but ${_report} does not exist.")
endif()
