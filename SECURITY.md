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

Release builds are compiled with defence-in-depth flags. See the "Security
hardening" section of `README.md` for the exact flags and how to turn them off
with `MYAPP_ENABLE_HARDENING=OFF`.
