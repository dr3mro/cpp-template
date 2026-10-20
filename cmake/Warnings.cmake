# Shared warning flags. Every target links myapp_options so a single place
# controls the warning level for the whole project.
add_library(myapp_options INTERFACE)

option(MYAPP_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

if(MSVC)
    target_compile_options(myapp_options INTERFACE /W4 /permissive-)
    if(MYAPP_WARNINGS_AS_ERRORS)
        target_compile_options(myapp_options INTERFACE /WX)
    endif()
else()
    target_compile_options(myapp_options INTERFACE -Wall -Wextra -pedantic -Wshadow -Wconversion)
    if(MYAPP_WARNINGS_AS_ERRORS)
        target_compile_options(myapp_options INTERFACE -Werror)
    endif()
endif()
