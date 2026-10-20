# =============================================================================
# fuzz/CMakeLists.txt - libFuzzer targets
#
# Every fuzz/fuzz_<name>.cpp becomes an executable <name>, with its seed
# corpus in fuzz/corpus/fuzz_<name>/. The `fuzz-run` target runs each one for
# MYAPP_FUZZ_SECONDS. Guide: https://github.com/dr3mro/cpp-template/wiki/Fuzzing
#
# Built when MYAPP_BUILD_FUZZERS is ON (the fuzz preset). Sanitizers.cmake
# already compiles everything with -fsanitize=fuzzer-no-link,address,undefined;
# only these binaries add -fsanitize=fuzzer, because libFuzzer supplies main().
# =============================================================================

file(GLOB _myapp_fuzz_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/fuzz_*.cpp")

set(_myapp_fuzz_targets "")
set(_myapp_fuzz_commands "")
foreach(_source IN LISTS _myapp_fuzz_sources)
    get_filename_component(_name "${_source}" NAME_WE)

    add_executable(${_name} "${_source}")
    target_link_libraries(${_name} PRIVATE ${PROJECT_NAME}_lib)
    target_compile_options(${_name} PRIVATE -fsanitize=fuzzer)
    target_link_options(${_name} PRIVATE -fsanitize=fuzzer)
    # Top of this project's build dir, also when it is a subproject.
    set_target_properties(${_name} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}")
    list(APPEND _myapp_fuzz_targets ${_name})

    # New inputs go to a writable corpus in the build dir (libFuzzer needs it
    # to exist); the seed corpus in the source tree is only read. A fuzzer
    # without a seed folder still runs, starting from an empty input.
    set(_corpus "${PROJECT_BINARY_DIR}/fuzz-corpus/${_name}")
    set(_seeds "${CMAKE_CURRENT_SOURCE_DIR}/corpus/${_name}")
    if(NOT IS_DIRECTORY "${_seeds}")
        message(STATUS "Fuzzer ${_name} has no seed corpus (fuzz/corpus/${_name}/); "
                       "add a few example inputs there and reconfigure.")
        set(_seeds "")
    endif()
    list(APPEND _myapp_fuzz_commands
        COMMAND ${CMAKE_COMMAND} -E echo "Fuzzing ${_name} for ${MYAPP_FUZZ_SECONDS}s..."
        COMMAND ${CMAKE_COMMAND} -E make_directory "${_corpus}"
        COMMAND $<TARGET_FILE:${_name}> -max_total_time=${MYAPP_FUZZ_SECONDS}
                "${_corpus}" ${_seeds})
endforeach()

# fuzz-run: every fuzzer for a bounded time, so it fits CI and an editor task.
if(_myapp_fuzz_targets)
    add_custom_target(fuzz-run
        ${_myapp_fuzz_commands}
        DEPENDS ${_myapp_fuzz_targets}
        COMMENT "Running fuzzers"
        VERBATIM)
endif()
