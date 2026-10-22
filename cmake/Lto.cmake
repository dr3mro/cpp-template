# =============================================================================
# Lto.cmake - link-time optimisation for optimised app builds
#
# Lets the compiler optimise across source files at link time (-flto, or /GL
# with /LTCG for MSVC): usually a smaller, faster program. Only optimised
# configurations (Release, RelWithDebInfo, MinSizeRel), and only in app mode:
# an installed static library with LTO objects only links with the very same
# compiler version, which a library's consumers cannot promise.
#
# Affects targets created after this point (CMAKE_INTERPROCEDURAL_OPTIMIZATION_<CONFIG>).
#
# Reads: MYAPP_ENABLE_LTO, MYAPP_LIBRARY_MODE (Options.cmake)
# =============================================================================
include_guard(DIRECTORY)

if(NOT MYAPP_ENABLE_LTO OR MYAPP_LIBRARY_MODE OR NOT PROJECT_IS_TOP_LEVEL)
    return()
endif()

include(CheckIPOSupported)
check_ipo_supported(RESULT _myapp_ipo_supported OUTPUT _myapp_ipo_output LANGUAGES CXX)
if(NOT _myapp_ipo_supported)
    message(STATUS "Link-time optimisation is not supported here; building without it")
    return()
endif()

foreach(_config RELEASE RELWITHDEBINFO MINSIZEREL)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_${_config} ON)
endforeach()
