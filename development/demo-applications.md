# Developing Demo Applications With DOCA

Applies to: DOCA SDK demo applications, public examples, and tutorial-style application code
Read when: a user asks how to build a demo application with DOCA
Load next: `modules/samples-applications.md`, `getting-started/sdk-development.md`, `getting-started/validation.md`

This is a topic router for demo-application work. The canonical implementation
rules live in `modules/samples-applications.md`; use this file when a
user starts from a "demo application" question rather than a source path.

## Demo Application Role

Demo applications should prove one end-to-end scenario with readable setup,
teardown, argument parsing, validation, and failure reporting. They can be
larger than samples, but they should still avoid site-specific infrastructure and
hard-coded environment facts.

## Development Practices

- Start from the nearest existing application or sample that uses the same
  library family.
- Run the build planner with the application focus path and inspect both
  `package_build_files` and `package_dependency_files` before naming required
  packages or helper sources.
- Discover devices, package metadata, and capabilities before suggesting
  runtime commands.
- Keep build validation separate from runtime validation. Runtime paths that
  need devices, hugepages, representors, or privileged configuration require
  explicit local approval.
- Report missing packages, helper sources, or runtime prerequisites as
  structured blockers.
- Keep output parseable enough for automation to distinguish setup, execution,
  success, and cleanup failures.

## Tutorial Pattern

For tutorial-style answers, include:

- The source package and version evidence used.
- The library or capability selected.
- The required Meson/pkg-config dependencies.
- The package-facing `meson.build.public` file and any
  `dependencies/meson.build` file used to derive those dependencies.
- The staged source layout when the demo is copied out of the package.
- Build-only validation commands.
- Runtime prerequisites and the approval class needed before running.
