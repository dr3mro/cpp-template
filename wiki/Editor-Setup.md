# Editor setup

The template ships settings for **Zed** and **VS Code**. Both use
[clangd](https://clangd.llvm.org) for code completion, go-to-definition and
inline errors, and **CodeLLDB** for debugging. Any other editor that speaks
clangd works too (CLion, Neovim, Emacs, Sublime).

On Windows there is also **Visual Studio**: the project ships `<name>.sln`,
which opens in VS 2019, 2022 and 2026 without CMake. It needs the
**Desktop development with C++** workload and the **C++ CMake tools for
Windows** component. See [Visual Studio](Visual-Studio).

## How clangd finds your build

clangd needs to know how each file is compiled (include paths, defines, C++
standard). CMake writes that into `build/<preset>/compile_commands.json` on
every configure, and links `build/compile_commands.json` to the **last
configured** preset. `.clangd` tells clangd to look there.

So: **configure once** (`cmake --preset debug`) before opening the project,
and configure again whenever clangd seems confused. `.vscode/settings.json`
also runs clang-tidy inside clangd, so tidy warnings show up as you type.

## Zed

Open the project folder (`zed .`). Zed picks up `.zed/`:

- **Format on save** is on (using `.clang-format`).
- **Tasks**: command palette (`Cmd+Shift+P`) → **task: spawn**, then pick one:

  | Task | Does |
  | --- | --- |
  | `build debug` / `build release` | configure and build |
  | `build debug-nosan` | configure and build without sanitizers (what the debugger uses) |
  | `run` / `run debug` | build and run the app |
  | `test` | build and run the tests (`debug` preset) |
  | `build tsan`, `build ci`, `test ci` | the other presets |
  | `coverage report` | coverage HTML report |
  | `build fuzz` / `fuzz run` | fuzzing |
  | `format`, `tidy` | code style and static analysis |
  | `docs` | the documentation website |
  | `clean` / `clean all` | remove one preset's build / everything generated |

  **task: rerun** repeats the last one.
- **Debugging**: `F4` (or **debugger: start**) → **Debug myapp** or **Debug
  tests**. Both build the `debug-nosan` preset first. Click left of a line
  number to set a breakpoint.

## VS Code

Open the folder (`code .`). Accept the prompt to install the recommended
extensions (or install them from the Extensions view):

- **clangd** (`llvm-vs-code-extensions.vscode-clangd`): code intelligence.
  The template turns Microsoft's C/C++ IntelliSense off so the two don't
  fight.
- **CodeLLDB** (`vadimcn.vscode-lldb`): the debugger.
- **CMake Tools** (`ms-vscode.cmake-tools`): set to always use the presets.
  Pick one in the status bar.

Then:

- **Tasks**: **Terminal → Run Task...** lists `configure <preset>`,
  `build <preset>` (including `build debug-nosan`, the unsanitized build the
  debugger uses), `test`, `run`, `format`, `tidy`, `docs`, `coverage report`,
  `fuzz run`, `clean` and `clean all`. `Cmd/Ctrl+Shift+B` runs the default
  build (`build debug`).
- **Debugging**: Run and Debug (`Cmd/Ctrl+Shift+D`) → **Debug myapp** or
  **Debug tests**, then `F5`. Each builds `debug-nosan` first.

## Other editors

Point your editor's clangd at the project; `.clangd` already says where the
compile commands are. For CLion, open the folder and enable the CMake presets
(Settings → Build, Execution, Deployment → CMake). For Visual Studio, open
`<name>.sln`; see [Visual Studio](Visual-Studio).

## Formatting on commit

To check formatting (and a few other things) before every commit, whatever
editor you use:

```bash
pipx install pre-commit      # or: brew install pre-commit
pre-commit install           # once per clone
```

See [Code quality](Code-Quality).
