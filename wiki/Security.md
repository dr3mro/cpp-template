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
| GCC/Clang on Linux (libstdc++ or libc++) | `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3`, `-fstack-clash-protection`, `-fcf-protection=full` on x64, `-mbranch-protection=standard` on ARM64, `-ftrivial-auto-var-init=zero`, `-fstrict-flex-arrays=3`, `-Wl,-z,relro,-z,now,-z,noexecstack`, `-Wl,--as-needed` |
| Apple Clang / Clang on macOS | the same stack, stack-clash, branch-protection, `-ftrivial-auto-var-init` and `-fstrict-flex-arrays` flags, plus `-D_FORTIFY_SOURCE=3` (Apple's libc); no RELRO or CET flags |
| Clang on Windows (GNU-style `clang++`) | `-mguard=cf` at compile time, `-Wl,/guard:cf -Wl,/DYNAMICBASE -Wl,/NXCOMPAT -Wl,/HIGHENTROPYVA`, `-Wl,/CETCOMPAT` on x64 only, `-mbranch-protection=standard` on ARM64 |
| Clang on Windows (`clang-cl`) | `/guard:cf` at compile time, `/guard:cf /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA`, `/CETCOMPAT` on x64 only |
| MSVC (`cl`) | `/GS /guard:cf /ZH:SHA_256`, `/guard:cf /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA`, `/CETCOMPAT` and `/guard:ehcont` on x64 only; `/sdl` in every configuration (`cmake/Warnings.cmake`) |

The flags follow the [OpenSSF Compiler Options Hardening
Guide](https://best.openssf.org/Compiler-Hardening-Guides/Compiler-Options-Hardening-Guide-for-C-and-C++.html),
except `-Wl,-z,nodlopen`: it would stop a library project from being loaded
with `dlopen()`.

The standard library's own checks (`cmake/StdlibChecks.cmake`) are detected
with a test compile, so they work with any compiler. They are cheap, so they
are on in **Debug builds too**, where they catch an out-of-range index or
`front()` on an empty container at the line that does it:

| Standard library | Optimised builds | Debug |
| --- | --- | --- |
| libstdc++ (`__GLIBCXX__`) | `-D_GLIBCXX_ASSERTIONS` | `-D_GLIBCXX_ASSERTIONS` |
| libc++ (`_LIBCPP_VERSION`) | `_LIBCPP_HARDENING_MODE_FAST` | `_LIBCPP_HARDENING_MODE_DEBUG` |
| Visual Studio STL (`_MSVC_STL_VERSION`) | `-D_MSVC_STL_HARDENING=1`, when that STL is new enough to know it | its own debug checks (`_ITERATOR_DEBUG_LEVEL=2`) |

`_GLIBCXX_DEBUG` (libstdc++'s full debug mode) is not set: it changes the
ABI, so everything linked into the program would have to use it.

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
- CI runs clang-tidy and CodeQL static analysis on every push, and OpenSSF
  Scorecard rates the repository's own security practices every week.

## Checking a binary

On Linux, see which protections a binary actually has:

```bash
readelf -d build/Darwin/release/myapp | grep -E 'BIND_NOW|FLAGS'   # full RELRO: BIND_NOW
readelf -h build/Darwin/release/myapp | grep Type                  # DYN (Position-Independent Executable)
```

or install `checksec` (`pipx install checksec.py`) and run
`checksec --file build/Darwin/release/myapp`.

## Verifying a release

Every GitHub Release carries what a user needs to trust a download (see
[CI and releases](CI-and-Releases#releases)):

```bash
sha256sum -c SHA256SUMS --ignore-missing                         # the file is intact
gh attestation verify myapp-linux-x64.tar.gz --repo <owner>/<repo>  # it was built by this repository's workflow
```

The `-sbom` archive next to each binary lists the dependencies in it (the
SPDX documents vcpkg writes), and the supply chain behind the build is
pinned: every GitHub Action to a commit SHA, vcpkg to a baseline commit.

## Good habits

- Build and test with the `debug` preset routinely; sanitizers find memory
  bugs before they ship.
- Give every parser of untrusted input a fuzz target.
- Keep dependencies current: merge Dependabot's vcpkg pull requests.
- Look at **Security → Code scanning** after CodeQL runs.
- Release from the `release` preset, which is the hardened one.
