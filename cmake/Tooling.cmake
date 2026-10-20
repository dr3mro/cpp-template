# Tooling targets: format, tidy, docs and diagram generation, plus the symlink
# that points clangd at whichever preset was configured last.

# Expose the compilation database at build/ so clangd finds it whatever preset
# was configured last.
if(NOT WIN32)
    file(MAKE_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
    file(REMOVE ${CMAKE_SOURCE_DIR}/build/compile_commands.json)
    file(CREATE_LINK ${CMAKE_BINARY_DIR}/compile_commands.json
         ${CMAKE_SOURCE_DIR}/build/compile_commands.json SYMBOLIC)
endif()

file(GLOB_RECURSE MYAPP_ALL_FILES CONFIGURE_DEPENDS
     ${CMAKE_SOURCE_DIR}/include/*.hpp ${CMAKE_SOURCE_DIR}/src/*.cpp ${CMAKE_SOURCE_DIR}/tests/*.cpp)
# main.cpp only exists in app mode; library mode has no executable.
if(EXISTS ${CMAKE_SOURCE_DIR}/main.cpp)
    list(APPEND MYAPP_ALL_FILES ${CMAKE_SOURCE_DIR}/main.cpp)
endif()
# fuzz/ ships with the template; examples/ only exists in library mode.
if(EXISTS ${CMAKE_SOURCE_DIR}/fuzz)
    file(GLOB _myapp_fuzz_files CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/fuzz/*.cpp)
    list(APPEND MYAPP_ALL_FILES ${_myapp_fuzz_files})
endif()
if(EXISTS ${CMAKE_SOURCE_DIR}/examples)
    file(GLOB _myapp_example_files CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/examples/*.cpp)
    list(APPEND MYAPP_ALL_FILES ${_myapp_example_files})
endif()

# .clang-format needs clang-format 20+. Prefer Homebrew LLVM's copy so the
# target uses the same version CI and pre-commit do.
find_program(CLANG_FORMAT_EXE NAMES clang-format
             HINTS /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin)
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
    # WarningsAsErrors stays '' in .clang-tidy so editors keep showing warnings;
    # CI turns this ON to make findings fail the build.
    option(MYAPP_TIDY_WERROR "Fail the tidy target on clang-tidy findings" OFF)
    set(_myapp_tidy_args "")
    if(MYAPP_TIDY_WERROR)
        list(APPEND _myapp_tidy_args "-warnings-as-errors=*")
    endif()
    add_custom_target(tidy
        COMMAND ${RUN_CLANG_TIDY_EXE} -quiet ${_myapp_tidy_args} -p ${CMAKE_BINARY_DIR} "${CMAKE_SOURCE_DIR}/(main.cpp|src/.*|tests/.*)"
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
