# Runs at build time (`cmake -P`) to refresh version.hpp with the current git
# hash. Only rewrites the file when its contents change, so an unchanged hash
# does not trigger a rebuild of everything that includes the header.
#
# Inputs (passed with -D):
#   TEMPLATE   the version.hpp.in to configure
#   OUTPUT     the generated header to write / refresh
#   SOURCE_DIR the project root used to run git

if(NOT TEMPLATE OR NOT OUTPUT)
    message(FATAL_ERROR "WriteVersion.cmake: TEMPLATE and OUTPUT are required")
endif()

set(_hash "unknown")
find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
        WORKING_DIRECTORY "${SOURCE_DIR}"
        OUTPUT_VARIABLE _hash
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
endif()
if(NOT _hash)
    set(_hash "unknown")
endif()

set(MYAPP_GIT_HASH "${_hash}")
configure_file("${TEMPLATE}" "${OUTPUT}.tmp" @ONLY)
file(COPY_FILE "${OUTPUT}.tmp" "${OUTPUT}" ONLY_IF_DIFFERENT)
file(REMOVE "${OUTPUT}.tmp")
