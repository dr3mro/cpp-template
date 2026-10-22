# =============================================================================
# Warnings.cmake - compiler warning flags for the whole project
#
# Adds the warning set to ${PROJECT_NAME}_options, which every in-tree target
# links, so this is the single place that controls the warning level. Every
# flag is in the default set of the compilers the template supports (GCC 11+,
# Clang 14+, Apple Clang, MSVC 2019+), so none needs a probe.
#
# Warnings as errors: CMake's own CMAKE_COMPILE_WARNING_AS_ERROR (the ci
# preset sets it), which `cmake --compile-no-warning-as-error` overrides.
# =============================================================================
include_guard(DIRECTORY)

if(MSVC)
    target_compile_options(${PROJECT_NAME}_options INTERFACE
        /W4              # high warning level
        /permissive-    # standards conformance
        /utf-8          # the sources are UTF-8, whatever the code page is
        /Zc:__cplusplus # __cplusplus reports the standard the compiler uses
        /sdl            # extra security warnings and checks (also in the .vcxproj)
        /external:W0    # no warnings from headers included as external (vcpkg's)
        # Off by default even at /W4; the same set lives in the .vcxproj.
        /w14242 # conversion, possible loss of data
        /w14254 # larger bit field assigned to a smaller one
        /w14263 # member function does not override a base virtual function
        /w14265 # class has virtual functions but a non-virtual destructor
        /w14287 # unsigned/negative constant mismatch
        /w14296 # expression is always true/false
        /w14311 # pointer truncation
        /w14826 # sign-extending conversion
        /w14905 # wide string literal cast to LPSTR
        /w14906 # string literal cast to LPWSTR
        /w14928 # illegal copy-initialization
    )
else()
    target_compile_options(${PROJECT_NAME}_options INTERFACE
        -Wall -Wextra -pedantic
        -Wshadow               # a local hides an outer name
        -Wconversion           # implicit narrowing conversions
        -Wsign-conversion      # implicit signed/unsigned conversions
        -Wold-style-cast       # (T)x instead of a named cast
        -Wnon-virtual-dtor     # a polymorphic class without a virtual destructor
        -Woverloaded-virtual   # a function hides a base virtual of the same name
        -Wcast-align           # a cast that raises the alignment requirement
        -Wnull-dereference     # a path that dereferences a null pointer
        -Wdouble-promotion     # float silently promoted to double
        -Wformat=2             # printf-style format strings
        -Wimplicit-fallthrough # a switch case falls through without [[fallthrough]]
    )
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options(${PROJECT_NAME}_options INTERFACE
            -Wduplicated-cond       # the same condition twice in an if/else-if chain
            -Wduplicated-branches   # both branches of an if do the same thing
            -Wlogical-op            # suspicious && / || use
            -Wuseless-cast          # a cast to the type the value already has
            -Wmisleading-indentation)
    endif()
endif()
