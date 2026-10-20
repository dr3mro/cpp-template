cmake_minimum_required(VERSION 3.25)

# Everything here must run before project(): include it only above that call.
# (PROJECT_SOURCE_DIR does not exist yet, hence CMAKE_CURRENT_LIST_DIR.)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/PreProject.cmake)

# The version has a single source of truth: the "version" field in vcpkg.json.
# Read it here so the CMake project and the manifest can never disagree (CI
# fails the build if they ever do).
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg.json" _myapp_vcpkg_manifest)
string(JSON MYAPP_VERSION GET "${_myapp_vcpkg_manifest}" version)

project(myapp VERSION ${MYAPP_VERSION} LANGUAGES CXX)

# ---- language ----
# The C++ standard is a property of the library target (see below) so that the
# app, tests, fuzzers, examples and downstream consumers all inherit it.
set(CMAKE_CXX_EXTENSIONS OFF)

# Generate compile_commands.json for clangd and clang-tidy.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

option(MYAPP_BUILD_FUZZERS "Build fuzz targets" OFF)
option(MYAPP_LIBRARY_MODE "Build as an installable library package (no app)" OFF)

# ---- modules (Warnings first: it creates myapp_options that the rest extend) ----
include(cmake/Warnings.cmake)
include(cmake/Sanitizers.cmake)
include(cmake/Hardening.cmake)
include(cmake/Ccache.cmake)
include(cmake/Version.cmake)
include(cmake/ArchitectureDiagram.cmake)
include(cmake/Tooling.cmake)

# ---- position-independent code (PIE/PIC) ----
# Independent of hardening: CMAKE_POSITION_INDEPENDENT_CODE plus
# check_pie_supported() lets CMake pick the right flag per target (-fPIC for
# libraries, -fPIE/-pie for executables) instead of forcing -fPIE/-pie onto
# everything, which breaks a shared library with "undefined reference to main".
# Must run before the first target is defined.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
include(CheckPIESupported)
check_pie_supported()
message(STATUS "Hardening: position-independent code ON (PIE/PIC added by CMake per target)")

# ---- library: everything under src/, so tests and the app can both link it ----
file(GLOB_RECURSE MYAPP_SOURCES CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/src/*.cpp)
add_library(${PROJECT_NAME}_lib ${MYAPP_SOURCES})
# C++17 travels with the library: everything that links it (app, tests,
# fuzzers, examples) and every downstream consumer of the installed package
# inherits the requirement.
target_compile_features(${PROJECT_NAME}_lib PUBLIC cxx_std_17)
# Refresh the build-time version header before the library compiles.
add_dependencies(${PROJECT_NAME}_lib myapp_version)
# BUILD_INTERFACE keeps the source path out of the installed export set.
target_include_directories(${PROJECT_NAME}_lib PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)
# PUBLIC + BUILD_INTERFACE: the warning/sanitizer options (and the generated
# include dir they carry) reach the library and every in-tree consumer, but the
# BUILD_INTERFACE wrapper keeps myapp_options out of the exported package.
target_link_libraries(${PROJECT_NAME}_lib PUBLIC $<BUILD_INTERFACE:myapp_options>)
include(${PROJECT_SOURCE_DIR}/cmake/ExportHeader.cmake)

# Public dependencies this package needs downstream. Add one entry per
# find_package() call that a consumer of the installed library must repeat, so
# the generated <name>Config.cmake can find_dependency() them (see
# cmake/Config.cmake.in). Example, once fmt is linked PUBLIC above:
#
#   set(MYAPP_PACKAGE_DEPENDENCIES fmt CONFIG)
set(MYAPP_PACKAGE_DEPENDENCIES "" CACHE STRING
    "Public dependencies repeated with find_dependency() by the installed package config")

# ---- executable (skipped in library mode) ----
if(NOT MYAPP_LIBRARY_MODE)
    add_executable(${PROJECT_NAME} main.cpp)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}_lib)
endif()

# ---- tests and fuzzers ----
if(MYAPP_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# Coverage target (needs the test binary, so it comes after tests/).
include(cmake/Coverage.cmake)

if(MYAPP_BUILD_FUZZERS)
    add_subdirectory(fuzz)
endif()

# ---- install, package config and CPack (library mode only) ----
if(MYAPP_LIBRARY_MODE)
    include(${PROJECT_SOURCE_DIR}/cmake/Install.cmake)
endif()

# ---- distclean: `cmake --build --preset <name> --target distclean` ----
include(${PROJECT_SOURCE_DIR}/cmake/DistClean.cmake)
