# =============================================================================
# Dependencies.cmake - third-party packages the project uses
#
# The one place to find packages. There are two ways to get one, and every
# package picks one of them:
#
#   1. vcpkg:        declare the package in vcpkg.json ("dependencies"), so
#                    vcpkg downloads and builds it, then find it here with
#                    myapp_find_dependency() (see Helpers.cmake)
#   2. FetchContent: fetch the package with myapp_fetch_dependency() (see
#                    FetchDependencies.cmake), which builds it from its source
#
# vcpkg is the default: it pins every dependency to one baseline, and Dependabot
# moves that baseline. FetchContent is for the packages that vcpkg does not
# have, and for projects that want no package manager at all.
#
# Mark a package PUBLIC when the library links it PUBLIC (its headers appear in
# your public headers). The installed package config then finds it too, so
# programs using the installed library configure without extra steps. A package
# that is fetched cannot be found that way: it is not installed anywhere, and
# Install.cmake warns about it.
#
# Examples:
#   myapp_find_dependency(fmt PUBLIC CONFIG)        # used in public headers
#   myapp_find_dependency(nlohmann_json CONFIG)     # only used inside src/
#   myapp_fetch_dependency(fmt                      # built from its source
#       https://github.com/fmtlib/fmt.git
#       123913715afeb8a437e6388b4473fcc4753e1c9a  # the full commit hash
#       PUBLIC)
#
# Test-only packages (doctest) are set up in tests/CMakeLists.txt instead, so
# they are only required when the tests are built.
# =============================================================================
include_guard(DIRECTORY)
