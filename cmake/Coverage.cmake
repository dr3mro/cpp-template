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

# _myapp_xcrun_find(<var> <tool>)
#
# Sets the cache entry <var> to `xcrun --find <tool>` (the copy inside the
# active Xcode or command line tools), unless <var> is already set.
function(_myapp_xcrun_find var tool)
    if(${var})
        return()
    endif()
    execute_process(
        COMMAND xcrun --find ${tool}
        OUTPUT_VARIABLE _path
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _result
        ERROR_QUIET)
    if(_result EQUAL 0 AND EXISTS "${_path}")
        set(${var} "${_path}" CACHE FILEPATH "Path to ${tool}" FORCE)
    endif()
endfunction()

# myapp_add_coverage_report()
#
# Defines `coverage` when coverage is enabled, the tests exist, and llvm-profdata
# and llvm-cov are found next to the compiler (so they match its version).
function(myapp_add_coverage_report)
    if(NOT MYAPP_ENABLE_COVERAGE OR NOT TARGET ${PROJECT_NAME}_tests)
        return()
    endif()

    # The tools must come from the same toolchain as the compiler, or
    # llvm-profdata rejects the profile ("unsupported format version").
    if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        # Apple's clang keeps them inside Xcode, reachable only through xcrun;
        # a Homebrew LLVM copy would not match Apple's profile format.
        _myapp_xcrun_find(MYAPP_LLVM_PROFDATA llvm-profdata)
        _myapp_xcrun_find(MYAPP_LLVM_COV llvm-cov)
    else()
        myapp_find_llvm_program(MYAPP_LLVM_PROFDATA llvm-profdata NEXT_TO_COMPILER)
        myapp_find_llvm_program(MYAPP_LLVM_COV llvm-cov NEXT_TO_COMPILER)
    endif()
    # Coverage was asked for explicitly, so stop here rather than fail later
    # with "unknown target 'coverage'".
    if(NOT MYAPP_LLVM_PROFDATA OR NOT MYAPP_LLVM_COV)
        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            set(_myapp_coverage_advice
                "Windows: install LLVM ('winget install LLVM.LLVM').")
        elseif(APPLE)
            set(_myapp_coverage_advice
                "macOS: install the Xcode command line tools "
                "('xcode-select --install') or LLVM ('brew install llvm').")
        else()
            set(_myapp_coverage_advice
                "Linux: install llvm ('apt install llvm').")
        endif()
        message(FATAL_ERROR
            "MYAPP_ENABLE_COVERAGE is ON but llvm-profdata/llvm-cov matching "
            "${CMAKE_CXX_COMPILER} were not found.\n"
            "${_myapp_coverage_advice}")
    endif()

    set(_out "${PROJECT_BINARY_DIR}")
    set(_tests "$<TARGET_FILE:${PROJECT_NAME}_tests>")
    # Report only the project's own code: not the tests, fuzzers or the
    # vcpkg packages (in-tree or, with presets, inside the build dir).
    # The paths are escaped: a project folder with a space or a '+' in it
    # would otherwise change the meaning of the pattern and let the tests
    # into the report.
    myapp_regex_escape(_myapp_coverage_source_dir "${PROJECT_SOURCE_DIR}")
    myapp_regex_escape(_myapp_coverage_binary_dir "${PROJECT_BINARY_DIR}")
    set(_ignore "--ignore-filename-regex=${_myapp_coverage_source_dir}/(tests|fuzz|vcpkg_installed)/|${_myapp_coverage_binary_dir}/vcpkg_installed/")

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
