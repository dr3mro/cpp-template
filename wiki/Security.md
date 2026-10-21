# Security

Two parts: how the template makes release builds harder to exploit, and how
it helps you find vulnerabilities before anyone else does. For *reporting* a
vulnerability, every project has a short `SECURITY.md` that GitHub shows under
**Security → Policy**.

## Hardening flags

Optimised builds (`Release`, `RelWithDebInfo`, `MinSizeRel`) are compiled with
defence-in-depth flags that make memory bugs much harder to exploit. Debug
builds skip them, so the debugger and the sanitizers stay usable. The flags
are set in `cmake/Hardening.cmake`, and each configure prints the exact list
on a `Hardening (optimised configs):` line.

The flags depend on the platform and on the **standard library**, not just on
the compiler. The configure output lists exactly what was chosen.

| Platform / compiler | Flags |
| --- | --- |
| GCC/Clang on Linux (libstdc++ or libc++) | `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3`, `-fstack-clash-protection`, `-fcf-protection=full` on x64, `-mbranch-protection=standard` on ARM64, `-Wl,-z,relro,-z,now,-z,noexecstack` |
| Apple Clang / Clang on macOS | the same stack, stack-clash and branch-protection flags, plus `-D_FORTIFY_SOURCE=3` (Apple's libc); no RELRO or CET flags |
| Clang on Windows (GNU-style `clang++`) | `-mguard=cf` at compile time, `-Wl,/guard:cf -Wl,/DYNAMICBASE -Wl,/NXCOMPAT -Wl,/HIGHENTROPYVA`, `-Wl,/CETCOMPAT` on x64 only, `-mbranch-protection=standard` on ARM64 |
| Clang on Windows (`clang-cl`) | `/guard:cf` at compile time, `/guard:cf /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA`, `/CETCOMPAT` on x64 only |
| MSVC (`cl`) | `/GS /guard:cf`, `/guard:cf /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA`, `/CETCOMPAT` on x64 only |

The standard library's own checks are detected with a test compile, so they
work with any compiler:

| Standard library | Flag |
| --- | --- |
| libstdc++ (`__GLIBCXX__`) | `-D_GLIBCXX_ASSERTIONS` |
| libc++ (`_LIBCPP_VERSION`) | `-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST` |
| Visual Studio STL (`_MSVC_STL_VERSION`) | `-D_MSVC_STL_HARDENING=1`, only when that STL is new enough to know it |

`_FORTIFY_SOURCE` is only added with glibc or Apple's libc. It is a glibc
feature and does nothing with the Visual Studio STL, so it is left out on
Windows, as is `_GLIBCXX_ASSERTIONS` (a libstdc++ feature).

Every flag is probed first (`check_cxx_compiler_flag`,
`check_linker_flag`), so an older clang that does not know one just skips it.

Every build is also position-independent (PIE for executables, PIC for
libraries) so address-space layout randomisation applies; that is set in
`cmake/ProjectDefaults.cmake` and does not depend on the hardening switch.

Turn hardening off with `-DMYAPP_ENABLE_HARDENING=OFF` (in a generated project,
`MYAPP` is the project's name in capitals).

## Finding bugs before attackers do

- `cmake --preset debug` runs every test under AddressSanitizer and
  UndefinedBehaviorSanitizer; `cmake --preset tsan` checks for data races.
- `fuzz/` holds libFuzzer targets; see [Fuzzing](Fuzzing).
- CI runs clang-tidy and CodeQL static analysis on every push.

## Checking a binary

On Linux, see which protections a binary actually has:

```bash
readelf -d build/release/myapp | grep -E 'BIND_NOW|FLAGS'   # full RELRO: BIND_NOW
readelf -h build/release/myapp | grep Type                  # DYN (Position-Independent Executable)
```

or install `checksec` (`pipx install checksec.py`) and run
`checksec --file build/release/myapp`.

## Good habits

- Build and test with the `debug` preset routinely; sanitizers find memory
  bugs before they ship.
- Give every parser of untrusted input a fuzz target.
- Keep dependencies current: merge Dependabot's vcpkg pull requests.
- Look at **Security → Code scanning** after CodeQL runs.
- Release from the `release` preset, which is the hardened one.
