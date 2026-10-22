# run - build, then run the program
#
# Usage:
#   cx run [preset] [target...] [-- program args]
#   cx run -- Amr
#   cx run release -- Amr
#
# Builds first, then runs build/<preset>/<name> (or
# build/<preset>/Debug/<name>.exe for the Visual Studio presets). Arguments
# after "--" go to the program unchanged. A library project has no program:
# the command says so and points at cx test and examples/.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
set(CX_CONFIGURE_EXTRA "${_extra}")
_cx_ensure_configured("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
_cx_build("${_preset}" "${_targets}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("build failed for preset '${_preset}'")
endif()

_cx_program_path("${_preset}" _program _is_app)
if(NOT _is_app)
    _cx_fail("this is a library project: there is no program to run.\n"
             "Run the tests with `cx test`, or build the example consumer in "
             "examples/ (see the README).")
endif()
if(NOT EXISTS "${_program}")
    _cx_fail("the program was not built: ${_program}")
endif()

_cx_run("${_program}" ${CX_PASSTHROUGH})
if(NOT CX_RUN_RESULT EQUAL 0)
    _cx_fail("'${_program}' exited with code ${CX_RUN_RESULT}")
endif()
