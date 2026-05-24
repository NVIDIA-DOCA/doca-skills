---
name: doca-apsh-config
description: >
  Use this skill when the user is generating, refreshing, or
  validating a DOCA App Shield host profile by running
  doca_apsh_config.py — picking the --os axis (linux vs windows),
  the --files set (symbols / memregions / kpgd_file / hash),
  staging dwarf2json or pdbparse-to-json.py, rotating after a host
  kernel change, or diagnosing DPU-side apsh consumer regressions
  that trace back to a stale profile. Trigger even when the user
  does not explicitly mention "doca_apsh_config" or "App Shield
  profile" — typical implicit phrasings include "DPU apsh started
  returning wrong data after I patched the host",
  "DOCA_ERROR_NOT_FOUND on a process that is definitely running",
  "dwarf2json crashed on my kernel", "pefile version pin error",
  "regenerate the symbol map after a kernel upgrade", or "build
  the per-PID hash bundle". Refuse and route elsewhere for
  DPU-side doca_apsh_* API calls, DOCA install/repair, and
  dwarf2json / pdbparse internals — owned by doca-apsh,
  doca-setup, and the upstream Volatility Foundation repos.
metadata:
  kind: tool
compatibility: >
  Requires DOCA SDK installed on the host at /opt/mellanox/doca
  with the App Shield optional component; doca_apsh_config.py
  ships at /opt/mellanox/doca/tools/doca_apsh_config.py. Python 3
  plus operator-staged dwarf2json (Linux) or pdbparse-to-json.py
  (Windows) required. Reads host kernel DWARF or PDB symbols;
  produces artifacts the DPU-side doca-apsh library consumes.
---

# DOCA App Shield Configuration Tool

**Where to start:** This is a tool skill for invoking
`doca_apsh_config.py` — the host-side companion script that
produces the host-OS profile (symbol map + memory-regions
descriptor + optional KPGD anchor + optional per-process hash
bundle) that the DPU-side
[`doca-apsh`](../../libs/doca-apsh/SKILL.md) library and any
apsh-class introspection consumer must load before they can read
host kernel state honestly. Open [`TASKS.md`](TASKS.md) and start
at [`## install`](TASKS.md#install) for the host-side
prerequisites (DOCA install on the host, `dwarf2json` for Linux
or `pdbparse-to-json.py` for Windows) and
[`## run`](TASKS.md#run) for the profile-generation flow. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
profile artifacts this tool produces*, *which host OS
generations it supports*, *how a stale profile fails silently*,
or *how to confirm a profile actually matches the live host
kernel before relying on it in production*.

## Example questions this skill answers well

The CLASSES of `doca_apsh_config.py` questions this skill is
built to answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"I need a fresh App Shield profile for my host before the
  DPU-side `doca-apsh` introspection will work — what do I
  run?"** — worked example: *"generate a Linux profile for an
  Ubuntu host whose kernel I just upgraded"*. Answered by the
  end-to-end workflow in
  [`TASKS.md ## install`](TASKS.md#install) (host-side
  prerequisites: DOCA, `dwarf2json` from the public Volatility
  Foundation repo, Python deps), then
  [`TASKS.md ## configure`](TASKS.md#configure) (axis
  selection: `--os`, the `--files` subset, optional
  `--find_kpgd` and `--pid`), then
  [`TASKS.md ## run`](TASKS.md#run). The DPU side then loads
  the produced artifacts per
  [`doca-apsh TASKS.md ## configure`](../../libs/doca-apsh/TASKS.md#configure).
- **"My DPU-side `doca-apsh` queries started returning
  `DOCA_ERROR_NOT_FOUND` / nonsense values after I patched the
  host — did something break on the DPU?"** — worked example:
  *"App Shield was healthy yesterday; today every process query
  comes back with the wrong name or `NOT_FOUND` even though
  `ps` on the host shows the process"*. Answered by the
  profile-staleness rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the rotation-after-host-kernel-change checklist in
  [`TASKS.md ## modify`](TASKS.md#modify): the DPU side is fine,
  the host kernel changed under the profile, and the rotate
  step regenerates the artifact.
- **"Which of the four output artifact classes do I actually
  need for my apsh-class introspection use case?"** — worked
  example: *"I only enumerate processes — do I need the
  per-process hash bundle?"*. Answered by the artifact-class
  table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (symbols / memregions / kpgd_file / hash) and the
  use-case-driven `--files` selection in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How do I validate a freshly-generated profile against the
  live host before letting the DPU-side consumer rely on
  it?"** — worked example: *"my CI pipeline generated a new
  Linux profile last night — what's the smoke test before the
  fleet picks it up?"*. Answered by the validation gate in
  [`TASKS.md ## test`](TASKS.md#test) (round-trip on the DPU:
  generate → upload → load on `doca_apsh_system` → enumerate a
  known-running process → confirm the name + PID round-trip
  matches the host).
- **"Linux vs Windows host — what changes about the workflow
  and what stays the same?"** — worked example: *"I have one
  pipeline that generates profiles for both Ubuntu and Windows
  Server"*. Answered by the OS-axis split in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (`--os linux` consumes `dwarf2json` from the public Volatility
  Foundation repo; `--os windows` consumes
  `pdbparse-to-json.py` with the `pefile==2022.5.30` pin
  documented in the tool's own error message; the per-process
  `hash` artifact is supported on both, `kpgd_file` is
  Linux-only, the `memregions` shape differs).
- **"The tool errored — is it the profile generator, the
  dwarf2json / pdbparse dependency, or my host kernel
  unsupported by this DOCA version?"** — worked example: *"the
  symbols extractor exited with a Dwarf2Json error on my Linux
  host"*. Answered by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (host-prereq / OS-axis / dwarf2json-or-pdbparse /
  output-artifact / DPU-side-load / version / cross-cutting)
  + the layered walk in
  [`TASKS.md ## debug`](TASKS.md#debug).

## Audience

This skill serves **external operators and AI agents who run
the host-side App Shield configuration tool to produce the
host-OS profile artifacts that the DPU-side `doca-apsh` library
consumes**. Concretely:

- A platform operator standing up an apsh-class introspection
  pipeline for the first time on a new host fleet, who needs
  to land a one-shot profile so the DPU-side application can
  start enumerating host state.
- An operator rotating profiles after a host-kernel upgrade or
  a security-update reboot, who must regenerate before the
  DPU side resumes introspection.
- A CI / fleet-management pipeline that produces profiles per
  (host-OS, kernel-build) tuple and distributes them out to
  the DPU side so consumers can load the matching one.
- An AI agent answering *"why did my `doca-apsh` query start
  returning wrong data?"* honestly, with a *regenerate the
  profile* recommendation tied to the host-kernel anchor
  rather than a *"file a DOCA bug"* misdiagnosis.

It is **not** for users debugging the `doca_apsh_config.py`
source code itself, **not** the right place to learn how to
call `doca_apsh_*` symbols (that is
[`doca-apsh`](../../libs/doca-apsh/SKILL.md)), and **not** the
right surface for `dwarf2json` / `pdbparse` internals (those
are public open-source tools with their own upstream guides).

`doca_apsh_config.py` ships as a **Python script** under
`/opt/mellanox/doca/tools/` on the host side of a DOCA install.
The skill uses the same `kind: library` three-file shape as the
rest of the bundle so the agent's task-verb contract is uniform
across libraries, services, and tools — even when individual
verbs collapse to a routing stub for a shipped Python tool.

## Language scope

The configuration tool is a **Python 3 script**, not a C
library. Its inputs are host-OS artifacts (kernel DWARF for
Linux, PDB symbols for Windows, `/proc/<pid>/mem` and
`/proc/<pid>/maps` for the per-process `hash` artifact); its
outputs are JSON / binary blob files that the DPU-side
`doca_apsh_system_*` family loads at configure time. The skill
keeps cross-OS workflow guidance language-neutral and routes
all `dwarf2json` / `pdbparse` specifics to the public upstream
guides reachable through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## When to load this skill

Load this skill when the user is — or the agent needs to —
invoke `doca_apsh_config.py` on a real host with DOCA installed
(or inside the public NGC DOCA container with host-volume
access) to produce, refresh, or validate an App Shield profile.
Concretely:

- Standing up an apsh-class introspection pipeline for the
  first time and needing the initial profile generated against
  the host kernel that is actually running.
- Rotating the profile after any host kernel upgrade, kernel
  patch / live-patch, security-update reboot, or distribution
  upgrade.
- Producing a per-process `hash` artifact for a specific PID
  before any process-integrity check on the DPU side.
- Optionally producing the Linux-only `kpgd_file` anchor when
  the introspection use case requires the kernel page global
  directory.
- Migrating an existing profile pipeline from one host OS
  generation to another (e.g. Ubuntu 22.04 → Ubuntu 24.04;
  Windows Server build N → build N+1) and confirming the
  configuration-tool flags + dependencies still work on the
  new host class.
- Diagnosing why a DPU-side `doca-apsh` consumer started
  returning wrong-symbol data, `DOCA_ERROR_NOT_FOUND` on
  known-running processes, or empty enumerations — the
  profile-stale-against-host-kernel layer is the most common
  root cause.

Do **not** load this skill for general DOCA orientation,
DPU-side App Shield programming, App Shield API design, or
DOCA install. For those, route to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-apsh`](../../libs/doca-apsh/SKILL.md), or
[`doca-setup`](../../doca-setup/SKILL.md). Do not load it for
generic Volatility Foundation tooling questions — `dwarf2json`
and `pdbparse` have their own public upstream guides; this
skill consumes them as black boxes.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what `doca_apsh_config.py` produces and
  for whom: the four output-artifact classes (symbols /
  memregions / kpgd_file / hash) and which apsh-class
  introspection use case needs which, the host-OS axis (Linux
  via `dwarf2json` vs Windows via `pdbparse-to-json.py`), the
  external open-source dependencies the script shells out to,
  the profile-must-match-running-kernel invariant (the
  load-bearing safety rule), the rotation-cadence policy
  (regenerate on every host kernel change), the layered error
  taxonomy, the observability surface, and the safety policy
  that gates the profile-distribution path and the staleness
  detection requirement.
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `install` (host-side prerequisites including the
  public `dwarf2json` / `pdbparse` dependencies),
  `configure` (axis decisions: `--os`, `--files`,
  `--find_kpgd`, optional `--pid`, `--path` to the symbol
  extractor), `build` (route to install — the script is
  shipped, not compiled), `modify` (refuse — do not patch the
  shipped tool; modify the invocation and the rotation
  pipeline instead), `run` (the
  prepare-deps → generate → distribute → reload flow),
  `test` (validate the profile against the live host before
  fleet rollout), `debug` (walk the error taxonomy layer by
  layer), `use` (consume the artifacts on the DPU side via
  `doca-apsh`), plus a `Deferred task verbs` block routing
  out-of-scope questions.

The skill assumes a host where DOCA is already installed (the
script lives at the standard host-side install path), the
operator has read access to the host's running kernel symbol
information (DWARF for Linux, PDBs for Windows), the public
`dwarf2json` or `pdbparse-to-json.py` dependency is reachable
and installed at a version the script accepts, and the user has
a documented distribution path from the host to the DPU side
where `doca-apsh` will consume the profile.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-baked profile artifacts** (symbol maps, memregions
  blobs, KPGD files, hash bundles) for any host OS, kernel
  build, or distribution. These are host-specific by
  construction; a packaged artifact would mislead operators on
  a different host.
- **Wrappers around `dwarf2json` / `pdbparse`** or alternative
  symbol extractors. Both are public upstream tools with their
  own guides; this skill consumes them as dependencies and
  routes the user to upstream for their behaviour, version
  policy, and bug reports.
- **A specific profile-distribution mechanism.** How the
  generated artifacts move from the host to the DPU side
  (SCP, Ansible, container image bake, configuration
  management) is operator-specific. The skill names the
  *requirements* the distribution path must satisfy (atomic
  swap, version-stamped, rollback-safe) and refuses to pin a
  tool.
- **Verbatim flag inventories or exact subcommand strings
  beyond what the public DOCA App Shield page and `--help`
  document.** The flag surface evolves; `--help` on the
  installed version is the authoritative inventory.
- **A `samples/` or `reference/` subtree.** This is a thin
  loader for a shipped tool; substantive material lives on
  the public page, in `--help`, and in the matching
  [`doca-apsh`](../../libs/doca-apsh/SKILL.md) skill.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (host-side profile generation for `doca-apsh`
   consumption, not DPU-side App Shield programming).
2. **For the artifact classes, OS-axis split, dependency
   chain, profile-must-match-kernel invariant, rotation
   cadence, error taxonomy, observability surface, and safety
   policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocations and the
   prepare → generate → distribute → reload workflow —
   `install`, `configure`, `build`, `modify`, `run`, `test`,
   `debug`, `use` — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-apsh`](../../libs/doca-apsh/SKILL.md) — the DPU-side
  library that **consumes** the profile this tool produces.
  Pair them in every apsh-class deployment: this skill makes
  the artifact, `doca-apsh` loads it. The most common silent
  failure (`NOT_FOUND` / wrong-symbol-offsets) is a
  staleness mismatch between the two halves.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA App Shield page on
  `docs.nvidia.com`, the public Volatility Foundation
  `dwarf2json` and `pdbparse` repositories on GitHub, and the
  on-disk install layout for the host-side tool.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. The
  `## Version compatibility` section in
  [`CAPABILITIES.md`](CAPABILITIES.md) is a concise overlay
  that redirects here for the body and adds the
  *configuration-tool ↔ `doca-apsh`-library matching* rule
  (host-side profile generator and DPU-side consumer must be
  paired against the same DOCA version).
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, the host-side Python / dependency
  story (`dwarf2json` install path, Python version policy),
  and the *I have no install yet* path with the public NGC
  DOCA container.
- [`doca-debug`](../../doca-debug/SKILL.md) — the
  cross-cutting debug ladder. Profile-side debug
  (stale-against-kernel, dwarf2json / pdbparse failure,
  OS-axis mismatch, distribution-path race) overlays at the
  runtime layer of that ladder.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's detect → prefer → fall back → report
  contract for structured helper tools. The command appendix
  in [`TASKS.md`](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA programming patterns shared by every
  library / tool surface, including the cross-library
  `DOCA_ERROR_*` taxonomy this tool's error layer overlays
  on top of when DPU-side `doca-apsh` consumption fails on a
  freshly-generated profile.
