# =============================================================================
# PreProject.cmake - setup that must happen before project()
#
# project() enables the C++ language, which locks in the compiler and loads the
# toolchain file (vcpkg reads vcpkg.json at that moment). Everything that
# influences those steps therefore lives here.
#
# Only the top-level project does this: when this project is pulled into
# another one (add_subdirectory/FetchContent), the parent owns the compiler and
# the toolchain.
#
# Options defined here (the rest are in Options.cmake):
#   MYAPP_USE_LLVM_CLANG  use LLVM clang++ (coverage and fuzz presets need it)
#   MYAPP_BUILD_TESTS     build the unit tests; also asks vcpkg for doctest
# =============================================================================
include_guard(GLOBAL)

# PROJECT_IS_TOP_LEVEL does not exist before project(); compare directories.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(_myapp_top_level ON)
else()
    set(_myapp_top_level OFF)
endif()

# Tests default to ON only when this is the project being built, so a parent
# project does not build (or download dependencies for) our tests.
option(MYAPP_BUILD_TESTS "Build the doctest unit tests" ${_myapp_top_level})

if(NOT _myapp_top_level)
    return()
endif()

# ---- compiler ----------------------------------------------------------------
# The coverage and fuzz presets need LLVM's clang (llvm-profdata/llvm-cov and
# libFuzzer). Only CMAKE_HOST_* is known this early: APPLE and UNIX are set by
# project().
option(MYAPP_USE_LLVM_CLANG "Prefer LLVM clang++ (Homebrew's on macOS) as the compiler" OFF)
if(MYAPP_USE_LLVM_CLANG AND NOT DEFINED CMAKE_CXX_COMPILER)
    myapp_find_llvm_program(MYAPP_LLVM_CLANGXX clang++)
    if(NOT MYAPP_LLVM_CLANGXX)
        message(FATAL_ERROR
            "MYAPP_USE_LLVM_CLANG is ON but clang++ was not found.\n"
            "Install LLVM first: 'brew install llvm' (macOS) or "
            "'apt install clang' (Linux).")
    endif()
    set(CMAKE_CXX_COMPILER "${MYAPP_LLVM_CLANGXX}" CACHE FILEPATH "C++ compiler")
endif()

# ---- vcpkg toolchain -----------------------------------------------------------
set(_myapp_vcpkg_setup_help
    "One-time vcpkg setup:\n"
    "  git clone --depth 1 https://github.com/microsoft/vcpkg.git ~/.vcpkg\n"
    "  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics\n"
    "  echo 'export VCPKG_ROOT=\"$HOME/.vcpkg\"' >> ~/.zshrc\n"
    "Then open a new terminal (or run 'source ~/.zshrc') and configure again.")

# Plain `cmake` (e.g. Zed's built-in "CMake: Configure" task) skips the presets,
# so fall back to the vcpkg toolchain from $VCPKG_ROOT when none was given.
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT}
   AND EXISTS "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE FILEPATH "vcpkg toolchain")
endif()

if(DEFINED CMAKE_TOOLCHAIN_FILE AND NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    # The presets pass $env{VCPKG_ROOT}/scripts/...; with VCPKG_ROOT unset that
    # becomes "/scripts/buildsystems/vcpkg.cmake", which CMake would only
    # report as a missing file.
    message(FATAL_ERROR
        "Toolchain file not found: ${CMAKE_TOOLCHAIN_FILE}\n"
        "VCPKG_ROOT is unset or does not point at a bootstrapped vcpkg clone.\n"
        ${_myapp_vcpkg_setup_help})
elseif(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    # Still allowed: every dependency can also come from the system or
    # CMAKE_PREFIX_PATH. find_package() will say which one is missing.
    message(WARNING
        "Configuring without vcpkg: dependencies must already be installed "
        "on this system.\n" ${_myapp_vcpkg_setup_help})
endif()

# doctest is a vcpkg manifest *feature*, so it is only downloaded when the tests
# are built. vcpkg reads this during project().
if(MYAPP_BUILD_TESTS)
    list(APPEND VCPKG_MANIFEST_FEATURES tests)
endif()
