# Collects the class graphs Doxygen generated into ${DEST_DIR} and renders a
# PNG beside every .dot file, so the classes/ folder under docs/diagrams/
# matches the layout of the architecture diagram rendered next to it.
#
# Run from a custom target as:
#   cmake -DDOT_EXECUTABLE=... -DOUTPUT_DIR=... -DDEST_DIR=... -P CollectClassDiagrams.cmake

foreach(required DOT_EXECUTABLE OUTPUT_DIR DEST_DIR)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "CollectClassDiagrams.cmake: ${required} is not set")
    endif()
endforeach()

file(MAKE_DIRECTORY "${DEST_DIR}")

# Doxygen writes the graphs next to the HTML output (HTML_OUTPUT = .).
file(GLOB graphs
    "${OUTPUT_DIR}/*__coll__graph.dot"
    "${OUTPUT_DIR}/*__inherit__graph.dot"
    "${OUTPUT_DIR}/inherit_graph_*.dot")

set(collected "")
foreach(graph IN LISTS graphs)
    get_filename_component(file_name "${graph}" NAME)

    if(file_name MATCHES "^(.+)__coll__graph\\.dot$")
        set(stem "${CMAKE_MATCH_1}")
        set(kind "collaboration")
    elseif(file_name MATCHES "^(.+)__inherit__graph\\.dot$")
        set(stem "${CMAKE_MATCH_1}")
        set(kind "inheritance")
    elseif(file_name MATCHES "^inherit_graph_[0-9]+\\.dot$")
        # Numbered overflow graphs carry no class name anywhere, so keep them verbatim.
        set(dest "${DEST_DIR}/${file_name}")
        configure_file("${graph}" "${dest}" COPYONLY)
        list(APPEND collected "${dest}")
        continue()
    else()
        # Other graphs (file dependencies, include graphs) are not class diagrams.
        continue()
    endif()

    # Prefer the class name from the graph title (myapp::core::Greeter): the
    # file name is mangled for portability (lowercase, doubled underscores,
    # upper-case letters prefixed) and would yield an unreadable result.
    set(class_name "")
    file(READ "${graph}" header LIMIT 1024)
    if(header MATCHES "digraph \"([^\"]+)\"")
        set(class_name "${CMAKE_MATCH_1}")
        string(REGEX REPLACE "^.*::" "" class_name "${class_name}")
    endif()
    if(class_name STREQUAL "")
        # No parseable title: strip the class keyword and namespace markers
        # from the mangled stem and drop the underscores left by encoding.
        string(REGEX REPLACE "^(class|struct|namespace)" "" class_name "${stem}")
        string(REGEX REPLACE "^.*_1_1" "" class_name "${class_name}")
        string(REPLACE "__" "_" class_name "${class_name}")
        string(REGEX REPLACE "^_+" "" class_name "${class_name}")
    endif()
    if(class_name STREQUAL "")
        set(class_name "${stem}")
    endif()

    set(dest "${DEST_DIR}/${class_name}_${kind}.dot")
    if(EXISTS "${dest}")
        # Same class name in two namespaces: fall back to Doxygen's mangled
        # file name rather than silently overwriting the first diagram.
        set(dest "${DEST_DIR}/${file_name}")
    endif()
    configure_file("${graph}" "${dest}" COPYONLY)
    list(APPEND collected "${dest}")
endforeach()

foreach(dot IN LISTS collected)
    string(REGEX REPLACE "\\.dot$" ".png" png "${dot}")
    execute_process(
        COMMAND "${DOT_EXECUTABLE}" -Tpng "${dot}" -o "${png}"
        RESULT_VARIABLE dot_result
        ERROR_VARIABLE dot_error)
    if(NOT dot_result EQUAL 0)
        message(FATAL_ERROR "CollectClassDiagrams.cmake: dot failed for ${dot}: ${dot_error}")
    endif()
endforeach()

list(LENGTH collected collected_count)
message(STATUS "Collected ${collected_count} class diagram(s) into ${DEST_DIR}")
