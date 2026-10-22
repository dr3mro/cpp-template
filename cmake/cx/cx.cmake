# =============================================================================
# cx.cmake - the implementation behind the cx command
#
#   cmake -P cmake/cx/cx.cmake -- <command> [preset] [target...] [options] [-- args]
#
# The wrappers in the project root (cx, cx.ps1, cx.cmd) only find cmake and
# run this file, so every platform behaves the same. This file is a dispatcher:
# it parses the command and the options, then includes
# cmake/cx/commands/<command>.cmake. Adding a command means adding one file
# there; nothing in this file changes.
#
# Planned but not implemented yet (deliberately not commands): `add` for
# adding a dependency, and `new` for absorbing the project generator.
# =============================================================================
cmake_minimum_required(VERSION 3.25)
# CMake 4.1+: macros keep backslashes in their arguments (Windows paths). cx
# uses functions where it matters, so this only quiets the policy warning.
if(POLICY CMP0219)
    cmake_policy(SET CMP0219 NEW)
endif()

get_filename_component(CX_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CX_COMMANDS_DIR "${CMAKE_CURRENT_LIST_DIR}/commands")
include("${CMAKE_CURRENT_LIST_DIR}/lib.cmake")

# ---- read the arguments after the first "--" ---------------------------------
# CMAKE_ARGV<n> is used instead of CMAKE_ARGUMENTS so an argument keeps its
# semicolons and brackets; the wrappers put their arguments after a literal
# "--" for that reason.
set(_i 0)
while(_i LESS CMAKE_ARGC)
    if("${CMAKE_ARGV${_i}}" STREQUAL "--")
        break()
    endif()
    math(EXPR _i "${_i} + 1")
endwhile()
math(EXPR _i "${_i} + 1")

set(CX_COMMAND "")
set(CX_WORDS "")
set(CX_PASSTHROUGH "")
set(CX_HELP OFF)
set(CX_HELP_FOR "")
set(CX_VERBOSE OFF)
set(CX_FRESH OFF)
set(CX_ALL OFF)
set(CX_CHECK OFF)
set(CX_DEV_RUN OFF)
set(CX_SECONDS "")
set(CX_SECONDS_DEFINED OFF)
set(CX_PREFIX "")
set(CX_ARCH "")
set(CX_PRESET_OPTION "")
set(CX_RELEASE OFF)
set(CX_CONFIGURE_EXTRA "")
set(CX_CMAKE_ARGS "")

while(_i LESS CMAKE_ARGC)
    set(_arg "${CMAKE_ARGV${_i}}")
    math(EXPR _i "${_i} + 1")
    if(_arg STREQUAL "--")
        while(_i LESS CMAKE_ARGC)
            _cx_arg_append(CX_PASSTHROUGH "${CMAKE_ARGV${_i}}")
            math(EXPR _i "${_i} + 1")
        endwhile()
        break()
    endif()
    if(_arg STREQUAL "--preset" OR _arg STREQUAL "--seconds" OR _arg STREQUAL "--prefix"
       OR _arg STREQUAL "--arch")
        if(NOT _i LESS CMAKE_ARGC)
            _cx_fail("missing value for ${_arg}")
        endif()
        set(_value "${CMAKE_ARGV${_i}}")
        math(EXPR _i "${_i} + 1")
        if(_arg STREQUAL "--preset")
            if(NOT CX_PRESET_OPTION STREQUAL "")
                _cx_fail("--preset is given twice")
            endif()
            set(CX_PRESET_OPTION "${_value}")
        elseif(_arg STREQUAL "--seconds")
            set(CX_SECONDS "${_value}")
            set(CX_SECONDS_DEFINED ON)
        elseif(_arg STREQUAL "--arch")
            set(CX_ARCH "${_value}")
        else()
            set(CX_PREFIX "${_value}")
        endif()
        continue()
    endif()
    if(_arg MATCHES "^--preset=")
        string(REGEX REPLACE "^--preset=" "" _value "${_arg}")
        if(NOT CX_PRESET_OPTION STREQUAL "")
            _cx_fail("--preset is given twice")
        endif()
        set(CX_PRESET_OPTION "${_value}")
        continue()
    endif()
    if(_arg MATCHES "^--(seconds|prefix|arch)=")
        string(REGEX REPLACE "^--([a-z]+)=(.*)$" "\\1" _key "${_arg}")
        string(REGEX REPLACE "^--([a-z]+)=(.*)$" "\\2" _value "${_arg}")
        if(_key STREQUAL "seconds")
            set(CX_SECONDS "${_value}")
            set(CX_SECONDS_DEFINED ON)
        elseif(_key STREQUAL "arch")
            set(CX_ARCH "${_value}")
        else()
            set(CX_PREFIX "${_value}")
        endif()
        continue()
    endif()
    if(_arg STREQUAL "--release")
        set(CX_RELEASE ON)
    elseif(_arg STREQUAL "-v" OR _arg STREQUAL "--verbose")
        set(CX_VERBOSE ON)
    elseif(_arg STREQUAL "-h" OR _arg STREQUAL "--help" OR _arg STREQUAL "-?")
        set(CX_HELP ON)
    elseif(_arg STREQUAL "--fresh")
        set(CX_FRESH ON)
    elseif(_arg STREQUAL "--all")
        set(CX_ALL ON)
    elseif(_arg STREQUAL "--check")
        set(CX_CHECK ON)
    elseif(_arg STREQUAL "--run")
        set(CX_DEV_RUN ON)
    elseif(_arg MATCHES "^-")
        _cx_fail("unknown option: ${_arg}")
    elseif(CX_COMMAND STREQUAL "")
        set(CX_COMMAND "${_arg}")
    else()
        _cx_list_append(CX_WORDS "${_arg}")
    endif()
endwhile()

# --arch names the architecture and is checked once, here. The commands turn it
# into cmake arguments for this machine (see _cx_arch_args in lib.cmake).
if(NOT CX_ARCH STREQUAL "")
    _cx_canonical_arch("${CX_ARCH}" _arch)
    if(_arch STREQUAL "")
        _cx_fail("unknown --arch '${CX_ARCH}': use x64, arm64 or x86")
    endif()
    set(CX_ARCH "${_arch}")
endif()

if(CX_PRESET_OPTION STREQUAL "" AND CX_RELEASE)
    set(CX_PRESET_OPTION "release")
elseif(NOT CX_PRESET_OPTION STREQUAL "" AND CX_RELEASE
       AND NOT CX_PRESET_OPTION STREQUAL "release")
    _cx_fail("--release and --preset ${CX_PRESET_OPTION} contradict each other")
endif()
if(NOT CX_PRESET_OPTION STREQUAL "")
    list(PREPEND CX_WORDS "${CX_PRESET_OPTION}")
endif()

if(CX_COMMAND STREQUAL "")
    set(CX_COMMAND help)
elseif(CX_HELP)
    set(CX_HELP_FOR "${CX_COMMAND}")
    set(CX_COMMAND help)
endif()

_cx_command_names(_commands)
if(NOT CX_COMMAND IN_LIST _commands)
    list(JOIN _commands ", " _text)
    _cx_fail("unknown command '${CX_COMMAND}'.\nCommands: ${_text}")
endif()

include("${CX_COMMANDS_DIR}/${CX_COMMAND}.cmake")
