# Security hardening. Default ON, but the flags only apply to optimised builds:
# _FORTIFY_SOURCE needs -O, and the extra instructions would just bloat a debug
# binary that the sanitizers already instrument heavily.
option(MYAPP_ENABLE_HARDENING "Enable security hardening flags (optimised builds only)" ON)

if(NOT MYAPP_ENABLE_HARDENING)
    return()
endif()

# The optimised configs that get hardened; Debug and the sanitizers do not.
set(_myapp_hardened_configs "Release,RelWithDebInfo,MinSizeRel")
set(_myapp_hardening_flags "")

if(MSVC)
    # Compiler-side: buffer-overrun check and Control-flow Guard instrumentation.
    target_compile_options(myapp_options INTERFACE
        $<$<CONFIG:${_myapp_hardened_configs}>:/GS>
        $<$<CONFIG:${_myapp_hardened_configs}>:/guard:cf>)
    # Linker-side: ASLR and DEP/non-executable stack on every build.
    target_link_options(myapp_options INTERFACE
        $<$<CONFIG:${_myapp_hardened_configs}>:/DYNAMICBASE>
        $<$<CONFIG:${_myapp_hardened_configs}>:/NXCOMPAT>)
    list(APPEND _myapp_hardening_flags "/GS /guard:cf /DYNAMICBASE /NXCOMPAT")
    # High-entropy ASLR only applies to 64-bit builds; /CETCOMPAT only exists on
    # x64 (not ARM64). CMAKE_SIZEOF_VOID_P is 8 on both, so use the architecture.
    # Only the compiler's own architecture ID is trustworthy here: an ARM64
    # cross-build running on an AMD64 host reports CMAKE_SYSTEM_PROCESSOR=AMD64.
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        target_link_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:/HIGHENTROPYVA>)
        list(APPEND _myapp_hardening_flags "/HIGHENTROPYVA")
    endif()
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID STREQUAL "x64")
        target_link_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:/CETCOMPAT>)
        list(APPEND _myapp_hardening_flags "/CETCOMPAT")
    endif()
else()
    # _FORTIFY_SOURCE is set by some distros already; undefine it first so the
    # redefinition below does not warn, then set it to level 3 (optimised only).
    target_compile_options(myapp_options INTERFACE
        $<$<CONFIG:${_myapp_hardened_configs}>:-U_FORTIFY_SOURCE>
        $<$<CONFIG:${_myapp_hardened_configs}>:-D_FORTIFY_SOURCE=3>
        $<$<CONFIG:${_myapp_hardened_configs}>:-fstack-protector-strong>)
    list(APPEND _myapp_hardening_flags "-fstack-protector-strong -D_FORTIFY_SOURCE=3")

    # Clash protection and Intel CET are not available on every compiler (Apple
    # Clang on arm64 accepts the flag name but warns it is unused, which would
    # fail a -Werror build). Probe with -Werror so only flags the compiler truly
    # honours are added.
    include(CheckCXXCompilerFlag)
    set(CMAKE_REQUIRED_FLAGS "-Werror")
    check_cxx_compiler_flag("-fstack-clash-protection" MYAPP_HAS_STACK_CLASH)
    check_cxx_compiler_flag("-fcf-protection=full" MYAPP_HAS_CF_PROTECTION)
    unset(CMAKE_REQUIRED_FLAGS)
    if(MYAPP_HAS_STACK_CLASH)
        target_compile_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:-fstack-clash-protection>)
        list(APPEND _myapp_hardening_flags "-fstack-clash-protection")
    endif()
    if(MYAPP_HAS_CF_PROTECTION)
        target_compile_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:-fcf-protection=full>)
        list(APPEND _myapp_hardening_flags "-fcf-protection=full")
    endif()

    # Standard-library hardening: detect the library actually in use rather than
    # guessing from the OS, so a libc++ build on Linux is hardened the libc++ way.
    include(CheckCXXSourceCompiles)
    check_cxx_source_compiles(
        "#include <cstdint>
#if defined(_LIBCPP_VERSION)
int main() { return 0; }
#else
#error not libc++
#endif"
        MYAPP_USING_LIBCXX)
    if(MYAPP_USING_LIBCXX)
        target_compile_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST>)
        list(APPEND _myapp_hardening_flags "-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST")
    else()
        # libstdc++ (GCC/Clang on most Linux distributions).
        target_compile_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:-D_GLIBCXX_ASSERTIONS>)
        list(APPEND _myapp_hardening_flags "-D_GLIBCXX_ASSERTIONS")
    endif()

    # Full RELRO + non-executable stack are Linux linker options.
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        target_link_options(myapp_options INTERFACE
            $<$<CONFIG:${_myapp_hardened_configs}>:-Wl,-z,relro,-z,now,-z,noexecstack>)
        list(APPEND _myapp_hardening_flags "-Wl,-z,relro,-z,now,-z,noexecstack")
    endif()
endif()

# One status line so a build log shows exactly which hardening flags landed.
# PIE/PIC is set up in CMakeLists.txt (before the targets exist), not here.
list(JOIN _myapp_hardening_flags " " _myapp_hardening_summary)
message(STATUS "Hardening (optimised configs): ${_myapp_hardening_summary}")
