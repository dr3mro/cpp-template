# =============================================================================
# Sanitizers.cmake - runtime error detectors (ASan/UBSan, TSan, MSan, fuzzing)
#
# Adds -fsanitize flags to ${PROJECT_NAME}_options so the library, app, tests
# and fuzzers are all instrumented the same way.
#
# Reads (Options.cmake):
#   MYAPP_SANITIZER      "", address (+UBSan), thread or memory - one at a time
#   MYAPP_BUILD_FUZZERS  instrument for libFuzzer (+ASan/UBSan); clang only
# =============================================================================
include_guard(DIRECTORY)
include(CheckCXXSourceCompiles)

# _myapp_use_sanitizer(<compile-flag> <link-flag> <what>)
#
# Compiles AND links a probe program with the flags first: not every compiler
# supports every sanitizer (Apple Clang has no -fsanitize=memory), and a
# compile-only check would miss a missing runtime library. Fails with a clear
# message, or adds the flags (plus frame pointers for readable stack traces).
function(_myapp_use_sanitizer compile_flag link_flag what)
    string(MAKE_C_IDENTIFIER "MYAPP_HAS_${compile_flag}" _result)
    set(CMAKE_REQUIRED_FLAGS "${compile_flag}")
    set(CMAKE_REQUIRED_LINK_OPTIONS "${link_flag}")
    check_cxx_source_compiles("int main() { return 0; }" ${_result})
    if(NOT ${_result})
        message(FATAL_ERROR "This compiler cannot build with ${compile_flag} (${what}).")
    endif()
    target_compile_options(${PROJECT_NAME}_options INTERFACE ${compile_flag} -fno-omit-frame-pointer)
    target_link_options(${PROJECT_NAME}_options INTERFACE ${link_flag})
    # UBSan only prints a report and carries on by default, so a test (or a
    # fuzz input) that hits undefined behaviour would still pass. Make every
    # UBSan finding abort the program, like ASan and TSan findings do.
    if(compile_flag MATCHES "undefined")
        target_compile_options(${PROJECT_NAME}_options INTERFACE -fno-sanitize-recover=undefined)
    endif()
endfunction()

# ---- validate the choice -------------------------------------------------------
if(NOT MYAPP_SANITIZER MATCHES "^(|address|thread|memory)$")
    message(FATAL_ERROR
        "MYAPP_SANITIZER must be empty or exactly one of: address, thread, memory "
        "(got \"${MYAPP_SANITIZER}\"). Only one sanitizer can be enabled at a time.")
endif()

# ---- fuzzing -------------------------------------------------------------------
# Everything is compiled with -fsanitize=fuzzer-no-link (coverage feedback for
# libFuzzer) plus ASan/UBSan. Only the fuzz binaries themselves link
# -fsanitize=fuzzer (fuzz/CMakeLists.txt), because libFuzzer brings its own
# main() and would break every other executable.
if(MYAPP_BUILD_FUZZERS)
    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(FATAL_ERROR
            "MYAPP_BUILD_FUZZERS needs clang (libFuzzer); the compiler is "
            "${CMAKE_CXX_COMPILER_ID}. Use the fuzz preset or -DMYAPP_USE_LLVM_CLANG=ON.")
    endif()
    if(MYAPP_SANITIZER AND NOT MYAPP_SANITIZER STREQUAL "address")
        message(FATAL_ERROR "Fuzzing already uses ASan/UBSan; it cannot be combined "
                            "with MYAPP_SANITIZER=${MYAPP_SANITIZER}.")
    endif()
    _myapp_use_sanitizer("-fsanitize=fuzzer-no-link,address,undefined"
                         "-fsanitize=address,undefined" "libFuzzer")
    return()
endif()

# ---- one regular sanitizer -----------------------------------------------------
if(MYAPP_SANITIZER STREQUAL "")
    return()
endif()

if(MSVC)
    if(NOT MYAPP_SANITIZER STREQUAL "address")
        message(FATAL_ERROR
            "MYAPP_SANITIZER=${MYAPP_SANITIZER} is not supported with MSVC; only address is.")
    endif()

    # MSVC's AddressSanitizer does not go together with the run-time checks
    # (/RTC1) or with Edit and Continue (/ZI), and it needs the linker to
    # disable incremental linking.
    #   /RTC1 and /Zi live in the debug flags of the compiler, so they are
    #   removed from them here (the flags of every target in this build);
    #   /ZI is added by the Visual Studio generator and is turned off too.
    string(REGEX REPLACE "/RTC1|/RTCs|/RTCu|/Zi" "" _myapp_msvc_debug_flags
           "${CMAKE_CXX_FLAGS_DEBUG}")
    set(CMAKE_CXX_FLAGS_DEBUG "${_myapp_msvc_debug_flags}"
        CACHE STRING "Debug flags" FORCE)
    set_property(GLOBAL PROPERTY VS_GLOBAL_EditAndContinue OFF)

    target_compile_options(${PROJECT_NAME}_options INTERFACE
        /fsanitize=address
        /Z7)             # debug info: /ZI (Edit and Continue) is not supported
    target_link_options(${PROJECT_NAME}_options INTERFACE
        /fsanitize=address
        /INCREMENTAL:NO) # incremental linking is not supported with ASan
    return()
endif()

# MemorySanitizer only works when everything it runs is instrumented: the
# standard library and every dependency. With an uninstrumented libc++ it
# reports uninitialized values inside std:: and in the test framework, and
# the build fails there instead of in the project's own code.
if(MYAPP_SANITIZER STREQUAL "memory")
    message(WARNING
        "MYAPP_SANITIZER=memory (MemorySanitizer) needs an instrumented C++ "
        "standard library and instrumented dependencies. With an uninstrumented "
        "libc++ the standard library itself reports uninitialized values and the "
        "build fails in the test framework. See the wiki: "
        "Debugging-and-Sanitizers#using-memorysanitizer")
endif()

# address also gets UBSan, so the everyday debug preset catches both memory
# errors and undefined behaviour.
if(MYAPP_SANITIZER STREQUAL "address")
    set(_myapp_san_flag "-fsanitize=address,undefined")
else()
    set(_myapp_san_flag "-fsanitize=${MYAPP_SANITIZER}")
endif()
_myapp_use_sanitizer("${_myapp_san_flag}" "${_myapp_san_flag}" "MYAPP_SANITIZER=${MYAPP_SANITIZER}")
