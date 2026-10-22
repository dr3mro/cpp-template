# build - configure if needed, then build the project
#
# Usage:
#   cx build [preset] [target...] [--arch <name>] [-- <cmake args>]
#   cx build release format-check tidy
#
# Configures when build/<preset>/ has no cache, when a CMakeLists.txt or
# CMakePresets.json is newer than it, or when -- gives cmake arguments. Then
# runs `cmake --build --preset <preset> [--target <target>...]`.
#
# The preset is the first plain word that names one; every other word is a
# build target. A target on its own uses the preset it belongs to: tidy uses
# debug-nosan, format and package use release, coverage/fuzz-run/docs use their
# own presets.
#
# --arch x64|arm64|x86 builds for that architecture. The default is this
# machine's. Each platform gets the settings for it: macOS sets
# CMAKE_OSX_ARCHITECTURES, Windows loads that architecture's Visual Studio
# environment, and Linux uses -m32 for x86 or a GCC cross compiler. The build
# folder records the target, so a build for another one reconfigures it.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
set(CX_CONFIGURE_EXTRA "${_extra}")
set(CX_CMAKE_ARGS "${CX_PASSTHROUGH}")
_cx_ensure_configured("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
_cx_build("${_preset}" "${_targets}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("build failed for preset '${_preset}'")
endif()
