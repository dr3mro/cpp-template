# =============================================================================
# Hardening.cmake - security hardening flags for optimised builds
#
# Adds exploit mitigations (stack protector, FORTIFY_SOURCE, CET, RELRO, ...)
# to ${PROJECT_NAME}_options. Only Release, RelWithDebInfo and MinSizeRel are
# hardened: _FORTIFY_SOURCE needs optimisation, and Debug builds are already
# instrumented by the sanitizers. PIC/PIE is set in ProjectDefaults.cmake.
#
# Reads: MYAPP_ENABLE_HARDENING (Options.cmake)
# =============================================================================
include_guard(DIRECTORY)

if(NOT MYAPP_ENABLE_HARDENING)
    return()
endif()

include(CheckCXXCompilerFlag)
include(CheckCXXSourceCompiles)

set(_myapp_hardened_configs "Release,RelWithDebInfo,MinSizeRel")
set(_myapp_hardening_summary "")

# _myapp_harden([COMPILE <flag>...] [LINK <flag>...])
#
# Adds each flag to ${PROJECT_NAME}_options for the hardened configurations
# only, and records it for the status line printed at the end.
function(_myapp_harden)
    cmake_parse_arguments(ARG "" "" "COMPILE;LINK" ${ARGN})
    foreach(_flag IN LISTS ARG_COMPILE)
        target_compile_options(${PROJECT_NAME}_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:${_flag}>)
    endforeach()
    foreach(_flag IN LISTS ARG_LINK)
        target_link_options(${PROJECT_NAME}_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:${_flag}>)
    endforeach()
    list(APPEND _myapp_hardening_summary ${ARG_COMPILE} ${ARG_LINK})
    set(_myapp_hardening_summary "${_myapp_hardening_summary}" PARENT_SCOPE)
endfunction()

if(MSVC)
    # Buffer-overrun checks and Control Flow Guard; ASLR and DEP at link time.
    _myapp_harden(COMPILE /GS /guard:cf
                  LINK /DYNAMICBASE /NXCOMPAT)
    # High-entropy ASLR needs a 64-bit image.
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        _myapp_harden(LINK /HIGHENTROPYVA)
    endif()
    # /CETCOMPAT only exists on x64 (not ARM64). Use the compiler's own
    # architecture: an ARM64 cross-build on an AMD64 host still reports
    # CMAKE_SYSTEM_PROCESSOR=AMD64.
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "x64")
        _myapp_harden(LINK /CETCOMPAT)
    endif()
else()
    # Some distributions predefine _FORTIFY_SOURCE; undefine it first so level 3
    # does not trigger a redefinition warning.
    _myapp_harden(COMPILE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -fstack-protector-strong)

    # Stack-clash protection and Intel CET are not available everywhere (Apple
    # Clang on arm64 accepts the flag but warns it is unused, which would fail a
    # -Werror build), so probe with -Werror and only add what really works.
    set(CMAKE_REQUIRED_FLAGS "-Werror")
    check_cxx_compiler_flag("-fstack-clash-protection" MYAPP_HAS_STACK_CLASH)
    check_cxx_compiler_flag("-fcf-protection=full" MYAPP_HAS_CF_PROTECTION)
    unset(CMAKE_REQUIRED_FLAGS)
    if(MYAPP_HAS_STACK_CLASH)
        _myapp_harden(COMPILE -fstack-clash-protection)
    endif()
    if(MYAPP_HAS_CF_PROTECTION)
        _myapp_harden(COMPILE -fcf-protection=full)
    endif()

    # Standard-library assertions (cheap bounds checks in operator[], front(),
    # ...). Detect the library in use rather than guessing from the OS, so a
    # libc++ build on Linux is hardened the libc++ way.
    check_cxx_source_compiles([[
        #include <cstdint>
        #if !defined(_LIBCPP_VERSION)
        #error not libc++
        #endif
        int main() { return 0; }]] MYAPP_USING_LIBCXX)
    if(MYAPP_USING_LIBCXX)
        _myapp_harden(COMPILE -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST)
    else()
        _myapp_harden(COMPILE -D_GLIBCXX_ASSERTIONS)
    endif()

    # Full RELRO and a non-executable stack (GNU linker options).
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        _myapp_harden(LINK -Wl,-z,relro,-z,now,-z,noexecstack)
    endif()
endif()

# One line in the configure log shows exactly which flags landed.
list(JOIN _myapp_hardening_summary " " _myapp_hardening_summary)
message(STATUS "Hardening (optimised configs): ${_myapp_hardening_summary}")
