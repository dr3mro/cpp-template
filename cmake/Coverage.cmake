# =============================================================================
# Coverage.cmake - LLVM source-based code coverage
#
# Two parts, because the flags must exist before the targets and the report
# needs the test target:
#   include(Coverage)            adds the instrumentation flags (with the other
#                                build flags, before any target exists)
#   myapp_add_coverage_report()  defines the `coverage` target (after tests/)
#
# `cmake --build --preset coverage --target coverage` runs the tests, prints a
# summary and writes an HTML report to build/coverage/html/.
#
# Reads: MYAPP_ENABLE_COVERAGE (Options.cmake). Needs clang plus matching
# llvm-profdata and llvm-cov.
# =============================================================================
include_guard(DIRECTORY)

if(MYAPP_ENABLE_COVERAGE)
    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(FATAL_ERROR
            "MYAPP_ENABLE_COVERAGE needs clang (LLVM source-based coverage); the "
            "compiler is ${CMAKE_CXX_COMPILER_ID}. Use the coverage preset or "
            "-DMYAPP_USE_LLVM_CLANG=ON.")
    endif()
    target_compile_options(${PROJECT_NAME}_options INTERFACE -fprofile-instr-generate -fcoverage-mapping)
    target_link_options(${PROJECT_NAME}_options INTERFACE -fprofile-instr-generate -fcoverage-mapping)
endif()

# myapp_add_coverage_report()
#
# Defines `coverage` when coverage is enabled, the tests exist, and llvm-profdata
# and llvm-cov are found next to the compiler (so they match its version).
function(myapp_add_coverage_report)
    if(NOT MYAPP_ENABLE_COVERAGE OR NOT TARGET ${PROJECT_NAME}_tests)
        return()
    endif()

    myapp_find_llvm_program(MYAPP_LLVM_PROFDATA llvm-profdata NEXT_TO_COMPILER)
    myapp_find_llvm_program(MYAPP_LLVM_COV llvm-cov NEXT_TO_COMPILER)
    if(NOT MYAPP_LLVM_PROFDATA OR NOT MYAPP_LLVM_COV)
        message(WARNING "llvm-profdata/llvm-cov not found: the coverage target is not defined.")
        return()
    endif()

    set(_out "${PROJECT_BINARY_DIR}")
    set(_tests "$<TARGET_FILE:${PROJECT_NAME}_tests>")
    # Report only the project's own code: not the tests, fuzzers or the
    # vcpkg packages (in-tree or, with presets, inside the build dir).
    set(_ignore "--ignore-filename-regex=${PROJECT_SOURCE_DIR}/(tests|fuzz|vcpkg_installed)/|${PROJECT_BINARY_DIR}/vcpkg_installed/")

    add_custom_target(coverage
        COMMAND ${CMAKE_COMMAND} -E rm -f ${_out}/default.profraw ${_out}/merged.profdata
        COMMAND ${CMAKE_COMMAND} -E env "LLVM_PROFILE_FILE=${_out}/default.profraw" ${_tests}
        COMMAND ${MYAPP_LLVM_PROFDATA} merge -sparse ${_out}/default.profraw -o ${_out}/merged.profdata
        COMMAND ${MYAPP_LLVM_COV} report ${_tests} -instr-profile=${_out}/merged.profdata ${_ignore}
        COMMAND ${MYAPP_LLVM_COV} show ${_tests} -instr-profile=${_out}/merged.profdata ${_ignore}
                -format=html -output-dir=${_out}/html
        DEPENDS ${PROJECT_NAME}_tests
        COMMENT "Running tests and generating coverage report (output: ${_out}/html/)"
        VERBATIM)
endfunction()
