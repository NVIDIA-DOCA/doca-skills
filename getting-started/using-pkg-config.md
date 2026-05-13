# Using pkg-config With DOCA

Applies to: DOCA SDK dependency discovery and Meson build troubleshooting
Read when: a user asks how to use `pkg-config` with DOCA
Load next: `getting-started/pkg-config.md`, `environment-setup/linux-distributions.md`

The canonical dependency workflow lives in `getting-started/pkg-config.md`. Use this file as a short topic entrypoint.

`pkg-config` is the source-backed way to verify which DOCA package metadata the local SDK exposes. It should answer
dependency questions before an agent edits source or suggests a Meson workaround.

## Basic Checks

```bash
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
pkg-config --print-errors --exists <pkg-name>
```

When a package is missing, report the dependency as an unmet prerequisite and include the command that failed. Do not
hard-code include or library paths in a sample to bypass package metadata.
