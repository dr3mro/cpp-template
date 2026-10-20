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

set(_myapp_tidy_args -quiet -p "${PROJECT_BINARY_DIR}")
if(MYAPP_TIDY_WERROR)
    list(APPEND _myapp_tidy_args "-warnings-as-errors=*")
endif()

add_custom_target(tidy
    COMMAND "${MYAPP_RUN_CLANG_TIDY}" ${_myapp_tidy_args}
            # Report findings in the project's own headers only. Anchored at the
            # source tree so the generated build/**/generated/include/<name>/
            # headers can never match.
            "-header-filter=^${PROJECT_SOURCE_DIR}/(include|src)/${PROJECT_NAME}/"
            # Files to check (a regex over compile_commands.json entries).
            "${PROJECT_SOURCE_DIR}/(main.cpp|src/.*|tests/.*)"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Running clang-tidy on the project"
    VERBATIM)

# clang-tidy compiles the sources itself, so the generated version.hpp must
# exist first (CI builds this target without building the library).
add_dependencies(tidy ${PROJECT_NAME}_version)
