# =============================================================================
# CMakeLint.cmake - cmake-lint target
#
# cmake-lint reads .cmake-format.yaml from the source directory (100 columns,
# the naming scheme and the complexity limits). It is only defined when the
# tool is installed; otherwise a STATUS message explains how to install it.
#
# This is a module of its own, so that the target exists even when
# clang-format is missing or too old (the format targets need clang-format
# 21+, this one needs nothing but cmakelang).
# =============================================================================
include_guard(DIRECTORY)

find_program(MYAPP_CMAKE_LINT cmake-lint)
if(NOT MYAPP_CMAKE_LINT)
    message(STATUS
        "cmake-lint not found; install it with 'pipx install cmakelang==0.6.13' "
        "to enable the cmake-lint target")
    return()
endif()

# One level of subdirectories covers this layout (src/, tests/, fuzz/,
# examples/); GLOB_RECURSE would descend into build/ and vcpkg_installed/.
file(GLOB _myapp_cmake_files CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/*/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/cmake/*.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/*.cmake.in")
add_custom_target(cmake-lint
    COMMAND "${MYAPP_CMAKE_LINT}" ${_myapp_cmake_files}
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Linting CMake files with cmake-lint"
    VERBATIM)
