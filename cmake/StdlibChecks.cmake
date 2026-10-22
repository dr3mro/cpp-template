# =============================================================================
# StdlibChecks.cmake - the standard library's own checks
#
# Each C++ standard library can check its own preconditions (an index out of
# range in operator[], front() on an empty container, ...) and abort instead
# of corrupting memory. The checks are nearly free, so they are on in every
# build of this project: the cheaper set in optimised builds (a hardening
# measure, see Hardening.cmake), the full set in Debug.
#
#   libc++         _LIBCPP_HARDENING_MODE: _FAST optimised, _DEBUG in Debug
#   libstdc++      _GLIBCXX_ASSERTIONS in every configuration (_GLIBCXX_DEBUG
#                  would change the ABI, so it stays a manual opt-in)
#   Visual Studio  _MSVC_STL_HARDENING optimised (newer STLs only); Debug
#                  already has _ITERATOR_DEBUG_LEVEL=2 by default
#
# The library is detected, not guessed from the operating system: a libc++
# build on Linux is checked the libc++ way, and clang on Windows uses the
# Visual Studio STL.
#
# Reads: MYAPP_ENABLE_HARDENING (Options.cmake) for the optimised checks.
# Provides: MYAPP_USING_LIBCXX, MYAPP_USING_LIBSTDCXX, MYAPP_USING_MSVC_STL.
# =============================================================================
include_guard(DIRECTORY)
include(CheckCXXSourceCompiles)

check_cxx_source_compiles([[
    #include <cstdint>
    #if !defined(_LIBCPP_VERSION)
    #error not libc++
    #endif
    int main() { return 0; }]] MYAPP_USING_LIBCXX)
check_cxx_source_compiles([[
    #include <cstdint>
    #if !defined(__GLIBCXX__)
    #error not libstdc++
    #endif
    int main() { return 0; }]] MYAPP_USING_LIBSTDCXX)
check_cxx_source_compiles([[
    #include <cstdint>
    #if !defined(_MSVC_STL_VERSION)
    #error not the Visual Studio STL
    #endif
    int main() { return 0; }]] MYAPP_USING_MSVC_STL)

set(_myapp_optimised_configs "Release,RelWithDebInfo,MinSizeRel")

if(MYAPP_USING_LIBCXX)
    target_compile_definitions(${PROJECT_NAME}_options INTERFACE
        $<$<CONFIG:Debug>:_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG>)
    if(MYAPP_ENABLE_HARDENING)
        set(_myapp_libcxx_fast "_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST")
        target_compile_definitions(${PROJECT_NAME}_options INTERFACE
            $<$<CONFIG:${_myapp_optimised_configs}>:${_myapp_libcxx_fast}>)
    endif()
elseif(MYAPP_USING_LIBSTDCXX)
    if(MYAPP_ENABLE_HARDENING)
        target_compile_definitions(${PROJECT_NAME}_options INTERFACE _GLIBCXX_ASSERTIONS)
    else()
        target_compile_definitions(${PROJECT_NAME}_options INTERFACE
            $<$<CONFIG:Debug>:_GLIBCXX_ASSERTIONS>)
    endif()
elseif(MYAPP_USING_MSVC_STL AND MYAPP_ENABLE_HARDENING)
    # Only newer STLs know the switch, so compile a program with it first: a
    # compiler that does not accept it must not break the build.
    set(CMAKE_REQUIRED_DEFINITIONS "-D_MSVC_STL_HARDENING=1")
    check_cxx_source_compiles([[
        #include <vector>
        #if !defined(_MSVC_STL_HARDENING)
        #error the STL does not know the hardening switch
        #endif
        int main() { return 0; }]] MYAPP_HAS_MSVC_STL_HARDENING)
    unset(CMAKE_REQUIRED_DEFINITIONS)
    if(MYAPP_HAS_MSVC_STL_HARDENING)
        target_compile_definitions(${PROJECT_NAME}_options INTERFACE
            $<$<CONFIG:${_myapp_optimised_configs}>:_MSVC_STL_HARDENING=1>)
    endif()
endif()
