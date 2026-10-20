# Generate the version header so the git hash is captured at configure time.
# The header lands in <build>/generated/include/<name>/version.hpp, which keeps
# it out of the source tree and always in sync with the current commit.
find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE MYAPP_GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
endif()
if(NOT MYAPP_GIT_HASH)
    set(MYAPP_GIT_HASH "unknown")
endif()

configure_file(
    "${CMAKE_SOURCE_DIR}/include/${PROJECT_NAME}/version.hpp.in"
    "${CMAKE_BINARY_DIR}/generated/include/${PROJECT_NAME}/version.hpp"
    @ONLY)

# Expose the generated header to every target that links myapp_options, which
# is the whole project. This is also what lets clangd find it via the -I flag in
# compile_commands.json.
target_include_directories(myapp_options INTERFACE "${CMAKE_BINARY_DIR}/generated/include")
