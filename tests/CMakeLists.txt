# Unit tests. doctest is installed by vcpkg when the "tests" feature is on,
# which the top-level CMakeLists enables whenever MYAPP_BUILD_TESTS is ON.
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

file(GLOB_RECURSE MYAPP_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
add_executable(${PROJECT_NAME}_tests ${MYAPP_TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_tests PRIVATE ${PROJECT_NAME}_lib doctest::doctest)

# Register every TEST_CASE individually with CTest.
include(${doctest_DIR}/doctest.cmake)
doctest_discover_tests(${PROJECT_NAME}_tests)
