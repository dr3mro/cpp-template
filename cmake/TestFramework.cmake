# =============================================================================
# TestFramework.cmake - the unit test framework (doctest)
#
# The tests need doctest. Where it comes from depends on how the project gets
# its dependencies:
#   - vcpkg:        doctest is a manifest feature ("tests"), so vcpkg installs
#                   it when the tests are built
#   - FetchContent: doctest is fetched and built from its source
#
# Either way the tests get the same target (doctest::doctest) and the same
# helper (doctest_discover_tests), so tests/CMakeLists.txt does not have to
# know which of the two is in use.
# =============================================================================
include_guard(DIRECTORY)

if(MYAPP_USE_VCPKG)
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
else()
    # doctest's own main() is not wanted: this project's tests have their own
    # (tests/test_main.cpp), and two main() functions do not link.
    set(DOCTEST_WITH_TESTS OFF CACHE BOOL "Build doctest's own tests" FORCE)
    set(DOCTEST_WITH_MAIN_IN_STATIC_LIB OFF CACHE BOOL
        "Build a static library with a main() function" FORCE)
    include(FetchDependencies)
    myapp_fetch_dependency(doctest
        https://github.com/doctest/doctest.git
        2d0a9359a60c51affe2a9bebb1be1dca47868151
        SYSTEM
        FIND_PACKAGE_ARGS CONFIG)
endif()

# doctest's helper script registers every TEST_CASE with CTest on its own. It
# sits next to the sources when doctest is built from them, and next to the
# package configuration when an installed doctest is used.
if(DOCTEST_CMAKE_HELPER)
    include(${DOCTEST_CMAKE_HELPER})
else()
    include(${doctest_DIR}/doctest.cmake)
endif()
