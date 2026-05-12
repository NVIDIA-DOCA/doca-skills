# Building DOCA Samples

Applies to: DOCA SDK samples and package-facing sample builds
Read when: a user asks how to build a DOCA sample
Load next: `modules/samples-applications.md`, `getting-started/validation.md`, `getting-started/pkg-config.md`

This topic router provides the sample-build entrypoint. Detailed sample staging rules live in
`modules/samples-applications.md`.

## Prerequisites

- Start from a writable source tree or staged sample tree.
- Inspect the nearest `meson.build.public` or `meson.build`.
- Verify required packages with `pkg-config`.
- Keep runtime prerequisites separate from build prerequisites.

## Step-By-Step Build Plan

1. Discover available capabilities:

   ```bash
   python3 tools/lookup_capability.py --repo-root . --list
   ```

2. Inspect the relevant API and dependency inventory:

   ```bash
   python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
   ```

3. Ask the planner for a build-safe command shape:

   ```bash
   python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . --focus-path <sample-path>
   ```

4. Inspect the reported `package_build_files` when present. A `meson.build.public` file records the package-facing
   dependencies, helper sources, and include directories for package-facing builds.

5. Verify each Meson/pkg-config dependency before executing the build.

6. Run build execution only with local approval for repository-contained build output and the planner-reported build
   directory.

If any step fails, report the failing command and `unmet_prerequisites` instead of installing packages or changing
system state.
