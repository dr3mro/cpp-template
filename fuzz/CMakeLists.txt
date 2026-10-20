# Fuzz targets. Only built when MYAPP_BUILD_FUZZERS is ON (the fuzz preset),
# which also supplies a fuzzer-capable clang and -fsanitize=fuzzer via
# CMAKE_CXX_FLAGS / CMAKE_EXE_LINKER_FLAGS.

set(MYAPP_FUZZ_SECONDS "10" CACHE STRING
    "Seconds each fuzz target runs in the fuzz-run target")

file(GLOB MYAPP_FUZZ_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/fuzz_*.cpp)
set(MYAPP_FUZZ_NAMES "")
foreach(fuzz_source IN LISTS MYAPP_FUZZ_SOURCES)
    get_filename_component(fuzz_name ${fuzz_source} NAME_WE)
    add_executable(${fuzz_name} ${fuzz_source})
    target_link_libraries(${fuzz_name} PRIVATE ${PROJECT_NAME}_lib)
    # Keep the binaries at the top of the build dir so fuzz-run finds them.
    set_target_properties(${fuzz_name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
    list(APPEND MYAPP_FUZZ_NAMES ${fuzz_name})
endforeach()

# fuzz-run: drive every fuzz target for a bounded time so it fits in CI and an
# editor task. New findings go to the build dir; the seeded corpus in the source
# tree is merged in read-only.
if(MYAPP_FUZZ_NAMES)
    set(_myapp_fuzz_cmds "")
    set(_myapp_fuzz_deps "")
    foreach(fuzz_name IN LISTS MYAPP_FUZZ_NAMES)
        list(APPEND _myapp_fuzz_deps ${fuzz_name})
        list(APPEND _myapp_fuzz_cmds
            COMMAND ${CMAKE_COMMAND} -E echo
                    "Fuzzing ${fuzz_name} for ${MYAPP_FUZZ_SECONDS}s..."
            # libFuzzer needs the writable corpus dir to exist before it runs.
            COMMAND ${CMAKE_COMMAND} -E make_directory
                    ${CMAKE_BINARY_DIR}/fuzz-corpus/${fuzz_name}
            COMMAND $<TARGET_FILE:${fuzz_name}>
                    -max_total_time=${MYAPP_FUZZ_SECONDS}
                    ${CMAKE_BINARY_DIR}/fuzz-corpus/${fuzz_name}
                    ${CMAKE_CURRENT_SOURCE_DIR}/corpus/${fuzz_name})
    endforeach()
    add_custom_target(fuzz-run
        ${_myapp_fuzz_cmds}
        DEPENDS ${_myapp_fuzz_deps}
        COMMENT "Running fuzzers"
        VERBATIM)
endif()
