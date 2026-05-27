---
name: doca-apsh
description: >
  Use this skill for hands-on DOCA App Shield work on a BlueField
  DPU to introspect a paired host's kernel state — standing up a
  doca_apsh_system, enumerating host processes / kernel modules /
  libraries / threads from the DPU side, loading the host kernel
  symbol map, running doca_apsh_*_get() enumerators (App Shield
  has no separate cap-query family; DOCA_ERROR_NOT_SUPPORTED from
  the enumerator is the cap signal), or debugging DOCA_ERROR_*
  returns. Trigger even without explicit mention of "App Shield"
  or "doca_apsh"; implicit phrasings include "agent-less rootkit
  detection on BlueField", "list host processes from the DPU",
  "DPU-side host kernel introspection", "enumerator worked
  yesterday, NOT_PERMITTED today", "process query NOT_FOUND but
  ps shows it", "kernel module integrity check from the DPU".
  Refuse and route elsewhere for host kernel symbol-map authoring,
  bulk host↔DPU memory copies (doca-dma), packet I/O / flow
  steering (doca-eth / doca-flow), and real-time host event
  streams (doca-comch).
metadata:
  kind: library
compatibility: >
  Requires DOCA SDK installed at /opt/mellanox/doca on the
  BlueField DPU (Ubuntu 22.04/24.04 or RHEL/SLES on the Arm side)
  paired with an x86/Arm host whose running kernel will be
  introspected over PCIe. Reads the install via `pkg-config
  doca-apsh`; requires sudo on the DPU side and a
  host-OS-version-matching kernel symbol map loaded on the DPU.
---

# DOCA App Shield

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on App Shield work** on a BlueField DPU
paired with a host whose kernel state they want to introspect. Open
[`TASKS.md`](TASKS.md) if the user wants to *do* something (configure
/ build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what can
App Shield express* on this version. If the user has not installed
DOCA yet, route to [`doca-setup`](../../doca-setup/SKILL.md) first.
If the user is not sure App Shield is even the right library — the
flow is actually a bulk host↔DPU copy, a packet-I/O offload, or a
real-time event stream — read the path-selection rule in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
before configuring anything.

## Example questions this skill answers well

The CLASSES of App Shield questions this skill is built to answer,
each with one worked example. The agent should treat the *class* as
the load-bearing piece — the worked example is a single instance.

- **"Which side of the host ↔ DPU pair does App Shield code run
  on?"** — worked example: *"I want to enumerate processes on my
  x86 host using DOCA App Shield — do I install something on the
  host?"*. Answered by the DPU-side / host-side asymmetry rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  side-split table + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"What do I need on the DPU before I can introspect the host?"** —
  worked example: *"`doca_apsh_system_create` returns
  `DOCA_ERROR_NOT_PERMITTED` on the first run"*. Answered by the
  symbol-map + sudo prerequisite in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  permission matrix + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure) step 2.
- **"How do I enumerate the running processes on the host from the
  DPU side?"** — worked example: *"list every process on the host,
  one snapshot, starting from the shipped App Shield sample"*.
  Answered by the object-family lifecycle in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  object table + the workflow in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`TASKS.md ## run`](TASKS.md#run).
- **"Why does my process / module query return `NOT_FOUND`?"** —
  worked example: *"I ask for process name `vmtouch` and get
  `DOCA_ERROR_NOT_FOUND` — is App Shield broken?"*. Answered by the
  *"`NOT_FOUND` is a normal answer, not an error"* rule in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the smoke-test guidance in
  [`TASKS.md ## test`](TASKS.md#test).
- **"Should I use DOCA App Shield, or DOCA DMA / Eth / Flow / a
  custom host agent for this workload?"** — worked example: *"I
  want a real-time stream of every fork() on the host — should I
  use App Shield?"*. Answered by the path-selection rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing pointers in [`## Related skills`](#related-skills).
- **"Is App Shield on my installed DOCA version, and is the
  introspection target I want supported on this host OS / kernel
  version?"** — worked example: *"is `doca_apsh_module` enumeration
  available on DOCA 2.6 against my Ubuntu 22.04 host"*. Answered by
  the version-compatibility overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md), plus the
  capability-query rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

## Audience

This skill serves **external developers building DPU-side security
monitoring applications that consume the DOCA App Shield library**
— i.e., users whose code runs on the BlueField Arm side and calls
`doca_apsh_*` (directly in C/C++, or through FFI/bindings from
another language) to introspect the running kernel state of a paired
host. It is *not* for NVIDIA developers contributing to DOCA App
Shield itself, and it is *not* for users who want to instrument code
on the host side (the host runs nothing for App Shield).

**Language scope.** DOCA App Shield ships as a C library with
`pkg-config` module name `doca-apsh`. The shipped samples are
written in C. C and C++ consumers are the canonical case; the
worked examples in `TASKS.md` assume that path. Other-language
consumers (Rust, Go, Python, …) consume the same `*.so` through
FFI or language-specific bindings; the skill's contribution in that
case is to keep the DPU-side-only rule, the symbol-map prerequisite,
the object-family lifecycle, the capability-discovery rule, the
permission policy, and the error-taxonomy guidance language-neutral,
and to route the agent to the public C ABI as the authoritative
surface that any wrapper will eventually call.

## When to load this skill

Load this skill when the user is doing hands-on DOCA App Shield
work, in any language. Concretely:

- Initializing a `doca_apsh_system` on the DPU side, configured
  against the host's PCIe path and the host's kernel symbol map,
  before `doca_ctx_start()`.
- Enumerating any of the App Shield object families against an
  active `doca_apsh_system` — `doca_apsh_proc` (processes),
  `doca_apsh_module` (kernel modules), `doca_apsh_lib` (loaded
  libraries on a process), `doca_apsh_thread` (threads on a
  process).
- Reading the device + host-OS capability surface for App Shield
  via dry-running each enumerator (`doca_apsh_processes_get`,
  module / lib / thread variants) and inspecting the
  `DOCA_ERROR_NOT_SUPPORTED` return — App Shield does NOT ship a
  separate `doca_apsh_cap_*` query family; the enumerator return
  *is* the negative-cap signal — before assuming a particular
  introspection target
  works on this host OS / kernel version.
- Loading or refreshing the host kernel symbol map ("VMA / OS
  symbols" file) on the DPU side, recognising that the map is
  host-OS-version-specific and must be refreshed when the host
  kernel is upgraded.
- Debugging a `DOCA_ERROR_*` returned from an App Shield call
  (lifecycle vs. permission vs. capability vs. *"not present on the
  host right now"*) and the per-call status reported on the DPU
  side.
- Choosing between App Shield and an adjacent option (DOCA DMA when
  the goal is bulk host ↔ DPU memory movement, DOCA Eth / Flow
  when the goal is packet I/O, a custom host agent when the goal
  is a real-time event stream — App Shield is poll-based, not
  event-driven).
- Designing or extending non-C bindings (Rust, Go, Python, …) that
  wrap the App Shield C ABI — for the DPU-side-only rule,
  symbol-map prerequisite, object-family lifecycle, permission, and
  capability rules the wrapper must honor.

Do **not** load this skill for general DOCA orientation, install of
DOCA itself, or non-App-Shield library questions. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive App Shield-
specific material lives in two companion files:

- `CAPABILITIES.md` — what App Shield can express on this version:
  the DPU-side / host-side asymmetry rule, the object family
  (`doca_apsh_system` → `_proc` / `_module` / `_lib` / `_thread`)
  and its read-mostly observation shape, the implicit
  capability-query surface (enumerator return code; App Shield
  does NOT ship a separate `doca_apsh_cap_*` family), the App
  Shield error taxonomy
  (mapped onto the cross-library `DOCA_ERROR_*` set with the
  *"`NOT_FOUND` is a normal answer"* rule called out explicitly),
  the observability surface (per-query return + per-snapshot
  caller-side bookkeeping), the safety policy that gates the
  symbol-map prerequisite and the DPU-side sudo rule, and the
  path-selection rule against the adjacent DOCA libraries (DMA,
  Eth, Flow).
- `TASKS.md` — step-by-step workflows for the six in-scope App
  Shield verbs: `configure`, `build`, `modify`, `run`, `test`,
  `debug`. Plus a `## rollback` overlay (Apsh-specific six-step
  teardown that stops enumeration before `doca_ctx_stop`,
  unloads the symbol map, destroys the apsh_system, and routes
  any mode-flip residual through `doca-hardware-safety`) and the
  5-phase universal debug-loop instantiation appended to
  `## debug`. Plus a `Deferred task verbs` block that points
  out-of-scope questions at the right next skill.

The skill assumes a host + BlueField pair where DOCA is already
installed at the standard location, the DPU side has the privileges
its public install profile expects (in particular, sudo on the DPU
side to open the host introspection path), and a host-OS-matching
kernel symbol map is available on the DPU side. It does not cover
installing DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA App Shield application source code, in any
  language.** The verified App Shield source code is the shipped C
  samples at `/opt/mellanox/doca/samples/doca_apsh/<name>/`. The
  agent's job is to route the user to those files and prescribe a
  minimum-diff modification on them via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the App Shield-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Pre-baked kernel symbol maps** ("VMA / OS symbols" files /
  PDB blobs / kernel-symbol blobs) for any host OS version.
  These are host-OS-version-specific and out of the agent's
  surface — they belong to the user's host inventory, not to a
  skill bundle. The skill describes the prerequisite; it does
  not ship the artifact.
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, …) parked inside the skill. The agent constructs
  the build manifest *in the user's project directory* against
  the user's installed DOCA, where `pkg-config --modversion
  doca-apsh` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope.
2. **For the App Shield capability surface, the DPU-side-only
   rule, the object family, the symbol-map prerequisite, the
   capability-query rule, the error taxonomy (including the
   `NOT_FOUND` rule), observability, the safety policy, and the
   path-selection rule against DMA / Eth / Flow, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "App Shield-specific
guidance".

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The App
  Shield URL is
  `https://docs.nvidia.com/doca/sdk/DOCA-App-Shield/index.html`;
  the on-disk samples live under
  `/opt/mellanox/doca/samples/doca_apsh/`.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, DPU-side privilege checks, and the *I
  have no install yet* path with the public NGC DOCA container.
  This skill assumes its preconditions are satisfied (in
  particular, the DPU has DOCA installed and the agent can run
  with sudo on the DPU side).
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule + detection chain and adds
  at most one App Shield-specific overlay rule.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, and the
  program-side debug order. This skill layers App Shield
  specifics on top.
- [`doca-dma`](../doca-dma/SKILL.md) — the right library when the
  workload is a bulk host ↔ DPU memory copy rather than a
  read-mostly observation of host kernel state. This skill's
  path-selection rule routes to DMA when App Shield is *not* the
  answer.
- [`doca-comch`](../doca-comch/SKILL.md) — the right library when
  the flow is producer / consumer messaging between a host
  process and a DPU process. App Shield does not assume any host
  agent; if the user can install one, comch is often the simpler
  primitive for non-security workloads.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). App Shield-specific debug (symbol-map
  mismatch, DPU-side privilege gaps, the *`NOT_FOUND` is normal*
  trap) overlays on top of that ladder.
