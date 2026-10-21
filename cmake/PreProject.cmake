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

# ---- Windows: the Visual Studio compiler needs a developer shell ----------------
# On Windows the Visual Studio tools (cl.exe, the Windows SDK and the INCLUDE
# and LIB environment variables that point at them) only exist inside a
# developer shell. Outside one, CMake takes whatever compiler comes first on
# the PATH (clang++ or g++), and that compiler has no Visual Studio STL to
# work with: the first error is a wall of "STL1000: Unexpected compiler while
# looking for the 'iostream' header".
#
# A multi-config generator (Visual Studio) finds MSVC by itself, so it needs
# none of this. So does a compiler the user chose explicitly
# (-DCMAKE_CXX_COMPILER=clang-cl, or the CXX environment variable).
if(CMAKE_HOST_WIN32 OR "$ENV{OS}" STREQUAL "Windows_NT")
    get_property(_myapp_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(NOT _myapp_multi_config
       AND NOT DEFINED CMAKE_CXX_COMPILER
       AND NOT DEFINED ENV{CXX})
        # The architecture of this machine, in the spelling the Visual Studio
        # developer shell uses.
        set(_myapp_arch "amd64")
        if("$ENV{PROCESSOR_ARCHITECTURE}" STREQUAL "ARM64"
           OR "$ENV{PROCESSOR_ARCHITEW6432}" STREQUAL "ARM64")
            set(_myapp_arch "arm64")
        endif()
        if(DEFINED ENV{VSCMD_VER} OR DEFINED ENV{VCToolsInstallDir})
            # Inside a developer shell: use its cl, not the clang++ or g++ that
            # happens to come first on the PATH.
            myapp_find_msvc_cl(_myapp_cl)
            if(_myapp_cl)
                set(CMAKE_CXX_COMPILER "${_myapp_cl}" CACHE FILEPATH "C++ compiler")
            endif()
        else()
            message(FATAL_ERROR
                "No Visual Studio compiler: the Visual Studio tools (cl.exe, the\n"
                "Windows SDK and the INCLUDE and LIB environment variables) are only\n"
                "set up inside a developer shell, and this shell is not one.\n"
                "\n"
                "Pick one of these:\n"
                "\n"
                "  1. Build in Visual Studio, which needs neither CMake nor a shell:\n"
                "       start myapp.sln\n"
                "\n"
                "  2. Let CMake find Visual Studio itself, with a Visual Studio\n"
                "     generator (these presets also build the tests):\n"
                "       cmake --preset vs2022\n"
                "       cmake --preset vs2026\n"
                "\n"
                "  3. Open a developer shell for your architecture and configure from\n"
                "     there. Find Visual Studio (this needs the Visual Studio\n"
                "     Installer):\n"
                "       & \"\${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\Installer\\vswhere.exe\" -latest -property installationPath\n"
                "     Then start its developer shell (use -Arch arm64 on an ARM64\n"
                "     machine):\n"
                "       & \"<the path from vswhere>\\Common7\\Tools\\Launch-VsDevShell.ps1\" -Arch ${_myapp_arch} -HostArch ${_myapp_arch}\n"
                "     and run 'cmake --preset release' in it.")
        endif()
    endif()
endif()

# ---- vcpkg toolchain -----------------------------------------------------------
# The setup steps depend on the host OS. vcpkg.json pins a baseline commit, so
# the clone has to be complete: a shallow clone does not contain that commit
# and the first configure fails with "failed to git show versions/baseline.json".
if(CMAKE_HOST_WIN32 OR "$ENV{OS}" STREQUAL "Windows_NT")
    set(_myapp_vcpkg_setup_help
        "One-time vcpkg setup:\n"
        "  git clone https://github.com/microsoft/vcpkg.git C:\\vcpkg\n"
        "  C:\\vcpkg\\bootstrap-vcpkg.bat -disableMetrics\n"
        "Then set VCPKG_ROOT as a user environment variable\n"
        "(System Properties -> Environment Variables -> New) and open a new\n"
        "terminal (and restart Visual Studio).")
elseif(CMAKE_HOST_APPLE)
    set(_myapp_vcpkg_setup_help
        "One-time vcpkg setup:\n"
        "  git clone https://github.com/microsoft/vcpkg.git ~/.vcpkg\n"
        "  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics\n"
        "  echo 'export VCPKG_ROOT=\"$HOME/.vcpkg\"' >> ~/.zshrc\n"
        "Then open a new terminal (or run 'source ~/.zshrc') and configure again.")
else()
    set(_myapp_vcpkg_setup_help
        "One-time vcpkg setup:\n"
        "  git clone https://github.com/microsoft/vcpkg.git ~/.vcpkg\n"
        "  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics\n"
        "  echo 'export VCPKG_ROOT=\"$HOME/.vcpkg\"' >> ~/.bashrc\n"
        "Then open a new terminal (or run 'source ~/.bashrc') and configure again.")
endif()

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
