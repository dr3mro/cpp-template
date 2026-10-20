# =============================================================================
# src/CMakeLists.txt - the project's library
#
# Every .cpp under src/ goes into one library. The app (main.cpp), the tests,
# the fuzzers and, in library mode, outside consumers all link it, so all real
# code lives here and main() stays a thin entry point.
#
# Provides: ${PROJECT_NAME}_lib, plus the alias ${PROJECT_NAME}::${PROJECT_NAME}
#           (the same name the installed package exports).
# =============================================================================

file(GLOB_RECURSE _myapp_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
add_library(${PROJECT_NAME}_lib ${_myapp_sources})

# Lets a parent project that uses add_subdirectory()/FetchContent link
# <name>::<name>, exactly as it would after find_package().
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME}_lib)

# The C++ standard travels with the library: the app, tests, fuzzers and every
# consumer of the installed package inherit it.
target_compile_features(${PROJECT_NAME}_lib PUBLIC cxx_std_17)

# Public headers. BUILD_INTERFACE keeps the source path out of the installed
# package, which points at <prefix>/include instead.
target_include_directories(${PROJECT_NAME}_lib PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# Project-wide flags (warnings, sanitizers, hardening, generated headers).
# PUBLIC so every in-tree target that links the library gets them too;
# BUILD_INTERFACE so they never leak into the installed package.
target_link_libraries(${PROJECT_NAME}_lib PUBLIC $<BUILD_INTERFACE:${PROJECT_NAME}_options>)

# Refresh version.hpp (git hash) before the library compiles.
add_dependencies(${PROJECT_NAME}_lib ${PROJECT_NAME}_version)

# Third-party packages found in cmake/Dependencies.cmake are linked here, e.g.
#   target_link_libraries(${PROJECT_NAME}_lib PUBLIC fmt::fmt)

include(ExportHeader)
