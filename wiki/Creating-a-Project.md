# Creating a project

Every project starts with `scripts/new-project.sh` (or the `newcpp` alias from
[Getting started](Getting-Started)). On Windows, or anywhere without bash,
`scripts/new-project.ps1` does the same thing.

```bash
newcpp bank_app                         # creates ./bank_app
newcpp bank_app ~/dev/bank              # choose the folder
newcpp bank_app --std 20                # C++20 instead of C++17 (or 23)
newcpp bank_lib --lib                   # an installable library instead of an app
newcpp bank_app --github-user dr3mro    # fill in the GitHub Pages docs link in the README
newcpp bank_app --no-git                # don't create a git repository
```

Options can be combined: `newcpp bank_lib ~/dev/bank_lib --lib --std 20`.

The PowerShell version takes the same options with their PowerShell names,
and also understands the bash-style names, so the same command line works
with both scripts:

```powershell
pwsh -NoProfile -File scripts/new-project.ps1 bank_app
pwsh -NoProfile -File scripts/new-project.ps1 bank_app C:\dev\bank -Std 20 -GitHubUser dr3mro
pwsh -NoProfile -File scripts/new-project.ps1 bank_lib -Lib -NoGit
pwsh -NoProfile -File scripts/new-project.ps1 bank_app C:\dev\bank --std 20 --github-user dr3mro
pwsh -NoProfile -File scripts/new-project.ps1 bank_lib --lib --no-git
```

`--std 20`, `--std=20`, `--lib`, `--no-git`, `--github-user <user>` and
`--github-user=<user>` are all accepted. `-h` and `--help` print the usage.

On Windows PowerShell 5.1 (the one that comes with Windows) the execution
policy may block a downloaded script with *"running scripts is disabled on
this system"*. Two fixes:

```powershell
# Once per user: no administrator needed.
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# ...or for one run only:
powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 bank_app
```

If the template was downloaded as a zip from GitHub, `RemoteSigned` still
blocks the script because Windows marks the file as "downloaded from the
internet". Unblock it once:

```powershell
Unblock-File .\scripts\new-project.ps1
```

Both scripts produce the same project, byte for byte (apart from the random
Visual Studio GUID); CI checks that.

## Choosing a name

The name must be **lower_snake_case**: lower-case letters, digits and
underscores, starting with a letter (`bank_app`, `inventory`, `text_stats`).
It becomes a C++ namespace, so it has to be a valid identifier.

A few names are refused, because the project would not build or would break
the rules of C++:

- **C++ keywords** (`class`, `new`, `delete`, ...) and the reserved
  namespaces `std` and `posix`.
- **Names of build targets**: the ones CMake defines (`all`, `clean`,
  `install`, `test`, `package`, ...) and the ones the template defines
  (`docs`, `format`, `tidy`, `coverage`, `distclean`, `example`,
  `fuzz_greeter`), plus `doctest`, the test framework.
- **Names Windows does not allow** for a file or a folder (`con`, `prn`,
  `aux`, `nul`, `com1`, `lpt1`, ...).
- **Names with a double underscore** or a trailing underscore: those are
  reserved for the implementation.

The script says so and stops; pick another name, for example `bank_app`
instead of `bank`.

## What the script does

1. Copies the template, but only files that git tracks. Your template's
   `build/` and other generated folders never travel along.
2. Renames the placeholder `myapp` everywhere, so in a project called
   `bank_app` you get:

   | Template | Your project |
   | --- | --- |
   | `include/myapp/`, `src/myapp/` | `include/bank_app/`, `src/bank_app/` |
   | namespace `myapp::core` | `bank_app::core` |
   | targets `myapp`, `myapp_lib`, `myapp_tests` | `bank_app`, `bank_app_lib`, `bank_app_tests` |
   | options `MYAPP_SANITIZER`, ... | `BANK_APP_SANITIZER`, ... |
   | helper `myapp_find_dependency()` | `bank_app_find_dependency()` |
   | `"name": "myapp"` in `vcpkg.json` | `"name": "bank-app"` (vcpkg names use hyphens) |
   | `myapp.sln`, `myapp.vcxproj` | `bank_app.sln`, `bank_app.vcxproj` |

   Any file or folder whose name carries the placeholder is renamed, so new
   template files are covered automatically. The Visual Studio files also get
   a **fresh project GUID**, so two projects never share one.

3. Sets the C++ standard you chose, in CMake and in the Visual Studio project
   (`stdcpp17`, `stdcpp20`, `stdcpp23`).
4. Replaces the README with a project README (with your docs link when you pass
   `--github-user`).
5. Keeps only the pieces for the mode you picked (see below) and the matching
   release workflow.
6. Runs `git init` and makes a first commit (unless `--no-git`).

It refuses to overwrite a folder that already exists.

## App or library?

| | App (default) | Library (`--lib`) |
| --- | --- | --- |
| You get | a program built from `main.cpp` | a package other projects can install and use |
| Your code goes in | `src/` and `include/`, built into `<name>_lib` | the same |
| Extra files | `main.cpp` | `examples/`, a tiny program that uses the installed library |
| `cmake --install` puts | the program in `bin/` | the library, headers and CMake package files |
| Release workflow publishes | the program for each platform | the installed package for each platform |

In both modes, all real code lives in the library target `<name>_lib`. The app,
the tests and the fuzzers link it, so they all exercise the same code.

The Visual Studio project follows the mode too: in a library project it
builds a static library instead of an executable, because there is no
`main()`.

Pick **library** when other projects will reuse the code. You can still test it
fully, and [the tutorial](Library-and-App-Tutorial) shows how an app made from
the template uses it.

## Opening the project in Visual Studio

`bank_app.sln` is in the project root: double-click it and Visual Studio
2019, 2022 or 2026 opens it, with no CMake needed. It needs the **Desktop
development with C++** workload. See [Visual Studio](Visual-Studio).

## After creating the project

1. Replace the example `Greeter` class (`include/<name>/core/greeter.hpp`,
   `src/<name>/core/greeter.cpp`, `tests/test_greeter.cpp`,
   `fuzz/fuzz_greeter.cpp` and `fuzz/corpus/fuzz_greeter/`) with your own code.
   See [Writing code](Writing-Code).
2. Write the description at the top of `README.md` and `main.cpp`.
3. Put it on GitHub: see the next section.

## Publishing the project on GitHub

`new-project.sh` already made a git repository with a first commit on `main`
(unless you passed `--no-git`). All that's left is an empty repository on
GitHub to push it to.

> **Don't use GitHub's "Use this template" button** for this. It copies the
> template's files without running `new-project.sh`, so everything would
> still be called `myapp`.

### Option A: GitHub CLI (one command)

Install it once (`brew install gh`, or see <https://cli.github.com>) and log in
with `gh auth login`. Then, inside the project folder:

```bash
gh repo create bank_app --public --source=. --push      # or --private
```

This creates the repository, adds it as `origin` and pushes `main`.

### Option B: the website

1. Go to <https://github.com/new>, enter the name (`bank_app`) and choose
   public or private.
2. Leave **Add a README**, **.gitignore** and **license** unset; the project
   already has them, and a non-empty repository rejects the first push.
3. Click **Create repository**, then in the project folder:

   ```bash
   git remote add origin https://github.com/<you>/bank_app.git
   git push -u origin main
   ```

### After the first push

- CI starts by itself; watch it in the **Actions** tab.
- Turn on the docs website: **Settings → Pages → Build and deployment →
  Source: GitHub Actions**. It appears at `https://<you>.github.io/bank_app/`
  after the next push to `main` (the link in the README already points there
  if you used `--github-user`).
- Optional: protect `main` so pull requests must pass CI
  (see [CI and releases](CI-and-Releases#pull-requests)).
