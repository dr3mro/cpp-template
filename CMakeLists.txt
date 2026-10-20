cmake_minimum_required(VERSION 3.21)

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
target_include_directories(${PROJECT_NAME}_lib PUBLIC ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME}_lib PUBLIC myapp_options)

# ---- executable ----
add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}_lib)

# ---- tests and fuzzers ----
if(MYAPP_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(MYAPP_BUILD_FUZZERS)
    add_subdirectory(fuzz)
endif()
