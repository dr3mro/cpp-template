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
    # The version comes from the doctest override in vcpkg.json, so this path
    # builds the same doctest that vcpkg installs. FetchContent needs a commit,
    # so each version is mapped to the commit its tag points to.
    file(READ "${CMAKE_CURRENT_LIST_DIR}/../vcpkg.json" _myapp_manifest)
    string(JSON _doctest_name GET "${_myapp_manifest}" overrides 0 name)
    string(JSON _doctest_version GET "${_myapp_manifest}" overrides 0 version)
    if(NOT _doctest_name STREQUAL "doctest")
        message(FATAL_ERROR "vcpkg.json: the first override must pin doctest")
    endif()
    if(_doctest_version STREQUAL "2.5.3")
        set(_doctest_commit 2d0a9359a60c51affe2a9bebb1be1dca47868151)
    else()
        message(FATAL_ERROR
            "No commit is known for doctest ${_doctest_version}. "
            "Add its tag's commit to cmake/TestFramework.cmake.")
    endif()

    include(FetchDependencies)
    myapp_fetch_dependency(doctest
        https://github.com/doctest/doctest.git
        ${_doctest_commit}
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
