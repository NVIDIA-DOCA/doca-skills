# Source-Package Safe Validation

Applies to: docs, samples, applications, and SDK-facing source changes
Read when: selecting validation for changes that should not require site-specific infrastructure
Load next: `getting-started/quickstart.md`, `getting-started/first-commands.md`, `reference/README.md`, `getting-started/pkg-config.md`, `getting-started/troubleshooting.md`

Use the smallest command that proves the changed behavior. Prefer repository-root
commands so another developer can reproduce the result.

## Documentation-Only Changes

```bash
git diff --check
prek run --files <changed-files>
```

For AI guidance or adapter changes, also run:

```bash
python3 tools/validate_ai_adapters.py
python3 tools/validate_ai_contracts.py
```

These checks are wired into pre-commit for relevant `top-level guidance directories`, adapter,
contract, package-manifest, and `tools/` changes.

If `prek` is not installed, use:

```bash
pre-commit run --files <changed-files>
```

## C/C++ Source Changes

For formatting and static checks, run file-level hooks first:

```bash
prek run --files <changed-source-files>
```

For build coverage, configure a focused Meson build that includes the touched
target and run the matching Ninja target or test suite. Keep the command in the
final report so reviewers can repeat it.

## Environment Discovery Checklist

Before proposing SDK build or runtime commands, collect environment facts from
the baseline source-package discovery commands in
`getting-started/first-commands.md`. For API-specific answers, add the API or
library lookup command from the same file.

For buildable examples, also verify local package metadata:

```bash
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

If a runtime command depends on devices, hugepages, representors, firmware, or
privileged configuration, report the runtime prerequisite and stop before
mutation unless the user explicitly approves that class of action.

## Build Validation And Troubleshooting

Start with the sample or application audit command in
`getting-started/first-commands.md` so the response is reproducible and
machine-checkable. When the local owner approves build output, use the
approval-gated local build command from that same page with the planner-reported
focus path and build directory.

If Meson or `pkg-config` reports a missing package, keep the failing command,
package name, and stderr in `unmet_prerequisites`. Use
`getting-started/troubleshooting.md` to classify the failure before editing
source. Build validation is not complete until the configure and compile
commands both pass, or until the final report clearly states the remaining
environment blocker.

## Sample And Application Checks

When changing an SDK example, validate both the direct target and any helper
files it relies on. If a sample has platform-specific prerequisites, state them
explicitly instead of implying the command is universal.

## Read-Only Agent Discovery

Packaged AI docs include capability lookup and a read-only task runner for the
first environment discovery step. Use lookup to choose the relevant source
guidance, then run the baseline source-package discovery commands in
`getting-started/first-commands.md` before suggesting runtime commands.

The command reports source version, manifest capabilities visible in the current
source view, and experimental API marker counts. If it reports a blocker, keep
the blocker in the final answer instead of guessing local package, device, or
capability facts.

For comparable discovery responses, include a structured `outputs` object
with `source_version`, `available_capabilities`, and
`experimental_api_summary`. These names are the package contract for the
read-only discovery step; do not replace them with a prose-only summary.

## Install-Only Discovery Fallback

If the user only has a binary or runtime install and the source-package helpers
under `tools` are absent, keep the response structured and use the
installed package surface as a fallback:

```bash
prefix=${DOCA_PREFIX:-/opt/mellanox/doca}
find "$prefix/include" -maxdepth 1 -name 'doca*.h' -print
find "$prefix" -path '*/pkgconfig/doca-*.pc' -print
find "$prefix/samples" -maxdepth 3 -type f -print 2>/dev/null
grep -R --include='*.h' -o "DOCA_EXPERIMENTAL" "$prefix/include" 2>/dev/null | wc -l
```

Map those files into the same fields the source runner would populate:

- `source_version`: package version when available from package metadata or
  `pkg-config --modversion`; otherwise `unknown`.
- `available_capabilities`: installed libraries inferred from `doca-*.pc`
  files and SDK `doca_*.h` headers. If
  `contracts/agent-manifest.json` is present, it remains the canonical
  capability list.
- `experimental_api_summary`: a union with a `status` discriminator. The
  source-backed counter result uses `status: "measured"` and
  `marker: "DOCA_EXPERIMENTAL"` plus `header_count`,
  `headers_with_experimental`, `experimental_marker_count`, and `headers`.
  Install-only fallbacks use the same `marker` with `status: "not_measured"` or
  `status: "approximate"`.

Use this exact fallback shape when the counter script is unavailable and grep
was not run:

```json
{
  "status": "not_measured",
  "marker": "DOCA_EXPERIMENTAL",
  "fallback_command": "grep -R --include='*.h' -o \"DOCA_EXPERIMENTAL\" <prefix>/include 2>/dev/null | wc -l",
  "reason": "source-package experimental API counter is unavailable"
}
```

If grep was run, set `status` to `approximate`, include
`experimental_marker_count`, keep the count command in `fallback_command`, and
state that the count came from installed SDK headers. Do not paste raw match
output into structured results. Add the missing helper path to
`unmet_prerequisites`; do not hide the difference between source-package
discovery and install-only discovery.

For source-backed API lookup or lifecycle answers, use the same capability
helper to inspect the package dynamically before selecting functions:

```bash
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id> --symbol-filter <term>
```

The inventory reports SDK headers, exported symbols, Meson dependencies, and
sample references present in this source view. If it cannot find a symbol or
dependency, report the searched capability and filter rather than inventing a
private or unavailable API.

For build tasks that are not safe to execute automatically, use the
sample/application audit command in `getting-started/first-commands.md`. The
result names target paths, package-facing build files, sample/application
dependency files, approval classes, expected local output directories, blocked
prerequisites, and next commands without creating output directories or running
builds.

After review, `build-sdk-sample` can execute the focused local build only with
the explicit local build approval command in
`getting-started/first-commands.md` and the planner-reported output directory.

This executor is limited to repository-root Meson setup and compile commands.
The result JSON records the selected focus path, derived target directory,
build directory, command records, built targets, and unmet prerequisites. It
must not install packages or run runtime, device, network, credential, or
production actions.

Skills packages do not publish module patch helpers. If a DOCA source
package publishes a source-change task in its own manifest, use that exact task
ID and keep any execution under the local source owner's review and approval
policy.

Use `package-info.json`, `contracts/agent-manifest.json`,
`contracts/capability-catalog.json`, `lookup_capability.py`, and
`run_agent_task.py` when filing a bug report or comparing packages. These
package artifacts identify the package manifest, visible
capabilities, supported task IDs, source version, and discovery blockers.

Maintainer-only measurement definitions, scoring code, result harvesting, and
regression gates are not part of the helper payload. Packages
should expose source-backed discovery and validation commands, not scorer
inputs or scorer helpers.
