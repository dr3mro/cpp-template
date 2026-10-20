# Unit tests. doctest is installed by vcpkg when the "tests" feature is on,
# which the top-level CMakeLists enables whenever MYAPP_BUILD_TESTS is ON.
find_package(doctest CONFIG REQUIRED)

file(GLOB_RECURSE MYAPP_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
add_executable(${PROJECT_NAME}_tests ${MYAPP_TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_tests PRIVATE ${PROJECT_NAME}_lib doctest::doctest)

# Register every TEST_CASE individually with CTest.
include(${doctest_DIR}/doctest.cmake)
doctest_discover_tests(${PROJECT_NAME}_tests)
