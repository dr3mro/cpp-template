# =============================================================================
# Dependencies.cmake - third-party packages the project uses
#
# The one place to find packages. Each package is:
#   1. declared in vcpkg.json ("dependencies"), so vcpkg installs it, then
#   2. found here with myapp_find_dependency() (see Helpers.cmake), then
#   3. linked in src/CMakeLists.txt (or main.cpp's target in CMakeLists.txt).
#
# Mark a package PUBLIC when the library links it PUBLIC (its headers appear in
# your public headers). The installed package config then finds it too, so
# programs using the installed library configure without extra steps.
#
# Examples:
#   myapp_find_dependency(fmt PUBLIC CONFIG)        # used in public headers
#   myapp_find_dependency(nlohmann_json CONFIG)     # only used inside src/
#
# Test-only packages (doctest) are found in tests/CMakeLists.txt instead, so
# they are only required when the tests are built.
# =============================================================================
include_guard(DIRECTORY)
