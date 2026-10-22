# Security policy

## Supported versions

Only the latest release gets security fixes. Fixes are not backported to
older releases; update to the latest one.

## Scope

In scope: the code in this repository, its build configuration (the
hardening and sanitizer settings), and the release artifacts the release
workflow publishes (their checksums, provenance attestations and SBOMs).

Out of scope: vulnerabilities in third-party dependencies (report those
upstream; the release SBOM lists exactly which versions a release contains),
and problems that need an already compromised build machine or toolchain.

## Reporting a vulnerability

Please do **not** open a public issue for a security vulnerability.

Instead, open a **private GitHub security advisory**:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability** (or **Advisories → New draft security advisory**).
3. Describe the issue, the affected version, and steps to reproduce it.

You will get a response acknowledging the report within a week. Once a fix is
ready we will publish a patched release and credit reporters who wish to be
named.

## Verifying a release

Every release carries `SHA256SUMS` and a signed build-provenance attestation
for each archive:

```bash
sha256sum -c SHA256SUMS --ignore-missing
gh attestation verify <archive> --repo <owner>/<repo>
```

## Hardening

Release builds are compiled with security hardening flags (stack protection,
`_FORTIFY_SOURCE`, PIE, RELRO and the MSVC equivalents). The full list, and how
to turn it off with `-DMYAPP_ENABLE_HARDENING=OFF`, is on the
[Security wiki page](https://github.com/dr3mro/cpp-template/wiki/Security).
