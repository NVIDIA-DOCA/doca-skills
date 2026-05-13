# Building DOCA Samples

Applies to: DOCA SDK samples and package-facing sample builds
Read when: a user asks how to build a DOCA sample
Load next: `framework/README.md`, `getting-started/validation.md`, `getting-started/pkg-config.md`

This topic router provides the sample-build entrypoint. Detailed sample staging rules live in `framework/README.md`.

## Prerequisites

- Start from a writable source tree or staged sample tree.
- Inspect the nearest `meson.build`.
- Verify required packages with `pkg-config`.
- Keep runtime prerequisites separate from build prerequisites.

## Step-By-Step Build Plan

1. Discover available capabilities:

   ```bash
   sed -n '1p' VERSION 2>/dev/null || true
   find contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print 2>/dev/null
   ```

2. Inspect the relevant API and dependency inventory:

   ```bash
   grep -R "<symbol-or-topic>" libs/*/include/public 2>/dev/null
   pkg-config --modversion <pkg-name>
   pkg-config --cflags --libs <pkg-name>
   ```

3. Inspect the package-facing build shape:

   ```bash
   find <sample-path> -maxdepth 2 \( -name meson.build -o -name meson.build \) -print
   find <sample-path> -path '*/dependencies/meson.build' -print
   ```

4. Inspect the selected package build files when present. A `meson.build` file records the package-facing dependencies,
   helper sources, and include directories for package-facing builds.

5. Verify each Meson/pkg-config dependency before executing the build.

6. Run build execution only with local approval for repository-contained build output and an agreed build directory.

If any step fails, report the failing command and `unmet_prerequisites` instead of installing packages or changing
system state.
