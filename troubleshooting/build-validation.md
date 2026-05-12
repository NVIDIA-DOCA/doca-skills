# Troubleshooting Build Validation Issues

Applies to: DOCA SDK sample and application build validation
Read when: a build validation command fails or cannot be selected
Load next: `getting-started/validation.md`, `getting-started/troubleshooting.md`, `getting-started/pkg-config.md`

This topic router is for build validation failures. The canonical source-package safe
flows live in `getting-started/validation.md` and
`getting-started/troubleshooting.md`.

## Common Build Validation Issues

- A Meson dependency is absent from the local `pkg-config` search path.
- A package build needs helper sources that were not staged.
- A sample requires DPDK or driver features not present in the local SDK.
- A command selected runtime validation when only build validation was approved.
- The package view does not contain the module named in the request.

## Dependency Management

Use `pkg-config --modversion <name>` and `pkg-config --cflags --libs <name>` to
prove dependency availability. Report failures as `unmet_prerequisites`; do not
install packages or hard-code absolute include/library paths.

## Validation Practice

Start with:

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . --focus-path <sample-or-application-path>
```

Run the executor form only when the local owner approves repository-contained
build output and supplies the planner-reported build directory.
