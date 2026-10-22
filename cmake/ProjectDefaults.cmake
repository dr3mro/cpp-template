# =============================================================================
# ProjectDefaults.cmake - language, build type, PIC/PIE and install defaults
#
# Settings that apply to every target in this project. Included right after
# project() and before any target is created (several of these only affect
# targets defined after them).
# =============================================================================
include_guard(DIRECTORY)

# ---- language ------------------------------------------------------------------
# The C++ standard itself is a property of the library target (cxx_std_17 in
# src/CMakeLists.txt), so it travels to everything that links it. Here we only
# ask for the standard dialect (-std=c++17, not -std=gnu++17).
set(CMAKE_CXX_EXTENSIONS OFF)

# compile_commands.json for clangd and clang-tidy (see CompileCommands.cmake).
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ---- defaults the top-level project chooses, never imposed on a parent ---------
if(PROJECT_IS_TOP_LEVEL)
    # Single-config generators (Ninja, Makefiles) build "no configuration" when
    # CMAKE_BUILD_TYPE is empty, which means no optimisation and no -g. Default
    # to Release instead; presets always set it explicitly.
    if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
        set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    endif()

    # Keep `cmake --install` out of /usr/local and out of the source tree.
    # Presets set installDir (build/<os>/install/<preset>); this covers plain cmake.
    if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
        set(CMAKE_INSTALL_PREFIX "${PROJECT_BINARY_DIR}/install"
            CACHE PATH "Install prefix" FORCE)
    endif()
endif()

# ---- position-independent code (PIC/PIE) -----------------------------------------
# Lets CMake add the right flag per target type: -fPIC for libraries and
# -fPIE/-pie for executables. Forcing -fPIE/-pie onto every target instead
# breaks a shared library ("undefined reference to main"). Independent of
# hardening, so a static library stays linkable into someone else's shared one.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
include(CheckPIESupported)
check_pie_supported()

# Standard install directory names (lib, bin, include, ...) for Install.cmake.
include(GNUInstallDirs)
