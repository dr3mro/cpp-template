# =============================================================================
# CompileCommands.cmake - point clangd at the last configured preset
#
# Each preset writes compile_commands.json into its own build/<preset>/ dir.
# clangd looks in build/ (see .clangd), so this links
# build/compile_commands.json to whichever preset was configured last.
#
# Skipped:
#   - for subprojects: a parent's source tree is not ours to touch;
#   - on Windows, where symlinks need special privileges;
#   - when the build dir *is* build/ (plain `cmake -B build`): the database is
#     already there.
# =============================================================================
include_guard(DIRECTORY)

if(NOT PROJECT_IS_TOP_LEVEL OR WIN32
   OR PROJECT_BINARY_DIR STREQUAL "${PROJECT_SOURCE_DIR}/build")
    return()
endif()

file(MAKE_DIRECTORY "${PROJECT_SOURCE_DIR}/build")
file(REMOVE "${PROJECT_SOURCE_DIR}/build/compile_commands.json")
file(CREATE_LINK "${PROJECT_BINARY_DIR}/compile_commands.json"
     "${PROJECT_SOURCE_DIR}/build/compile_commands.json" SYMBOLIC)
