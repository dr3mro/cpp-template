#!/usr/bin/env bash
# Create a new C++ project from this template.
#
#   scripts/new-project.sh <name> [destination-dir] [--std 17|20|23] [--lib] [--no-git]
#                          [--no-vcpkg] [--ext cpp|cc] [--github-user <user>] [--author <name>]
#
# A thin wrapper: the generator itself is new-project.cmake, the same one
# new-project.ps1 runs, so both produce the same project. `--help` prints all
# the options. Needs CMake 3.25+ (the project needs it anyway).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v cmake >/dev/null 2>&1; then
    echo "error: cmake was not found on PATH. Install CMake 3.25+ first:" >&2
    echo "  macOS: brew install cmake    Linux: your package manager, or https://cmake.org/download/" >&2
    exit 1
fi

exec cmake -P "$here/new-project.cmake" -- "$@"
