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
        "cmake-lint not found; install it with "
        "'pipx install cmakelang==0.6.13 && pipx inject cmakelang pyyaml' "
        "to enable the cmake-lint target")
    return()
endif()

# Keep this list explicit: configure-dependent globs make Ninja regenerate
# while optional tools or package managers update generated files.
set(_myapp_cmake_candidates
    "${PROJECT_SOURCE_DIR}/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/src/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/tests/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/fuzz/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/examples/CMakeLists.txt"
    "${PROJECT_SOURCE_DIR}/cmake/ArchitectureDiagram.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/CMakeLint.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Ccache.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/CollectClassDiagrams.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/CompileCommands.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Coverage.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Dependencies.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/DistClean.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Docs.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/ExportHeader.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/FetchDependencies.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Format.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Hardening.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Helpers.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/HomebrewLLVM.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Install.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Lto.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Options.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/PreProject.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/ProjectDefaults.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Sanitizers.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/StdlibChecks.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Summary.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/TestFramework.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Tidy.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Version.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Warnings.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/WindowsClang.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/WriteVersion.cmake"
    "${PROJECT_SOURCE_DIR}/cmake/VcpkgToolchain.cmake")
set(_myapp_cmake_files "")
foreach(_file IN LISTS _myapp_cmake_candidates)
    if(EXISTS "${_file}")
        list(APPEND _myapp_cmake_files "${_file}")
    endif()
endforeach()
add_custom_target(cmake-lint
    COMMAND "${MYAPP_CMAKE_LINT}" ${_myapp_cmake_files}
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Linting CMake files with cmake-lint"
    VERBATIM)
