# Sample Build Planning

Applies to: DOCA SDK sample or application build planning with `doca-skills`
Read when: the user asks how to build a specific sample or application
Load next: `../getting-started/building-samples.md`, `../skills/doca-build-sdk-sample/SKILL.md`, `../contracts/tasks/build-sdk-sample.yaml`

## Prompt

```text
Plan how to build <sample-or-application-path> from my DOCA SDK source package.
Show the likely Meson target, dependencies, missing prerequisites, and commands.
Do not run the sample or change device, network, or package state.
```

## Expected Agent Flow

```mermaid
flowchart TD
    prompt["Prompt names sample or application path"]
    skill["Use doca-build-sdk-sample skill"]
    task["Load build-sdk-sample task contract"]
    source["Inspect target source package path"]
    meson["Read nearby Meson and dependency files"]
    plan["Prepare configure and build commands"]
    guard["Separate build plan from runtime actions"]
    answer["Return target, deps, blockers, commands"]

    prompt --> skill
    skill --> task
    task --> source
    source --> meson
    meson --> plan
    plan --> guard
    guard --> answer
```

## Command Shape

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root <source-package-root> \
    --focus-path <sample-or-application-path>
```

## Expected Answer Shape

- Target path and nearest build files.
- Package or pkg-config dependencies visible in source files.
- Helper sources or include directories that affect the build.
- Configure and build command candidates.
- Missing prerequisites that block a real build.
- Runtime steps that stay blocked until explicitly approved.
