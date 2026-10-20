#!/usr/bin/env bash
# Create a new C++ project from this template.
#
#   scripts/new-project.sh <name> [destination-dir] [--std 17|20|23] [--no-git]
#
# <name> must be a valid C++ identifier in lower_snake_case (for example: grocery, bank_app).
# It becomes the CMake project, the executable, the namespace and the include/<name>/ folder.
set -euo pipefail

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

NAME=""; DEST=""; STD="17"; GIT=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --std) STD="${2:?}"; shift 2 ;;
        --no-git) GIT=0; shift ;;
        -h|--help) usage ;;
        *) if [[ -z "$NAME" ]]; then NAME="$1"; elif [[ -z "$DEST" ]]; then DEST="$1"; else usage; fi; shift ;;
    esac
done

[[ -n "$NAME" ]] || usage
[[ "$NAME" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "error: name must be lower_snake_case, e.g. bank_app" >&2; exit 1; }
[[ "$STD" =~ ^(17|20|23)$ ]] || { echo "error: --std must be 17, 20 or 23" >&2; exit 1; }

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-$PWD/$NAME}"
[[ ! -e "$DEST" ]] || { echo "error: $DEST already exists" >&2; exit 1; }

UPPER="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"

echo "Creating $NAME in $DEST (C++$STD)"
mkdir -p "$DEST"
# Copy everything except git history, build output and this script.
(cd "$TEMPLATE_DIR" && tar --exclude='./.git' --exclude='./build' --exclude='./docs' --exclude='./.cache' \
    --exclude='./.DS_Store' --exclude='./scripts/new-project.sh' -cf - .) | (cd "$DEST" && tar -xf -)
rmdir "$DEST/scripts" 2>/dev/null || true

# Rename folders: include/myapp -> include/<name>, src/myapp -> src/<name>.
mv "$DEST/include/myapp" "$DEST/include/$NAME"
mv "$DEST/src/myapp" "$DEST/src/$NAME"

# Replace the placeholder in every text file (perl works the same on macOS and Linux).
find "$DEST" -type f ! -name '*.png' -print0 | xargs -0 perl -pi -e "s/MYAPP/$UPPER/g; s/myapp/$NAME/g"

# vcpkg package names allow hyphens but not underscores: fix up the manifest name.
if [[ -f "$DEST/vcpkg.json" ]]; then
    VCPKG_NAME="${NAME//_/-}"
    perl -pi -e "s/\"name\": \"[^\"]+\"/\"name\": \"$VCPKG_NAME\"/" "$DEST/vcpkg.json"
fi

# C++ standard.
perl -pi -e "s/CMAKE_CXX_STANDARD 17/CMAKE_CXX_STANDARD $STD/" "$DEST/CMakeLists.txt"
perl -pi -e "s/^Standard: c\+\+17/Standard: c++$STD/" "$DEST/.clang-format"

# Swap the template README for the project README.
mv "$DEST/PROJECT_README.md" "$DEST/README.md"

if [[ $GIT -eq 1 ]] && command -v git >/dev/null; then
    (cd "$DEST" && git init -q -b main && git add -A && git commit -qm "Initial commit from C++ template")
    echo "Initialised git repository on branch main"
fi

# The presets point CMake at $VCPKG_ROOT, so check it is usable before promising a build.
VCPKG_READY=0
if [[ -n "${VCPKG_ROOT:-}" && -f "${VCPKG_ROOT:-}/scripts/buildsystems/vcpkg.cmake" ]]; then
    VCPKG_READY=1
fi

cat <<MSG

Done. Next steps:
  cd "$DEST"
  cmake --preset debug && cmake --build --preset debug && ctest --preset debug
  zed .
MSG

if [[ $VCPKG_READY -eq 0 ]]; then
    cat <<MSG

vcpkg is not set up yet (VCPKG_ROOT missing or invalid), so the first build
will fail. One-time setup first:

  git clone --depth 1 https://github.com/microsoft/vcpkg.git ~/.vcpkg
  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
  echo 'export VCPKG_ROOT="\$HOME/.vcpkg"' >> ~/.zshrc

See README.md for details.
MSG
fi
