# Full clean: deletes every generated folder so the next configure starts from
# scratch. `--target clean` only removes compiled files inside one build dir, so
# this file works two ways:
#
#   cmake -P cmake/DistClean.cmake                      # script mode: deletes now
#   cmake --build --preset debug --target distclean     # via the target below
#
# When include()d from CMakeLists.txt it only defines the distclean target;
# nothing is deleted at configure time.

if(NOT CMAKE_SCRIPT_MODE_FILE)
    # Only the top-level project gets the target, so a parent project that pulls
    # this one in with add_subdirectory/FetchContent can't wipe its own tree.
    if(PROJECT_IS_TOP_LEVEL)
        add_custom_target(distclean
            COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_FILE}
            COMMENT "Removing all generated folders"
            VERBATIM)
    endif()
    return()
endif()

# ---- script mode ----
# Paths are relative to the project root, so it works from any directory.
get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(_generated
    build              # all preset build trees (including generated docs/diagrams)
    docs               # Doxygen HTML
    vcpkg_installed    # in-tree vcpkg packages (re-downloaded on next configure)
)

foreach(_dir IN LISTS _generated)
    if(EXISTS "${_root}/${_dir}")
        message(STATUS "Removing ${_dir}/")
        file(REMOVE_RECURSE "${_root}/${_dir}")
    endif()
endforeach()
message(STATUS "Clean.")
