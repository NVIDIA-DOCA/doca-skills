# Source-package Build Troubleshooting

Applies to: SDK-facing sample and application build failures
Read when: Meson, Ninja, or dependency discovery fails in an SDK source package
Load next: `getting-started/first-commands.md`, `getting-started/pkg-config.md`, `getting-started/validation.md`, `framework/README.md`

Treat build failures as evidence to classify, not as a reason to guess new code. Keep the package read-only until the
failure points to a source defect.

## First Checks

Use `getting-started/first-commands.md` for the baseline source-package discovery, API or library lookup, and
planner-only build command.

The planner-only build task reports nearby Meson files, expected output directories, approval classes, and likely
prerequisites without creating build output or running a build.

## Common Failures

- `Dependency "<name>" not found`: run `pkg-config --modversion <name>` and read `getting-started/pkg-config.md`. Report
  the package as an unmet prerequisite if the check fails.
- Header exists but link fails: run `pkg-config --cflags --libs <name>` and verify the Meson dependency uses the package
  name from the package Meson file.
- Sample source file cannot be found: stage the sample from a writable directory and include helper files listed by the
  sample's `meson.build`.
- DPDK or driver symbols are missing: verify the package versions and feature checks printed by the package Meson file
  before changing source.
- Runtime command needs hugepages, devices, representors, or privileged setup: stop at build validation unless the local
  owner explicitly approves runtime or device mutation.

## Build Evidence To Keep

When reporting a failure, include:

- The exact command.
- The repository-relative focus path.
- The dependency or source file that failed.
- The relevant `meson.build` path.
- The `unmet_prerequisites` entry when the environment is incomplete.
- The next safe command the user can run after fixing the prerequisite.

Do not claim validation passed when only discovery ran. Separate discovery, configure, compile, and runtime evidence in
the final response.
