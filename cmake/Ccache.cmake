# ccache transparently caches compiler invocations. It is optional; opt out with
# -DMYAPP_USE_CCACHE=OFF if it misbehaves or you want a clean compile.
option(MYAPP_USE_CCACHE "Use ccache when it is installed" ON)

if(MYAPP_USE_CCACHE)
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    endif()
endif()
