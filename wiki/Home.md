# C++ Project Template wiki

Everything you need to use the template: from installing the tools to
publishing a release. New to it? Read the **Start here** pages in order.

📖 API documentation (Doxygen): <https://dr3mro.github.io/cpp-template/>
💾 Template repository: <https://github.com/dr3mro/cpp-template>

## Start here

1. [Getting started](Getting-Started): install the tools and build your first project
2. [Creating a project](Creating-a-Project): `new-project.sh`, app or library
3. [Project layout](Project-Layout): what every file and folder is for
4. [Building and running](Building-and-Running): presets, build types, installing, cleaning
5. [Editor setup](Editor-Setup): Zed or VS Code with clangd and the debugger

## Everyday work

- [Writing code](Writing-Code): adding components, code style, good habits
- [Adding dependencies](Adding-Dependencies): third-party libraries with vcpkg, the right way
- [Tutorial: a library and an app](Library-and-App-Tutorial): make a library and use it from another project
- [Testing guide](Testing-Guide): doctest, running and filtering tests
- [Debugging and sanitizers](Debugging-and-Sanitizers): LLDB, reading ASan/UBSan/TSan reports
- [Fuzzing](Fuzzing): find crashes with libFuzzer; work with the corpus
- [Code quality](Code-Quality): warnings, formatting, clang-tidy, coverage, pre-commit
- [Documentation](Documentation): doc comments, the docs website and diagrams
- [Recipes](Recipes): short answers to "how do I...?"

## Reference

- [Options reference](Options-Reference): every `-D` switch
- [Security](Security): hardening flags and security checks
- [CI and releases](CI-and-Releases): what GitHub Actions checks, and publishing releases
- [CMake internals](CMake-Internals): how the build works inside
- [Maintaining the template](Maintaining-the-Template): updating dependencies and older projects, editing this wiki
- [Troubleshooting](Troubleshooting): error messages and their fixes
- [FAQ](FAQ) and [Glossary](Glossary)

## Conventions used in these pages

- Examples use the template's placeholder name **`myapp`**. In your project,
  read `myapp` as your project's name and `MYAPP` as the same in capitals
  (`bank_app` / `BANK_APP`).
- Commands run from the project's root folder (the one with `CMakePresets.json`).
- **Configure** means `cmake --preset <name>`, **build** means
  `cmake --build --preset <name>`, and **test** means `ctest --preset <name>`.
