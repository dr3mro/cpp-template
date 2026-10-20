# Security policy

## Reporting a vulnerability

Please do **not** open a public issue for a security vulnerability.

Instead, open a **private GitHub security advisory**:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability** (or **Advisories → New draft security advisory**).
3. Describe the issue, the affected version, and steps to reproduce it.

You will get a response acknowledging the report. Once a fix is ready we will
publish a patched release and credit reporters who wish to be named.

## Hardening

Release builds are compiled with security hardening flags (stack protection,
`_FORTIFY_SOURCE`, PIE, RELRO and the MSVC equivalents). The full list, and how
to turn it off with `-DMYAPP_ENABLE_HARDENING=OFF`, is on the
[Security wiki page](https://github.com/dr3mro/cpp-template/wiki/Security).
