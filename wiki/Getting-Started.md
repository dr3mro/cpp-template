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
| **vcpkg** | a package manager that downloads and builds the libraries your project uses | yes |
| **LLVM** | clang-format 20+ (formatting), clang-tidy (static analysis), and clang for fuzzing and coverage | recommended |
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

## Linux (Ubuntu / Debian)

```bash
sudo apt install cmake ninja-build g++ clang clang-tidy llvm libclang-rt-dev \
                 doxygen graphviz git curl zip unzip tar pkg-config pipx
pipx install clang-format          # the distribution's copy is often older than 20
git clone https://github.com/microsoft/vcpkg ~/.vcpkg
~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics
echo 'export VCPKG_ROOT="$HOME/.vcpkg"' >> ~/.bashrc
echo 'export PATH="$VCPKG_ROOT:$PATH"' >> ~/.bashrc
```

Then open a new terminal. On other distributions, install the same tools with
your package manager. CMake must be 3.25 or newer (`cmake --version`); if
yours is older, `pipx install cmake` gives you a current one.

## Windows

1. Install **Visual Studio 2022 or 2026** (Community is free) with the
   **Desktop development with C++** workload. It includes the compiler, CMake
   and Ninja. Visual Studio 2019 works too: the template's own solution opens
   in it without CMake (see [Visual Studio](Visual-Studio)).
2. In a terminal:

   ```powershell
   git clone https://github.com/microsoft/vcpkg C:\vcpkg
   C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics
   ```

3. Set `VCPKG_ROOT` as a **user environment variable**: Start → "Edit
   environment variables for your account" → New → name `VCPKG_ROOT`, value
   `C:\vcpkg`. Restart terminals and Visual Studio afterwards.
4. Use the `vs2022` or `vs2026` preset (or the others from a
   "Developer PowerShell for VS").

To build without CMake at all, open `<name>.sln` in the project root in
Visual Studio; see [Visual Studio](Visual-Studio).

`new-project.sh` is a bash script; run it from **Git Bash** or WSL.

## Check the setup

```bash
cmake --version          # 3.25 or newer
ninja --version
echo $VCPKG_ROOT         # must print the vcpkg folder, not an empty line
clang-format --version   # 20 or newer (optional)
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
./build/debug/hello Amr          # prints: Hello, Amr!
```

If all four commands succeed, you're set. Next:

- [Creating a project](Creating-a-Project): the options of `new-project.sh`, app or library
- [Project layout](Project-Layout): what every file and folder is for
- [Building and running](Building-and-Running): presets, build types, installing, cleaning
- [Editor setup](Editor-Setup): Zed or VS Code with clangd and the debugger

If something failed, see [Troubleshooting](Troubleshooting).
