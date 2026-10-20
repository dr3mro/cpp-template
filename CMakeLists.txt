cmake_minimum_required(VERSION 3.25)

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

# doctest is a vcpkg manifest *feature*, so it is only downloaded and installed
# when the tests are actually built. The toolchain reads the manifest during
# project(), so this has to happen before that call.
option(MYAPP_BUILD_TESTS "Build the doctest unit tests" ON)
if(MYAPP_BUILD_TESTS)
    set(VCPKG_MANIFEST_FEATURES tests)
endif()

project(myapp VERSION 0.1.0 LANGUAGES CXX)

# ---- language ----
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
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
include(cmake/Tooling.cmake)

# ---- library: everything under src/, so tests and the app can both link it ----
file(GLOB_RECURSE MYAPP_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/src/*.cpp)
add_library(${PROJECT_NAME}_lib ${MYAPP_SOURCES})
# Refresh the build-time version header before the library compiles.
add_dependencies(${PROJECT_NAME}_lib myapp_version)
# BUILD_INTERFACE keeps the source path out of the installed export set.
target_include_directories(${PROJECT_NAME}_lib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)
# PUBLIC + BUILD_INTERFACE: the warning/sanitizer options (and the generated
# include dir they carry) reach the library and every in-tree consumer, but the
# BUILD_INTERFACE wrapper keeps myapp_options out of the exported package.
target_link_libraries(${PROJECT_NAME}_lib PUBLIC $<BUILD_INTERFACE:myapp_options>)
# Exported as <name>::<name> so consumers write a clean target_link_libraries.
# OUTPUT_NAME drops the _lib suffix from the installed file (libmyapp.a), and
# VERSION/SOVERSION give shared builds a soname. Hidden visibility means only
# MYAPP_EXPORT classes are visible from a shared library.
set_target_properties(${PROJECT_NAME}_lib PROPERTIES
    EXPORT_NAME ${PROJECT_NAME}
    OUTPUT_NAME ${PROJECT_NAME}
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON)

# Export header: produces <name>_EXPORT, empty for static builds and
# import/export annotations for shared ones (needed for Windows DLLs).
include(GenerateExportHeader)
generate_export_header(${PROJECT_NAME}_lib
    BASE_NAME MYAPP
    EXPORT_FILE_NAME ${CMAKE_BINARY_DIR}/generated/include/${PROJECT_NAME}/${PROJECT_NAME}_export.h)
get_target_property(_myapp_lib_type ${PROJECT_NAME}_lib TYPE)
if(_myapp_lib_type STREQUAL "STATIC_LIBRARY")
    target_compile_definitions(${PROJECT_NAME}_lib PUBLIC MYAPP_STATIC_DEFINE)
endif()

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
    include(GNUInstallDirs)
    include(CMakePackageConfigHelpers)

    install(TARGETS ${PROJECT_NAME}_lib
        EXPORT ${PROJECT_NAME}Targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

    # Public headers plus the generated version and export headers (skip the
    # .in template).
    install(DIRECTORY ${CMAKE_SOURCE_DIR}/include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            PATTERN "*.in" EXCLUDE)
    install(FILES
        ${CMAKE_BINARY_DIR}/generated/include/${PROJECT_NAME}/version.hpp
        ${CMAKE_BINARY_DIR}/generated/include/${PROJECT_NAME}/${PROJECT_NAME}_export.h
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})

    install(EXPORT ${PROJECT_NAME}Targets
        FILE ${PROJECT_NAME}Targets.cmake
        NAMESPACE ${PROJECT_NAME}::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})

    configure_package_config_file(
        ${CMAKE_SOURCE_DIR}/cmake/Config.cmake.in
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})
    write_basic_package_version_file(
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
        COMPATIBILITY SameMajorVersion)
    install(FILES
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}Config.cmake
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})

    set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
    set(CPACK_GENERATOR "TGZ")
    include(CPack)
endif()
