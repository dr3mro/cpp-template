#!/usr/bin/env bash
# Create a new C++ project from this template.
#
#   scripts/new-project.sh <name> [destination-dir] [--std 17|20|23] [--no-git] [--lib]
#                          [--github-user <user>]
#
# <name> must be a valid C++ identifier in lower_snake_case (for example: inventory, bank_app).
# It becomes the CMake project, the executable, the namespace and the include/<name>/ folder.
# It also names the Visual Studio solution and project (<name>.sln, <name>.vcxproj),
# which get a fresh project GUID and the C++ standard you chose.
# Pass --lib to generate an installable library package (with examples/) instead of an app.
# Pass --github-user to fill in the README's GitHub Pages docs link
# (https://<user>.github.io/<name>/); without it the README keeps a placeholder.
set -euo pipefail

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

NAME=""; DEST=""; STD="17"; GIT=1; LIB=0; GITHUB_USER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --std) STD="${2:?}"; shift 2 ;;
        --no-git) GIT=0; shift ;;
        --lib) LIB=1; shift ;;
        --github-user) GITHUB_USER="${2:?}"; shift 2 ;;
        -h|--help) usage ;;
        *) if [[ -z "$NAME" ]]; then NAME="$1"; elif [[ -z "$DEST" ]]; then DEST="$1"; else usage; fi; shift ;;
    esac
done

[[ -n "$NAME" ]] || usage
[[ "$NAME" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "error: name must be lower_snake_case, e.g. bank_app" >&2; exit 1; }
[[ "$STD" =~ ^(17|20|23)$ ]] || { echo "error: --std must be 17, 20 or 23" >&2; exit 1; }
[[ -z "$GITHUB_USER" || "$GITHUB_USER" =~ ^[A-Za-z0-9-]+$ ]] || { echo "error: --github-user must be a GitHub user name (letters, digits, -)" >&2; exit 1; }

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
    # Run from inside the template: git prints paths relative to it, and tar
    # must resolve them from there (not from wherever the script was started).
    # --others adds new files that are not ignored yet; the [[ -f ]] filter
    # skips tracked files deleted from the working tree.
    (cd "$TEMPLATE_DIR" \
        && git ls-files -z --cached --others --exclude-standard \
        | sort -zu \
        | while IFS= read -r -d '' file; do [[ -f "$file" ]] && printf '%s\0' "$file"; done \
        | tar --null -T - -cf -) | (cd "$DEST" && tar -xf -)
else
    (cd "$TEMPLATE_DIR" && tar --exclude='./.git' --exclude='./build' --exclude='./docs' \
        --exclude='./install' --exclude='./install-*' --exclude='./vcpkg_installed' \
        --exclude='./.cache' --exclude='./.DS_Store' --exclude='./scripts/new-project.sh' --exclude='./scripts/new-project.ps1' \
        --exclude='./.github/workflows/template-test.yml' --exclude='./wiki' \
        --exclude='./.github/workflows/wiki.yml' --exclude='./.gitmodules' -cf - .) | (cd "$DEST" && tar -xf -)
fi
rm -f "$DEST/scripts/new-project.sh" "$DEST/scripts/new-project.ps1"
rmdir "$DEST/scripts" 2>/dev/null || true
rm -f "$DEST/.github/workflows/template-test.yml"
# The wiki pages describe the template itself, so new projects start without
# them (and without the workflow that publishes them).
rm -rf "$DEST/wiki" "$DEST/.github/workflows/wiki.yml" "$DEST/.gitmodules"

# Rename every file and folder whose name carries the placeholder, deepest
# paths first: include/myapp -> include/<name>, src/myapp -> src/<name>,
# myapp.sln -> <name>.sln, myapp.vcxproj -> <name>.vcxproj, and anything a
# future version of the template adds.
find "$DEST" -depth \( -name '*myapp*' -o -name '*MYAPP*' \) -print0 \
    | while IFS= read -r -d '' path; do
        parent="$(dirname "$path")"
        base="$(basename "$path")"
        newbase="${base//MYAPP/$UPPER}"
        newbase="${newbase//myapp/$NAME}"
        [[ "$base" == "$newbase" ]] && continue
        mv "$path" "$parent/$newbase"
    done

# Every project gets its own Visual Studio project GUID (the template ships a
# placeholder, so two projects would otherwise share one). This runs before
# the placeholder replacement below, so the GUID is not touched by it.
generate_guid() {
    local uuid
    if command -v uuidgen >/dev/null 2>&1; then
        uuid="$(uuidgen)"
    elif command -v python3 >/dev/null 2>&1; then
        uuid="$(python3 -c 'import uuid;print(uuid.uuid4())')"
    elif command -v python >/dev/null 2>&1; then
        uuid="$(python -c 'import uuid;print(uuid.uuid4())')"
    else
        uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || printf '00000000-0000-4000-8000-000000000000')"
    fi
    # A python3 that is only a Windows Store stub prints nothing; never
    # write an empty GUID into the project.
    [[ "$uuid" =~ ^[0-9A-Fa-f-]{36}$ ]] || uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')"
    printf '%s' "$(printf '%s' "$uuid" | tr '[:lower:]' '[:upper:]')"
}

PROJECT_GUID="$(generate_guid)"
for vs_file in "$DEST/$NAME.sln" "$DEST/$NAME.vcxproj"; do
    [[ -f "$vs_file" ]] || continue
    perl -pi -e "s/3F2A6B1C-9D4E-4C7A-8B5F-1E2D3C4B5A69/$PROJECT_GUID/g" "$vs_file"
done

# Replace the placeholder in every text file (perl works the same on macOS and
# Linux). The Visual Studio files are plain text, so they are covered too and
# keep their CRLF line endings.
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
perl -pi -e "s/cxx_std_17/cxx_std_$STD/" "$DEST/src/CMakeLists.txt"
perl -pi -e "s/^Standard: c\+\+17/Standard: c++$STD/" "$DEST/.clang-format"

# The Visual Studio project follows the same standard. Visual Studio 2019 and
# 2022 have no "stdcpp23", so C++23 is the latest standard they offer.
case "$STD" in
    17) VS_STD="stdcpp17" ;;
    20) VS_STD="stdcpp20" ;;
    *) VS_STD="stdcpplatest" ;;
esac
if [[ -f "$DEST/$NAME.vcxproj" ]]; then
    perl -pi -e "s/stdcpp17/$VS_STD/g" "$DEST/$NAME.vcxproj"
fi

# Swap the template README for the project README, and fill in the GitHub
# Pages docs link (or leave a placeholder that says what to replace).
mv "$DEST/PROJECT_README.md" "$DEST/README.md"
GH_USER_TEXT="${GITHUB_USER:-your-github-user}"
perl -pi -e "s/\@GITHUB_USER\@/$GH_USER_TEXT/g" "$DEST/README.md"

# App mode keeps main.cpp and drops the library example; --lib does the reverse.
if [[ $LIB -eq 1 ]]; then
    perl -0pi -e 's/(option\(\w+_LIBRARY_MODE\s+"[^"]*"\s+)OFF\b/${1}ON/' "$DEST/cmake/Options.cmake"
    rm -f "$DEST/main.cpp"
    # The Visual Studio project needs no change: it builds a static library
    # when main.cpp is missing, and an executable when it is there.

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
  cmake --install build/release
  cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH=\$PWD/build/install/release && cmake --build build/examples"
else
    BUILD_HINT="cmake --preset debug && cmake --build --preset debug && ctest --preset debug"
fi

cat <<MSG

Done. Next steps:
  cd "$DEST"
  $BUILD_HINT
  zed .

On Windows you can also open $NAME.sln in Visual Studio (2019, 2022 or 2026)
and build there; no CMake needed.
MSG

if [[ $VCPKG_READY -eq 0 ]]; then
    cat <<MSG

vcpkg is not set up yet (VCPKG_ROOT missing or invalid), so the first build
will fail. The Visual Studio solution does not need it. One-time setup
(a full clone: vcpkg.json pins a baseline commit, so no --depth 1):

MSG
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            cat <<MSG
  git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
  C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics
  [Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")

Then open a new terminal (and restart Visual Studio).
MSG
            ;;
        *)
            cat <<MSG
  git clone https://github.com/microsoft/vcpkg.git ~/.vcpkg
  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
  export VCPKG_ROOT="\$HOME/.vcpkg"     # add this line to your shell profile
MSG
            ;;
    esac
    cat <<MSG

See README.md for details.
MSG
fi
