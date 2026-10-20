# =============================================================================
# Options.cmake - every user-facing switch, in one place
#
# Set them on the command line (-DMYAPP_SANITIZER=address), in a preset's
# cacheVariables, or in your own CMakeUserPresets.json. The modules only read
# these; none of them declares options of its own.
#
# Two more switches live in PreProject.cmake because they must exist before
# project(): MYAPP_USE_LLVM_CLANG and MYAPP_BUILD_TESTS.
# =============================================================================
include_guard(DIRECTORY)

# ---- what to build -------------------------------------------------------------
option(MYAPP_LIBRARY_MODE
       "Build an installable library package (with examples/) instead of an app" OFF)
option(MYAPP_BUILD_FUZZERS
       "Build the libFuzzer targets in fuzz/ (needs clang; the fuzz preset sets this)" OFF)

# ---- compiler checks -----------------------------------------------------------
option(MYAPP_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

set(MYAPP_SANITIZER "" CACHE STRING
    "Sanitizer to enable: address (includes UBSan), thread or memory; empty for none")
set_property(CACHE MYAPP_SANITIZER PROPERTY STRINGS "" address thread memory)

option(MYAPP_ENABLE_HARDENING
       "Add security hardening flags to optimised (Release-like) builds" ON)
option(MYAPP_ENABLE_COVERAGE
       "Instrument for LLVM source-based coverage and add the coverage target (clang only)" OFF)

# ---- tooling -------------------------------------------------------------------
option(MYAPP_USE_CCACHE "Use ccache when it is installed" ON)
option(MYAPP_TIDY_WERROR "Make the tidy target fail on clang-tidy findings (CI)" OFF)
set(MYAPP_FUZZ_SECONDS "10" CACHE STRING
    "Seconds each fuzz target runs in the fuzz-run target")
