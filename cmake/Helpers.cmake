# =============================================================================
# Helpers.cmake - small functions shared by the other modules
#
# Included first, before project(), so it may only use what CMake knows that
# early (no PROJECT_* variables, no compiler information).
#
# Provides:
#   MYAPP_LLVM_HINTS               Homebrew's LLVM bin directories
#   myapp_read_manifest_version()  read "version" from vcpkg.json
#   myapp_find_llvm_program()      find clang-format, llvm-cov, clang++, ...
#   myapp_find_dependency()        find_package() + record it for the package config
#   myapp_regex_escape()           make a path safe to use as a regular expression
# =============================================================================
include_guard(GLOBAL)

# Homebrew installs LLVM outside PATH (Apple Silicon, then Intel prefix). Every
# LLVM tool lookup searches these before PATH, so a newer Homebrew LLVM wins
# over an older system copy.
set(MYAPP_LLVM_HINTS /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin)

# myapp_read_manifest_version(<out-var> <vcpkg.json>)
#
# vcpkg.json's "version" field is the project's single source of truth, so the
# CMake project version and the manifest can never disagree.
function(myapp_read_manifest_version out_var manifest)
    file(READ "${manifest}" _json)
    string(JSON _version ERROR_VARIABLE _error GET "${_json}" version)
    if(_error)
        message(FATAL_ERROR "Could not read \"version\" from ${manifest}: ${_error}")
    endif()
    set(${out_var} "${_version}" PARENT_SCOPE)
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
        string(JOIN " " _myapp_dep_call ${_myapp_dep_package} ${_myapp_dep_UNPARSED_ARGUMENTS})
        # A global property, so Install.cmake can read it from any directory.
        set_property(GLOBAL APPEND PROPERTY MYAPP_PACKAGE_DEPENDENCIES "${_myapp_dep_call}")
    endif()
endmacro()
