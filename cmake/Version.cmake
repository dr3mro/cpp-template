# Generate the version header at build time so the git hash never goes stale
# between commits. A custom target runs cmake -P cmake/WriteVersion.cmake, which
# only rewrites the header when the hash actually changed (so it does not cause
# a full rebuild on every build). myapp_lib depends on this target; the top-level
# CMakeLists.txt adds that dependency once the library exists.

set(MYAPP_VERSION_HEADER "${CMAKE_BINARY_DIR}/generated/include/${PROJECT_NAME}/version.hpp")

add_custom_target(myapp_version
    COMMAND ${CMAKE_COMMAND}
            -DTEMPLATE=${CMAKE_SOURCE_DIR}/include/${PROJECT_NAME}/version.hpp.in
            -DOUTPUT=${MYAPP_VERSION_HEADER}
            -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DPROJECT_NAME=${PROJECT_NAME}
            -DPROJECT_VERSION=${PROJECT_VERSION}
            -DPROJECT_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
            -DPROJECT_VERSION_MINOR=${PROJECT_VERSION_MINOR}
            -DPROJECT_VERSION_PATCH=${PROJECT_VERSION_PATCH}
            -P ${CMAKE_SOURCE_DIR}/cmake/WriteVersion.cmake
    BYPRODUCTS ${MYAPP_VERSION_HEADER}
    COMMENT "Writing ${PROJECT_NAME}/version.hpp"
    VERBATIM)

# Expose the generated header to every target that links myapp_options, which
# is the whole project. This is also what lets clangd find it via the -I flag in
# compile_commands.json.
target_include_directories(myapp_options INTERFACE "${CMAKE_BINARY_DIR}/generated/include")
