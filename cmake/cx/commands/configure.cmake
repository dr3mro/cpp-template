# configure - configure the project for a preset
#
# Usage:
#   cx configure [preset] [--fresh]
#   cx configure [preset] --preset <name>
#
# Runs `cmake --preset <preset>`. This is the only command that always
# configures, even when the build folder is up to date. --fresh passes
# `--fresh` to CMake, which starts the preset's build folder over with only
# the preset's values.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
if(NOT _targets STREQUAL "")
    _cx_fail("cx configure takes a preset, not a target")
endif()
set(CX_CONFIGURE_EXTRA "${_extra}")
_cx_configure("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
