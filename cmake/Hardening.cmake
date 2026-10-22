# =============================================================================
# Hardening.cmake - security hardening flags for optimised builds
#
# Adds exploit mitigations (stack protector, FORTIFY_SOURCE, CET, RELRO, ...)
# to ${PROJECT_NAME}_options. Only Release, RelWithDebInfo and MinSizeRel are
# hardened: _FORTIFY_SOURCE needs optimisation, and Debug builds are already
# instrumented by the sanitizers. PIC/PIE is set in ProjectDefaults.cmake.
#
# The flags depend on the platform, not on the compiler. Every flag that not
# every supported toolchain knows is probed first, so a toolchain that does
# not know one does not fail the build. The choices follow the OpenSSF
# Compiler Options Hardening Guide for C and C++.
#
# Reads: MYAPP_ENABLE_HARDENING (Options.cmake)
# =============================================================================
include_guard(DIRECTORY)

if(NOT MYAPP_ENABLE_HARDENING)
    return()
endif()

include(CheckCXXCompilerFlag)
include(CheckLinkerFlag)

set(_myapp_hardened_configs "Release,RelWithDebInfo,MinSizeRel")
set(_myapp_hardening_summary "")

# ---- the architecture, in the spelling the flags need ----------------------------
# x64 and ARM64 are the two that differ: /CETCOMPAT exists on x64 only, and
# branch protection (BTI) is an ARM64 thing. cl and clang-cl report the
# architecture in MSVC's spelling (CMAKE_CXX_COMPILER_ARCHITECTURE_ID), every
# other compiler in the processor name.
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _myapp_processor)
string(TOLOWER "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}" _myapp_architecture_id)
set(_myapp_arch_x64 OFF)
set(_myapp_arch_arm64 OFF)
if(_myapp_architecture_id STREQUAL "x64" OR _myapp_processor MATCHES "^(amd64|x64)$")
    set(_myapp_arch_x64 ON)
endif()
if(_myapp_architecture_id STREQUAL "arm64" OR _myapp_processor MATCHES "^(arm64|aarch64)$")
    set(_myapp_arch_arm64 ON)
endif()

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

# The standard library's own checks are in StdlibChecks.cmake, because they
# are on in Debug builds too.

if(MSVC)
    # Buffer-overrun checks and Control Flow Guard; ASLR and DEP at link time.
    # Control Flow Guard needs /guard:cf at link time as well: the compiler
    # flag only marks the objects, the linker flag turns the feature on.
    _myapp_harden(COMPILE /GS /guard:cf
                  LINK /guard:cf /DYNAMICBASE /NXCOMPAT)
    # SHA-256 instead of MD5 for the source file hashes in the PDB.
    _myapp_harden(COMPILE /ZH:SHA_256)
    # High-entropy ASLR needs a 64-bit image.
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        _myapp_harden(LINK /HIGHENTROPYVA)
    endif()
    # /CETCOMPAT only exists on x64 (not ARM64). EH continuation metadata
    # (/guard:ehcont) lets CET shadow stacks check exception handling too; it
    # needs the flag at compile and at link time, and is x64-only as well.
    if(_myapp_arch_x64)
        _myapp_harden(COMPILE /guard:ehcont LINK /CETCOMPAT /guard:ehcont)
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    # Windows with LLVM's clang in its GNU style (clang++ instead of
    # clang-cl): the same protections as with MSVC, but spelled the way the
    # driver expects. The compiler flags go to clang, the linker flags go to
    # the linker (lld-link), which the GNU style reaches with -Wl,.
    set(CMAKE_REQUIRED_FLAGS "-Werror")
    check_cxx_compiler_flag("-mguard=cf" MYAPP_HAS_GUARD_CF)
    check_linker_flag("-Wl,/DYNAMICBASE" MYAPP_HAS_DYNAMICBASE)
    check_linker_flag("-Wl,/NXCOMPAT" MYAPP_HAS_NXCOMPAT)
    check_linker_flag("-Wl,/HIGHENTROPYVA" MYAPP_HAS_HIGHENTROPYVA)
    # /CETCOMPAT only exists on x64 (not ARM64).
    if(_myapp_arch_x64)
        check_linker_flag("-Wl,/CETCOMPAT" MYAPP_HAS_CETCOMPAT)
    endif()
    # ARM64: branch protection (BTI) needs -mbranch-protection=standard.
    if(_myapp_arch_arm64)
        check_cxx_compiler_flag("-mbranch-protection=standard" MYAPP_HAS_BRANCH_PROTECTION)
    endif()
    unset(CMAKE_REQUIRED_FLAGS)

    if(MYAPP_HAS_GUARD_CF)
        _myapp_harden(COMPILE -mguard=cf)
    endif()
    if(MYAPP_HAS_DYNAMICBASE)
        _myapp_harden(LINK -Wl,/DYNAMICBASE)
    endif()
    if(MYAPP_HAS_NXCOMPAT)
        _myapp_harden(LINK -Wl,/NXCOMPAT)
    endif()
    if(MYAPP_HAS_HIGHENTROPYVA AND CMAKE_SIZEOF_VOID_P EQUAL 8)
        _myapp_harden(LINK -Wl,/HIGHENTROPYVA)
    endif()
    if(MYAPP_HAS_CETCOMPAT)
        _myapp_harden(LINK -Wl,/CETCOMPAT)
    endif()
    if(MYAPP_HAS_BRANCH_PROTECTION)
        _myapp_harden(COMPILE -mbranch-protection=standard)
    endif()
else()
    # Some distributions predefine _FORTIFY_SOURCE; undefine it first so level 3
    # does not trigger a redefinition warning. Only glibc (Linux) and Apple's
    # libc (macOS) have the fortified functions; elsewhere the macro does
    # nothing, and Windows has no use for it at all.
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        _myapp_harden(COMPILE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3)
    endif()
    _myapp_harden(COMPILE -fstack-protector-strong)

    # Stack-clash protection and Intel CET are not available everywhere (Apple
    # Clang on arm64 accepts the flag but warns it is unused, which would fail a
    # -Werror build), so probe with -Werror and only add what really works.
    set(CMAKE_REQUIRED_FLAGS "-Werror")
    check_cxx_compiler_flag("-fstack-clash-protection" MYAPP_HAS_STACK_CLASH)
    check_cxx_compiler_flag("-fcf-protection=full" MYAPP_HAS_CF_PROTECTION)
    # Zero instead of leftover stack data in variables that are read before
    # they are written (GCC 12+, Clang 16+), and _FORTIFY_SOURCE bounds for
    # trailing arrays that are not declared as flexible (GCC 13+, Clang 16+).
    check_cxx_compiler_flag("-ftrivial-auto-var-init=zero" MYAPP_HAS_AUTO_VAR_INIT)
    check_cxx_compiler_flag("-fstrict-flex-arrays=3" MYAPP_HAS_STRICT_FLEX_ARRAYS)
    # ARM64: branch protection (BTI) needs -mbranch-protection=standard. The
    # flag does not exist on other architectures, so it is only probed there.
    if(_myapp_arch_arm64)
        check_cxx_compiler_flag("-mbranch-protection=standard" MYAPP_HAS_BRANCH_PROTECTION)
    endif()
    unset(CMAKE_REQUIRED_FLAGS)
    if(MYAPP_HAS_STACK_CLASH)
        _myapp_harden(COMPILE -fstack-clash-protection)
    endif()
    if(MYAPP_HAS_CF_PROTECTION)
        _myapp_harden(COMPILE -fcf-protection=full)
    endif()
    if(MYAPP_HAS_AUTO_VAR_INIT)
        _myapp_harden(COMPILE -ftrivial-auto-var-init=zero)
    endif()
    if(MYAPP_HAS_STRICT_FLEX_ARRAYS)
        _myapp_harden(COMPILE -fstrict-flex-arrays=3)
    endif()
    if(MYAPP_HAS_BRANCH_PROTECTION)
        _myapp_harden(COMPILE -mbranch-protection=standard)
    endif()

    # Full RELRO and a non-executable stack (GNU linker options), and no
    # DT_NEEDED entries for libraries nothing uses. (-z,nodlopen is left out
    # on purpose: it would stop a library project from being dlopen()ed.)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        _myapp_harden(LINK -Wl,-z,relro,-z,now,-z,noexecstack -Wl,--as-needed)
    endif()
endif()

# One line in the configure log shows exactly which flags landed.
list(JOIN _myapp_hardening_summary " " _myapp_hardening_summary)
message(STATUS "Hardening (optimised configs): ${_myapp_hardening_summary}")
