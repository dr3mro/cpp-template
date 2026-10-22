# =============================================================================
# tests/CMakeLists.txt - doctest unit tests
#
# Every .cpp in tests/ is compiled into one test executable that links the
# library. Each TEST_CASE is registered with CTest individually, so
# `ctest --preset debug` lists and runs them one by one. In app mode, a
# `<name>_version` test runs the program with --version.
#
# Built when MYAPP_BUILD_TESTS is ON; vcpkg then installs doctest (the "tests"
# feature in vcpkg.json, requested in PreProject.cmake).
# =============================================================================

find_package(doctest CONFIG QUIET)
if(NOT doctest_FOUND)
    # Almost always means CMake ran without a preset, so the vcpkg toolchain
    # (and the doctest it installs) was never loaded.
    message(FATAL_ERROR
        "doctest was not found. Configure with a preset so vcpkg installs it:\n"
        "  cmake --preset debug\n"
        "or pass -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake, "
        "or turn tests off with -DMYAPP_BUILD_TESTS=OFF.")
endif()

file(GLOB_RECURSE _myapp_test_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
add_executable(${PROJECT_NAME}_tests ${_myapp_test_sources})
# The project-wide flags (sanitizers, warnings) come from
# ${PROJECT_NAME}_options, which every target of this project links itself.
target_link_libraries(${PROJECT_NAME}_tests PRIVATE
    ${PROJECT_NAME}_lib ${PROJECT_NAME}_options doctest::doctest)

include(${doctest_DIR}/doctest.cmake)
doctest_discover_tests(${PROJECT_NAME}_tests)

# A smoke test of the program itself (app mode only): it starts, and
# prints the version from vcpkg.json. The app target is defined in the
# top-level CMakeLists.txt before this directory is added.
if(NOT MYAPP_LIBRARY_MODE)
    add_test(NAME ${PROJECT_NAME}_version COMMAND ${PROJECT_NAME} --version)
    string(REPLACE "." "\\." _myapp_version_regex "${PROJECT_VERSION}")
    set_tests_properties(${PROJECT_NAME}_version PROPERTIES
        PASS_REGULAR_EXPRESSION "^${PROJECT_NAME} ${_myapp_version_regex} ")
endif()
