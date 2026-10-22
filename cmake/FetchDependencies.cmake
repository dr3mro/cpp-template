# =============================================================================
# FetchDependencies.cmake - dependencies that are built from their source
#
# The alternative to vcpkg: CMake downloads the sources of a dependency and
# builds it as part of this project (FetchContent). A project that uses it
# needs no package manager at all, and every dependency is pinned to one
# commit, so the same sources are built everywhere.
#
# Only the dependencies that FetchContent can build are a good fit: ones that
# are header-only, or that come with a CMake build of their own. A library
# that only has a Meson or a Make build belongs in vcpkg.
#
# Provides:
#   myapp_fetch_dependency()  fetch a dependency and make it available
# =============================================================================
include_guard(GLOBAL)

include(FetchContent)

# FetchContent's update step fetches from the network on every build, so the
# build would need the network and could end up with different sources than
# the ones that were pinned. Off: the commit below is the one that is built,
# and a build never needs the network once the sources are there.
set(FETCHCONTENT_UPDATES_DISCONNECTED ON)

# myapp_fetch_dependency(<name> <git-url> <commit> [PUBLIC] [SYSTEM]
#                        [FIND_PACKAGE_ARGS <find_package arguments>...])
#
# Downloads <commit> of <git-url> and adds it to the build, so the target
# <name>::<name> can be linked. With FIND_PACKAGE_ARGS, an already installed
# package is used instead of the sources: find_package() is tried first, and
# the sources are only downloaded when there is no such package.
#
# <commit> is a full SHA, not a tag: a tag can be moved, and a build that
# follows a moved tag is no longer the build that was tested. GIT_SHALLOW is
# off for the same reason: a shallow clone does not necessarily contain the
# commit at all.
#
# SYSTEM keeps the dependency's own include directories out of the project's
# warning set, so a warning in someone else's code does not fail this
# project's build.
#
# PUBLIC marks a dependency whose headers appear in this project's public
# headers. The installed package cannot find a fetched dependency (it is not
# installed anywhere), so Install.cmake warns about it.
function(myapp_fetch_dependency name url commit)
    set(_public OFF)
    set(_system OFF)
    set(_find_package_args "")
    # The arguments are read one by one: FIND_PACKAGE_ARGS takes everything
    # that follows it, and a CMake list would split the arguments at the
    # semicolons some of them contain.
    set(_rest ${ARGN})
    while(_rest)
        list(POP_FRONT _rest _arg)
        if(_arg STREQUAL "PUBLIC")
            set(_public ON)
        elseif(_arg STREQUAL "SYSTEM")
            set(_system ON)
        elseif(_arg STREQUAL "FIND_PACKAGE_ARGS")
            set(_find_package_args ${_rest})
            set(_rest "")
        else()
            message(FATAL_ERROR
                "myapp_fetch_dependency: unknown argument '${_arg}' "
                "(expected PUBLIC, SYSTEM or FIND_PACKAGE_ARGS)")
        endif()
    endwhile()

    set(_declare_args
        GIT_REPOSITORY "${url}"
        GIT_TAG "${commit}"
        # A shallow clone may not contain the pinned commit, and a full clone
        # is what makes a commit hash usable at all.
        GIT_SHALLOW OFF)
    if(_system)
        list(APPEND _declare_args SYSTEM)
    endif()
    if(_find_package_args)
        list(APPEND _declare_args FIND_PACKAGE_ARGS ${_find_package_args})
    endif()
    FetchContent_Declare(${name} ${_declare_args})
    FetchContent_MakeAvailable(${name})

    if(_public)
        # A global property, so Install.cmake can read it from any directory.
        set_property(GLOBAL APPEND PROPERTY MYAPP_FETCHED_PUBLIC_DEPENDENCIES "${name}")
    endif()
endfunction()
