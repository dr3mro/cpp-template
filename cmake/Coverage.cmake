# Coverage report target. Included after tests/ so the test binary exists.
# Only defined when the coverage preset enabled it and the matching LLVM tools
# are present; the report and HTML land in build/coverage/.
if(NOT MYAPP_ENABLE_COVERAGE)
    return()
endif()

# Prefer the LLVM tools shipped next to the compiler we are actually using, so
# llvm-profdata/llvm-cov always match the clang that instrumented the build.
get_filename_component(_myapp_llvm_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
find_program(MYAPP_LLVM_PROFDATA NAMES llvm-profdata
             HINTS "${_myapp_llvm_dir}" /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin)
find_program(MYAPP_LLVM_COV NAMES llvm-cov
             HINTS "${_myapp_llvm_dir}" /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin)

if(NOT (MYAPP_LLVM_PROFDATA AND MYAPP_LLVM_COV AND TARGET ${PROJECT_NAME}_tests))
    return()
endif()

set(_myapp_cov_dir ${CMAKE_BINARY_DIR})
add_custom_target(coverage
    COMMAND ${CMAKE_COMMAND} -E rm -f
            ${_myapp_cov_dir}/default.profraw
            ${_myapp_cov_dir}/merged.profdata
    COMMAND ${CMAKE_COMMAND} -E env
            "LLVM_PROFILE_FILE=${_myapp_cov_dir}/default.profraw"
            $<TARGET_FILE:${PROJECT_NAME}_tests>
    COMMAND ${MYAPP_LLVM_PROFDATA} merge -sparse
            ${_myapp_cov_dir}/default.profraw
            -o ${_myapp_cov_dir}/merged.profdata
    COMMAND ${MYAPP_LLVM_COV} report
            $<TARGET_FILE:${PROJECT_NAME}_tests>
            -instr-profile=${_myapp_cov_dir}/merged.profdata
            "--ignore-filename-regex=${CMAKE_SOURCE_DIR}/(tests|vcpkg_installed)/"
    COMMAND ${MYAPP_LLVM_COV} show
            $<TARGET_FILE:${PROJECT_NAME}_tests>
            -instr-profile=${_myapp_cov_dir}/merged.profdata
            "--ignore-filename-regex=${CMAKE_SOURCE_DIR}/(tests|vcpkg_installed)/"
            -format=html -output-dir=${_myapp_cov_dir}/html
    DEPENDS ${PROJECT_NAME}_tests
    COMMENT "Running tests and generating coverage report (output: build/coverage/html/)"
    VERBATIM)
