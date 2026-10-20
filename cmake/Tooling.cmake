# Tooling targets: format, tidy, docs and diagram generation, plus the symlink
# that points clangd at whichever preset was configured last.

# Expose the compilation database at build/ so clangd finds it whatever preset
# was configured last. Skipped when the build directory *is* build/ (a plain
# `cmake -B build` without a preset): the database is already there, and a link
# onto itself would fail.
if(NOT WIN32 AND NOT PROJECT_BINARY_DIR STREQUAL "${PROJECT_SOURCE_DIR}/build")
    file(MAKE_DIRECTORY ${PROJECT_SOURCE_DIR}/build)
    file(REMOVE ${PROJECT_SOURCE_DIR}/build/compile_commands.json)
    # CMAKE_BINARY_DIR on purpose: the generator writes a single compilation
    # database at the top of the build tree, even when this project is an
    # add_subdirectory() subproject, so the link must point there.
    file(CREATE_LINK ${CMAKE_BINARY_DIR}/compile_commands.json
         ${PROJECT_SOURCE_DIR}/build/compile_commands.json SYMBOLIC)
endif()

file(GLOB_RECURSE MYAPP_ALL_FILES CONFIGURE_DEPENDS
     ${PROJECT_SOURCE_DIR}/include/*.hpp ${PROJECT_SOURCE_DIR}/src/*.cpp ${PROJECT_SOURCE_DIR}/tests/*.cpp)
# main.cpp only exists in app mode; library mode has no executable.
if(EXISTS ${PROJECT_SOURCE_DIR}/main.cpp)
    list(APPEND MYAPP_ALL_FILES ${PROJECT_SOURCE_DIR}/main.cpp)
endif()
# fuzz/ ships with the template; examples/ only exists in library mode.
if(EXISTS ${PROJECT_SOURCE_DIR}/fuzz)
    file(GLOB _myapp_fuzz_files CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/fuzz/*.cpp)
    list(APPEND MYAPP_ALL_FILES ${_myapp_fuzz_files})
endif()
if(EXISTS ${PROJECT_SOURCE_DIR}/examples)
    file(GLOB _myapp_example_files CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/examples/*.cpp)
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
        COMMAND ${RUN_CLANG_TIDY_EXE} -quiet ${_myapp_tidy_args} -p ${PROJECT_BINARY_DIR}
                # Anchored at the source tree so the generated
                # build/**/generated/include/<name>/ headers can never match;
                # .clang-tidy's HeaderFilterRegex alone cannot express that
                # exclusion in POSIX extended regex.
                "-header-filter=^${PROJECT_SOURCE_DIR}/(include|src)/myapp/"
                "${PROJECT_SOURCE_DIR}/(main.cpp|src/.*|tests/.*)"
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Running clang-tidy on the project"
        VERBATIM)
    # version.hpp is generated; make sure it exists before tidy compiles the
    # sources (the CI tidy job builds this target without building the library).
    add_dependencies(tidy myapp_version)
endif()

find_program(DOT_EXECUTABLE dot)

# Doxygen draws class/include graphs only when Graphviz is installed.
if(DOT_EXECUTABLE)
    set(MYAPP_DOXY_HAVE_DOT YES)
else()
    set(MYAPP_DOXY_HAVE_DOT NO)
endif()

# All diagrams are generated output under docs/diagrams/ (never committed):
# the architecture graph written by ArchitectureDiagram.cmake, plus every class
# graph Doxygen produces. The docs target builds them so the Doxygen site can
# embed them.
set(MYAPP_DIAGRAMS_DIR ${PROJECT_BINARY_DIR}/docs/diagrams)

find_package(Doxygen QUIET)
if(DOXYGEN_FOUND)
    # main.cpp is app-only; library mode would otherwise warn about a missing
    # input file.
    if(EXISTS ${PROJECT_SOURCE_DIR}/main.cpp)
        set(MYAPP_DOXY_EXTRA_INPUT ${PROJECT_SOURCE_DIR}/main.cpp)
    else()
        set(MYAPP_DOXY_EXTRA_INPUT "")
    endif()
    configure_file(${PROJECT_SOURCE_DIR}/Doxyfile.in ${PROJECT_BINARY_DIR}/Doxyfile @ONLY)

    add_custom_target(docs
        COMMAND ${DOXYGEN_EXECUTABLE} ${PROJECT_BINARY_DIR}/Doxyfile
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        COMMENT "Generating documentation with Doxygen (output: docs/)"
        VERBATIM)

    if(DOT_EXECUTABLE)
        configure_file(${PROJECT_SOURCE_DIR}/Doxyfile.classes.in
                       ${PROJECT_BINARY_DIR}/Doxyfile.classes @ONLY)
        # Render every diagram into docs/diagrams/ before Doxygen runs, so the
        # README's \image and the class graphs always reference current files.
        add_custom_target(docs-diagrams
            # Wipe first so graphs from renamed or removed classes cannot
            # linger (the architecture .dot is written by the configure step).
            COMMAND ${CMAKE_COMMAND} -E rm -rf ${MYAPP_DIAGRAMS_DIR}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${MYAPP_DIAGRAMS_DIR}
            COMMAND ${DOT_EXECUTABLE} -Tpng ${MYAPP_ARCHITECTURE_DOT}
                    -o ${MYAPP_DIAGRAMS_DIR}/architecture.png
            COMMAND ${CMAKE_COMMAND} -E rm -rf ${PROJECT_BINARY_DIR}/class-diagrams
            COMMAND ${DOXYGEN_EXECUTABLE} ${PROJECT_BINARY_DIR}/Doxyfile.classes
            COMMAND ${CMAKE_COMMAND}
                    -DDOT_EXECUTABLE=${DOT_EXECUTABLE}
                    -DOUTPUT_DIR=${PROJECT_BINARY_DIR}/class-diagrams
                    -DDEST_DIR=${MYAPP_DIAGRAMS_DIR}/classes
                    -P ${PROJECT_SOURCE_DIR}/cmake/CollectClassDiagrams.cmake
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            COMMENT "Rendering architecture and class diagrams (output: docs/diagrams/)"
            VERBATIM)
        add_dependencies(docs docs-diagrams)
    endif()
endif()
