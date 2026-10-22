# =============================================================================
# Docs.cmake - Doxygen documentation with generated diagrams
#
#   docs  writes the HTML site to docs/ (open docs/index.html)
#
# With Graphviz installed, the docs target first renders into docs/diagrams/:
#   architecture.png   the CMake targets and how they link (from
#                      ArchitectureDiagram.cmake, so it never drifts)
#   <name>.png         every hand-written diagrams/*.dot, if that folder exists
#   classes/*.png      Doxygen's class and collaboration graphs (with .dot)
# docs/ is generated output (git-ignored) and docs/diagrams/ is wiped on every
# run, so stale graphs never linger. README.md embeds architecture.png.
# =============================================================================
include_guard(DIRECTORY)

find_package(Doxygen QUIET)
if(NOT DOXYGEN_FOUND)
    return()
endif()
find_program(MYAPP_DOT_EXECUTABLE dot)

# ---- values substituted into Doxyfile.in / Doxyfile.classes.in ------------------
set(MYAPP_DOCS_DIR "${PROJECT_SOURCE_DIR}/docs")
set(MYAPP_DIAGRAMS_DIR "${MYAPP_DOCS_DIR}/diagrams")
# Doxygen draws class/include graphs only when Graphviz is available.
if(MYAPP_DOT_EXECUTABLE)
    set(MYAPP_DOXY_HAVE_DOT YES)
else()
    set(MYAPP_DOXY_HAVE_DOT NO)
endif()
# main.cpp is app-only; library mode would otherwise warn about a missing input.
# The path is quoted: a project folder may contain spaces.
set(MYAPP_DOXY_EXTRA_INPUT "")
if(EXISTS "${PROJECT_SOURCE_DIR}/main.cpp")
    set(MYAPP_DOXY_EXTRA_INPUT "\"${PROJECT_SOURCE_DIR}/main.cpp\"")
endif()

configure_file("${PROJECT_SOURCE_DIR}/Doxyfile.in" "${PROJECT_BINARY_DIR}/Doxyfile" @ONLY)

add_custom_target(docs
    COMMAND "${DOXYGEN_EXECUTABLE}" "${PROJECT_BINARY_DIR}/Doxyfile"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating documentation with Doxygen (output: docs/)"
    VERBATIM)

if(NOT MYAPP_DOT_EXECUTABLE)
    return()
endif()

# ---- diagrams (need Graphviz) ----------------------------------------------------
include(ArchitectureDiagram)   # writes ${MYAPP_ARCHITECTURE_DOT} at configure time
configure_file("${PROJECT_SOURCE_DIR}/Doxyfile.classes.in"
               "${PROJECT_BINARY_DIR}/Doxyfile.classes" @ONLY)

# One `dot` call per diagram source: the generated architecture graph, then
# any hand-written diagrams/*.dot.
set(_myapp_render_commands
    COMMAND "${MYAPP_DOT_EXECUTABLE}" -Tpng "${MYAPP_ARCHITECTURE_DOT}"
            -o "${MYAPP_DIAGRAMS_DIR}/architecture.png")
file(GLOB _myapp_handwritten_dots "${PROJECT_SOURCE_DIR}/diagrams/*.dot")
foreach(_dot IN LISTS _myapp_handwritten_dots)
    get_filename_component(_name "${_dot}" NAME_WE)
    list(APPEND _myapp_render_commands
        COMMAND "${MYAPP_DOT_EXECUTABLE}" -Tpng "${_dot}" -o "${MYAPP_DIAGRAMS_DIR}/${_name}.png")
endforeach()

set(_myapp_class_graphs_dir "${PROJECT_BINARY_DIR}/class-diagrams")
add_custom_target(docs-diagrams
    # Start from empty folders so renamed or removed classes leave nothing behind.
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${MYAPP_DIAGRAMS_DIR}" "${_myapp_class_graphs_dir}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${MYAPP_DIAGRAMS_DIR}"
    ${_myapp_render_commands}
    # Class graphs: a second Doxygen pass keeps its .dot files
    # (Doxyfile.classes), then CollectClassDiagrams.cmake gives them readable
    # names and renders them into docs/diagrams/classes/.
    COMMAND "${DOXYGEN_EXECUTABLE}" "${PROJECT_BINARY_DIR}/Doxyfile.classes"
    COMMAND ${CMAKE_COMMAND}
            -DDOT_EXECUTABLE=${MYAPP_DOT_EXECUTABLE}
            -DOUTPUT_DIR=${_myapp_class_graphs_dir}
            -DDEST_DIR=${MYAPP_DIAGRAMS_DIR}/classes
            -P "${PROJECT_SOURCE_DIR}/cmake/CollectClassDiagrams.cmake"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Rendering architecture and class diagrams (output: docs/diagrams/)"
    VERBATIM)
add_dependencies(docs docs-diagrams)
