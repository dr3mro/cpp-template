# =============================================================================
# lib.cmake - the helpers every cx command shares
#
# Included by cmake/cx/cx.cmake. Nothing here parses the command line: the
# dispatcher does that and hands the commands CX_PRESET_WORDS, CX_TARGET_WORDS,
# CX_PASSTHROUGH and the CX_* option variables. The helpers below are written
# once so every command configures, builds, tests and reports the same way.
#
# Provides:
#   _cx_say()                    plain stdout (message() writes to stderr)
#   _cx_fail()                   "error: ..." and exit 1
#   _cx_run()                    run a command, stream its output, keep the code
#   _cx_resolve()                preset/alias/target words -> preset + targets
#   _cx_project_name()           the project name, from the cache or CMakeLists
#   _cx_ensure_configured()      configure when the build folder is missing/stale
#   _cx_build(), _cx_ctest()     the two commands every building command needs
#   _cx_program_path()           where the app lands for a preset
# =============================================================================

include_guard(GLOBAL)

# Bumped when the command itself changes in a way a project may want to see.
set(CX_VERSION "0.1.0")

# ---- output -------------------------------------------------------------------
# message() decorates its text (-- ) and writes to stderr, so plain output goes
# to stdout through `cmake -E cat`, exactly as scripts/new-project.cmake does.
function(_cx_say text)
    string(RANDOM LENGTH 12 _tag)
    set(_tmp "${CX_ROOT}")
    foreach(_var TMPDIR TEMP TMP)
        if(DEFINED ENV{${_var}} AND IS_DIRECTORY "$ENV{${_var}}")
            file(TO_CMAKE_PATH "$ENV{${_var}}" _tmp)
            break()
        endif()
    endforeach()
    set(_file "${_tmp}/cx-${_tag}.txt")
    file(WRITE "${_file}" "${text}\n")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E cat "${_file}")
    file(REMOVE "${_file}")
endfunction()

# Stops with "error: <text>", leaving CMake's own decoration out where the
# running CMake allows it (cmake_language(EXIT) is 3.29+).
function(_cx_fail)
    set(text "")
    set(_i 0)
    while(_i LESS ARGC)
        string(APPEND text "${ARGV${_i}}")
        math(EXPR _i "${_i} + 1")
    endwhile()
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.29)
        message(NOTICE "error: ${text}")
        cmake_language(EXIT 1)
    endif()
    message(FATAL_ERROR "error: ${text}")
endfunction()

# _cx_run(<command...>)
#
# Prints the command first ("> cmake --build --preset debug"), then runs it
# with its output going straight to the terminal, so a long build shows its
# progress and the user can interrupt it. The exit code is left in
# CX_RUN_RESULT, in the caller's scope. A function, not a macro: a macro
# re-reads its arguments as CMake code, which breaks Windows paths
# (C:\Program Files\... has the invalid escape "\P").
function(_cx_run)
    set(_cx_call ${ARGN})
    set(_cx_display "")
    set(_cx_quoted "")
    foreach(_cx_arg IN LISTS _cx_call)
        string(REPLACE "${_cx_arg_sep}" ";" _cx_arg "${_cx_arg}")
        string(APPEND _cx_quoted " [==[${_cx_arg}]==]")
        if(_cx_arg STREQUAL "${CMAKE_COMMAND}")
            set(_cx_arg "cmake")
        elseif(_cx_arg STREQUAL "${CX_CTEST}")
            set(_cx_arg "ctest")
        endif()
        if(_cx_arg MATCHES " ")
            set(_cx_arg "\"${_cx_arg}\"")
        endif()
        if(_cx_display STREQUAL "")
            set(_cx_display "${_cx_arg}")
        else()
            set(_cx_display "${_cx_display} ${_cx_arg}")
        endif()
    endforeach()
    _cx_say("> ${_cx_display}")
    cmake_language(EVAL CODE "execute_process(COMMAND${_cx_quoted} RESULT_VARIABLE _cx_result)")
    set(CX_RUN_RESULT "${_cx_result}" PARENT_SCOPE)
endfunction()

# ctest lives next to the cmake that is running this script (also when cmake
# came from Visual Studio and is not on PATH).
get_filename_component(_cx_cmake_dir "${CMAKE_COMMAND}" DIRECTORY)
find_program(CX_CTEST NAMES ctest HINTS "${_cx_cmake_dir}")

# A function for the same reason as _cx_run: an argument may be a Windows path.
function(_cx_list_append list_var value)
    string(REPLACE ";" "\\;" _cx_escaped "${value}")
    list(APPEND ${list_var} "${_cx_escaped}")
    set(${list_var} "${${list_var}}" PARENT_SCOPE)
endfunction()

# Arguments after "--" are the user's: they must reach the command exactly as
# typed, semicolons included. A CMake list cannot hold ";" inside an element,
# so each ";" is stored as the control character _cx_arg_sep, and _cx_run turns
# it back into ";" when it builds the command.
string(ASCII 1 _cx_arg_sep)
function(_cx_arg_append list_var value)
    string(REPLACE ";" "${_cx_arg_sep}" _cx_encoded "${value}")
    list(APPEND ${list_var} "${_cx_encoded}")
    set(${list_var} "${${list_var}}" PARENT_SCOPE)
endfunction()

# ---- presets ------------------------------------------------------------------
# Reads the configure presets of one file. The arrays stay parallel: index i of
# each output belongs to preset i.
function(_cx_read_presets_file file out_names out_display out_hidden out_conditions)
    set(_names "")
    set(_display "")
    set(_hidden "")
    set(_conditions "")
    if(EXISTS "${file}")
        file(READ "${file}" _json)
        string(JSON _count ERROR_VARIABLE _error LENGTH "${_json}" configurePresets)
        if(NOT _error AND _count GREATER 0)
            set(_i 0)
            while(_i LESS _count)
                string(JSON _name GET "${_json}" configurePresets ${_i} name)
                string(JSON _shown ERROR_VARIABLE _error GET
                       "${_json}" configurePresets ${_i} displayName)
                if(_error)
                    set(_shown "-")
                endif()
                string(JSON _flag ERROR_VARIABLE _error GET
                       "${_json}" configurePresets ${_i} hidden)
                if(_error)
                    set(_flag "OFF")
                endif()
                string(JSON _condition ERROR_VARIABLE _error GET
                       "${_json}" configurePresets ${_i} condition)
                if(_error)
                    # A sentinel, not "": list(APPEND) drops an empty value
                    # from an empty list, which would shift every later row.
                    set(_condition "{}")
                endif()
                list(APPEND _names "${_name}")
                list(APPEND _display "${_shown}")
                list(APPEND _hidden "${_flag}")
                list(APPEND _conditions "${_condition}")
                math(EXPR _i "${_i} + 1")
            endwhile()
        endif()
    endif()
    set(${out_names} "${_names}" PARENT_SCOPE)
    set(${out_display} "${_display}" PARENT_SCOPE)
    set(${out_hidden} "${_hidden}" PARENT_SCOPE)
    set(${out_conditions} "${_conditions}" PARENT_SCOPE)
endfunction()

# The shared file, then the personal one: a user preset may have any name.
function(_cx_collect_presets out_names out_display out_hidden out_conditions)
    _cx_read_presets_file("${CX_ROOT}/CMakePresets.json"
                          _names _display _hidden _conditions)
    _cx_read_presets_file("${CX_ROOT}/CMakeUserPresets.json"
                          _user_names _user_display _user_hidden _user_conditions)
    list(APPEND _names ${_user_names})
    list(APPEND _display ${_user_display})
    list(APPEND _hidden ${_user_hidden})
    list(APPEND _conditions ${_user_conditions})
    set(${out_names} "${_names}" PARENT_SCOPE)
    set(${out_display} "${_display}" PARENT_SCOPE)
    set(${out_hidden} "${_hidden}" PARENT_SCOPE)
    set(${out_conditions} "${_conditions}" PARENT_SCOPE)
endfunction()

# _cx_json_names(<file> <array> <out>): the "name" of every object in an array.
function(_cx_json_names file array out)
    set(_names "")
    if(EXISTS "${file}")
        file(READ "${file}" _json)
        string(JSON _count ERROR_VARIABLE _error LENGTH "${_json}" "${array}")
        if(NOT _error AND _count GREATER 0)
            set(_i 0)
            while(_i LESS _count)
                string(JSON _name GET "${_json}" "${array}" ${_i} name)
                list(APPEND _names "${_name}")
                math(EXPR _i "${_i} + 1")
            endwhile()
        endif()
    endif()
    set(${out} "${_names}" PARENT_SCOPE)
endfunction()

# The equals and notEquals forms of a preset condition.
function(_cx_condition_equals type text out)
    string(JSON _lhs GET "${_text}" lhs)
    string(JSON _rhs GET "${_text}" rhs)
    if(_lhs STREQUAL _rhs)
        set(_result ON)
    else()
        set(_result OFF)
    endif()
    if(type STREQUAL "notEquals")
        if(_result)
            set(_result OFF)
        else()
            set(_result ON)
        endif()
    endif()
    set(${out} "${_result}" PARENT_SCOPE)
endfunction()

# The inList and notInList forms of a preset condition.
function(_cx_condition_in_list type text out)
    string(JSON _lhs GET "${_text}" lhs)
    string(JSON _count LENGTH "${_text}" list)
    set(_result OFF)
    set(_i 0)
    while(_i LESS _count)
        string(JSON _item GET "${_text}" list ${_i})
        if(_lhs STREQUAL _item)
            set(_result ON)
        endif()
        math(EXPR _i "${_i} + 1")
    endwhile()
    if(type STREQUAL "notInList")
        if(_result)
            set(_result OFF)
        else()
            set(_result ON)
        endif()
    endif()
    set(${out} "${_result}" PARENT_SCOPE)
endfunction()

# Evaluates a preset condition. The template uses equals/notEquals on
# ${hostSystemName}; the other forms are here so a personal preset works too.
function(_cx_condition_ok condition out)
    if(condition STREQUAL "")
        set(${out} ON PARENT_SCOPE)
        return()
    endif()
    set(_host_ref "\${hostSystemName}")
    string(REPLACE "${_host_ref}" "${CMAKE_HOST_SYSTEM_NAME}" _text "${condition}")
    string(JSON _type ERROR_VARIABLE _error GET "${_text}" type)
    if(_error)
        set(${out} ON PARENT_SCOPE)
        return()
    endif()
    if(_type STREQUAL "equals" OR _type STREQUAL "notEquals")
        _cx_condition_equals("${_type}" "${_text}" _result)
    elseif(_type STREQUAL "inList" OR _type STREQUAL "notInList")
        _cx_condition_in_list("${_type}" "${_text}" _result)
    elseif(_type STREQUAL "not")
        string(JSON _inner GET "${_text}" condition)
        _cx_condition_ok("${_inner}" _result)
        if(_result)
            set(_result OFF)
        else()
            set(_result ON)
        endif()
    else()
        # anyOf, allOf and anything newer: fail open rather than hide a preset.
        set(_result ON)
    endif()
    set(${out} "${_result}" PARENT_SCOPE)
endfunction()

# True when <word> is a configure preset. Hidden presets are not user presets,
# and a preset whose condition excludes this machine gets an explanation
# instead of "unknown word".
function(_cx_exact_preset word out)
    _cx_collect_presets(_names _display _hidden _conditions)
    list(FIND _names "${word}" _index)
    if(_index EQUAL -1)
        set(${out} OFF PARENT_SCOPE)
        return()
    endif()
    list(GET _hidden ${_index} _flag)
    if(_flag)
        _cx_fail("preset '${word}' is hidden and cannot be used directly")
    endif()
    list(GET _conditions ${_index} _condition)
    _cx_condition_ok("${_condition}" _ok)
    if(NOT _ok)
        _cx_fail("preset '${word}' is not available on ${CMAKE_HOST_SYSTEM_NAME}: "
                 "its condition excludes this host")
    endif()
    set(${out} ON PARENT_SCOPE)
endfunction()

# debug, except on Windows ARM64 where the ASan runtime may be absent.
function(_cx_default_preset out)
    set(_preset debug)
    if(CMAKE_HOST_WIN32)
        if("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "ARM64"
           OR "$ENV{PROCESSOR_ARCHITEW6432}" STREQUAL "ARM64")
            # The MSVC AddressSanitizer runtime is not part of every Visual
            # Studio install on ARM64 (the same rule new-project.cmake uses).
            set(_preset debug-nosan)
        endif()
    endif()
    set(${out} "${_preset}" PARENT_SCOPE)
endfunction()

# _cx_alias(<word> <out-preset> <out-extra-args> <out-ok>)
function(_cx_alias word out_preset out_extra out_ok)
    set(_preset "")
    set(_extra "")
    if(word STREQUAL "nosan")
        set(_preset debug-nosan)
    elseif(word STREQUAL "gcc")
        set(_preset ci-gcc)
    elseif(word STREQUAL "clang")
        set(_preset ci-clang)
    elseif(word STREQUAL "asan")
        set(_preset debug)
    elseif(word STREQUAL "msan")
        # There is no msan preset: configure the debug preset with the memory
        # sanitizer. The option prefix follows the project name.
        _cx_project_name(_name "")
        string(TOUPPER "${_name}" _upper)
        set(_preset debug)
        set(_extra "-D${_upper}_SANITIZER=memory")
    elseif(word STREQUAL "vs")
        if(CMAKE_HOST_WIN32)
            set(_preset vs2026)
        endif()
    endif()
    set(${out_preset} "${_preset}" PARENT_SCOPE)
    set(${out_extra} "${_extra}" PARENT_SCOPE)
    if(_preset STREQUAL "")
        set(${out_ok} OFF PARENT_SCOPE)
    else()
        set(${out_ok} ON PARENT_SCOPE)
    endif()
endfunction()

# The project name comes from the build cache after a configure, and from the
# project() line before it. Nothing here hard-codes the template's name.
function(_cx_project_name out preset)
    set(_name "")
    if(NOT preset STREQUAL "")
        _cx_build_dir("${preset}" _dir)
        set(_cache "${_dir}/CMakeCache.txt")
        if(EXISTS "${_cache}")
            file(STRINGS "${_cache}" _line REGEX "^CMAKE_PROJECT_NAME:")
            if(_line)
                string(REGEX REPLACE "^CMAKE_PROJECT_NAME:[^=]*=" "" _name "${_line}")
            endif()
        endif()
    endif()
    if(_name STREQUAL "")
        file(STRINGS "${CX_ROOT}/CMakeLists.txt" _line
             REGEX "^project\\([ \t]*[A-Za-z_][A-Za-z0-9_]*")
        if(_line)
            string(REGEX REPLACE "^project\\([ \t]*([A-Za-z_][A-Za-z0-9_]*).*" "\\1"
                   _name "${_line}")
        endif()
    endif()
    set(${out} "${_name}" PARENT_SCOPE)
endfunction()

# _cx_build_dir(<preset> <out>): the folder a preset builds into,
# build/<host OS>/<target arch>/<preset>. The OS is CMake's hostSystemName, the
# same value the presets expand; the arch is the one the build targets, so a
# cross --arch build gets its own folder.
function(_cx_build_dir preset out)
    _cx_host_arch(_host)
    _cx_target_arch("${preset}" "${_host}" _target)
    set(${out} "${CX_ROOT}/build/${CMAKE_HOST_SYSTEM_NAME}/${_target}/${preset}" PARENT_SCOPE)
endfunction()

# _cx_normalize_path(<input> <out>)
function(_cx_normalize_path input out)
    file(TO_CMAKE_PATH "${input}" _path)
    string(REGEX REPLACE "/+$" "" _path "${_path}")
    if(CMAKE_HOST_WIN32)
        string(TOLOWER "${_path}" _path)
    endif()
    set(${out} "${_path}" PARENT_SCOPE)
endfunction()

# _cx_cache_value(<cache> <key> <out>)
function(_cx_cache_value cache key out)
    file(STRINGS "${cache}" _line REGEX "^${key}:[^=]*=")
    if(_line)
        string(REGEX REPLACE "^[^=]*=" "" _value "${_line}")
        set(${out} "${_value}" PARENT_SCOPE)
    else()
        set(${out} "" PARENT_SCOPE)
    endif()
endfunction()

# _cx_validate_build_tree(<preset> <out>)
function(_cx_validate_build_tree preset out)
    _cx_build_dir("${preset}" _dir)
    set(_cache "${_dir}/CMakeCache.txt")
    if(NOT EXISTS "${_cache}")
        set(${out} ON PARENT_SCOPE)
        return()
    endif()
    _cx_normalize_path("${CX_ROOT}" _source)
    _cx_normalize_path("${_dir}" _binary)
    _cx_cache_value("${_cache}" CMAKE_HOME_DIRECTORY _recorded_source)
    _cx_cache_value("${_cache}" CMAKE_CACHEFILE_DIR _recorded_binary)
    _cx_cache_value("${_cache}" CMAKE_TOOLCHAIN_FILE _toolchain)
    _cx_normalize_path("${_recorded_source}" _recorded_source)
    _cx_normalize_path("${_recorded_binary}" _recorded_binary)
    if(NOT _recorded_source STREQUAL _source OR NOT _recorded_binary STREQUAL _binary)
        _cx_fail(
            "${_dir} belongs to another checkout or path.\n"
            "  current source: ${CX_ROOT}\n"
            "  recorded source: ${_recorded_source}\n"
            "Use a new build directory, or explicitly reconfigure with:\n"
            "  cmake --preset ${preset} -B \"${_dir}\" --fresh")
    endif()
    if(_toolchain)
        _cx_normalize_path("${_toolchain}" _toolchain)
        if(NOT EXISTS "${_toolchain}")
            _cx_fail(
                "${_dir} records a missing toolchain:\n"
                "  ${_toolchain}\n"
                "Use a new build directory, or explicitly reconfigure with:\n"
                "  cmake --preset ${preset} -B \"${_dir}\" --fresh")
        endif()
        _cx_normalize_path("${CX_ROOT}/cmake/VcpkgToolchain.cmake" _expected_toolchain)
        if(_toolchain MATCHES "/vcpkgtoolchain\\.cmake$"
           AND NOT _toolchain STREQUAL _expected_toolchain)
            _cx_fail(
                "${_dir} records a toolchain from another checkout:\n"
                "  ${_toolchain}\n"
                "Use a new build directory, or explicitly reconfigure with:\n"
                "  cmake --preset ${preset} -B \"${_dir}\" --fresh")
        endif()
    endif()
    set(${out} OFF PARENT_SCOPE)
endfunction()

# The targets the template defines, plus the three that carry the project's
# own name. Kept in one place so `targets`, `help` and resolution agree.
function(_cx_target_names out)
    _cx_project_name(_name "")
    set(_targets
        format format-check cmake-lint tidy docs coverage fuzz-run package
        install clean all
        "${_name}" "${_name}_lib" "${_name}_tests")
    set(${out} "${_targets}" PARENT_SCOPE)
endfunction()

# True when <word> is one of the build targets.
function(_cx_is_target word out)
    _cx_target_names(_targets)
    if(word IN_LIST _targets)
        set(${out} ON PARENT_SCOPE)
    else()
        set(${out} OFF PARENT_SCOPE)
    endif()
endfunction()

# tidy and the documentation/coverage/fuzz targets only make sense on the
# preset that defines them; the code-quality and packaging targets use release;
# everything else belongs to the everyday debug preset.
function(_cx_target_default_preset target out)
    if(target STREQUAL "tidy")
        set(_preset debug-nosan)
    elseif(target STREQUAL "coverage")
        set(_preset coverage)
    elseif(target STREQUAL "fuzz-run")
        set(_preset fuzz)
    elseif(target STREQUAL "docs")
        set(_preset docs)
    elseif(target MATCHES "^(format|format-check|cmake-lint|package)$")
        set(_preset release)
    else()
        _cx_default_preset(_preset)
    endif()
    set(${out} "${_preset}" PARENT_SCOPE)
endfunction()

# _cx_did_you_mean(<word> <out>): candidates that share the first three letters.
function(_cx_did_you_mean word out)
    string(LENGTH "${word}" _len)
    set(_hits "")
    if(_len GREATER_EQUAL 3)
        string(TOLOWER "${word}" _lower)
        string(SUBSTRING "${_lower}" 0 3 _prefix)
        _cx_collect_presets(_names _display _hidden _conditions)
        _cx_target_names(_targets)
        set(_candidates ${_names} ${_targets} nosan gcc clang asan msan vs release)
        foreach(_candidate IN LISTS _candidates)
            string(TOLOWER "${_candidate}" _candidate_lower)
            string(SUBSTRING "${_candidate_lower}" 0 3 _candidate_prefix)
            if(_candidate_prefix STREQUAL _prefix AND NOT _candidate_lower STREQUAL _lower)
                list(APPEND _hits "${_candidate}")
            endif()
        endforeach()
        list(REMOVE_DUPLICATES _hits)
    endif()
    list(JOIN _hits ", " _joined)
    set(${out} "${_joined}" PARENT_SCOPE)
endfunction()

# The error for a word that is neither a preset, an alias nor a target.
function(_cx_unknown_word word)
    _cx_collect_presets(_names _display _hidden _conditions)
    set(_visible "")
    set(_index 0)
    foreach(_name IN LISTS _names)
        list(GET _hidden ${_index} _flag)
        if(NOT _flag)
            list(APPEND _visible "${_name}")
        endif()
        math(EXPR _index "${_index} + 1")
    endforeach()
    _cx_target_names(_targets)
    list(JOIN _visible ", " _presets)
    list(JOIN _targets ", " _target_text)
    _cx_did_you_mean("${word}" _hint)
    string(CONCAT _message
        "unknown word '${word}'.\n"
        "Presets: ${_presets}\n"
        "Aliases: nosan, gcc, clang, asan, msan, vs\n"
        "Targets: ${_target_text}")
    if(NOT _hint STREQUAL "")
        string(APPEND _message "\nDid you mean ${_hint}?")
    endif()
    _cx_fail("${_message}")
endfunction()

# _cx_resolve(<words> <out-preset> <out-targets> <out-extra-configure-args>)
#
# The one place that turns plain words into a preset and a list of targets.
# One preset word at most; every other word is a target. Without a preset the
# first target's own preset is used (tidy -> debug-nosan, package -> release,
# ...), or the host's default preset when there is no target at all.
function(_cx_resolve words out_preset out_targets out_extra)
    set(_preset "")
    set(_targets "")
    set(_extra "")
    set(_explicit OFF)
    foreach(_word IN LISTS words)
        _cx_exact_preset("${_word}" _is_preset)
        if(_is_preset)
            if(_explicit)
                _cx_fail("only one preset can be named (second one: '${_word}')")
            endif()
            set(_preset "${_word}")
            set(_explicit ON)
            continue()
        endif()
        _cx_alias("${_word}" _alias_preset _alias_extra _alias_ok)
        if(_alias_ok)
            if(_explicit)
                _cx_fail("only one preset can be named (second one: '${_word}')")
            endif()
            _cx_exact_preset("${_alias_preset}" _alias_available)
            set(_preset "${_alias_preset}")
            set(_extra "${_alias_extra}")
            set(_explicit ON)
            continue()
        endif()
        _cx_is_target("${_word}" _is_target)
        if(_is_target)
            list(APPEND _targets "${_word}")
            continue()
        endif()
        _cx_unknown_word("${_word}")
    endforeach()
    if(NOT _explicit)
        if(_targets)
            list(GET _targets 0 _first)
            _cx_target_default_preset("${_first}" _preset)
            foreach(_target IN LISTS _targets)
                _cx_target_default_preset("${_target}" _target_preset)
                if(NOT _target_preset STREQUAL _preset)
                    _cx_fail("targets '${_first}' and '${_target}' use different "
                             "presets ('${_preset}' and '${_target_preset}'); name one")
                endif()
            endforeach()
        else()
            _cx_default_preset(_preset)
        endif()
    endif()
    set(${out_preset} "${_preset}" PARENT_SCOPE)
    set(${out_targets} "${_targets}" PARENT_SCOPE)
    set(${out_extra} "${_extra}" PARENT_SCOPE)
endfunction()

# ---- configure and build ------------------------------------------------------
function(_cx_needs_configure preset out)
    _cx_validate_build_tree("${preset}" _valid)
    _cx_build_dir("${preset}" _dir)
    set(_cache "${_dir}/CMakeCache.txt")
    if(NOT EXISTS "${_cache}")
        set(${out} ON PARENT_SCOPE)
        return()
    endif()
    file(TIMESTAMP "${_cache}" _cache_time "%s" UTC)
    set(_need OFF)
    foreach(_file CMakePresets.json CMakeUserPresets.json CMakeLists.txt)
        if(EXISTS "${CX_ROOT}/${_file}")
            file(TIMESTAMP "${CX_ROOT}/${_file}" _time "%s" UTC)
            if(_time GREATER _cache_time)
                set(_need ON)
            endif()
        endif()
    endforeach()
    # Every CMakeLists.txt in the source tree (not in build/ or docs/).
    file(GLOB_RECURSE _lists RELATIVE "${CX_ROOT}" LIST_DIRECTORIES false
         "${CX_ROOT}/CMakeLists.txt" "${CX_ROOT}/*/CMakeLists.txt"
         "${CX_ROOT}/*/*/CMakeLists.txt")
    foreach(_rel IN LISTS _lists)
        if(_rel MATCHES "^(build|docs|vcpkg_installed)/")
            continue()
        endif()
        file(TIMESTAMP "${CX_ROOT}/${_rel}" _time "%s" UTC)
        if(_time GREATER _cache_time)
            set(_need ON)
        endif()
    endforeach()
    set(${out} "${_need}" PARENT_SCOPE)
endfunction()

# ---- architecture -------------------------------------------------------------
# cx knows three architectures by these names: x64, arm64 and x86. Anything else
# gives "" and the caller decides whether that is an error.
function(_cx_canonical_arch value out)
    string(TOLOWER "${value}" _lower)
    set(_arch "")
    if(_lower MATCHES "^(x64|x86_64|amd64)$")
        set(_arch x64)
    elseif(_lower MATCHES "^(arm64|aarch64)$")
        set(_arch arm64)
    elseif(_lower MATCHES "^(x86|i386|i686|win32)$")
        set(_arch x86)
    endif()
    set(${out} "${_arch}" PARENT_SCOPE)
endfunction()

# The architecture this machine runs cx on.
function(_cx_host_arch out)
    if(CMAKE_HOST_WIN32)
        set(_raw "$ENV{PROCESSOR_ARCHITEW6432}")
        if(_raw STREQUAL "")
            set(_raw "$ENV{PROCESSOR_ARCHITECTURE}")
        endif()
    else()
        # CMAKE_HOST_SYSTEM_PROCESSOR is not set when cmake runs a script.
        execute_process(COMMAND uname -m OUTPUT_VARIABLE _raw
                        OUTPUT_STRIP_TRAILING_WHITESPACE)
    endif()
    _cx_canonical_arch("${_raw}" _arch)
    if(_arch STREQUAL "")
        _cx_fail("cannot tell this machine's architecture from '${_raw}'")
    endif()
    set(${out} "${_arch}" PARENT_SCOPE)
endfunction()

# The architecture a preset builds for, when the preset names one (the Visual
# Studio presets do: "architecture": { "value": "ARM64" }). "" otherwise.
function(_cx_preset_architecture preset out)
    set(_value "")
    foreach(_file IN ITEMS "${CX_ROOT}/CMakePresets.json" "${CX_ROOT}/CMakeUserPresets.json")
        if(EXISTS "${_file}")
            file(READ "${_file}" _json)
            string(JSON _count ERROR_VARIABLE _error LENGTH "${_json}" configurePresets)
            if(NOT _error)
                set(_i 0)
                while(_i LESS _count)
                    string(JSON _name GET "${_json}" configurePresets ${_i} name)
                    if(_name STREQUAL preset)
                        string(JSON _platform ERROR_VARIABLE _error GET
                               "${_json}" configurePresets ${_i} architecture value)
                        if(NOT _error)
                            set(_value "${_platform}")
                        endif()
                    endif()
                    math(EXPR _i "${_i} + 1")
                endwhile()
            endif()
        endif()
    endforeach()
    _cx_canonical_arch("${_value}" _arch)
    set(${out} "${_arch}" PARENT_SCOPE)
endfunction()

# The architecture a build targets, in order: the preset's own (the Visual
# Studio presets name one), then --arch, then this machine's.
function(_cx_target_arch preset host out)
    _cx_preset_architecture("${preset}" _platform)
    if(NOT _platform STREQUAL "" AND NOT CX_ARCH STREQUAL ""
       AND NOT CX_ARCH STREQUAL _platform)
        _cx_fail("preset '${preset}' builds ${_platform}, which conflicts with "
                 "--arch ${CX_ARCH}; use the preset for ${CX_ARCH} or drop --arch")
    endif()
    if(NOT _platform STREQUAL "")
        set(_target "${_platform}")
    elseif(NOT CX_ARCH STREQUAL "")
        set(_target "${CX_ARCH}")
    else()
        set(_target "${host}")
    endif()
    set(${out} "${_target}" PARENT_SCOPE)
endfunction()

# The cmake arguments that select the target on this machine. A preset that
# names its platform gets none: the preset already sets it.
function(_cx_arch_args preset host target out)
    set(_args "")
    _cx_preset_architecture("${preset}" _platform)
    if(_platform STREQUAL "")
        if(CMAKE_HOST_APPLE)
            if(target STREQUAL "x86")
                _cx_fail("macOS does not build for x86 (32-bit); use --arch x64 or arm64")
            endif()
            if(target STREQUAL "x64")
                set(_osx x86_64)
            else()
                set(_osx arm64)
            endif()
            set(_args "-DCMAKE_OSX_ARCHITECTURES=${_osx}")
        elseif(CMAKE_HOST_WIN32)
            # VcpkgToolchain.cmake turns this into the vcpkg triplet. The
            # compiler comes from _cx_arch_env.
            set(_args "-DMYAPP_WINDOWS_TARGET_ARCH=${target}")
        elseif(target STREQUAL host)
            # A native build needs no arguments.
        elseif(host STREQUAL "x64" AND target STREQUAL "x86")
            set(_args
                -DCMAKE_C_FLAGS_INIT=-m32
                -DCMAKE_CXX_FLAGS_INIT=-m32
                -DCMAKE_EXE_LINKER_FLAGS_INIT=-m32
                -DCMAKE_SHARED_LINKER_FLAGS_INIT=-m32
                -DVCPKG_TARGET_TRIPLET=x86-linux)
        else()
            if(target STREQUAL "x86")
                _cx_fail("cannot build for x86 on a Linux ${host} machine")
            endif()
            if(target STREQUAL "arm64")
                set(_triple aarch64-linux-gnu)
                set(_processor aarch64)
            else()
                set(_triple x86_64-linux-gnu)
                set(_processor x86_64)
            endif()
            find_program(_cx_cc NAMES ${_triple}-gcc)
            find_program(_cx_cxx NAMES ${_triple}-g++)
            if(NOT _cx_cc OR NOT _cx_cxx)
                _cx_fail("a ${target} build on ${host} needs the ${_triple} GCC cross "
                         "compiler (${_triple}-gcc and ${_triple}-g++); install it first")
            endif()
            set(_args
                "-DCMAKE_C_COMPILER=${_cx_cc}"
                "-DCMAKE_CXX_COMPILER=${_cx_cxx}"
                -DCMAKE_SYSTEM_NAME=Linux
                "-DCMAKE_SYSTEM_PROCESSOR=${_processor}"
                "-DVCPKG_TARGET_TRIPLET=${target}-linux")
        endif()
    endif()
    set(${out} "${_args}" PARENT_SCOPE)
endfunction()

# Visual Studio's name for an architecture, as vcvarsall.bat takes it.
function(_cx_vcvars_arch arch out)
    if(arch STREQUAL "x64")
        set(_name amd64)
    else()
        set(_name "${arch}")
    endif()
    set(${out} "${_name}" PARENT_SCOPE)
endfunction()

# A Windows build for another architecture runs in that architecture's Visual
# Studio environment (vcvarsall.bat <host>_<target>). The variables it sets are
# applied to this process, so cmake and the build tools it starts inherit them.
# Loaded once per cx run; the global property is the guard.
function(_cx_arch_env preset host target)
    if(NOT CMAKE_HOST_WIN32 OR target STREQUAL host)
        return()
    endif()
    _cx_preset_architecture("${preset}" _platform)
    if(NOT _platform STREQUAL "")
        return()
    endif()
    get_property(_loaded GLOBAL PROPERTY CX_MSVC_ENV SET)
    if(_loaded)
        return()
    endif()

    _cx_vcvars_arch("${host}" _host_name)
    _cx_vcvars_arch("${target}" _target_name)
    set(_combo "${_host_name}_${_target_name}")
    set(_vswhere "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
    if(NOT EXISTS "${_vswhere}")
        _cx_fail("cannot find Visual Studio (vswhere.exe) to build for ${target}")
    endif()
    execute_process(COMMAND "${_vswhere}" -latest -products *
                            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
                            -property installationPath
                    OUTPUT_VARIABLE _install OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(_vcvars "${_install}/VC/Auxiliary/Build/vcvarsall.bat")
    if(_install STREQUAL "" OR NOT EXISTS "${_vcvars}")
        _cx_fail("cannot find the Visual Studio C++ tools for ${_combo}; "
                 "install the MSVC build tools for ${target}")
    endif()

    set(_bat "${CX_ROOT}/build/cx-msvc-${_combo}.bat")
    file(WRITE "${_bat}"
         "@echo off\r\ncall \"${_vcvars}\" ${_combo} >nul\r\nif errorlevel 1 exit /b 1\r\nset\r\n")
    execute_process(COMMAND cmd /c "${_bat}"
                    OUTPUT_VARIABLE _env RESULT_VARIABLE _result)
    file(REMOVE "${_bat}")
    if(NOT _result EQUAL 0)
        _cx_fail("could not load the ${_combo} environment from ${_vcvars}")
    endif()

    # Semicolons are escaped while the lines are split, so a PATH stays whole.
    string(REPLACE ";" "\\;" _env "${_env}")
    string(REPLACE "\r\n" "\n" _env "${_env}")
    string(REPLACE "\n" ";" _lines "${_env}")
    foreach(_line IN LISTS _lines)
        string(FIND "${_line}" "=" _eq)
        if(_eq GREATER 0)
            string(SUBSTRING "${_line}" 0 ${_eq} _name)
            math(EXPR _start "${_eq} + 1")
            string(SUBSTRING "${_line}" ${_start} -1 _value)
            string(REPLACE "\\;" ";" _value "${_value}")
            set(ENV{${_name}} "${_value}")
        endif()
    endforeach()
    set_property(GLOBAL PROPERTY CX_MSVC_ENV ON)
endfunction()

# True when the build folder was configured for another architecture. A folder
# with no record counts as the host's: it is only stale for another target.
function(_cx_arch_mismatch preset host target out)
    set(_mismatch OFF)
    _cx_build_dir("${preset}" _dir)
    set(_cache "${_dir}/CMakeCache.txt")
    if(EXISTS "${_cache}")
        _cx_cache_value("${_cache}" CX_TARGET_ARCH _recorded)
        if(_recorded STREQUAL "")
            set(_recorded "${host}")
        endif()
        if(NOT _recorded STREQUAL target)
            set(_mismatch ON)
        endif()
    endif()
    set(${out} "${_mismatch}" PARENT_SCOPE)
endfunction()

# Run cmake --preset for <preset>; the result is the exit code. The target
# architecture picks the arguments, and the arguments after -- (CX_CMAKE_ARGS)
# come last, so they can override them.
function(_cx_configure preset out_result)
    _cx_host_arch(_host)
    _cx_target_arch("${preset}" "${_host}" _target)
    _cx_arch_env("${preset}" "${_host}" "${_target}")
    _cx_arch_mismatch("${preset}" "${_host}" "${_target}" _mismatch)
    _cx_arch_args("${preset}" "${_host}" "${_target}" _arch_args)
    _cx_build_dir("${preset}" _dir)
    set(_args --preset "${preset}" -B "${_dir}")
    if(CX_FRESH OR _mismatch)
        list(APPEND _args --fresh)
    endif()
    list(APPEND _args "-DCX_TARGET_ARCH=${_target}" ${_arch_args})
    if(NOT CX_CONFIGURE_EXTRA STREQUAL "")
        list(APPEND _args ${CX_CONFIGURE_EXTRA})
    endif()
    if(NOT CX_CMAKE_ARGS STREQUAL "")
        list(APPEND _args ${CX_CMAKE_ARGS})
    endif()
    _cx_run(${CMAKE_COMMAND} ${_args})
    set(${out_result} "${CX_RUN_RESULT}" PARENT_SCOPE)
endfunction()

# Configure only when the build folder is missing or stale, when its target
# architecture differs, or when -- gives cmake arguments. The Visual Studio
# environment is loaded here too, because the build step runs the compiler.
function(_cx_ensure_configured preset out_result)
    _cx_host_arch(_host)
    _cx_target_arch("${preset}" "${_host}" _target)
    _cx_arch_env("${preset}" "${_host}" "${_target}")
    _cx_needs_configure("${preset}" _need)
    _cx_arch_mismatch("${preset}" "${_host}" "${_target}" _mismatch)
    if(_mismatch OR NOT CX_CMAKE_ARGS STREQUAL "")
        set(_need ON)
    endif()
    if(NOT _need)
        set(${out_result} 0 PARENT_SCOPE)
        return()
    endif()
    _cx_configure("${preset}" _result)
    set(${out_result} "${_result}" PARENT_SCOPE)
endfunction()

# _cx_refind(<preset> <out-result> <TOOL>...): reconfigure <preset> when its
# cache recorded any <NAME>_<TOOL> (e.g. CMAKE_LINT) as not found. find_program
# only searches again on a configure, so a tool installed after the first
# configure would otherwise stay missing and its target undefined.
function(_cx_refind preset out_result)
    set(${out_result} 0 PARENT_SCOPE)
    _cx_build_dir("${preset}" _dir)
    set(_cache "${_dir}/CMakeCache.txt")
    if(NOT EXISTS "${_cache}")
        return()
    endif()
    _cx_project_name(_name "${preset}")
    string(TOUPPER "${_name}" _upper)
    foreach(_tool IN LISTS ARGN)
        file(STRINGS "${_cache}" _line REGEX "^${_upper}_${_tool}:[^=]*=.*-NOTFOUND$")
        # The line ends in -NOTFOUND, which if(_line) reads as false.
        if(NOT _line STREQUAL "")
            _cx_configure("${preset}" _result)
            set(${out_result} "${_result}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
endfunction()

# Run cmake --build for <preset> and the optional targets.
function(_cx_build preset targets out_result)
    _cx_build_dir("${preset}" _dir)
    set(_args --build "${_dir}")
    if(preset MATCHES "^vs")
        list(APPEND _args --config Debug)
    endif()
    if(NOT targets STREQUAL "")
        list(APPEND _args --target ${targets})
    endif()
    if(CX_VERBOSE)
        list(APPEND _args --verbose)
    endif()
    _cx_run(${CMAKE_COMMAND} ${_args})
    set(${out_result} "${CX_RUN_RESULT}" PARENT_SCOPE)
endfunction()

# Stop an existing instance of the program before `cx run` rebuilds it.
function(_cx_stop_program program)
    get_filename_component(_name "${program}" NAME)
    if(CMAKE_HOST_WIN32)
        find_program(_taskkill NAMES taskkill)
        if(_taskkill)
            execute_process(COMMAND "${_taskkill}" /IM "${_name}" /T /F
                            OUTPUT_QUIET ERROR_QUIET)
        endif()
    else()
        find_program(_pkill NAMES pkill)
        if(_pkill)
            execute_process(COMMAND "${_pkill}" -TERM -x "${_name}"
                            OUTPUT_QUIET ERROR_QUIET)
        endif()
    endif()
endfunction()

# Run ctest --preset for <preset>, with any arguments after --.
function(_cx_ctest preset out_result)
    if(NOT CX_CTEST)
        _cx_fail("ctest was not found next to cmake")
    endif()
    _cx_build_dir("${preset}" _dir)
    set(_args --preset "${preset}" --test-dir "${_dir}")
    if(CX_VERBOSE)
        list(APPEND _args -V)
    endif()
    if(CX_PASSTHROUGH)
        list(APPEND _args ${CX_PASSTHROUGH})
    endif()
    _cx_run("${CX_CTEST}" ${_args})
    set(${out_result} "${CX_RUN_RESULT}" PARENT_SCOPE)
endfunction()

# True when the preset has a matching test preset.
function(_cx_test_preset_exists preset out)
    _cx_json_names("${CX_ROOT}/CMakePresets.json" testPresets _shared)
    _cx_json_names("${CX_ROOT}/CMakeUserPresets.json" testPresets _user)
    set(_names ${_shared} ${_user})
    if(preset IN_LIST _names)
        set(${out} ON PARENT_SCOPE)
    else()
        set(${out} OFF PARENT_SCOPE)
    endif()
endfunction()

# _cx_program_path(<preset> <out-path> <out-is-app>)
# Visual Studio presets are multi-config: the build preset selects Debug, so
# the program sits one folder deeper than with Ninja.
function(_cx_program_path preset out_path out_is_app)
    _cx_project_name(_name "${preset}")
    _cx_is_library(_library "${preset}")
    if(_library)
        set(${out_is_app} OFF PARENT_SCOPE)
        set(${out_path} "" PARENT_SCOPE)
        return()
    endif()
    _cx_build_dir("${preset}" _dir)
    if(preset MATCHES "^vs")
        string(APPEND _dir "/Debug")
    endif()
    set(_suffix "")
    if(CMAKE_HOST_WIN32)
        set(_suffix ".exe")
    endif()
    set(${out_path} "${_dir}/${_name}${_suffix}" PARENT_SCOPE)
    set(${out_is_app} ON PARENT_SCOPE)
endfunction()

# _cx_is_library(<out-var> <preset>)
# True for a library project. The configured cache wins; before the first
# configure the default in cmake/Options.cmake is read (the generator flips
# that default to ON for a library). The absence of main.cpp is the last
# resort, for projects that do not have Options.cmake.
function(_cx_is_library out preset)
    _cx_project_name(_name "")
    string(TOUPPER "${_name}" _upper)
    _cx_build_dir("${preset}" _dir)
    set(_cache "${_dir}/CMakeCache.txt")
    if(EXISTS "${_cache}")
        file(STRINGS "${_cache}" _line REGEX "^${_upper}_LIBRARY_MODE:BOOL=ON")
        if(_line)
            set(${out} ON PARENT_SCOPE)
            return()
        endif()
        file(STRINGS "${_cache}" _line REGEX "^${_upper}_LIBRARY_MODE:BOOL=OFF")
        if(_line)
            set(${out} OFF PARENT_SCOPE)
            return()
        endif()
    endif()
    set(_options "${CX_ROOT}/cmake/Options.cmake")
    if(EXISTS "${_options}")
        file(READ "${_options}" _text)
        if(_text MATCHES
           "option\\(${_upper}_LIBRARY_MODE[ \t\r\n]+\"[^\"]*\"[ \t\r\n]+(ON|OFF)\\)")
            if(CMAKE_MATCH_1 STREQUAL "ON")
                set(${out} ON PARENT_SCOPE)
            else()
                set(${out} OFF PARENT_SCOPE)
            endif()
            return()
        endif()
    endif()
    if(EXISTS "${CX_ROOT}/main.cpp")
        set(${out} OFF PARENT_SCOPE)
    else()
        set(${out} ON PARENT_SCOPE)
    endif()
endfunction()

# ---- project files -------------------------------------------------------------
function(_cx_project_version out)
    set(_version "")
    if(EXISTS "${CX_ROOT}/VERSION")
        file(READ "${CX_ROOT}/VERSION" _text)
        string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+" _version "${_text}")
    endif()
    set(${out} "${_version}" PARENT_SCOPE)
endfunction()

# ---- command discovery ---------------------------------------------------------
function(_cx_command_names out)
    file(GLOB _files RELATIVE "${CX_COMMANDS_DIR}" "${CX_COMMANDS_DIR}/*.cmake")
    set(_names "")
    foreach(_file IN LISTS _files)
        get_filename_component(_name "${_file}" NAME_WE)
        list(APPEND _names "${_name}")
    endforeach()
    list(SORT _names)
    set(${out} "${_names}" PARENT_SCOPE)
endfunction()

# The comment block at the top of a command file: its first line is the
# one-line summary `cx help` prints, the rest is the usage `cx help <command>`
# prints. Reading the file instead of a central table is what lets a new
# command be just a new file.
function(_cx_command_header command out)
    set(_file "${CX_COMMANDS_DIR}/${command}.cmake")
    set(_header "")
    if(EXISTS "${_file}")
        file(STRINGS "${_file}" _lines)
        foreach(_line IN LISTS _lines)
            if(NOT _line MATCHES "^#")
                break()
            endif()
            string(REGEX REPLACE "^# ?" "" _text "${_line}")
            string(APPEND _header "${_text}\n")
        endforeach()
        string(REGEX REPLACE "\n$" "" _header "${_header}")
    endif()
    set(${out} "${_header}" PARENT_SCOPE)
endfunction()
