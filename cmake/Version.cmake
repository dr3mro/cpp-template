# Generate the version header at build time so the git hash never goes stale
# between commits. A custom target runs cmake -P cmake/WriteVersion.cmake, which
# only rewrites the header when the hash actually changed (so it does not cause
# a full rebuild on every build). myapp_lib depends on this target; the top-level
# CMakeLists.txt adds that dependency once the library exists.

set(MYAPP_VERSION_HEADER "${PROJECT_BINARY_DIR}/generated/include/${PROJECT_NAME}/version.hpp")

# Write the header once at configure time too, so clangd and clang-tidy find
# it immediately after configuring (the CI tidy job only configures before it
# builds the tidy target). The custom target below refreshes the hash at build
# time; configure_file plus copy-only-if-different keeps reconfigures from
# touching a header whose contents did not change.
set(MYAPP_GIT_HASH "unknown")
find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
        # git walks up from here, so a copy embedded in a parent repository
        # still gets that repository's hash.
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        OUTPUT_VARIABLE MYAPP_GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
endif()
if(NOT MYAPP_GIT_HASH)
    set(MYAPP_GIT_HASH "unknown")
endif()
configure_file("${PROJECT_SOURCE_DIR}/include/${PROJECT_NAME}/version.hpp.in"
               "${MYAPP_VERSION_HEADER}.tmp" @ONLY)
file(COPY_FILE "${MYAPP_VERSION_HEADER}.tmp" "${MYAPP_VERSION_HEADER}" ONLY_IF_DIFFERENT)
file(REMOVE "${MYAPP_VERSION_HEADER}.tmp")

add_custom_target(myapp_version
    COMMAND ${CMAKE_COMMAND}
            -DTEMPLATE=${PROJECT_SOURCE_DIR}/include/${PROJECT_NAME}/version.hpp.in
            -DOUTPUT=${MYAPP_VERSION_HEADER}
            -DSOURCE_DIR=${PROJECT_SOURCE_DIR}
            -DPROJECT_NAME=${PROJECT_NAME}
            -DPROJECT_VERSION=${PROJECT_VERSION}
            -DPROJECT_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
            -DPROJECT_VERSION_MINOR=${PROJECT_VERSION_MINOR}
            -DPROJECT_VERSION_PATCH=${PROJECT_VERSION_PATCH}
            -P ${PROJECT_SOURCE_DIR}/cmake/WriteVersion.cmake
    BYPRODUCTS ${MYAPP_VERSION_HEADER}
    COMMENT "Writing ${PROJECT_NAME}/version.hpp"
    VERBATIM)

# Expose the generated header to every target that links myapp_options, which
# is the whole project. This is also what lets clangd find it via the -I flag in
# compile_commands.json.
target_include_directories(myapp_options INTERFACE "${PROJECT_BINARY_DIR}/generated/include")
