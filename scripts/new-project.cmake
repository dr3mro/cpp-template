# =============================================================================
# new-project.cmake - create a new C++ project from this template
#
#   cmake -P scripts/new-project.cmake -- <name> [destination-dir] [options]
#
# Usually run through scripts/new-project.sh or scripts/new-project.ps1, which
# only find cmake and pass their arguments on. One implementation for every
# system: CMake is already needed to build the project, so the generator
# needs nothing else (no bash, perl, Python or PowerShell features).
#
# Options (each also in the PowerShell spelling, e.g. -Std 20, -NoGit, and
# with an equals sign, e.g. --std=20):
#   --std 17|20|23          C++ standard (default 17)
#   --lib                   an installable library package instead of an app
#   --no-git                do not create a git repository
#   --no-vcpkg              no vcpkg: the dependencies are built from their
#                           source with FetchContent instead
#   --github-user <user>    fill in the README's GitHub Pages docs link
#   --author <name>         name in main.cpp's header comment
#                           (default: git config user.name, then "Your Name")
#   -h, --help              print this text
#
# The same settings can be given before -P (cmake -DNAME=bank_app -DSTD=20
# -DLIB=ON -DNO_VCPKG=ON -P ...), and a personal defaults file can set AUTHOR,
# GITHUB_USER, STD and NO_VCPKG once for every project:
#   Linux, macOS  $XDG_CONFIG_HOME/cpp-template/defaults.cmake
#                 (or ~/.config/cpp-template/defaults.cmake)
#   Windows       %APPDATA%\cpp-template\defaults.cmake
# Command-line options win over -D values, and -D values over that file.
#
# The template is copied (only the files git tracks, when it is a checkout),
# every "myapp"/"MYAPP" is renamed in paths and in file contents, the Visual
# Studio project gets a fresh GUID, and the files for the other mode are
# dropped. See the wiki page "Creating a project".
# =============================================================================
cmake_minimum_required(VERSION 3.25)

get_filename_component(_template_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(_cwd "${CMAKE_CURRENT_BINARY_DIR}") # the current directory in script mode

# ---- output -------------------------------------------------------------------
# message() writes to stderr and decorates its text, so plain output (the
# next steps, the usage) goes to stdout through `cmake -E cat`.
function(_say text)
    string(RANDOM LENGTH 12 _tag)
    set(_tmp "${_cwd}")
    foreach(_var TMPDIR TEMP TMP)
        if(DEFINED ENV{${_var}} AND IS_DIRECTORY "$ENV{${_var}}")
            file(TO_CMAKE_PATH "$ENV{${_var}}" _tmp)
            break()
        endif()
    endforeach()
    set(_file "${_tmp}/new-project-${_tag}.txt")
    file(WRITE "${_file}" "${text}\n")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E cat "${_file}")
    file(REMOVE "${_file}")
endfunction()

set(_usage [=[
Usage: new-project <name> [destination-dir] [options]

Create a new C++ project from this template.

Options:
  --std 17|20|23         C++ standard (default 17)
  --lib                  an installable library package instead of an app
  --no-git               do not create a git repository
  --no-vcpkg             no vcpkg: the dependencies are built from their
                         source with FetchContent instead
  --github-user <user>   fill in the README's GitHub Pages docs link
  --author <name>        name in main.cpp's header comment
                         (default: git config user.name, then "Your Name")
  -h, --help             print this text

PowerShell spellings work too: -Std 20, -Lib, -NoGit, -NoVcpkg,
-GitHubUser <user>, -Author <name>. Values may also follow an equals sign:
--std=20.

<name> is a lower_snake_case C++ identifier, e.g. bank_app. It becomes the
CMake project, the executable, the namespace and the include/<name>/ folder.]=])

# Stops with "error: <text>", without CMake's own decoration where the
# running CMake allows it (cmake_language(EXIT) is 3.29+).
function(_fail)
    string(CONCAT text ${ARGV})
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.29)
        message(NOTICE "error: ${text}")
        cmake_language(EXIT 1)
    endif()
    message(FATAL_ERROR "error: ${text}")
endfunction()

# ---- settings: defaults file, then -D values, then the command line -----------
foreach(_var NAME DEST STD LIB NO_GIT NO_VCPKG GITHUB_USER AUTHOR)
    if(DEFINED ${_var})
        set(_from_d_${_var} "${${_var}}")
        set(_has_d_${_var} ON)
    endif()
endforeach()

if(CMAKE_HOST_WIN32 AND DEFINED ENV{APPDATA})
    set(_defaults_file "$ENV{APPDATA}/cpp-template/defaults.cmake")
elseif(DEFINED ENV{XDG_CONFIG_HOME} AND NOT "$ENV{XDG_CONFIG_HOME}" STREQUAL "")
    set(_defaults_file "$ENV{XDG_CONFIG_HOME}/cpp-template/defaults.cmake")
elseif(DEFINED ENV{HOME})
    set(_defaults_file "$ENV{HOME}/.config/cpp-template/defaults.cmake")
endif()
set(STD "")
set(AUTHOR "")
set(GITHUB_USER "")
if(_defaults_file AND EXISTS "${_defaults_file}")
    include("${_defaults_file}")
endif()
foreach(_var NAME DEST STD LIB NO_GIT NO_VCPKG GITHUB_USER AUTHOR)
    if(_has_d_${_var})
        set(${_var} "${_from_d_${_var}}")
    endif()
endforeach()

# The arguments after "--", read straight from CMAKE_ARGV<n>: a CMake list
# would split a value that contains a semicolon or a bracket. Both spellings
# name the same option: compare the name in lower case without its dashes
# (--no-git, -NoGit -> nogit).
set(_i 1)
while(_i LESS CMAKE_ARGC AND NOT "${CMAKE_ARGV${_i}}" STREQUAL "--")
    math(EXPR _i "${_i} + 1")
endwhile()
math(EXPR _i "${_i} + 1")

set(_seen "")
set(_help OFF)
while(_i LESS CMAKE_ARGC)
    set(_arg "${CMAKE_ARGV${_i}}")
    math(EXPR _i "${_i} + 1")
    if(NOT _arg MATCHES "^-")
        if(NOT DEFINED _cli_name)
            set(_cli_name "${_arg}")
        elseif(NOT DEFINED _cli_dest)
            set(_cli_dest "${_arg}")
        else()
            _fail("unexpected argument: ${_arg}")
        endif()
        continue()
    endif()
    set(_has_value OFF)
    if(_arg MATCHES "^([^=]+)=")
        set(_option "${CMAKE_MATCH_1}")
        string(LENGTH "${_option}" _cut)
        math(EXPR _cut "${_cut} + 1")
        string(SUBSTRING "${_arg}" ${_cut} -1 _value)
        set(_has_value ON)
    else()
        set(_option "${_arg}")
    endif()
    string(TOLOWER "${_option}" _key)
    string(REGEX REPLACE "^-+" "" _key "${_key}")
    string(REPLACE "-" "" _key "${_key}")
    if(_key MATCHES "^(std|githubuser|author)$")
        if(NOT _has_value)
            if(NOT _i LESS CMAKE_ARGC)
                _fail("missing value for ${_option}")
            endif()
            set(_value "${CMAKE_ARGV${_i}}")
            math(EXPR _i "${_i} + 1")
        endif()
    elseif(_key MATCHES "^(lib|nogit|novcpkg)$")
        if(_has_value)
            _fail("${_option} takes no value")
        endif()
    elseif(_key MATCHES "^(h|help|\\?)$")
        set(_help ON)
        continue()
    else()
        _fail("unknown option: ${_arg}")
    endif()
    if(_key IN_LIST _seen)
        _fail("${_option} is given twice")
    endif()
    list(APPEND _seen ${_key})
    if(_key STREQUAL "std")
        set(STD "${_value}")
    elseif(_key STREQUAL "githubuser")
        set(GITHUB_USER "${_value}")
    elseif(_key STREQUAL "author")
        set(AUTHOR "${_value}")
    elseif(_key STREQUAL "lib")
        set(LIB ON)
    elseif(_key STREQUAL "nogit")
        set(NO_GIT ON)
    elseif(_key STREQUAL "novcpkg")
        set(NO_VCPKG ON)
    endif()
endwhile()
if(DEFINED _cli_name)
    set(NAME "${_cli_name}")
endif()
if(DEFINED _cli_dest)
    set(DEST "${_cli_dest}")
endif()

if(_help)
    _say("${_usage}")
    return()
endif()
if(NOT NAME)
    _say("${_usage}")
    _fail("the project name is missing")
endif()
if(STD STREQUAL "")
    set(STD 17)
endif()

# ---- validate ------------------------------------------------------------------
if(NOT NAME MATCHES "^[a-z][a-z0-9_]*$")
    _fail("name must be lower_snake_case, e.g. bank_app")
endif()
# Names that would produce a project that does not build, or one that breaks
# the rules of C++: keywords, the reserved std/posix namespaces, targets that
# CMake or the template already define, the test framework, and names Windows
# does not allow for a file or folder.
set(_reserved
    alignas alignof and and_eq asm auto bitand bitor bool break case catch char
    char8_t char16_t char32_t class compl concept const consteval constexpr
    constinit const_cast continue co_await co_return co_yield decltype default
    delete do double dynamic_cast else enum explicit export extern false float
    for friend goto if inline int long mutable namespace new noexcept not not_eq
    nullptr operator or or_eq private protected public register reinterpret_cast
    requires return short signed sizeof static static_assert static_cast struct
    switch template this thread_local throw true try typedef typeid typename
    union unsigned using virtual void volatile wchar_t while xor xor_eq
    std posix
    all clean help install install_local install_strip test package
    package_source edit_cache rebuild_cache list_install_components
    docs format tidy coverage distclean doctest example fuzz_greeter
    con prn aux nul com1 com2 com3 com4 com5 com6 com7 com8 com9
    lpt1 lpt2 lpt3 lpt4 lpt5 lpt6 lpt7 lpt8 lpt9)
if(NAME IN_LIST _reserved)
    _fail("'${NAME}' cannot be a project name: it is a C++ keyword, a reserved "
          "namespace, a build target name or a reserved Windows name. Pick "
          "another, e.g. ${NAME}_app")
endif()
# Identifiers with a double underscore are reserved for the implementation.
if(NAME MATCHES "__" OR NAME MATCHES "_$")
    _fail("name must not contain \"__\" or end with \"_\"")
endif()
if(NOT STD MATCHES "^(17|20|23)$")
    _fail("--std must be 17, 20 or 23")
endif()
if(NOT GITHUB_USER STREQUAL "" AND NOT GITHUB_USER MATCHES "^[A-Za-z0-9-]+$")
    _fail("--github-user must be a GitHub user name (letters, digits, -)")
endif()
if(AUTHOR MATCHES "[\r\n]")
    _fail("--author must be a single line")
endif()

find_program(_git git)
if(AUTHOR STREQUAL "" AND _git)
    execute_process(COMMAND "${_git}" config user.name
        OUTPUT_VARIABLE AUTHOR OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
endif()
if(AUTHOR STREQUAL "")
    set(AUTHOR "Your Name")
endif()

if(NOT DEST)
    set(DEST "${NAME}")
endif()
# C:\dev\bank -> C:/dev/bank: cmake_path() and the file() commands want the
# CMake spelling.
file(TO_CMAKE_PATH "${DEST}" DEST)
cmake_path(ABSOLUTE_PATH DEST BASE_DIRECTORY "${_cwd}" NORMALIZE)
string(REGEX REPLACE "(.)/$" "\\1" DEST "${DEST}")
if(EXISTS "${DEST}")
    _fail("${DEST} already exists")
endif()

string(TOUPPER "${NAME}" _upper)
if(LIB)
    set(_lib ON)
else()
    set(_lib OFF)
endif()

_say("Creating ${NAME} in ${DEST} (C++${STD})")

# ---- the files to copy -----------------------------------------------------------
# Only what git tracks (plus new files that are not ignored yet), so build
# output and other ignored clutter never travel along. Without git (a zip
# download), everything except the usual generated folders.
set(_files "")
set(_use_git OFF)
if(_git)
    execute_process(COMMAND "${_git}" -C "${_template_dir}" rev-parse --is-inside-work-tree
        OUTPUT_VARIABLE _inside OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _result ERROR_QUIET)
    if(_result EQUAL 0 AND _inside STREQUAL "true")
        set(_use_git ON)
    endif()
endif()
if(_use_git)
    # core.quotepath=off keeps non-ASCII names as they are; a name git still
    # has to quote (a newline, a quote) is not a template file.
    execute_process(
        COMMAND "${_git}" -C "${_template_dir}" -c core.quotepath=off
                ls-files --cached --others --exclude-standard
        OUTPUT_VARIABLE _listing RESULT_VARIABLE _result)
    if(NOT _result EQUAL 0)
        _fail("git ls-files failed in ${_template_dir}")
    endif()
    string(REPLACE ";" "\\;" _listing "${_listing}")
    string(REPLACE "\n" ";" _listing "${_listing}")
    foreach(_rel IN LISTS _listing)
        if(NOT _rel STREQUAL "" AND NOT _rel MATCHES "^\"" AND EXISTS "${_template_dir}/${_rel}"
           AND NOT IS_DIRECTORY "${_template_dir}/${_rel}")
            list(APPEND _files "${_rel}")
        endif()
    endforeach()
else()
    file(GLOB_RECURSE _files RELATIVE "${_template_dir}" LIST_DIRECTORIES false
         "${_template_dir}/*")
    list(FILTER _files EXCLUDE REGEX
         "^(\\.git|build|docs|install[^/]*|vcpkg_installed|vcpkg-binary-cache|\\.cache|\\.xfer)/")
    list(FILTER _files EXCLUDE REGEX "(^|/)\\.DS_Store$")
endif()
# Template-only files: the generator, the template's own tests and notes, and
# the wiki (it documents the template, not the new project).
list(FILTER _files EXCLUDE REGEX "^scripts/new-project\\.(sh|ps1|cmake)$")
list(FILTER _files EXCLUDE REGEX "^\\.github/workflows/(template-test|wiki)\\.yml$")
list(FILTER _files EXCLUDE REGEX "^(\\.gitmodules|NOTES\\.md|wiki/.*)$")
list(REMOVE_DUPLICATES _files)

# ---- copy, renaming the placeholder in paths and in contents ----------------------
# The app project and the test project are two projects, so each carries its
# own placeholder GUID and gets its own fresh one.
set(_template_guid "3F2A6B1C-9D4E-4C7A-8B5F-1E2D3C4B5A69")
set(_template_test_guid "9C8D7E6F-5A4B-4C3D-8E2F-1A2B3C4D5E6F")
# cmakelang predates file(COPY_FILE) (CMake 3.21) and reports a false
# "invalid form discriminator" for it.
# cmake-lint: disable=E1126

# A random name hashed into a UUID: string(UUID) only makes name-based ones.
string(RANDOM LENGTH 32 _seed)
string(TIMESTAMP _now "%s%f")
string(UUID _guid NAMESPACE 6ba7b810-9dad-11d1-80b4-00c04fd430c8
       NAME "${_seed}${_now}${NAME}" TYPE SHA1 UPPER)
string(RANDOM LENGTH 32 _seed_tests)
string(UUID _guid_tests NAMESPACE 6ba7b810-9dad-11d1-80b4-00c04fd430c8
       NAME "${_seed_tests}${_now}${NAME}_tests" TYPE SHA1 UPPER)

# _rename_path(<relative path> <out-var>): the path with the placeholder renamed.
function(_rename_path rel out_var)
    string(REPLACE "MYAPP" "${_upper}" rel "${rel}")
    string(REPLACE "myapp" "${NAME}" rel "${rel}")
    set(${out_var} "${rel}" PARENT_SCOPE)
endfunction()

# _write_like(<hex of the original> <file> <text>) writes <text> with the line
# endings the original had: CRLF (the Visual Studio files, or anything in a
# Windows checkout) or LF (the shell scripts, which need it everywhere).
# file(READ) drops the CRs, and on Windows file(WRITE) adds one to every LF,
# so neither keeps line endings: file(CONFIGURE ... NEWLINE_STYLE) writes
# exactly the ones asked for. @ and "cmakedefine" are escaped so that
# configuring changes nothing else.
function(_write_like hex path text)
    if(hex MATCHES "^([0-9a-f][0-9a-f])*0d0a")
        set(_style CRLF)
    else()
        set(_style UNIX)
    endif()
    string(REPLACE "\r\n" "\n" text "${text}")
    string(REPLACE "@" "@_wl_at@" text "${text}")
    string(REPLACE "cmakedefine" "@_wl_cmakedefine@" text "${text}")
    set(_wl_at "@")
    set(_wl_cmakedefine "cmakedefine")
    file(CONFIGURE OUTPUT "${path}" CONTENT "${text}" @ONLY NEWLINE_STYLE ${_style})
endfunction()

foreach(_rel IN LISTS _files)
    _rename_path("${_rel}" _new_rel)
    set(_source "${_template_dir}/${_rel}")
    set(_target "${DEST}/${_new_rel}")
    get_filename_component(_target_dir "${_target}" DIRECTORY)
    file(MAKE_DIRECTORY "${_target_dir}")
    # A file with a NUL byte in its first 8 KB is binary (as `grep -I` sees
    # it): it is copied as it is. file(READ) keeps every other byte, CRLF line
    # endings included.
    file(READ "${_source}" _head LIMIT 8192 HEX)
    if(_head MATCHES "^([0-9a-f][0-9a-f])*00" OR _rel MATCHES "\\.(png|jpe?g|gif|ico)$")
        file(COPY_FILE "${_source}" "${_target}")
        continue()
    endif()
    # Copy first, so the file keeps its permissions, then rewrite it if the
    # placeholder occurs in it.
    file(COPY_FILE "${_source}" "${_target}")
    file(READ "${_source}" _text)
    set(_new "${_text}")
    string(REPLACE "${_template_guid}" "${_guid}" _new "${_new}")
    string(REPLACE "${_template_test_guid}" "${_guid_tests}" _new "${_new}")
    string(REPLACE "MYAPP" "${_upper}" _new "${_new}")
    string(REPLACE "myapp" "${NAME}" _new "${_new}")
    string(REPLACE "@AUTHOR@" "${AUTHOR}" _new "${_new}")
    if(NOT _new STREQUAL _text)
        _write_like("${_head}" "${_target}" "${_new}")
    endif()
endforeach()

# Edits one copied file in place: _edit(<path> <regex> <replacement>) or, with
# LITERAL first, a plain text replacement.
function(_edit path)
    if(NOT EXISTS "${DEST}/${path}")
        return()
    endif()
    file(READ "${DEST}/${path}" _text)
    if(ARGV1 STREQUAL "LITERAL")
        string(REPLACE "${ARGV2}" "${ARGV3}" _new "${_text}")
    else()
        string(REGEX REPLACE "${ARGV1}" "${ARGV2}" _new "${_text}")
    endif()
    if(NOT _new STREQUAL _text)
        file(READ "${DEST}/${path}" _head LIMIT 8192 HEX)
        _write_like("${_head}" "${DEST}/${path}" "${_new}")
    endif()
endfunction()

# vcpkg package names allow hyphens but not underscores. The manifest carries
# the name and the dependencies; the version lives in the VERSION file.
string(REPLACE "_" "-" _vcpkg_name "${NAME}")
_edit(vcpkg.json "\"name\": \"[^\"]+\"" "\"name\": \"${_vcpkg_name}\"")

# ---- C++ standard -----------------------------------------------------------------
_edit(src/CMakeLists.txt LITERAL "cxx_std_17" "cxx_std_${STD}")
# clang-format knows c++17 and c++20 but has no c++23 (Latest is the newest
# it knows).
if(STD STREQUAL "23")
    set(_format_std "Latest")
else()
    set(_format_std "c++${STD}")
endif()
_edit(.clang-format "(^|\n)Standard: c\\+\\+17" "\\1Standard: ${_format_std}")
# Visual Studio 2019 and 2022 have no "stdcpp23", so C++23 maps to the latest.
if(STD STREQUAL "17")
    set(_vs_std stdcpp17)
elseif(STD STREQUAL "20")
    set(_vs_std stdcpp20)
else()
    set(_vs_std stdcpplatest)
endif()
# The standard is a setting every project of the template shares, so it lives
# in the property sheet (<name>.props), not in the project file.
_edit(${NAME}.props LITERAL "stdcpp17" "${_vs_std}")

# ---- README -------------------------------------------------------------------------
file(REMOVE "${DEST}/README.md")
file(RENAME "${DEST}/PROJECT_README.md" "${DEST}/README.md")
if(GITHUB_USER STREQUAL "")
    _edit(README.md LITERAL "@GITHUB_USER@" "your-github-user")
else()
    _edit(README.md LITERAL "@GITHUB_USER@" "${GITHUB_USER}")
endif()

# ---- documentation ------------------------------------------------------------------
# The template's CHANGELOG is the template's history, not the project's: the
# project starts with an empty one (the part before the first release).
if(EXISTS "${DEST}/CHANGELOG.md")
    file(READ "${DEST}/CHANGELOG.md" _changelog)
    string(FIND "${_changelog}" "\n## [Unreleased]" _at)
    if(_at GREATER -1)
        string(SUBSTRING "${_changelog}" 0 ${_at} _changelog)
        file(WRITE "${DEST}/CHANGELOG.md" "${_changelog}\n## [Unreleased]\n")
    endif()
endif()
# Parts of the docs that are about the template itself sit between
# <!-- template-only --> and <!-- /template-only --> lines, and are left out.
file(GLOB_RECURSE _docs "${DEST}/*.md")
foreach(_doc IN LISTS _docs)
    file(READ "${_doc}" _text)
    if(_text MATCHES "<!-- template-only -->")
        set(_section "\n?<!-- template-only -->[^<]*(<[^!][^<]*)*<!-- /template-only -->\n?")
        string(REGEX REPLACE "${_section}" "\n" _text "${_text}")
        file(WRITE "${_doc}" "${_text}")
    endif()
endforeach()

# ---- code owners --------------------------------------------------------------------
# The template's CODEOWNERS names its own author. A project is owned by its
# GitHub user when one was given, and has no CODEOWNERS otherwise.
if(EXISTS "${DEST}/.github/CODEOWNERS")
    if(GITHUB_USER STREQUAL "")
        file(REMOVE "${DEST}/.github/CODEOWNERS")
    else()
        file(WRITE "${DEST}/.github/CODEOWNERS"
             "# Every change is reviewed by the owner.\n* @${GITHUB_USER}\n")
    endif()
endif()

# ---- which template made this project ----------------------------------------------
# A project never changes with the template, so record where it came from:
# the template's release tag (template-vX.Y.Z), or "unreleased" plus the
# commit when the template has no tag yet.
set(_template_version "unreleased")
if(_use_git)
    execute_process(
        COMMAND "${_git}" -C "${_template_dir}" describe --tags --match "template-v*"
                --always --dirty
        OUTPUT_VARIABLE _described OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    if(_described MATCHES "^template-v")
        set(_template_version "${_described}")
    elseif(_described)
        set(_template_version "unreleased (${_described})")
    endif()
endif()
file(WRITE "${DEST}/.template-version"
     "cpp-template ${_template_version}\nhttps://github.com/dr3mro/cpp-template\n")

# _drop_lines(<file> <regex>): removes the lines that match <regex> (Zed's
# tasks.json keeps one task per line). Walks the text with string(FIND), like
# _json_drop below, because a CMake list would split on brackets.
function(_drop_lines path regex)
    if(NOT EXISTS "${DEST}/${path}")
        return()
    endif()
    file(READ "${DEST}/${path}" _rest)
    set(_out "")
    while(NOT _rest STREQUAL "")
        string(FIND "${_rest}" "\n" _at)
        if(_at EQUAL -1)
            set(_line "${_rest}")
            set(_rest "")
            set(_eol "")
        else()
            string(SUBSTRING "${_rest}" 0 ${_at} _line)
            math(EXPR _at "${_at} + 1")
            string(SUBSTRING "${_rest}" ${_at} -1 _rest)
            set(_eol "\n")
        endif()
        if(NOT _line MATCHES "${regex}")
            string(APPEND _out "${_line}${_eol}")
        endif()
    endwhile()
    file(WRITE "${DEST}/${path}" "${_out}")
endfunction()

# ---- JSON editing (the editor configuration) --------------------------------------
# _json_drop(<file> <indent> <regex>): removes from <file> the array entries
# that start with "{" on a line of their own, indented by <indent> spaces, and
# whose text matches <regex>. Line based on purpose: string(JSON) would sort
# every object's keys and change the layout of the whole file. The result is
# checked with string(JSON), so a template change that breaks the layout
# fails here instead of producing a broken file.
function(_json_drop path indent regex)
    if(NOT EXISTS "${DEST}/${path}")
        return()
    endif()
    file(READ "${DEST}/${path}" _rest)
    string(REPEAT " " ${indent} _pad)
    # Walk the text line by line with string(FIND): a CMake list would split
    # differently on the brackets and semicolons that JSON is full of.
    set(_out "")
    set(_block "")
    set(_in_block OFF)
    while(NOT _rest STREQUAL "")
        string(FIND "${_rest}" "\n" _at)
        if(_at EQUAL -1)
            set(_line "${_rest}")
            set(_rest "")
            set(_eol "")
        else()
            string(SUBSTRING "${_rest}" 0 ${_at} _line)
            math(EXPR _at "${_at} + 1")
            string(SUBSTRING "${_rest}" ${_at} -1 _rest)
            set(_eol "\n")
        endif()
        if(NOT _in_block AND _line STREQUAL "${_pad}{")
            set(_in_block ON)
            set(_block "${_line}${_eol}")
        elseif(_in_block)
            string(APPEND _block "${_line}${_eol}")
            if(_line MATCHES "^${_pad}},?$")
                set(_in_block OFF)
                if(NOT _block MATCHES "${regex}")
                    string(APPEND _out "${_block}")
                endif()
            endif()
        else()
            string(APPEND _out "${_line}${_eol}")
        endif()
    endwhile()
    # Dropping the last entry leaves a comma before the closing bracket.
    string(REGEX REPLACE "},(\n *\\])" "}\\1" _out "${_out}")
    string(JSON _type ERROR_VARIABLE _error TYPE "${_out}")
    if(_error)
        message(FATAL_ERROR "new-project: editing ${path} broke it: ${_error}")
    endif()
    file(WRITE "${DEST}/${path}" "${_out}")
endfunction()

# _json_remove_key(<file> <key>): removes <key> from every object in <file>.
# Line based, like _json_drop, so the layout of the file stays as it is. A key
# that is the last one of its object leaves a comma behind, which JSON does not
# allow, so that comma goes too. The result is checked with string(JSON), so a
# template change that breaks the file fails here instead of producing a
# broken file.
function(_json_remove_key path key)
    if(NOT EXISTS "${DEST}/${path}")
        return()
    endif()
    file(READ "${DEST}/${path}" _rest)
    set(_out "")
    while(NOT _rest STREQUAL "")
        string(FIND "${_rest}" "\n" _at)
        if(_at EQUAL -1)
            set(_line "${_rest}")
            set(_rest "")
            set(_eol "")
        else()
            string(SUBSTRING "${_rest}" 0 ${_at} _line)
            math(EXPR _at "${_at} + 1")
            string(SUBSTRING "${_rest}" ${_at} -1 _rest)
            set(_eol "\n")
        endif()
        if(NOT _line MATCHES "\"${key}\"[ \t]*:")
            string(APPEND _out "${_line}${_eol}")
        endif()
    endwhile()
    # The key was the last one of its object: the comma before the closing
    # brace goes too.
    string(REGEX REPLACE ",(\n[ ]*\\})" "\\1" _out "${_out}")
    string(JSON _type ERROR_VARIABLE _error TYPE "${_out}")
    if(_error)
        message(FATAL_ERROR "new-project: editing ${path} broke it: ${_error}")
    endif()
    file(WRITE "${DEST}/${path}" "${_out}")
endfunction()

# _drop_dependabot_ecosystem(<ecosystem>): removes the Dependabot update
# block for one package ecosystem, and the comment above it. Dependabot has no
# baseline to advance without a manifest, and it fails on a manifest it cannot
# find.
function(_drop_dependabot_ecosystem ecosystem)
    if(NOT EXISTS "${DEST}/.github/dependabot.yml")
        return()
    endif()
    file(READ "${DEST}/.github/dependabot.yml" _text)
    # The block: the "- package-ecosystem:" line and the indented lines below
    # it.
    set(_block "\n  - package-ecosystem: ${ecosystem}\n(    [^\n]*\n)+")
    string(REGEX REPLACE "${_block}" "" _text "${_text}")
    # The comment above the block, which would describe a block that is gone.
    string(REGEX REPLACE "\n  #[^\n]*${ecosystem}[^\n]*" "" _text "${_text}")
    # No empty line at the end of the file.
    string(REGEX REPLACE "\n+$" "\n" _text "${_text}")
    file(WRITE "${DEST}/.github/dependabot.yml" "${_text}")
endfunction()

# ---- app or library ------------------------------------------------------------------
set(_workflows "${DEST}/.github/workflows")
if(_lib)
    _edit(cmake/Options.cmake
          "(option\\(${_upper}_LIBRARY_MODE[ \t\r\n]+\"[^\"]*\"[ \t\r\n]+)OFF\\)" "\\1ON)")
    file(REMOVE "${DEST}/main.cpp")
    # The Visual Studio project needs no change: it builds a static library
    # when main.cpp is missing, and an executable when it is there.

    # A library has no executable: drop the run tasks and the app debug
    # configuration. Zed's tasks.json keeps one task per line.
    _drop_lines(.zed/tasks.json "\"label\": \"run( debug)?\"")
    _json_drop(.zed/debug.json 2 "\"label\": \"Debug ${NAME}\"")
    _json_drop(.vscode/tasks.json 4 "\"label\": \"run\"")
    _json_drop(.vscode/launch.json 4 "\"name\": \"Debug ${NAME}\"")

    file(REMOVE "${_workflows}/release-app.yml")
    if(EXISTS "${_workflows}/release-lib.yml")
        file(RENAME "${_workflows}/release-lib.yml" "${_workflows}/release.yml")
    endif()
else()
    file(REMOVE_RECURSE "${DEST}/examples")
    file(REMOVE "${_workflows}/release-lib.yml")
    if(EXISTS "${_workflows}/release-app.yml")
        file(RENAME "${_workflows}/release-app.yml" "${_workflows}/release.yml")
    endif()
endif()

# ---- without vcpkg -------------------------------------------------------------------
# A project without vcpkg gets its dependencies from their source, with
# FetchContent (see cmake/FetchDependencies.cmake). Nothing here needs a
# package manager, so the manifest, the toolchain file and the Dependabot
# block for vcpkg go away.
if(NO_VCPKG)
    # The manifest is what vcpkg reads. Without it there is nothing to install.
    file(REMOVE "${DEST}/vcpkg.json")

    # The switch that tells the build not to use vcpkg. The template has it on,
    # so only the value of the option changes.
    _edit(cmake/PreProject.cmake
          "(option\\(${_upper}_USE_VCPKG[ \t\r\n]+\"[^\"]*\"[ \t\r\n]+)ON\\)" "\\1OFF)")

    # The presets must not point at the vcpkg toolchain any more: the toolchain
    # would install the manifest, and there is no manifest.
    _json_remove_key(CMakePresets.json toolchainFile)

    # Dependabot has no vcpkg baseline to advance.
    _drop_dependabot_ecosystem(vcpkg)
endif()

# ---- git --------------------------------------------------------------------------------
if(NOT NO_GIT AND _git)
    execute_process(COMMAND "${_git}" init -q -b main WORKING_DIRECTORY "${DEST}"
        RESULT_VARIABLE _r1 OUTPUT_QUIET ERROR_QUIET)
    execute_process(COMMAND "${_git}" add -A WORKING_DIRECTORY "${DEST}"
        RESULT_VARIABLE _r2 OUTPUT_QUIET ERROR_QUIET)
    execute_process(COMMAND "${_git}" commit -qm "Initial commit from C++ template"
        WORKING_DIRECTORY "${DEST}" RESULT_VARIABLE _r3 OUTPUT_QUIET ERROR_QUIET)
    if(_r1 EQUAL 0 AND _r2 EQUAL 0 AND _r3 EQUAL 0)
        _say("Initialised git repository on branch main")
    else()
        message(WARNING "git commit failed; set user.name and user.email, then commit yourself.")
    endif()
endif()

# ---- next steps ---------------------------------------------------------------------------
# The text below is printed as it is written, and some of its command lines
# are longer than the 100 columns cmake-lint allows for code.
# cmake-lint: disable=C0301
set(_vcpkg_ready OFF)
if(DEFINED ENV{VCPKG_ROOT} AND EXISTS "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
    set(_vcpkg_ready ON)
endif()
# The Windows text can be shown elsewhere for testing with
# MYAPP_FORCE_WINDOWS=1 (not part of the usage text).
set(_on_windows ${CMAKE_HOST_WIN32})
if("$ENV{MYAPP_FORCE_WINDOWS}" STREQUAL "1")
    set(_on_windows ON)
endif()

if(_on_windows)
    # The architecture, in the spelling the developer shell uses (-Arch).
    set(_arch amd64)
    if("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "ARM64"
       OR "$ENV{PROCESSOR_ARCHITEW6432}" STREQUAL "ARM64")
        set(_arch arm64)
    endif()
    # On ARM64 the MSVC AddressSanitizer runtime is not part of every Visual
    # Studio install, so the everyday debug build there is debug-nosan.
    set(_debug_preset debug)
    if(_arch STREQUAL "arm64")
        set(_debug_preset debug-nosan)
    endif()

    # The developer shell of the newest Visual Studio with the C++ tools for
    # this architecture.
    set(_dev_shell "")
    set(_vswhere "$ENV{ProgramFiles\(x86\)}/Microsoft Visual Studio/Installer/vswhere.exe")
    if(EXISTS "${_vswhere}")
        if(_arch STREQUAL "arm64")
            set(_component Microsoft.VisualStudio.Component.VC.Tools.ARM64)
        else()
            set(_component Microsoft.VisualStudio.Component.VC.Tools.x86.x64)
        endif()
        execute_process(COMMAND "${_vswhere}" -latest -products * -requires ${_component}
                                -property installationPath
            OUTPUT_VARIABLE _vs OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
        string(REGEX REPLACE "[\r\n].*" "" _vs "${_vs}")
        if(_vs AND EXISTS "${_vs}/Common7/Tools/Launch-VsDevShell.ps1")
            file(TO_NATIVE_PATH "${_vs}/Common7/Tools/Launch-VsDevShell.ps1" _dev_shell)
        endif()
    endif()

    # One command per line: Windows PowerShell 5.1 (the default shell on
    # Windows) cannot chain commands with &&. -SkipAutomaticLocation keeps the
    # developer shell in the project folder.
    file(TO_NATIVE_PATH "${DEST}" _native_dest)
    set(_text [=[

Done. Next steps:

  cd "@_native_dest@"  # the new project folder

]=])
    if(_dev_shell)
        string(APPEND _text [=[
  # 1) Open a developer shell for this machine (@_arch@):
  & "@_dev_shell@" -Arch @_arch@ -HostArch @_arch@ -SkipAutomaticLocation
]=])
    else()
        string(APPEND _text [=[
  # 1) Open a developer shell for this machine (@_arch@) from the Start menu
  #    (Developer PowerShell for VS), or start it yourself with:
  #    & "<VS path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch @_arch@ -HostArch @_arch@ -SkipAutomaticLocation
]=])
    endif()
    string(APPEND _text [=[

  # 2) From the project folder, build with CMake:
  cmake --preset @_debug_preset@
  cmake --build --preset @_debug_preset@
  ctest --preset @_debug_preset@
]=])
    if(_debug_preset STREQUAL "debug-nosan")
        string(APPEND _text [=[
  #    (the debug preset uses ASan, which needs the "C++ AddressSanitizer"
  #    component of the Visual Studio Installer on ARM64)
]=])
    endif()
    string(APPEND _text [=[
  cmake --preset release
  cmake --build --preset release
  ctest --preset release
]=])
    if(_lib)
        string(APPEND _text [=[
  cmake --install build/release
  cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH="$PWD/build/install/release"
  cmake --build build/examples
]=])
    endif()
    string(APPEND _text [=[

  # 3) Or open the solution in Visual Studio (2019, 2022 or 2026), no CMake needed:
  start @NAME@.sln]=])
else()
    set(_text [=[

Done. Next steps:

  cd "@DEST@"  # the new project folder

  cmake --preset debug && cmake --build --preset debug && ctest --preset debug
  # ...or the optimised build:
]=])
    if(_lib)
        # Install from release: the debug preset is ASan-instrumented, so a
        # consumer linked against it would fail without the same flags.
        string(APPEND _text [=[
  cmake --preset release && cmake --build --preset release
  cmake --install build/release
  cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH=$PWD/build/install/release && cmake --build build/examples
  zed .]=])
    else()
        string(APPEND _text [=[
  cmake --preset release && cmake --build --preset release && ctest --preset release
  zed .]=])
    endif()
endif()
string(CONFIGURE "${_text}" _text @ONLY)
_say("${_text}")

if(NO_VCPKG)
    set(_text [=[

  This project has no vcpkg: the dependencies are downloaded and built from
  their source (FetchContent) during the first configure, so that one needs a
  network connection. See README.md for details.]=])
    _say("${_text}")
elseif(NOT _vcpkg_ready)
    set(_text [=[

vcpkg is not set up yet (VCPKG_ROOT missing or invalid), so a CMake build
will fail. The Visual Studio solution does not need it. One-time setup
(a full clone: vcpkg.json pins a baseline commit, so no --depth 1):

]=])
    if(_on_windows)
        string(APPEND _text [=[
  git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
  C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics
  [Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")

Then open a new terminal (and restart Visual Studio).
]=])
    else()
        string(APPEND _text [=[
  git clone https://github.com/microsoft/vcpkg.git ~/.vcpkg
  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
  export VCPKG_ROOT="$HOME/.vcpkg"     # add this line to your shell profile
]=])
    endif()
    string(APPEND _text "\nSee README.md for details.")
    _say("${_text}")
endif()
