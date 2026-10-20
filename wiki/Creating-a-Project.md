# Creating a project

Every project starts with `scripts/new-project.sh` (or the `newcpp` alias from
[Getting started](Getting-Started)).

```bash
newcpp bank_app                         # creates ./bank_app
newcpp bank_app ~/dev/bank              # choose the folder
newcpp bank_app --std 20                # C++20 instead of C++17 (or 23)
newcpp bank_lib --lib                   # an installable library instead of an app
newcpp bank_app --github-user dr3mro    # fill in the GitHub Pages docs link in the README
newcpp bank_app --no-git                # don't create a git repository
```

Options can be combined: `newcpp bank_lib ~/dev/bank_lib --lib --std 20`.

## Choosing a name

The name must be **lower_snake_case**: lower-case letters, digits and
underscores, starting with a letter (`bank_app`, `inventory`, `text_stats`).
It becomes a C++ namespace, so it has to be a valid identifier.

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

3. Sets the C++ standard you chose.
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

Pick **library** when other projects will reuse the code. You can still test it
fully, and [the tutorial](Library-and-App-Tutorial) shows how an app made from
the template uses it.

## After creating the project

1. Replace the example `Greeter` class (`include/<name>/core/greeter.hpp`,
   `src/<name>/core/greeter.cpp`, `tests/test_greeter.cpp`,
   `fuzz/fuzz_greeter.cpp` and `fuzz/corpus/fuzz_greeter/`) with your own code.
   See [Writing code](Writing-Code).
2. Write the description at the top of `README.md` and `main.cpp`.
3. Put it on GitHub:

   ```bash
   git remote add origin https://github.com/<you>/<name>.git
   git push -u origin main
   ```

   Then turn on GitHub Pages for the docs: **Settings → Pages → Source:
   GitHub Actions** (see [CI and releases](CI-and-Releases)).
