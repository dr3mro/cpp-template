# test - configure if needed, build, then run the tests
#
# Usage:
#   cx test [preset] [target...] [-- ctest args]
#   cx test release
#   cx test debug -- --output-on-failure -R greeter
#
# Builds the project (or the named targets), then runs
# `ctest --preset <preset>`. Arguments after "--" go to ctest unchanged.
# Presets without a test preset (fuzz, docs) say so instead of failing
# somewhere inside ctest.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
_cx_test_preset_exists("${_preset}" _has_test)
if(NOT _has_test)
    _cx_fail("preset '${_preset}' has no test preset, so there is nothing to run.\n"
             "Use a preset with tests (debug, debug-nosan, release, ci, ...) or "
             "`cx build ${_preset}` for this one.")
endif()
set(CX_CONFIGURE_EXTRA "${_extra}")
_cx_ensure_configured("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
_cx_build("${_preset}" "${_targets}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("build failed for preset '${_preset}'")
endif()
_cx_ctest("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("tests failed for preset '${_preset}'")
endif()
