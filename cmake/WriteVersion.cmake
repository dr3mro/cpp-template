# =============================================================================
# WriteVersion.cmake - write <name>/version.hpp with the current git hash
#
# The single implementation of the version header, used two ways:
#
#   include(WriteVersion)                 # configure time: defines the function
#   myapp_write_version_header(...)       # (Version.cmake calls it once)
#
#   cmake -DTEMPLATE=... -DOUTPUT=... -DSOURCE_DIR=... -DPROJECT_NAME=...
#         -DPROJECT_VERSION=... -P WriteVersion.cmake
#                                         # build time: the <name>_version target
#
# The header is only rewritten when its contents change, so an unchanged hash
# does not rebuild everything that includes it.
# =============================================================================
include_guard(GLOBAL)

# myapp_write_version_header(TEMPLATE <in> OUTPUT <header> SOURCE_DIR <dir>)
#
# Configures <in> with @ONLY into <header>. Besides the PROJECT_VERSION*
# variables of the caller, the template sees MYAPP_GIT_HASH: the short hash of
# HEAD in <dir>, or "unknown" outside a git checkout.
function(myapp_write_version_header)
    cmake_parse_arguments(ARG "" "TEMPLATE;OUTPUT;SOURCE_DIR" "" ${ARGN})
    foreach(_required TEMPLATE OUTPUT SOURCE_DIR)
        if(NOT ARG_${_required})
            message(FATAL_ERROR "myapp_write_version_header: ${_required} is required")
        endif()
    endforeach()

    set(MYAPP_GIT_HASH "unknown")
    find_package(Git QUIET)
    if(GIT_FOUND)
        # git walks up from SOURCE_DIR, so a copy embedded in a parent
        # repository still gets that repository's hash.
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
            WORKING_DIRECTORY "${ARG_SOURCE_DIR}"
            OUTPUT_VARIABLE _hash
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(_hash)
            set(MYAPP_GIT_HASH "${_hash}")
        endif()
    endif()

    configure_file("${ARG_TEMPLATE}" "${ARG_OUTPUT}.tmp" @ONLY)
    # cmake-lint: disable=E1126
    # cmakelang predates file(COPY_FILE ...) (CMake 3.21), so it reports a
    # false "invalid form discriminator" here. The command is correct.
    file(COPY_FILE "${ARG_OUTPUT}.tmp" "${ARG_OUTPUT}" ONLY_IF_DIFFERENT)
    file(REMOVE "${ARG_OUTPUT}.tmp")
endfunction()

# Script mode (cmake -P): the inputs arrive as -D variables.
if(CMAKE_SCRIPT_MODE_FILE STREQUAL CMAKE_CURRENT_LIST_FILE)
    myapp_write_version_header(TEMPLATE "${TEMPLATE}" OUTPUT "${OUTPUT}" SOURCE_DIR "${SOURCE_DIR}")
endif()
