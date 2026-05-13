# SDK Source Discovery

Applies to: DOCA SDK source-package discovery with `doca-skills`
Read when: the user asks what SDK source package, contracts, or environment facts are available
Load next: `../getting-started/quickstart.md`, `../skills/doca-discover-environment/SKILL.md`, `../contracts/agent-manifest.json`

## Prompt

```text
I have a DOCA SDK source package at <source-package-root>. Tell me what source
version, helper contracts, capabilities, and blockers are visible. Do not change
the host.
```

## Expected Agent Flow

```mermaid
flowchart TD
    prompt["Prompt asks for source discovery"]
    quickstart["Read quickstart and user rules"]
    mode["Select SDK source package mode"]
    manifest["Open contracts/agent-manifest.json"]
    skill["Use doca-discover-environment skill"]
    command["Run source evidence commands"]
    facts["Collect version, capabilities, and sensor status"]
    blockers["List missing utilities, metadata, devices, or approvals"]
    answer["Answer with evidence and next safe command"]

    prompt --> quickstart
    quickstart --> mode
    mode --> manifest
    manifest --> skill
    skill --> command
    command --> facts
    facts --> blockers
    blockers --> answer
```

## Command Shape

```bash
find <source-package-root> -maxdepth 1 -name VERSION -print
find <source-package-root>/contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print 2>/dev/null
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

## Expected Answer Shape

- Source package path: `<source-package-root>`.
- Source version: value found by the helper, or `unknown`.
- Capabilities: IDs returned by the manifest and capability catalog.
- Sensors: read-only commands that ran, were missing, or reported no devices.
- Blocked actions: package install, device mutation, network mutation, runtime samples, credentials.
- Next safe command: exact command to inspect one capability or retry discovery.
