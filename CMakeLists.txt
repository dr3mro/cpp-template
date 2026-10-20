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

# ---- options ----
# MYAPP_BUILD_TESTS is declared above project() so the vcpkg toolchain can see
# it; MYAPP_ENABLE_SANITIZERS is only read after the toolchain has run.
option(MYAPP_ENABLE_SANITIZERS "Build with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

# ---- warnings (shared by every target via this interface target) ----
# Optimisation comes from CMAKE_BUILD_TYPE: Release = -O3 -DNDEBUG, Debug = -g.
add_library(myapp_options INTERFACE)
if(MSVC)
    target_compile_options(myapp_options INTERFACE /W4 /permissive-)
else()
    target_compile_options(myapp_options INTERFACE -Wall -Wextra -pedantic -Wshadow -Wconversion)
endif()

if(MYAPP_ENABLE_SANITIZERS)
    if(MSVC)
        target_compile_options(myapp_options INTERFACE /fsanitize=address)
    else()
        target_compile_options(myapp_options INTERFACE -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_link_options(myapp_options INTERFACE -fsanitize=address,undefined)
    endif()
endif()

# ---- library: everything under src/ except main.cpp, so tests can link it ----
file(GLOB_RECURSE MYAPP_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/src/*.cpp)

add_library(myapp_lib STATIC ${MYAPP_SOURCES})
target_include_directories(myapp_lib PUBLIC ${CMAKE_SOURCE_DIR}/include)
target_compile_definitions(myapp_lib PUBLIC MYAPP_VERSION="${PROJECT_VERSION}")
target_link_libraries(myapp_lib PUBLIC myapp_options)

# ---- executable ----
add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE myapp_lib)

# ---- tests (doctest, installed by vcpkg from vcpkg.json) ----
if(MYAPP_BUILD_TESTS)
    find_package(doctest CONFIG REQUIRED)

    enable_testing()
    file(GLOB_RECURSE MYAPP_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/tests/*.cpp)
    add_executable(myapp_tests ${MYAPP_TEST_SOURCES})
    target_link_libraries(myapp_tests PRIVATE myapp_lib doctest::doctest)

    # Register every TEST_CASE individually with CTest.
    include(${doctest_DIR}/doctest.cmake)
    doctest_discover_tests(myapp_tests)
endif()

# Expose the compilation database at build/ so clangd finds it whatever preset was configured last.
if(NOT WIN32)
    file(MAKE_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
    file(REMOVE ${CMAKE_SOURCE_DIR}/build/compile_commands.json)
    file(CREATE_LINK ${CMAKE_BINARY_DIR}/compile_commands.json
         ${CMAKE_SOURCE_DIR}/build/compile_commands.json SYMBOLIC)
endif()

# ---- tooling targets: format, tidy, docs, diagrams ----
file(GLOB_RECURSE MYAPP_ALL_FILES CONFIGURE_DEPENDS
     ${CMAKE_SOURCE_DIR}/include/*.hpp ${CMAKE_SOURCE_DIR}/src/*.cpp ${CMAKE_SOURCE_DIR}/tests/*.cpp)
list(APPEND MYAPP_ALL_FILES ${CMAKE_SOURCE_DIR}/main.cpp)

find_program(CLANG_FORMAT_EXE clang-format)
if(CLANG_FORMAT_EXE)
    add_custom_target(format
        COMMAND ${CLANG_FORMAT_EXE} -i ${MYAPP_ALL_FILES}
        COMMENT "Formatting sources with clang-format"
        VERBATIM)
    add_custom_target(format-check
        COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror ${MYAPP_ALL_FILES}
        COMMENT "Checking formatting with clang-format"
        VERBATIM)
endif()

find_program(RUN_CLANG_TIDY_EXE NAMES run-clang-tidy run-clang-tidy.py)
if(RUN_CLANG_TIDY_EXE)
    add_custom_target(tidy
        COMMAND ${RUN_CLANG_TIDY_EXE} -quiet -p ${CMAKE_BINARY_DIR} "${CMAKE_SOURCE_DIR}/(main.cpp|src/.*|tests/.*)"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running clang-tidy on the project"
        VERBATIM)
endif()

find_program(DOT_EXECUTABLE dot)
if(DOT_EXECUTABLE)
    # Every diagrams/*.dot file is rendered to a PNG beside it.
    file(GLOB DIAGRAM_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/diagrams/*.dot)
    set(DIAGRAM_PNGS "")
    foreach(dot_file IN LISTS DIAGRAM_SOURCES)
        string(REGEX REPLACE "\\.dot$" ".png" png_file ${dot_file})
        get_filename_component(name ${dot_file} NAME_WE)
        add_custom_command(
            OUTPUT ${png_file}
            COMMAND ${DOT_EXECUTABLE} -Tpng ${dot_file} -o ${png_file}
            DEPENDS ${dot_file}
            COMMENT "Rendering ${name}.png")
        list(APPEND DIAGRAM_PNGS ${png_file})
    endforeach()
    add_custom_target(diagrams DEPENDS ${DIAGRAM_PNGS})
endif()

# Doxygen draws class/include graphs only when Graphviz is installed.
if(DOT_EXECUTABLE)
    set(MYAPP_DOXY_HAVE_DOT YES)
else()
    set(MYAPP_DOXY_HAVE_DOT NO)
endif()

find_package(Doxygen QUIET)
if(DOXYGEN_FOUND)
    configure_file(${CMAKE_SOURCE_DIR}/Doxyfile.in ${CMAKE_BINARY_DIR}/Doxyfile @ONLY)
    add_custom_target(docs
        COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_BINARY_DIR}/Doxyfile
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Generating documentation with Doxygen (output: docs/)"
        VERBATIM)

    # Class diagrams are dot graphs that Doxygen renders and then normally
    # deletes, so this target needs Graphviz as well as Doxygen to exist.
    if(DOT_EXECUTABLE)
        configure_file(${CMAKE_SOURCE_DIR}/Doxyfile.classes.in
                       ${CMAKE_BINARY_DIR}/Doxyfile.classes @ONLY)

        add_custom_target(class-diagrams
            # Wipe both outputs first so graphs from renamed or removed classes
            # cannot linger in Doxygen's output and get copied back.
            COMMAND ${CMAKE_COMMAND} -E rm -rf
                    ${CMAKE_BINARY_DIR}/class-diagrams
                    ${CMAKE_SOURCE_DIR}/diagrams/classes
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SOURCE_DIR}/diagrams/classes
            COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_BINARY_DIR}/Doxyfile.classes
            COMMAND ${CMAKE_COMMAND}
                    -DDOT_EXECUTABLE=${DOT_EXECUTABLE}
                    -DOUTPUT_DIR=${CMAKE_BINARY_DIR}/class-diagrams
                    -DDEST_DIR=${CMAKE_SOURCE_DIR}/diagrams/classes
                    -P ${CMAKE_SOURCE_DIR}/cmake/CollectClassDiagrams.cmake
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            COMMENT "Generating class diagrams (output: diagrams/classes/)"
            VERBATIM)
    endif()
endif()

