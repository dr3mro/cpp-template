# =============================================================================
# Helpers.cmake - small functions shared by the other modules
#
# Included first, before project(), so it may only use what CMake knows that
# early (no PROJECT_* variables, no compiler information).
#
# Provides:
#   MYAPP_LLVM_HINTS               LLVM bin directories to search before PATH
#   myapp_read_version()           read the version from the VERSION file
#   myapp_find_llvm_program()      find clang-format, llvm-cov, clang++, ...
#   myapp_find_msvc_cl()           find cl.exe in the Visual Studio tools
#   myapp_find_dependency()        find_package() + record it for the package config
#   myapp_regex_escape()           make a path safe to use as a regular expression
# =============================================================================
include_guard(GLOBAL)

# Homebrew installs LLVM outside PATH (Apple Silicon, then Intel prefix). Every
# LLVM tool lookup searches these before PATH, so a newer Homebrew LLVM wins
# over an older system copy. The Windows installer puts LLVM in Program Files
# and only adds it to the PATH of new shells, so look there as well.
set(MYAPP_LLVM_HINTS /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin
                     "C:/Program Files/LLVM/bin")

# myapp_read_version(<out-var> <VERSION file>)
#
# VERSION is the project's single source of truth for its version: the first
# line holds it, and nothing else may follow on that line. The version has to
# be MAJOR.MINOR.PATCH, because CMake splits it into the three numbers the
# project() command and the SOVERSION use.
function(myapp_read_version out_var version_file)
    if(NOT EXISTS "${version_file}")
        message(FATAL_ERROR
            "Could not read the version from ${version_file}: the file does not exist")
    endif()
    file(READ "${version_file}" _content)
    # Only the first line: the file holds the version and nothing else, but a
    # stray second line should not turn into part of the version.
    string(REGEX MATCH "^([^\r\n]*)" _first_line "${_content}")
    string(STRIP "${_first_line}" _version)
    string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+$" _match "${_version}")
    if(NOT _match)
        message(FATAL_ERROR
            "Could not read the version from ${version_file}: expected a version like 0.1.0")
    endif()
    set(${out_var} "${_version}" PARENT_SCOPE)
    # The version reaches project(), the version header and the installed
    # package, so it is read at configure time. Watching the file makes a
    # changed version re-run the configure step: a plain build would keep the
    # version of the last configure.
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${version_file}")
endfunction()

# myapp_validate_build_tree(<source dir>)
#
# A build directory records the source tree and toolchain it was configured
# with. Reusing it from another checkout, or after moving the project, mixes
# objects from two trees without any warning, so stop with instructions to
# start with a fresh build directory instead.
function(myapp_validate_build_tree source_dir)
    if(NOT DEFINED CMAKE_HOME_DIRECTORY)
        return()
    endif()
    file(TO_CMAKE_PATH "${CMAKE_HOME_DIRECTORY}" _recorded_source)
    file(TO_CMAKE_PATH "${source_dir}" _source)
    file(TO_CMAKE_PATH "${CMAKE_CACHEFILE_DIR}" _recorded_binary)
    file(TO_CMAKE_PATH "${CMAKE_BINARY_DIR}" _binary)
    string(REGEX REPLACE "/+$" "" _recorded_source "${_recorded_source}")
    string(REGEX REPLACE "/+$" "" _source "${_source}")
    string(REGEX REPLACE "/+$" "" _recorded_binary "${_recorded_binary}")
    string(REGEX REPLACE "/+$" "" _binary "${_binary}")
    if(CMAKE_HOST_WIN32)
        string(TOLOWER "${_recorded_source}" _recorded_source)
        string(TOLOWER "${_source}" _source)
        string(TOLOWER "${_recorded_binary}" _recorded_binary)
        string(TOLOWER "${_binary}" _binary)
    endif()
    if(NOT _recorded_source STREQUAL _source
       OR (NOT _recorded_binary STREQUAL "" AND NOT _recorded_binary STREQUAL _binary))
        message(FATAL_ERROR
            "This build directory belongs to another checkout or path.\n"
            "  current source: ${_source}\n"
            "  recorded source: ${_recorded_source}\n"
            "  current build:  ${_binary}\n"
            "  recorded build: ${_recorded_binary}\n"
            "Use a new build directory, or explicitly reconfigure with:\n"
            "  cmake --preset <preset> --fresh")
    endif()
    if(DEFINED CMAKE_TOOLCHAIN_FILE AND NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        message(FATAL_ERROR
            "This build directory records a missing toolchain:\n"
            "  ${CMAKE_TOOLCHAIN_FILE}\n"
            "Use a new build directory, or explicitly reconfigure with:\n"
            "  cmake --preset <preset> --fresh")
    endif()
    if(DEFINED CMAKE_TOOLCHAIN_FILE)
        get_filename_component(_toolchain_name "${CMAKE_TOOLCHAIN_FILE}" NAME)
        if(_toolchain_name STREQUAL "VcpkgToolchain.cmake"
           AND NOT CMAKE_TOOLCHAIN_FILE STREQUAL
               "${source_dir}/cmake/VcpkgToolchain.cmake")
            message(FATAL_ERROR
                "This build directory records a toolchain from another checkout:\n"
                "  ${CMAKE_TOOLCHAIN_FILE}\n"
                "Use a new build directory, or explicitly reconfigure with:\n"
                "  cmake --preset <preset> --fresh")
        endif()
    endif()
endfunction()

# myapp_find_llvm_program(<var> <name>... [NEXT_TO_COMPILER])
#
# find_program() for an LLVM tool, searching Homebrew's LLVM before PATH. With
# NEXT_TO_COMPILER, the directory of the active C++ compiler is searched first,
# so tools such as llvm-cov always match the clang that built the code.
# The result is cached in <var>, like find_program().
function(myapp_find_llvm_program var)
    cmake_parse_arguments(ARG "NEXT_TO_COMPILER" "" "" ${ARGN})
    set(_hints "")
    if(ARG_NEXT_TO_COMPILER AND CMAKE_CXX_COMPILER)
        get_filename_component(_compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
        list(APPEND _hints "${_compiler_dir}")
    endif()
    find_program(${var} NAMES ${ARG_UNPARSED_ARGUMENTS} HINTS ${_hints} ${MYAPP_LLVM_HINTS})
endfunction()

# myapp_find_msvc_cl(<out-var> <host-arch> <target-arch>)
#
# Finds cl.exe in the Visual Studio tools of the current developer shell. The
# tools live in bin/Host<host arch>/<target arch>/. The result is empty
# outside a developer shell.
function(myapp_find_msvc_cl out_var host_arch target_arch)
    set(_hints "")
    if(DEFINED ENV{VCToolsInstallDir})
        if(target_arch STREQUAL "x64")
            set(_msvc_target "amd64")
        else()
            set(_msvc_target "${target_arch}")
        endif()
        list(APPEND _hints
            "$ENV{VCToolsInstallDir}/bin/Host${host_arch}/${_msvc_target}"
            "$ENV{VCToolsInstallDir}/bin/Hostx64/${_msvc_target}"
            "$ENV{VCToolsInstallDir}/bin/${_msvc_target}")
    endif()
    find_program(_cl NAMES cl HINTS ${_hints})
    # find_program() caches its result; this lookup must not leave an entry
    # behind, so it is not part of the project's configuration.
    unset(_cl CACHE)
    set(${out_var} "${_cl}" PARENT_SCOPE)
endfunction()

# myapp_regex_escape(<out-var> <text>)
#
# Escapes the characters that mean something in a regular expression, so a
# path can be used as one. A project folder may contain spaces, '+' or other
# characters that would otherwise change the meaning of the pattern (and
# silently match nothing).
function(myapp_regex_escape out_var text)
    string(REGEX REPLACE "([]^$.|?*+(){}\\\\])" "\\\\\\1" _escaped "${text}")
    set(${out_var} "${_escaped}" PARENT_SCOPE)
endfunction()

# myapp_find_dependency(<package> [PUBLIC] [find_package arguments...])
#
# Runs find_package(<package> ... REQUIRED). With PUBLIC, the same call is also
# recorded so the installed <name>Config.cmake repeats it with
# find_dependency(): use PUBLIC for every package whose targets the library
# links PUBLIC, otherwise consumers of the installed package fail to configure.
#
#   myapp_find_dependency(fmt PUBLIC CONFIG)
#   myapp_find_dependency(Threads)
#
# A macro (not a function) so the package's result variables, such as
# <package>_FOUND, stay visible to the caller.
macro(myapp_find_dependency _myapp_dep_package)
    cmake_parse_arguments(_myapp_dep "PUBLIC" "" "" ${ARGN})
    find_package(${_myapp_dep_package} ${_myapp_dep_UNPARSED_ARGUMENTS} REQUIRED)
    if(_myapp_dep_PUBLIC)
        string(JOIN " " _myapp_dep_call
            ${_myapp_dep_package} ${_myapp_dep_UNPARSED_ARGUMENTS})
        # A global property, so Install.cmake can read it from any directory.
        set_property(GLOBAL APPEND PROPERTY MYAPP_PACKAGE_DEPENDENCIES "${_myapp_dep_call}")
    endif()
endmacro()
