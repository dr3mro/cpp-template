# new-class - generate a paired .hpp / .cpp for a new class
#
# Usage:
#   cx new-class [path/]ClassName [namespace] [--no-test]
#
# The path before the last / sets the subdirectory under include/ and src/.
# The namespace defaults to the project name plus the path segments, but can
# be overridden with a second argument. A matching test file is created in
# tests/ unless --no-test is given.
#
# Examples
#   cx new-class Parser
#       include/myapp/parser.hpp          namespace myapp
#       tests/test_parser.cpp
#
#   cx new-class parser/Parser
#       include/myapp/parser/parser.hpp   namespace myapp::parser
#       tests/test_parser.cpp
#
#   cx new-class core/network/HttpClient
#       include/myapp/core/network/http_client.hpp   namespace myapp::core::network
#       tests/test_http_client.cpp
#
#   cx new-class parser/Parser myapp::io
#       include/myapp/parser/parser.hpp   namespace myapp::io
#       tests/test_parser.cpp
#
#   cx new-class parser/Parser --no-test
#       include/myapp/parser/parser.hpp   (no test file)

# ---- helpers ------------------------------------------------------------------

function(_cx_to_snake_case input output_var)
    string(REGEX REPLACE "([a-z0-9])([A-Z])" "\\1_\\2" _s "${input}")
    string(REGEX REPLACE "([A-Z]+)([A-Z][a-z])" "\\1_\\2" _s "${_s}")
    string(TOLOWER "${_s}" _s)
    set(${output_var} "${_s}" PARENT_SCOPE)
endfunction()

# ---- parse arguments ---------------------------------------------------------

# --no-test is parsed by cx.cmake into CX_NO_TEST; collect remaining words.
set(_no_test "${CX_NO_TEST}")
set(_pos_words "")
foreach(_w IN LISTS CX_WORDS)
    if(_w MATCHES "^-")
        _cx_fail("unknown option for new-class: ${_w}")
    else()
        list(APPEND _pos_words "${_w}")
    endif()
endforeach()

list(LENGTH _pos_words _nwords)
if(_nwords EQUAL 0)
    _cx_fail("cx new-class requires a class name.\n"
             "Usage: cx new-class [path/]ClassName [namespace] [--no-test]\n"
             "       cx new-class Parser\n"
             "       cx new-class parser/Parser\n"
             "       cx new-class parser/Parser myapp::io")
endif()
if(_nwords GREATER 2)
    _cx_fail("cx new-class takes at most two positional arguments.\n"
             "Usage: cx new-class [path/]ClassName [namespace] [--no-test]")
endif()

list(GET _pos_words 0 _input)

# Normalise :: to / so both spellings work.
string(REPLACE "::" "/" _input "${_input}")

if(NOT _input MATCHES "^[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)*$")
    _cx_fail("'${_input}' is not a valid input.\n"
             "Expected something like Parser, parser/Parser, or core/network/HttpClient")
endif()

# Optional explicit namespace (second positional arg).
set(_explicit_ns "")
if(_nwords EQUAL 2)
    list(GET _pos_words 1 _explicit_ns)
    string(REPLACE "/" "::" _explicit_ns "${_explicit_ns}")
    if(NOT _explicit_ns MATCHES "^[A-Za-z_][A-Za-z0-9_]*((::[A-Za-z_][A-Za-z0-9_]*)*)$")
        _cx_fail("'${_explicit_ns}' is not a valid namespace.\n"
                 "Expected something like myapp::core or myapp/core")
    endif()
endif()

# ---- detect source file extension --------------------------------------------

if(EXISTS "${CX_ROOT}/main.cc")
    set(_src_ext "cc")
    set(_hdr_ext "h")
else()
    set(_src_ext "cpp")
    set(_hdr_ext "hpp")
endif()

# ---- discover project name ---------------------------------------------------

file(READ "${CX_ROOT}/CMakeLists.txt" _cml)
string(REGEX MATCH "project\\([ \t\n]*([A-Za-z0-9_-]+)" _m "${_cml}")
set(_project "${CMAKE_MATCH_1}")
if(_project STREQUAL "")
    _cx_fail("could not determine project name from CMakeLists.txt")
endif()

# ---- split path/ClassName ----------------------------------------------------

string(REPLACE "/" ";" _parts "${_input}")
list(LENGTH _parts _nparts)
math(EXPR _last "${_nparts} - 1")
list(GET _parts ${_last} _class_name)

set(_subpath_parts "")
if(_nparts GREATER 1)
    math(EXPR _sub_end "${_nparts} - 2")
    foreach(_i RANGE 0 ${_sub_end})
        list(GET _parts ${_i} _p)
        list(APPEND _subpath_parts "${_p}")
    endforeach()
endif()

set(_dir_parts "${_project}" ${_subpath_parts})
list(JOIN _dir_parts "/" _subpath)

if(NOT _explicit_ns STREQUAL "")
    set(_namespace "${_explicit_ns}")
else()
    set(_ns_parts "${_project}" ${_subpath_parts})
    list(JOIN _ns_parts "::" _namespace)
endif()

# ---- derive file names -------------------------------------------------------

_cx_to_snake_case("${_class_name}" _snake)
string(TOUPPER "${_project}" _PROJECT)
string(REPLACE "-" "_" _PROJECT "${_PROJECT}")

set(_hpp_dir  "${CX_ROOT}/include/${_subpath}")
set(_cpp_dir  "${CX_ROOT}/src/${_subpath}")
set(_hpp_path "${_hpp_dir}/${_snake}.${_hdr_ext}")
set(_cpp_path "${_cpp_dir}/${_snake}.${_src_ext}")
set(_rel_include "${_subpath}/${_snake}.${_hdr_ext}")
set(_test_path "${CX_ROOT}/tests/test_${_snake}.${_src_ext}")

# ---- guard against overwrite -------------------------------------------------

if(EXISTS "${_hpp_path}")
    _cx_fail("file already exists: ${_hpp_path}")
endif()
if(EXISTS "${_cpp_path}")
    _cx_fail("file already exists: ${_cpp_path}")
endif()
if(NOT _no_test AND EXISTS "${_test_path}")
    _cx_fail("file already exists: ${_test_path}\n"
             "Use --no-test to skip test generation.")
endif()

# ---- write the header --------------------------------------------------------

file(MAKE_DIRECTORY "${_hpp_dir}")
file(WRITE "${_hpp_path}"
"#pragma once

/**
 * @file ${_snake}.${_hdr_ext}
 * @brief TODO: describe ${_class_name}.
 */

#include <${_project}/${_project}_export.h>

namespace ${_namespace}
{
    /** @brief TODO: describe ${_class_name}. */
    class ${_PROJECT}_EXPORT ${_class_name}
    {
    public:
        explicit ${_class_name}();
        ~${_class_name}();

    private:
    }; // class ${_class_name}
} // namespace ${_namespace}
")

# ---- write the source --------------------------------------------------------

file(MAKE_DIRECTORY "${_cpp_dir}")
file(WRITE "${_cpp_path}"
"/**
 * @file ${_snake}.${_src_ext}
 * @brief Implements ${_class_name}.
 */

#include \"${_rel_include}\"

namespace ${_namespace}
{
    ${_class_name}::${_class_name}() = default;

    ${_class_name}::~${_class_name}() = default;
} // namespace ${_namespace}
")

# ---- write the test ----------------------------------------------------------

if(NOT _no_test)
    file(WRITE "${_test_path}"
"/**
 * @file test_${_snake}.${_src_ext}
 * @brief Unit tests for ${_namespace}::${_class_name}.
 */

#include \"${_rel_include}\"
#include <doctest/doctest.h>

TEST_CASE(\"${_class_name} - TODO\")
{
    // TODO: write tests for ${_class_name}
}
")
endif()

# ---- report ------------------------------------------------------------------

_cx_say("created  ${_hpp_path}")
_cx_say("created  ${_cpp_path}")
if(NOT _no_test)
    _cx_say("created  ${_test_path}")
endif()
_cx_say("")

set(_cmake_hint "")
foreach(_d "${_cpp_dir}" "${CX_ROOT}/src/${_project}")
    if(EXISTS "${_d}/CMakeLists.txt")
        file(RELATIVE_PATH _cmake_hint "${CX_ROOT}" "${_d}/CMakeLists.txt")
        break()
    endif()
endforeach()
if(NOT _cmake_hint STREQUAL "")
    _cx_say("Next:     add ${_snake}.${_src_ext} to ${_cmake_hint}")
endif()
