# Source-Package First Commands

Applies to: source-package discovery, capability lookup, SDK build planning, and optional source-change task routing
Read when: another doc or portable skill needs safe first commands for a DOCA source package
Load next: `getting-started/validation.md`, `contracts/README.md`, `skills/doca-ai-runner/SKILL.md`

Run these commands from the repository or source-package root. Skip a command only when the source path or
source-package tool is absent, and record that absence in `unmet_prerequisites` instead of guessing package, device, or
capability facts.

## Baseline Source-Package Discovery

```bash
sed -n '1p' VERSION 2>/dev/null || true
find contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print 2>/dev/null
find libs -path '*/include/public/*.h' -print 2>/dev/null
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

Use these before naming runtime commands, local capabilities, package metadata, or source-package gaps. The collected
evidence should anchor `source_version`, `available_capabilities`, and `experimental_api_summary`.

## API Or Library Lookup

```bash
grep -R "<symbol-or-topic>" libs/*/include/public 2>/dev/null
find . -path '*/version.map' -print 2>/dev/null
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

Use `contracts/capability-catalog.json`, SDK headers, Meson files, and installed `doca-*.pc` metadata to map user terms
to capability IDs that are present in the current package. Do not assume framework-specific capabilities exist unless
the current package evidence lists them.

## Sample Or Application Audit

```bash
find <samples-or-applications-path> -maxdepth 2 \( -name meson.build -o -name meson.build \) -print
find <samples-or-applications-path> -path '*/dependencies/meson.build' -print
pkg-config --print-errors --exists <pkg-name>
```

Use this for manager, sample, application, or package-build questions. The build plan should report package-facing build
files, dependency files, helper sources, include directories, output directories, approval classes, and unmet
prerequisites without creating build output.

Source-change planners are not part of the skills repository. If a DOCA source package includes a source-change task in
its manifest, use that exact task ID and keep execution under the local package owner's policy.

## Approval-Gated Local Build

Run local build execution only after the local owner approves build output and only with the planner-reported focus path
and build directory:

```bash
meson setup <build-dir> . --reconfigure
ninja -C <build-dir> <target>
```

This executor is limited to repository-root Meson setup and compile commands. It must not install packages or run
runtime, device, network, credential, or production actions.

## Missing Evidence Fallback

If source-package contracts or headers are not present, switch to the installed-package fallback in
`getting-started/validation.md`. Keep the same structured fields where possible, mark unavailable source checks
explicitly, and do not hide the difference between source-package discovery and install-only discovery.
