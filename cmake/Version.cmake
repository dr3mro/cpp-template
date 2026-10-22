# =============================================================================
# Version.cmake - the generated <name>/version.hpp header
#
# The header carries the project version (from vcpkg.json) and the git
# description of the build (git describe --tags --always --dirty).
# It is written:
#   - once at configure time, so clangd and clang-tidy find it right away, and
#   - again before every build by the ${PROJECT_NAME}_version target, so the
#     hash never goes stale between commits (src/CMakeLists.txt makes the
#     library depend on that target).
# Both paths use the same function in WriteVersion.cmake.
#
# Provides: target ${PROJECT_NAME}_version, MYAPP_VERSION_HEADER, and the
#           generated include directory on ${PROJECT_NAME}_options.
# =============================================================================
include_guard(DIRECTORY)
include(WriteVersion)

set(MYAPP_GENERATED_INCLUDE_DIR "${PROJECT_BINARY_DIR}/generated/include")
set(MYAPP_VERSION_HEADER "${MYAPP_GENERATED_INCLUDE_DIR}/${PROJECT_NAME}/version.hpp")
set(_myapp_version_template "${PROJECT_SOURCE_DIR}/cmake/templates/version.hpp.in")

# Configure time.
myapp_write_version_header(
    TEMPLATE "${_myapp_version_template}"
    OUTPUT "${MYAPP_VERSION_HEADER}"
    SOURCE_DIR "${PROJECT_SOURCE_DIR}")

# Build time: the same function, run as a script with the values it needs.
add_custom_target(${PROJECT_NAME}_version
    COMMAND ${CMAKE_COMMAND}
            -DTEMPLATE=${_myapp_version_template}
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

# The generated headers (version.hpp here, the export header from
# ExportHeader.cmake) are public headers of the library: src/CMakeLists.txt
# adds this folder to the library's PUBLIC include directories, so consumers
# find them too. It is also what puts the -I flag into
# compile_commands.json for clangd.
