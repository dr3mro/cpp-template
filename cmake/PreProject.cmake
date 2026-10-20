# The coverage and fuzz presets need LLVM's clang (for llvm-profdata/llvm-cov and
# libFuzzer). Pick it here, before project(), because the compiler cannot be
# changed once the language is enabled. Only CMAKE_HOST_* is available this
# early: APPLE and UNIX are defined by project().
option(MYAPP_USE_LLVM_CLANG "Prefer Homebrew LLVM clang++ as the compiler" OFF)
if(MYAPP_USE_LLVM_CLANG AND NOT DEFINED CMAKE_CXX_COMPILER)
    find_program(MYAPP_LLVM_CLANGXX
        NAMES clang++
        HINTS /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin)
    if(NOT MYAPP_LLVM_CLANGXX)
        message(FATAL_ERROR
            "MYAPP_USE_LLVM_CLANG is ON but clang++ was not found.\n"
            "Install LLVM first: 'brew install llvm' (macOS) or "
            "'apt install clang' (Linux).")
    endif()
    set(CMAKE_CXX_COMPILER "${MYAPP_LLVM_CLANGXX}" CACHE FILEPATH "C++ compiler")
endif()

# Plain `cmake` (e.g. Zed's built-in "CMake: Configure" task) skips the presets,
# so fall back to the vcpkg toolchain from $VCPKG_ROOT when none was given.
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT}
   AND EXISTS "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE FILEPATH "vcpkg toolchain")
endif()

# Without the toolchain there is no way to fetch the manifest dependencies, so
# stop with the setup instructions instead of a confusing "package not found".
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    message(FATAL_ERROR
        "vcpkg is not set up: VCPKG_ROOT is unset or does not point at a "
        "bootstrapped clone, and no CMAKE_TOOLCHAIN_FILE was given.\n"
        "One-time setup:\n"
        "  git clone --depth 1 https://github.com/microsoft/vcpkg.git ~/.vcpkg\n"
        "  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics\n"
        "  echo 'export VCPKG_ROOT=\"$HOME/.vcpkg\"' >> ~/.zshrc\n"
        "Then open a new terminal (or run 'source ~/.zshrc') and configure again.")
endif()

# doctest is a vcpkg manifest *feature*, so it is only downloaded and installed
# when the tests are actually built. The toolchain reads the manifest during
# project(), so this has to happen before that call.
option(MYAPP_BUILD_TESTS "Build the doctest unit tests" ON)
if(MYAPP_BUILD_TESTS)
    set(VCPKG_MANIFEST_FEATURES tests)
endif()
