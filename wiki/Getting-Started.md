# Getting started

This page takes you from a fresh computer to a running program in about 15
minutes. You install the tools once per machine; after that, every new
project takes one command.

## What you'll install, and why

| Tool | What it is | Needed? |
| --- | --- | --- |
| **CMake** 3.25+ | reads the build description (`CMakeLists.txt`) and generates build files | yes |
| **Ninja** | runs the compile commands, fast and in parallel | yes |
| **A C++ compiler** | Clang (macOS: comes with Xcode), GCC (Linux) or MSVC (Windows) | yes |
| **vcpkg** | a package manager that downloads and builds the libraries your project uses | yes, unless the project was created with `--no-vcpkg` |
| **LLVM** | clang-format 21+ (formatting), clang-tidy (static analysis), and clang for fuzzing and coverage | recommended |
| **Doxygen** + **Graphviz** | generate the documentation website and its diagrams | optional |

New to these words? See the [Glossary](Glossary).

## macOS

1. Install the Xcode command line tools (the compiler), if you haven't yet:

   ```bash
   xcode-select --install
   ```

2. Install the tools with [Homebrew](https://brew.sh):

   ```bash
   brew install cmake ninja pkg-config llvm doxygen graphviz
   ```

3. Install vcpkg in your home folder:

   ```bash
   git clone https://github.com/microsoft/vcpkg ~/.vcpkg
   ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
   ```

4. Tell your shell where vcpkg is. Add these two lines to **both** `~/.zshrc`
   (your terminal reads it) and `~/.zshenv` (editor tasks in Zed and VS Code
   read this one):

   ```bash
   export VCPKG_ROOT="$HOME/.vcpkg"
   export PATH="$VCPKG_ROOT:$PATH"
   ```

5. Open a **new** terminal so the change takes effect.

A project created with `--no-vcpkg` needs none of this: it has no manifest,
and its dependencies are downloaded and built from their source during the
first configure. See [Adding-Dependencies](Adding-Dependencies).

## Linux (Ubuntu / Debian)

```bash
sudo apt install cmake ninja-build g++ clang clang-tidy llvm libclang-rt-dev \
                 doxygen graphviz git curl zip unzip tar pkg-config pipx
pipx install clang-format          # the distribution's copy is often older than 21
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/.vcpkg"' >> ~/.bashrc
echo 'export PATH="$VCPKG_ROOT:$PATH"' >> ~/.bashrc
```

Then open a new terminal. On other distributions, install the same tools with
your package manager. CMake must be 3.25 or newer (`cmake --version`); if
yours is older, `pipx install cmake` gives you a current one.

## Windows

The template works on Windows x64 and on Windows ARM64. Both use the same
steps; only the developer-shell architecture differs.

1. Install **Visual Studio 2022 or 2026** (Community is free) with the
   **Desktop development with C++** workload. It includes the compiler, CMake
   and Ninja. Visual Studio 2019 works too: the template's own solution opens
   in it without CMake (see [Visual Studio](Visual-Studio)).

   On Windows ARM64, also tick **MSVC v143/v145 - VS 2022/2026 C++ ARM64
   build tools** (and the ARM64 Windows SDK) in the installer's **Individual
   components** tab. Without them Visual Studio cannot build the ARM64
   solution platform.

2. LLVM is optional, but needed for clang-format 21+, clang-tidy, fuzzing and
   coverage. Install LLVM 21 or newer:

   ```powershell
   winget install LLVM.LLVM
   # later: winget upgrade LLVM.LLVM
   ```

   If you use LLVM's `clang++`/`clang-cl` with the Visual Studio standard
   library, keep it up to date: an older LLVM is rejected by a newer STL
   ("STL1000: Unexpected compiler version"). `cl` never has this problem.

3. Install vcpkg with a **full clone** (the manifest pins a baseline commit,
   so `--depth 1` would not contain it):

   ```powershell
   git clone https://github.com/microsoft/vcpkg C:\vcpkg
   C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics
   ```

4. Set `VCPKG_ROOT` as a **user environment variable**: Start → "Edit
   environment variables for your account" → New → name `VCPKG_ROOT`, value
   `C:\vcpkg`. Restart terminals and Visual Studio afterwards.

5. Allow the project script. Windows blocks downloaded PowerShell scripts by
   default. Either allow signed local scripts once per user (no administrator
   needed), or bypass the policy for one run:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   # ...or:
   powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 bank_app
   ```

   If the template came from a GitHub zip download, `RemoteSigned` still
   refuses it because Windows marks the file as downloaded. Unblock it once:

   ```powershell
   Unblock-File .\scripts\new-project.ps1
   ```

6. Generate a project and change into it:

   ```powershell
   .\scripts\new-project.ps1 bank_app C:\dev\bank_app --std 20
   cd C:\dev\bank_app
   ```

   The PowerShell-style options work too (`-Std 20 -Lib -NoGit`), and both
   scripts accept the same command line.

7. Build it in one of three ways:

   - **Developer shell** (the CMake presets need it for the MSVC environment):

     ```powershell
     & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
     # x64:
     & "<that path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
     # ARM64:
     & "<that path>\Common7\Tools\Launch-VsDevShell.ps1" -Arch arm64 -HostArch arm64 -SkipAutomaticLocation

     cmake --preset debug
     cmake --build --preset debug
     ctest --preset debug
     ```

     `-SkipAutomaticLocation` keeps the current folder: without it the
     developer shell moves you to `%USERPROFILE%\source\repos`, and CMake
     would configure in the wrong folder. On ARM64 the `debug` preset needs
     the **C++ AddressSanitizer** component of the Visual Studio Installer;
     use `cmake --preset debug-nosan` if it is not installed.

   - **A Visual Studio generator preset**, which finds MSVC itself and does
     not need a developer shell: `cmake --preset vs2022` or
     `cmake --preset vs2026`, then build with the matching build/test preset.

   - **The checked-in solution**, with no CMake at all: `start bank_app.sln`.
     See [Visual Studio](Visual-Studio).

To build without CMake at all, open `<name>.sln` in the project root in
Visual Studio; see [Visual Studio](Visual-Studio).

### Creating a project on Windows

No Git Bash needed: `scripts/new-project.ps1` does the same as the bash
script, in Windows PowerShell 5.1 and in PowerShell 7. It accepts both
`-Std 20 -Lib -NoGit` and `--std 20 --lib --no-git`. It needs CMake: the one
on PATH, or else the one that comes with Visual Studio (the **C++ CMake tools
for Windows** component, part of the Desktop development with C++ workload).

```powershell
pwsh -File scripts\new-project.ps1 bank_app
```

If the execution policy blocks the script, use the two fixes from step 5
above (`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or
`-ExecutionPolicy Bypass` for one run). Unblock a zip download with
`Unblock-File`.

For a shortcut, add a function to your PowerShell profile
(`$PROFILE`):

```powershell
function newcpp { & "$HOME\Templates\cpp-template\scripts\new-project.ps1" @args }
```

The bash script still works from **Git Bash** or WSL.

## Check the setup

```bash
cmake --version          # 3.25 or newer
ninja --version
echo $VCPKG_ROOT         # must print the vcpkg folder, not an empty line
clang-format --version   # 21 or newer (optional)
```

## Get the template

```bash
git clone https://github.com/dr3mro/cpp-template.git ~/Templates/cpp-template
echo 'alias newcpp="$HOME/Templates/cpp-template/scripts/new-project.sh"' >> ~/.zshrc   # or ~/.bashrc
```

Open a new terminal, and `newcpp` is available everywhere.

## Your first project

```bash
cd ~/dev                 # wherever you keep projects
newcpp hello             # creates ./hello from the template
cd hello
cmake --preset debug             # configure (the first run downloads doctest; give it a minute)
cmake --build --preset debug     # compile
ctest --preset debug             # run the tests
./build/Darwin/debug/hello Amr          # prints: Hello, Amr!
```

If all four commands succeed, you're set. Next:

- [Creating a project](Creating-a-Project): the options of `new-project.sh`, app or library
- [Project layout](Project-Layout): what every file and folder is for
- [Building and running](Building-and-Running): presets, build types, installing, cleaning
- [Editor setup](Editor-Setup): Zed or VS Code with clangd and the debugger

If something failed, see [Troubleshooting](Troubleshooting).
