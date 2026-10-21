# Notes

Working notes for the template overhaul (the plan from the cpp-template
review). NOT copied into generated projects; delete this file when the
overhaul is finished.

## Item 1: done

- Linux x64/arm64 triplets swapped back in release-lib.yml.
- `@AUTHOR@` in main.cpp, filled in by both generators (`--author` /
  `-Author`, default `git config user.name`, then "Your Name"); passed to perl
  through the environment, so `/ @ $ < >` come out unchanged.
- Release workflows: a `check-version` job (tag == vcpkg.json version) gates
  the builds; `publish` runs only after a successful build, also on manual runs.
- release-lib: architecture check of the installed library (objdump, lipo,
  dumpbin in PowerShell).
- release-app: Windows `.zip`, `.tar.gz` elsewhere; CPack ZIP on Windows.
- template-test: `@AUTHOR@` added to the placeholder checks; an `--author`
  round-trip test for new-project.sh and for new-project.ps1 under
  Windows PowerShell 5.1 and PowerShell 7.
- Docs: README, wiki Creating-a-Project and CI-and-Releases, CHANGELOG.

Checked locally: YAML parses, actionlint + shellcheck clean, the Linux
architecture check passes for the right CPU and fails for the wrong one,
new-project.sh with a tricky --author.
Only CI can check: the release workflows end to end, macOS lipo, Windows
dumpbin and Compress-Archive, the PowerShell --author test.

## Items 2-8: not started
