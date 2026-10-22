# =============================================================================
# Summary.cmake - print what this configure will build
#
# Included last. One block at the end of the configure output answers "what
# did I just configure?" without digging through CMakeCache.txt.
# =============================================================================
include_guard(DIRECTORY)

if(NOT PROJECT_IS_TOP_LEVEL)
    return()
endif()

# _myapp_summary_line(<label> <value>...) - one aligned "label : value" line.
function(_myapp_summary_line label)
    string(LENGTH "${label}" _len)
    math(EXPR _pad "18 - ${_len}")
    string(REPEAT " " ${_pad} _spaces)
    list(JOIN ARGN " " _value)
    message(STATUS "  ${label}${_spaces}: ${_value}")
endfunction()

if(MYAPP_LIBRARY_MODE)
    set(_myapp_mode "library (installable package)")
else()
    set(_myapp_mode "app")
endif()
get_target_property(_myapp_lib_type ${PROJECT_NAME}_lib TYPE)
if(MYAPP_SANITIZER STREQUAL "")
    set(_myapp_sanitizer "none")
else()
    set(_myapp_sanitizer "${MYAPP_SANITIZER}")
endif()

message(STATUS "")
message(STATUS "${PROJECT_NAME} ${PROJECT_VERSION} configuration:")
_myapp_summary_line("Mode" "${_myapp_mode}")
_myapp_summary_line("Library type" "${_myapp_lib_type}")
_myapp_summary_line("Build type" "${CMAKE_BUILD_TYPE}")
_myapp_summary_line("Compiler" "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
_myapp_summary_line("Sanitizer" "${_myapp_sanitizer}")
_myapp_summary_line("Hardening" "${MYAPP_ENABLE_HARDENING}")
if(CMAKE_COMPILE_WARNING_AS_ERROR)
    set(_myapp_werror ON)
else()
    set(_myapp_werror OFF)
endif()
_myapp_summary_line("Warnings as errors" "${_myapp_werror}")
if(MYAPP_ENABLE_LTO AND NOT MYAPP_LIBRARY_MODE AND CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
    set(_myapp_lto "ON (optimised configurations)")
else()
    set(_myapp_lto OFF)
endif()
_myapp_summary_line("LTO" "${_myapp_lto}")
_myapp_summary_line("Tests" "${MYAPP_BUILD_TESTS}")
_myapp_summary_line("Fuzzers" "${MYAPP_BUILD_FUZZERS}")
_myapp_summary_line("Coverage" "${MYAPP_ENABLE_COVERAGE}")
_myapp_summary_line("Install prefix" "${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
