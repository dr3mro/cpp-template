# =============================================================================
# ArchitectureDiagram.cmake - architecture.dot generated from the CMake targets
#
# Included by Docs.cmake. At the end of configuring it walks every target this
# project defined (library, app, tests, fuzzers) and writes a Graphviz graph of
# them and their links to ${MYAPP_ARCHITECTURE_DOT}. The docs target renders
# it to docs/diagrams/architecture.png, so the picture can never drift from
# the real build.
#
# The .dot lives in the build tree: each preset draws the targets it actually
# builds (the docs preset turns the tests on so they appear too).
# =============================================================================
include_guard(DIRECTORY)

set(MYAPP_ARCHITECTURE_DOT "${PROJECT_BINARY_DIR}/architecture.dot")

# _myapp_collect_targets(<dir> <out-var>)
#
# Recursively lists the real targets of <dir> and its subdirectories.
function(_myapp_collect_targets dir out_var)
    get_property(targets DIRECTORY ${dir} PROPERTY BUILDSYSTEM_TARGETS)
    get_property(subdirs DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)
    foreach(sub IN LISTS subdirs)
        _myapp_collect_targets(${sub} sub_targets)
        list(APPEND targets ${sub_targets})
    endforeach()
    set(${out_var} ${targets} PARENT_SCOPE)
endfunction()

# _myapp_dot_id(<name> <out-var>)
#
# Graphviz node ids cannot contain ':' or '-', so map names to safe ids.
function(_myapp_dot_id name out_var)
    string(MAKE_C_IDENTIFIER "${name}" id)
    set(${out_var} "n_${id}" PARENT_SCOPE)
endfunction()

# _myapp_dot_node_style(<target> <type> <out-style> <out-kind>)
#
# Picks the fill/colour and the label word for one target: tests and fuzzers
# get their own colour, everything else the default. <out-style> is empty for
# a library, so the caller can append it only when there is one.
function(_myapp_dot_node_style target type out_style out_kind)
    if(type STREQUAL "EXECUTABLE" AND target MATCHES "_tests$")
        set(style "fillcolor=\"#FCF3CF\", color=\"#B7950B\"")
        set(kind "unit tests")
    elseif(type STREQUAL "EXECUTABLE" AND target MATCHES "^fuzz")
        set(style "fillcolor=\"#FADBD8\", color=\"#B03A2E\"")
        set(kind "fuzz target")
    elseif(type STREQUAL "EXECUTABLE")
        set(style "fillcolor=\"#D5F5E3\", color=\"#1E8449\"")
        set(kind "executable")
    else()
        set(style "")
        string(TOLOWER "${type}" kind)
        string(REPLACE "_" " " kind "${kind}")
    endif()
    set(${out_style} "${style}" PARENT_SCOPE)
    set(${out_kind} "${kind}" PARENT_SCOPE)
endfunction()

# _myapp_dot_node_location(<target> <out-rel-dir> <out-source-count>)
#
# The first source file's directory hints at where the code lives; the count
# goes into the node label.
function(_myapp_dot_node_location target out_rel_dir out_source_count)
    get_target_property(target_dir ${target} SOURCE_DIR)
    get_target_property(sources ${target} SOURCES)
    list(LENGTH sources source_count)
    list(GET sources 0 first_source)
    cmake_path(ABSOLUTE_PATH first_source BASE_DIRECTORY ${target_dir})
    cmake_path(GET first_source PARENT_PATH first_dir)
    file(RELATIVE_PATH rel_dir ${PROJECT_SOURCE_DIR} ${first_dir})
    if(rel_dir STREQUAL "")
        set(rel_dir ".")
    endif()
    set(${out_rel_dir} "${rel_dir}" PARENT_SCOPE)
    set(${out_source_count} "${source_count}" PARENT_SCOPE)
endfunction()

# _myapp_dot_edges(<target> <node-id> <edges-var> <externals-var>)
#
# Appends the edges of one target to <edges-var> and records packages found in
# a subdirectory (doctest in tests/) in <externals-var>, because they are not
# visible here. Edges from tests and fuzzers are dashed and labelled "tests".
function(_myapp_dot_edges target id edges_var externals_var)
    get_target_property(links ${target} LINK_LIBRARIES)
    if(NOT links)
        return()
    endif()
    set(edges "${${edges_var}}")
    set(externals "${${externals_var}}")
    foreach(link IN LISTS links)
        # Keep what the build links; drop install-only parts.
        string(REGEX REPLACE "^\\$<BUILD_INTERFACE:(.*)>$" "\\1" link "${link}")
        if(link MATCHES "^\\$<")
            continue()
        endif()
        # Any Name::target is treated as external: packages found in a
        # subdirectory are not visible from this directory.
        if(link MATCHES "::")
            if(NOT link IN_LIST externals)
                list(APPEND externals ${link})
            endif()
        elseif(NOT TARGET ${link})
            continue()   # plain library names such as system libs
        else()
            get_target_property(link_type ${link} TYPE)
            if(link_type STREQUAL "INTERFACE_LIBRARY")
                continue()   # internal option bags such as myapp_options
            endif()
        endif()
        _myapp_dot_id(${link} link_id)
        if(target MATCHES "_tests$|^fuzz" AND NOT link MATCHES "::")
            string(APPEND edges "    ${id} -> ${link_id} [label=\"tests\", style=dashed];\n")
        else()
            string(APPEND edges "    ${id} -> ${link_id} [label=\"links\"];\n")
        endif()
    endforeach()
    set(${edges_var} "${edges}" PARENT_SCOPE)
    set(${externals_var} "${externals}" PARENT_SCOPE)
endfunction()

# _myapp_dot_nodes(<targets> <out-nodes> <out-edges> <out-externals>)
#
# Builds the node and edge lines of the graph, plus the external package nodes
# that are appended after them.
function(_myapp_dot_nodes targets out_nodes out_edges out_externals)
    set(nodes "")
    set(edges "")
    set(externals "")
    set(node_types "^(EXECUTABLE|STATIC_LIBRARY|SHARED_LIBRARY|MODULE_LIBRARY|OBJECT_LIBRARY)$")
    foreach(target IN LISTS targets)
        get_target_property(type ${target} TYPE)
        if(NOT type MATCHES "${node_types}")
            continue()   # skip custom/utility targets and INTERFACE option bags
        endif()

        _myapp_dot_id(${target} id)
        _myapp_dot_node_style(${target} ${type} style kind)
        _myapp_dot_node_location(${target} rel_dir source_count)
        if(style)
            set(style ", ${style}")
        endif()
        string(APPEND nodes
            "    ${id} [label=\"${target}\\n${kind} - ${source_count} file(s) in "
            "${rel_dir}/\"${style}];\n")

        _myapp_dot_edges(${target} ${id} edges externals)
    endforeach()

    foreach(ext IN LISTS externals)
        _myapp_dot_id(${ext} ext_id)
        string(APPEND nodes
            "    ${ext_id} [label=\"${ext}\\nexternal package\", "
            "fillcolor=\"#F2F3F4\", color=\"#7B7D7D\"];\n")
    endforeach()

    set(${out_nodes} "${nodes}" PARENT_SCOPE)
    set(${out_edges} "${edges}" PARENT_SCOPE)
    set(${out_externals} "${externals}" PARENT_SCOPE)
endfunction()

# _myapp_write_if_changed(<path> <content>)
#
# Only touches the file when it changes, so the PNG is not re-rendered and the
# docs target stays incremental on every configure.
function(_myapp_write_if_changed path content)
    if(EXISTS ${path})
        file(READ ${path} old_content)
    else()
        set(old_content "")
    endif()
    if(NOT old_content STREQUAL content)
        file(WRITE ${path} "${content}")
        message(STATUS "Architecture diagram source updated: ${path}")
    endif()
endfunction()

# _myapp_write_architecture()
#
# Writes ${MYAPP_ARCHITECTURE_DOT}: the header, the nodes, the edges and the
# external packages, in that order.
function(_myapp_write_architecture)
    _myapp_collect_targets(${PROJECT_SOURCE_DIR} all_targets)
    _myapp_dot_nodes("${all_targets}" nodes edges externals)

    string(CONCAT content
        "// Generated by cmake/ArchitectureDiagram.cmake - do not edit by hand.\n"
        "// Regenerate with: cmake --workflow --preset docs\n"
        "digraph Architecture {\n"
        "    graph [bgcolor=\"white\", fontname=\"Helvetica\", rankdir=TB, "
        "nodesep=0.45, ranksep=0.55, pad=0.25,\n"
        "           labelloc=\"t\", label=\"${PROJECT_NAME} ${PROJECT_VERSION} - "
        "Architecture\", fontsize=22];\n"
        "    node  [shape=box, style=\"rounded,filled\", fillcolor=\"#EAF2F8\", "
        "color=\"#2874A6\",\n"
        "           fontname=\"Helvetica\", fontsize=11, margin=\"0.16,0.10\"];\n"
        "    edge  [color=\"#566573\", fontname=\"Helvetica\", fontsize=10, arrowsize=0.75];\n"
        "\n"
        "${nodes}\n"
        "${edges}}\n")

    _myapp_write_if_changed(${MYAPP_ARCHITECTURE_DOT} "${content}")
endfunction()

# Deferred to the end of this project's CMakeLists so every target exists.
cmake_language(DEFER DIRECTORY ${PROJECT_SOURCE_DIR} CALL _myapp_write_architecture)
