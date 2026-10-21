# =============================================================================
# Warnings.cmake - compiler warning flags for the whole project
#
# Adds the warning set to ${PROJECT_NAME}_options, which every in-tree target
# links, so this is the single place that controls the warning level.
#
# Reads: MYAPP_WARNINGS_AS_ERRORS (Options.cmake)
# =============================================================================
include_guard(DIRECTORY)

if(MSVC)
    target_compile_options(${PROJECT_NAME}_options INTERFACE
        /W4              # high warning level
        /permissive-    # standards conformance
        /utf-8          # the sources are UTF-8, whatever the code page is
        /Zc:__cplusplus # __cplusplus reports the standard the compiler uses
    )
    if(MYAPP_WARNINGS_AS_ERRORS)
        target_compile_options(${PROJECT_NAME}_options INTERFACE /WX)
    endif()
else()
    target_compile_options(${PROJECT_NAME}_options INTERFACE
        -Wall -Wextra -pedantic
        -Wshadow        # a local hides an outer name
        -Wconversion)   # implicit narrowing conversions
    if(MYAPP_WARNINGS_AS_ERRORS)
        target_compile_options(${PROJECT_NAME}_options INTERFACE -Werror)
    endif()
endif()
