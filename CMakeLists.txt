# =============================================================================
# myapp - top-level build script
#
# This file only orchestrates. Every piece of build logic lives in a focused
# module under cmake/ (each one starts with a comment saying what it does and
# which options it reads) or in a subdirectory's CMakeLists.txt. Read top to
# bottom, it is the order in which the build is set up:
#
#   1. Before project()    compiler choice, vcpkg toolchain, test feature
#   2. Project             name and version (the version comes from the VERSION file)
#   3. Options, defaults   every -DMYAPP_* switch; language and install defaults
#   4. Build flags         the myapp_options target that every target links
#   5. Dependencies        third-party packages (edit cmake/Dependencies.cmake)
#   6. Targets             library (src/), app (main.cpp), tests, fuzzers
#   7. Developer tools     coverage, clangd link, format, tidy, docs, distclean
#   8. Install, summary    cmake --install / CPack, and a configure summary
# =============================================================================
cmake_minimum_required(VERSION 3.25)

# An in-source build would overwrite the checked-in myapp.sln/myapp.vcxproj
# (and litter the tree), so require a separate build folder: use a preset.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "In-source builds are not supported. Use a preset, e.g.\n"
        "  cmake --preset debug      (or vs2022 / vs2026 on Windows)\n"
        "then remove the CMakeCache.txt and CMakeFiles/ just created here.")
endif()

# ---- 1. Before project() ------------------------------------------------------
# These must run before project() enables C++, so they are included by path.
include(${CMAKE_CURRENT_LIST_DIR}/cmake/Helpers.cmake)
# Only the top-level project owns its build directory: when this project is
# pulled into another one (add_subdirectory/FetchContent), the recorded source
# is the parent's and the check would always fail.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    myapp_validate_build_tree("${CMAKE_CURRENT_LIST_DIR}")
endif()
# The cx command passes its target architecture so it can tell when a build
# folder must be reconfigured. Declaring it here keeps CMake from reporting it
# as an unused -D variable.
if(DEFINED CX_TARGET_ARCH)
    set(CX_TARGET_ARCH "${CX_TARGET_ARCH}" CACHE STRING
        "Target architecture recorded by the cx command")
endif()
include(${CMAKE_CURRENT_LIST_DIR}/cmake/PreProject.cmake)

# ---- 2. Project ---------------------------------------------------------------
myapp_read_version(MYAPP_VERSION "${CMAKE_CURRENT_LIST_DIR}/VERSION")
project(myapp
    VERSION ${MYAPP_VERSION}
    DESCRIPTION "C++ project created from the cpp-template"
    LANGUAGES CXX)

# From here on, modules are included by name: include(Warnings) loads
# cmake/Warnings.cmake. PREPEND so ours win over same-named modules of a
# parent project.
list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

# ---- 3. Options and defaults ----------------------------------------------------
include(Options)            # all -DMYAPP_* switches, with descriptions
include(ProjectDefaults)    # C++ dialect, build type, PIC/PIE, install prefix

# ---- 4. Build flags -------------------------------------------------------------
# One INTERFACE target carries every project-wide compile and link flag. The
# library links it PUBLIC (so the app, tests and fuzzers get it too) but only
# inside this build: it is never part of the installed package.
add_library(${PROJECT_NAME}_options INTERFACE)
include(Warnings)           # -Wall -Wextra ... (and -Werror on request)
include(Sanitizers)         # ASan/UBSan, TSan, MSan, libFuzzer instrumentation
include(StdlibChecks)       # the standard library's own checks (Debug too)
include(Hardening)          # stack protector, FORTIFY_SOURCE, RELRO, CET, ...
include(Lto)                # link-time optimisation for optimised app builds
include(Coverage)           # LLVM coverage instrumentation (coverage preset)
include(Ccache)             # compiler cache
include(Version)            # generated <name>/version.hpp (version + git hash)
include(HomebrewLLVM)       # link Homebrew's libc++ with Homebrew's clang++
include(WindowsClang)       # LLVM's clang against the Visual Studio STL (Windows)

# ---- 5. Dependencies ------------------------------------------------------------
include(FetchDependencies)   # myapp_fetch_dependency(): dependencies from source
include(Dependencies)       # find_package() calls for third-party libraries

# ---- 6. Targets -----------------------------------------------------------------
add_subdirectory(src)       # ${PROJECT_NAME}_lib: all the real code

# The app: a thin main() on top of the library. Library mode has no app.
# It links ${PROJECT_NAME}_options itself: the project-wide flags belong to
# this project and must not reach a consumer of the library.
if(NOT MYAPP_LIBRARY_MODE)
    add_executable(${PROJECT_NAME} main.cpp)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}_lib ${PROJECT_NAME}_options)
endif()

if(MYAPP_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests) # ${PROJECT_NAME}_tests, registered with CTest
endif()

if(MYAPP_BUILD_FUZZERS)
    add_subdirectory(fuzz)  # one libFuzzer binary per fuzz/fuzz_*.cpp
endif()

# ---- 7. Developer tools ---------------------------------------------------------
# Only for the project being worked on: as a subproject, these generic target
# names (format, docs, ...) would clash with the parent project's own.
if(PROJECT_IS_TOP_LEVEL)
    myapp_add_coverage_report() # `coverage` target (needs the tests)
    include(CompileCommands)    # build/compile_commands.json for clangd
    include(Format)             # `format` and `format-check` targets
    include(CMakeLint)          # `cmake-lint` target
    include(Tidy)               # `tidy` target
    include(Docs)               # `docs` target, diagrams included
    include(DistClean)          # `distclean` target
endif()

# ---- 8. Install and summary -----------------------------------------------------
include(Install)            # cmake --install and CPack
include(Summary)            # what this configure will build
