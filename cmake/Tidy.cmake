# =============================================================================
# Tidy.cmake - clang-tidy over the whole project
#
#   tidy  run clang-tidy (checks from .clang-tidy) on main.cpp, src/ and tests/
#
# .clang-tidy keeps WarningsAsErrors empty so editors show findings as
# warnings; MYAPP_TIDY_WERROR=ON (CI) turns them into errors for this target.
# =============================================================================
include_guard(DIRECTORY)

myapp_find_llvm_program(MYAPP_RUN_CLANG_TIDY run-clang-tidy run-clang-tidy.py)
if(NOT MYAPP_RUN_CLANG_TIDY)
    return()
endif()

# run-clang-tidy only looks for clang-tidy on PATH, and Homebrew's LLVM is not
# on PATH (it is keg-only). Find clang-tidy next to run-clang-tidy first, so
# both come from the same LLVM, and pass it explicitly.
get_filename_component(_myapp_run_clang_tidy_dir "${MYAPP_RUN_CLANG_TIDY}" DIRECTORY)
find_program(MYAPP_CLANG_TIDY NAMES clang-tidy
             HINTS "${_myapp_run_clang_tidy_dir}" ${MYAPP_LLVM_HINTS})
if(NOT MYAPP_CLANG_TIDY)
    return()
endif()

# The LLVM script is Python, often without a .py extension (a shebang line
# only), and Windows cannot run it directly, so it is started through Python.
if(CMAKE_HOST_WIN32)
    find_package(Python3 COMPONENTS Interpreter)
    if(NOT Python3_EXECUTABLE)
        return()
    endif()
    set(_myapp_tidy_runner "${Python3_EXECUTABLE}" "${MYAPP_RUN_CLANG_TIDY}")
else()
    set(_myapp_tidy_runner "${MYAPP_RUN_CLANG_TIDY}")
endif()

set(_myapp_tidy_args -quiet -p "${PROJECT_BINARY_DIR}"
                     "-clang-tidy-binary=${MYAPP_CLANG_TIDY}")
if(MYAPP_TIDY_WERROR)
    list(APPEND _myapp_tidy_args "-warnings-as-errors=*")
endif()

# The project folder can contain spaces, '+' and other characters that mean
# something in a regular expression, so the path is escaped before it is used
# as one. Otherwise the pattern matches nothing and clang-tidy checks no file
# at all.
myapp_regex_escape(_myapp_tidy_source_dir "${PROJECT_SOURCE_DIR}")
set(_myapp_tidy_pattern "${_myapp_tidy_source_dir}/(main.cpp|src/.*|tests/.*)")

# Check that the pattern really matches the project's sources, so a broken
# pattern fails the build instead of quietly checking nothing.
file(GLOB_RECURSE _myapp_tidy_files
     "${PROJECT_SOURCE_DIR}/src/*.cpp" "${PROJECT_SOURCE_DIR}/tests/*.cpp")
list(APPEND _myapp_tidy_files "${PROJECT_SOURCE_DIR}/main.cpp")
list(FILTER _myapp_tidy_files INCLUDE REGEX "${_myapp_tidy_pattern}")
if(NOT _myapp_tidy_files)
    message(FATAL_ERROR
        "clang-tidy would check no files: the pattern ${_myapp_tidy_pattern} "
        "matches none of the project's sources.")
endif()

add_custom_target(tidy
    COMMAND ${_myapp_tidy_runner} ${_myapp_tidy_args}
            # Report findings in the project's own headers only. Anchored at the
            # source tree so the generated build/**/generated/include/<name>/
            # headers can never match.
            "-header-filter=^${_myapp_tidy_source_dir}/(include|src)/${PROJECT_NAME}/"
            # Files to check (a regex over compile_commands.json entries).
            "${_myapp_tidy_pattern}"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Running clang-tidy on the project"
    VERBATIM)

# clang-tidy compiles the sources itself, so the generated version.hpp must
# exist first (CI builds this target without building the library).
add_dependencies(tidy ${PROJECT_NAME}_version)
