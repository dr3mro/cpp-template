#!/usr/bin/env bash
# Create a new C++ project from this template.
#
#   scripts/new-project.sh <name> [destination-dir] [--std 17|20|23] [--no-git] [--lib]
#
# <name> must be a valid C++ identifier in lower_snake_case (for example: grocery, bank_app).
# It becomes the CMake project, the executable, the namespace and the include/<name>/ folder.
# Pass --lib to generate an installable library package (with examples/) instead of an app.
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

NAME=""; DEST=""; STD="17"; GIT=1; LIB=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --std) STD="${2:?}"; shift 2 ;;
        --no-git) GIT=0; shift ;;
        --lib) LIB=1; shift ;;
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
# Copy only files git tracks, so build output, local installs and other ignored
# clutter never leak into the new project. When the template is not a git
# checkout (a plain zip download), fall back to a tar copy with the same kinds
# of paths excluded. The template-test workflow only makes sense in the template
# repo, so it is left out either way.
if git -C "$TEMPLATE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$TEMPLATE_DIR" ls-files -z --cached --modified --exclude-standard \
        | tar --null -T - -cf - | (cd "$DEST" && tar -xf -)
else
    (cd "$TEMPLATE_DIR" && tar --exclude='./.git' --exclude='./build' --exclude='./docs' \
        --exclude='./install' --exclude='./install-*' --exclude='./vcpkg_installed' \
        --exclude='./.cache' --exclude='./.DS_Store' --exclude='./scripts/new-project.sh' \
        --exclude='./.github/workflows/template-test.yml' -cf - .) | (cd "$DEST" && tar -xf -)
fi
rm -f "$DEST/scripts/new-project.sh"
rmdir "$DEST/scripts" 2>/dev/null || true
rm -f "$DEST/.github/workflows/template-test.yml"

# Rename folders: include/myapp -> include/<name>, src/myapp -> src/<name>.
mv "$DEST/include/myapp" "$DEST/include/$NAME"
mv "$DEST/src/myapp" "$DEST/src/$NAME"

# Replace the placeholder in every text file (perl works the same on macOS and Linux).
find "$DEST" -type f ! -name '*.png' -print0 | xargs -0 perl -pi -e "s/MYAPP/$UPPER/g; s/myapp/$NAME/g"

# vcpkg package names allow hyphens but not underscores: fix up the manifest
# name. The manifest's "version" field is the project's single source of
# truth (CMakeLists.txt reads it before project()), so it is the only place a
# version may be set.
if [[ -f "$DEST/vcpkg.json" ]]; then
    VCPKG_NAME="${NAME//_/-}"
    perl -pi -e "s/\"name\": \"[^\"]+\"/\"name\": \"$VCPKG_NAME\"/" "$DEST/vcpkg.json"
fi

# C++ standard (carried by the library target; see target_compile_features).
perl -pi -e "s/cxx_std_17/cxx_std_$STD/" "$DEST/CMakeLists.txt"
perl -pi -e "s/^Standard: c\+\+17/Standard: c++$STD/" "$DEST/.clang-format"

# Swap the template README for the project README.
mv "$DEST/PROJECT_README.md" "$DEST/README.md"

# App mode keeps main.cpp and drops the library example; --lib does the reverse.
if [[ $LIB -eq 1 ]]; then
    perl -pi -e 's/(option\(\w+_LIBRARY_MODE "[^"]*" )OFF\b/${1}ON/' "$DEST/CMakeLists.txt"
    rm -f "$DEST/main.cpp"

    # A library has no executable, so drop the run tasks and the app debug
    # config. Zed's tasks.json keeps one object per line; filter those lines.
    python3 - "$DEST" "$NAME" <<'PY'
import json, sys, pathlib

dest, name = pathlib.Path(sys.argv[1]), sys.argv[2]

tasks = dest / ".zed" / "tasks.json"
if tasks.exists():
    drop = {"run", "run debug"}
    kept = [ln for ln in tasks.read_text().splitlines()
            if not any(f'"label": "{d}"' in ln for d in drop)]
    tasks.write_text("\n".join(kept) + "\n")

def drop_entries(path, key, unwanted):
    p = pathlib.Path(path)
    if not p.exists():
        return
    items = json.loads(p.read_text())
    items = [it for it in items if it.get(key) not in unwanted]
    p.write_text(json.dumps(items, indent=2) + "\n")

drop_entries(dest / ".zed" / "debug.json", "label", {f"Debug {name}"})

vscode_tasks = dest / ".vscode" / "tasks.json"
if vscode_tasks.exists():
    data = json.loads(vscode_tasks.read_text())
    data["tasks"] = [t for t in data["tasks"] if t.get("label") != "run"]
    vscode_tasks.write_text(json.dumps(data, indent=2) + "\n")

launch = dest / ".vscode" / "launch.json"
if launch.exists():
    data = json.loads(launch.read_text())
    data["configurations"] = [c for c in data["configurations"] if c.get("name") != f"Debug {name}"]
    launch.write_text(json.dumps(data, indent=2) + "\n")
PY
else
    rm -rf "$DEST/examples"
fi

# Keep only the release workflow that matches the mode, named release.yml.
if [[ $LIB -eq 1 ]]; then
    rm -f "$DEST/.github/workflows/release-app.yml"
    mv "$DEST/.github/workflows/release-lib.yml" "$DEST/.github/workflows/release.yml"
else
    rm -f "$DEST/.github/workflows/release-lib.yml"
    mv "$DEST/.github/workflows/release-app.yml" "$DEST/.github/workflows/release.yml"
fi

if [[ $GIT -eq 1 ]] && command -v git >/dev/null; then
    (cd "$DEST" && git init -q -b main && git add -A && git commit -qm "Initial commit from C++ template")
    echo "Initialised git repository on branch main"
fi

# The presets point CMake at $VCPKG_ROOT, so check it is usable before promising a build.
VCPKG_READY=0
if [[ -n "${VCPKG_ROOT:-}" && -f "${VCPKG_ROOT:-}/scripts/buildsystems/vcpkg.cmake" ]]; then
    VCPKG_READY=1
fi

if [[ $LIB -eq 1 ]]; then
    # Install from release: the debug preset is ASan-instrumented, so a
    # consumer linked against it would fail without matching sanitizer flags.
    BUILD_HINT="cmake --preset debug && cmake --build --preset debug && ctest --preset debug
  cmake --preset release && cmake --build --preset release
  cmake --install build/release --prefix ./install
  cmake -S examples -B examples/build -DCMAKE_PREFIX_PATH=\$PWD/install && cmake --build examples/build"
else
    BUILD_HINT="cmake --preset debug && cmake --build --preset debug && ctest --preset debug"
fi

cat <<MSG

Done. Next steps:
  cd "$DEST"
  $BUILD_HINT
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
