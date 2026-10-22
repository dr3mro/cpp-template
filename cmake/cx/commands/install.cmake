# install - build a preset and install it
#
# Usage:
#   cx install [preset]
#   cx install release --prefix ~/apps/<name>
#
# Configures and builds the preset, then runs `cmake --install
# build/<os>/<preset>`. Without --prefix the preset's install folder is used
# (build/<os>/install/<preset>); the command prints where the files went.

_cx_resolve("${CX_WORDS}" _preset _targets _extra)
if(NOT _targets STREQUAL "")
    _cx_fail("cx install takes a preset, not a target")
endif()
set(CX_CONFIGURE_EXTRA "${_extra}")
_cx_ensure_configured("${_preset}" _result)
if(NOT _result EQUAL 0)
    _cx_fail("configure failed for preset '${_preset}'")
endif()
_cx_build("${_preset}" "" _result)
if(NOT _result EQUAL 0)
    _cx_fail("build failed for preset '${_preset}'")
endif()

_cx_build_dir("${_preset}" _dir)
set(_args --install "${_dir}")
set(_where "${CX_PREFIX}")
if(NOT CX_PREFIX STREQUAL "")
    list(APPEND _args --prefix "${CX_PREFIX}")
else()
    set(_cache "${_dir}/CMakeCache.txt")
    file(STRINGS "${_cache}" _line REGEX "^CMAKE_INSTALL_PREFIX:")
    if(_line)
        string(REGEX REPLACE "^CMAKE_INSTALL_PREFIX:[^=]*=" "" _where "${_line}")
    else()
        set(_where "${_dir}")
    endif()
endif()
_cx_run(${CMAKE_COMMAND} ${_args})
if(NOT CX_RUN_RESULT EQUAL 0)
    _cx_fail("install failed for preset '${_preset}'")
endif()
_cx_say("Installed to: ${_where}")
