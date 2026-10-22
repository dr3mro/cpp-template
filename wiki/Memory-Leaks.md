# Memory leaks

A leak is memory that your program allocated and then lost the only pointer
to. The memory is never given back to the system, so the process keeps
growing until it is killed.

Leaks matter most in **long-running processes**: a server that leaks a
kilobyte per request will eventually fall over. They also make bugs harder
to see, because the symptom (slow growth, an out-of-memory crash hours
later) is far away from the cause (the missing `delete`).

This page covers how to find leaks in this template, on both Linux and
macOS, and how to read what the tools tell you.

## Which tool to use

| Platform | Tool | How |
| --- | --- | --- |
| Linux | LeakSanitizer (built into AddressSanitizer) | nothing to do: the `debug` and `ci` presets already check for leaks |
| macOS | Apple's `leaks` | `leaks --atExit --quiet -- ./build/Darwin/arm64/debug-nosan/myapp` |
| macOS | LeakSanitizer (standalone) | build with `-fsanitize=leak` using Homebrew's LLVM |

**The macOS catch**: Apple's AddressSanitizer does not include
LeakSanitizer, so the `debug` and `ci` presets do **not** report leaks on
macOS. Linux's AddressSanitizer does include it. That is why the two
platforms need different commands.

## Linux and CI: leaks come for free

On Linux, AddressSanitizer includes LeakSanitizer. The `debug` preset is
already instrumented, so a leak fails the test run with no extra setup:

```bash
cmake --preset debug && cmake --build --preset debug && ctest --preset debug
```

A leak makes the test binary exit with code 23 and prints a report like
this (the runtime library named in frame `#0` differs per platform: it is
`libclang_rt.lsan_osx_dynamic.dylib` on macOS and
`libclang_rt.lsan-x86_64.so` on Linux):

```text
=================================================================
==54166==ERROR: LeakSanitizer: detected memory leaks

Direct leak of 64 byte(s) in 1 object(s) allocated from:
    #0 0x000100987b30 in malloc+0x5c (libclang_rt.lsan_osx_dynamic.dylib:arm64+0x33b30)
    #1 0x00010063ead0 in myapp::core::Greeter::Greet(...) const greeter.cpp:20
    #2 0x00010063d390 in main main.cpp:40
    #3 0x000191a1fe7c in start+0x1a1c (dyld:macOS)

SUMMARY: LeakSanitizer: 64 byte(s) leaked in 1 allocation(s).
```

Read it like this:

1. **The first line names the problem**: `detected memory leaks`.
2. **Each block is one leak**: `Direct leak` means nothing points at the
   block any more, `Indirect leak` means the block is only reachable
   through another leaked block.
3. **The stack is where it was allocated**. Frame `#1` in *your* code
   (skip frames inside the standard library) is the line to fix.
4. **`SUMMARY` gives the totals**: how many bytes, in how many
   allocations.

To switch leak checking off for one run (useful when a third-party library
leaks and you want to ignore it for now):

```bash
ASAN_OPTIONS=detect_leaks=0 ctest --preset debug
```

## macOS with Apple's `leaks` tool

`leaks` ships with macOS. It launches your program, inspects the heap when
it exits and reports what was left behind.

```bash
cmake --preset debug-nosan && cmake --build --preset debug-nosan
leaks --atExit --quiet -- ./build/Darwin/arm64/debug-nosan/myapp
```

The flags:

| Flag | Meaning |
| --- | --- |
| `--atExit` | run the program and check for leaks when it exits. It must be the **last** option, followed by `--` and the command |
| `-q`, `--quiet` | suppress the process header and footer, leaving just the leak report |
| `--list` | print the leaks as a flat list instead of a tree |
| `--groupByType` | group leaks of the same kind together |
| `--nostacks` | print without backtraces (much shorter output) |
| `-e`, `--exclude <symbol>` | ignore leaks whose backtrace includes that symbol |
| `--outputGraph=<path>` | save a memory graph, comparable later with `--diffFrom=` |

`leaks` exits with **0 when there are no leaks and 1 when there are**, which
makes it easy to use in a script or in CI.

### `leaks` needs a non-sanitized build

`leaks` inspects the malloc zones of the process, and AddressSanitizer
replaces the allocator. Running `leaks` on an ASan binary fails:

```text
Can't examine target process's malloc zone asan_0x106756758, so memory
analysis will be incomplete or incorrect.
leaks[52579]: [fatal] unable to inspect heap ranges of target process
```

So use the `debug-nosan` preset (or `release`) for `leaks`, not `debug`.

### It also cannot be combined with `-fsanitize=leak`

Both tools intercept the allocator, and the combination crashes with
`LeakSanitizer: bad pointer` / `CHECK failed`. Pick one or the other.

## macOS with standalone LeakSanitizer

If you prefer the LLVM report format (the same one Linux gives you), build
the project with LeakSanitizer instead of AddressSanitizer.

**Apple's compiler does not support this flag.** `clang++` from
`/usr/bin` (AppleClang) fails with:

```text
clang++: error: unsupported option '-fsanitize=leak' for target 'arm64-apple-darwin'
```

Use Homebrew's LLVM instead, which does support it:

```bash
brew install llvm
```

Then configure a build with the flag on both the compile and the link step.
The template's `MYAPP_USE_LLVM_CLANG` option already picks Homebrew's
`clang++` for you:

```bash
cmake -S . -B build/Darwin/arm64/leak -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DMYAPP_USE_LLVM_CLANG=ON \
  -DCMAKE_CXX_FLAGS="-fsanitize=leak" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=leak"
cmake --build build/Darwin/arm64/leak
./build/Darwin/arm64/leak/myapp
```

The check runs automatically when the program exits, and the exit code is
**23 when leaks were found**. There is no separate tool to run.

Options come from the `LSAN_OPTIONS` environment variable, as
`key=value` pairs separated by `:`:

| Option | Effect |
| --- | --- |
| `verbosity=1` | log what the checker is doing |
| `exitcode=1` | use a different exit code when leaks are found |
| `detect_leaks=0` | turn the check off for one run |
| `suppressions=<file>` | ignore leaks matching the patterns in a file |
| `print_suppressions=1` | report which suppressions matched |
| `max_leaks=<n>` | stop reporting after n leaks |

```bash
LSAN_OPTIONS=verbosity=1 ./build/Darwin/arm64/leak/myapp
```

A suppressions file lists one pattern per line, for leaks you have decided
to accept. The pattern is matched against the symbol names in the
allocation's stack trace:

```text
# lsan.supp
leak:myapp_third_party_init
```

```bash
LSAN_OPTIONS=suppressions=lsan.supp ./build/Darwin/arm64/leak/myapp
```

## In CI

On the GitHub Actions runners (Linux), nothing special is needed: the `ci`
preset already includes leak checking. The `coverage` job is the usual
place to look, because it runs the whole test suite.

To make the leak check explicit, or to run it on macOS, add a step like
this to your workflow (the `leaks` tool only exists on macOS, so the job
must run on a macOS runner):

```yaml
      - name: Check for memory leaks
        run: |
          cmake --preset debug-nosan
          cmake --build --preset debug-nosan
          leaks --atExit --quiet -- ./build/Darwin/arm64/debug-nosan/myapp
```

`leaks` exits with 1 when it finds a leak, which fails the step.

## What does and does not count as a leak

The tools report **unreachable** memory. A few things look like leaks but
are not:

- **Memory still reachable at exit.** A static cache or a global container
  that still holds its elements is reachable, so it is not reported.
  `leaks` and LSan only complain when nothing points at the block.
- **Memory freed at exit.** The standard library frees its own allocations
  during shutdown, so a clean program reports nothing.
- **Memory held by the OS or by a library you do not control.** These show
  up as leaks in the *library's* stack frame. Check the stack: if the
  allocation happened inside a dependency, it is usually not your bug.

## Avoiding leaks in the first place

- **Prefer automatic storage.** `std::string`, `std::vector` and the other
  standard containers own their memory and free it when they go out of
  scope.
- **Use `std::unique_ptr` for single ownership**, and
  `std::shared_ptr` only when the ownership is genuinely shared. Raw
  `new` and `delete` are hard to get right, especially with early returns
  and exceptions.
- **Let RAII handle cleanup.** A class that owns a resource should free it
  in its destructor, so the resource is released on every path out of the
  function, including the exception path.
- **Watch the containers that keep their capacity.** `std::vector` that
  grew to a million elements keeps that memory until it is destroyed or
  shrunk. That is not a leak, but it looks like one in a long-running
  process.
- **Do not cache without a plan.** A `static` map that grows with every
  key you see is the classic "leak" in a server.

## Troubleshooting

**`leaks` says "Process ... is not debuggable".** This is normal for an
unsigned binary. Leak detection still works; the tool just cannot read the
contents of the memory it found.

**`leaks` reports leaks in `libSystem` or in a dependency.** Read the
stack: leaks allocated inside a third-party library are usually its bug.
Suppress them with `-e <symbol>` rather than trying to fix them.

**The report is huge.** Use `leaks --nostacks` to see just the totals, or
`leaks --list` for a flat list.

**Nothing is reported, but memory keeps growing.** The leaked memory is
probably still reachable (a cache, a static container). Leak checkers
cannot see that; look for growing containers instead.

**A leak only shows up sometimes.** Leak checkers only see what executed.
Make sure a test actually exercises the leaking path, and see
[Fuzzing](Fuzzing) for finding paths you did not think of.

## See also

- [Debugging and sanitizers](Debugging-and-Sanitizers): the other
  sanitizers, and how to read their reports
- [Testing guide](Testing-Guide): writing the tests that exercise the
  code
- [Fuzzing](Fuzzing): finding crashes and leaks in code paths you did not
  write
- [Code quality](Code-Quality): the other static checks
