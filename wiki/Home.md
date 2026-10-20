# C++ Project Template wiki

These pages go deeper than the [README](https://github.com/dr3mro/cpp-template#readme).
The README gets you started: setup, creating a project, building, the
library-and-app tutorial and adding dependencies. The wiki explains how the
template works inside, collects recipes for everyday tasks, and answers the
questions that come up once you use it for real projects.

📖 API documentation (Doxygen): <https://dr3mro.github.io/cpp-template/>

## Pages

| Page | Read it when you want to... |
| --- | --- |
| [Recipes](Recipes) | do a common task: add a second program, a build option, link-time optimisation, your own presets, ... |
| [Testing guide](Testing-Guide) | write good doctest tests and run exactly the ones you need |
| [Debugging and sanitizers](Debugging-and-Sanitizers) | step through code, and read ASan, UBSan and TSan reports |
| [CMake internals](CMake-Internals) | understand how the build is put together, or change it safely |
| [CI and releases](CI-and-Releases) | know what each GitHub Actions job checks, fix a red build, publish a release |
| [Maintaining the template](Maintaining-the-Template) | update dependencies, bring template improvements into older projects, extend the template |
| [FAQ](FAQ) | find a quick answer |

## Conventions used in these pages

- Examples use the template's own placeholder name, **`myapp`**. In a project
  you created with `new-project.sh`, replace `myapp` with your project's name
  and `MYAPP` with the same name in capitals (`bank_app` / `BANK_APP`).
- Commands run from the project's root folder (the one with `CMakePresets.json`).
- "Configure" means `cmake --preset <name>`, "build" means
  `cmake --build --preset <name>`, and "test" means `ctest --preset <name>`.

## Editing this wiki

The pages live in the template repository under `wiki/`, and the `wiki`
workflow publishes them here on every push to `main`. Edit them there, not in
the GitHub web editor; edits made here are overwritten by the next sync.
