# DOCA App Shield capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(side-split / object family / capability discovery / path selection
/ version / errors / observability / safety) and read that section
end-to-end. The tables in each section are the load-bearing
content; the prose around them is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern (the
verbs `configure / build / modify / run / test / debug`), jump to
[TASKS.md](TASKS.md). For the canonical DOCA version-handling rules
that this skill layers an App Shield overlay on top of, see
[`doca-version`](../../doca-version/SKILL.md).

## Pattern overview

Every App Shield question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
App Shield release and every host / DPU pair, not just the worked
examples shown.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Place the code on the DPU side | All `doca_apsh_*` calls run on the BlueField Arm side; the host runs no agent; introspection is one-way over PCIe | [`## Capabilities and modes`](#capabilities-and-modes) side-split table |
| 2. Decide App Shield is the right library | The workload is read-mostly observation of host kernel state for security monitoring; it is NOT bulk data movement, packet I/O, or a real-time event stream | [`## Capabilities and modes`](#capabilities-and-modes) path-selection bullet |
| 3. Load the host kernel symbol map | Without a host-OS-version-matching kernel symbol map on the DPU side, App Shield cannot walk the host's data structures; this is a hard prerequisite, not an optimisation | [`## Safety policy`](#safety-policy) symbol-map row + [TASKS.md ## configure](TASKS.md#configure) step 2 |
| 4. Stand up the system + object lifecycle | DOCA Core lifecycle: create `doca_apsh_system` → configure (symbol map, host PCIe path, OS type) → start → enumerate `_proc` / `_module` / `_lib` / `_thread` → stop → destroy | [`## Capabilities and modes`](#capabilities-and-modes) object table + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Discover capabilities before enumerating | `doca_apsh_cap_*` against the active `doca_devinfo` BEFORE assuming a particular introspection target works on this host OS / kernel version | [`## Capabilities and modes`](#capabilities-and-modes) capability-query rule + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 6. Diagnose an App Shield error | Map symptom (`BAD_STATE`, `NOT_PERMITTED`, `NOT_FOUND`, `NOT_SUPPORTED`, `INVALID_VALUE`) to root cause without leaving the App Shield layer prematurely; in particular, recognise `NOT_FOUND` as a *normal answer*, not a bug | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **`doca_apsh_*` code runs on the DPU side, every time.** The host
  side runs no App Shield agent at all — that's the appeal. An
  agent recommending host-side install of App Shield is wrong for
  *every* version of the library, and the user will discover this
  only after wasted effort.
- **The host kernel symbol map is a hard prerequisite, every time.**
  Without an OS-version-matching symbol map loaded on the DPU side,
  no enumerator works. The map is host-OS-version-specific; a map
  that worked for the host's previous kernel will silently stop
  working after a host kernel upgrade. Cap-query, lifecycle, and
  permission set are all downstream of this prerequisite.

## Capabilities and modes

DOCA App Shield is a **DOCA Core Context** with one DPU-side anchor
object (`doca_apsh_system`) that other enumerators hang off. Every
`doca_apsh_system` instance follows the universal `cfg-create →
cfg-set-* → init → start → use → stop → destroy` lifecycle (see
[`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)).
On top of that lifecycle, App Shield layers an asymmetric side
split, a small object family, and a capability-query family.

**Side split — DPU vs host.** App Shield is asymmetric and the
asymmetry is the #1 first-app confusion.

| Side | What runs there | What does NOT run there | Why |
| --- | --- | --- | --- |
| DPU (BlueField Arm) | The entire App Shield program: `doca_apsh_*` calls, the loaded kernel symbol map, the `doca_apsh_system` + enumerator objects, the PCIe-side memory access | n/a | The DPU has direct memory-side access to the host over PCIe; the security stance is "observer is below the host's threat surface" |
| Host (x86 / Arm) | An unmodified kernel; the host's normal workload | App Shield code, App Shield agents, App Shield kernel modules, any DOCA library at all for the App Shield path | The appeal of App Shield is exactly that the host runs nothing — a compromised host cannot disable an observer it doesn't host |

**Object family.** App Shield exposes ONE root object and FOUR
enumerator object types. The agent must not invent additional ones;
the public surface is closed.

| Object | What it represents | Per-instance scope | Notes |
| --- | --- | --- | --- |
| `doca_apsh_system` | One host being introspected (one PCIe path from the DPU) | The root context every other enumerator hangs off | Configured with the host's PCIe path, host OS type, and the loaded kernel symbol map before `doca_ctx_start()` |
| `doca_apsh_proc` | A process enumerated from the host | Per host process snapshot | Enumerated against a started `doca_apsh_system`; `NOT_FOUND` is a normal answer for a process that exists in the user's mental model but not on the host right now |
| `doca_apsh_module` | A kernel module loaded on the host | Per host kernel module | Used for rootkit detection and integrity verification of the host's kernel-module set |
| `doca_apsh_lib` | A loaded library on a given host process | Per (host process, loaded library) | Hangs off a `doca_apsh_proc`, not directly off the system; the per-process library list snapshots at enumeration time |
| `doca_apsh_thread` | A thread on a given host process | Per (host process, thread) | Hangs off a `doca_apsh_proc`; useful when the integrity check is at thread granularity rather than process granularity |

**Capability discovery — the only rule.** Before enumerating any
target, call the matching `doca_apsh_cap_*` query against the
active `doca_devinfo` (per the cross-cutting cap-query rule in
[`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability)).
The query is the runtime authority for *"is this introspection
target supported on this host OS / kernel version against this DPU's
DOCA install"*. Quoting *"App Shield enumerates X"* from memory
without the cap query is the silent-fail case — when the user's
host OS / kernel pair doesn't carry that introspection target, the
program returns `DOCA_ERROR_NOT_SUPPORTED` at enumerate time and the
user has no idea why.

**Path selection — App Shield vs the adjacent libraries.** App
Shield is for read-mostly observation of host kernel state. It is
not the answer for every host ↔ DPU workload; the agent must walk
this rule before recommending App Shield setup.

| Use DOCA App Shield when … | Use a different library when … |
| --- | --- |
| Agent-less host security monitoring is the goal — rootkit detection, periodic process / module / library / thread snapshots, integrity verification of host kernel data structures, all from the DPU side with the host running nothing | The workload is bulk host ↔ DPU memory movement (large copies between two `doca_mmap` regions) — use [`doca-dma`](../doca-dma/SKILL.md) |
| The user can tolerate poll-based snapshots (periodic enumeration over the App Shield API) and does not need a host-side hook on every event | The workload is packet I/O at line rate (RX / TX queues, flow steering) — use [`doca-eth`](../doca-eth/SKILL.md) or [`doca-flow`](../doca-flow/SKILL.md) |
| The host is unmodified and the user wants to keep it that way (no kernel module to install, no userspace agent to maintain) | The user needs a real-time event stream of host events (every fork, every syscall, every page fault) — App Shield is poll-based, not event-driven; route to a host-resident solution or to [`doca-comch`](../doca-comch/SKILL.md) for a host ↔ DPU message channel the user can drive from a small custom host agent |

**Configuration shape.** *Mandatory* configurations before
`doca_ctx_start()` on a `doca_apsh_system`: the host PCIe path
(which BlueField-side PCIe path reaches the host being
introspected), the host OS type (so App Shield knows which symbol
layout to walk), and the loaded kernel symbol map (the
host-OS-version-specific blob that lets App Shield resolve kernel
addresses). *Optional* configurations follow the standard DOCA Core
surface; defaults come from the library and the active
`doca_devinfo`.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The App Shield-specific overlay** is:

- **The set of introspection targets that work on a given install is host-OS-version-bound, not just DOCA-version-bound.** Per the cross-cutting cap-query rule in [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability), use the `doca_apsh_cap_*` query family against the active `doca_devinfo` at runtime to discover what's actually enumerable on *this* host OS — a target that works against one host kernel may return `DOCA_ERROR_NOT_SUPPORTED` against another, even on the same DOCA install. Use `pkg-config --modversion doca-apsh` as the build-time anchor (per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)).
- **The host kernel symbol map is the second version axis.** A symbol map baked for one host kernel will silently stop working after a host kernel upgrade; this is not an App Shield bug, it's the OS-symbol surface having moved. When the user reports *"my enumerator worked yesterday and returns `NOT_PERMITTED` today"*, the first hypothesis is a host kernel upgrade that invalidated the loaded symbol map. Route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) for the cross-cutting version-mismatch diagnosis pattern, and then refresh the symbol map.
- **`doca-apsh.pc` plus `doca-common.pc` must both match `doca_caps --version`** at the four-way-match check (per [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)). A common partial-install pattern after a DOCA upgrade on the DPU side is that `doca-apsh.pc` lingers from the previous release while `doca-common.pc` was refreshed; route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) ladder step 2 before any App Shield-layer diagnosis.

## Error taxonomy

App Shield-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *App Shield surface* meaning that the agent
must disambiguate before falling back to the cross-library response.

| Error | App Shield context where it shows up | App Shield-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Enumerator call (`doca_apsh_processes_get`, module / lib / thread variants) before `doca_ctx_start()`; or destroying the `doca_apsh_system` while an enumerator's returned list is still being walked | Lifecycle violation. Walk the call sequence against the lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the most common case is enumerating before the `doca_apsh_system` is in `RUNNING`. |
| `DOCA_ERROR_NOT_PERMITTED` | `doca_apsh_system_create`, first enumerator call | The DPU side is missing required privileges (sudo / raw PCIe + memory access path), OR the host kernel symbol map is not loaded / not loadable on this install. Walk the matrix in [`## Safety policy`](#safety-policy) before any code change. |
| `DOCA_ERROR_NOT_FOUND` | Process / module / library / thread enumerator with a specific target identifier (name, PID, …) | The requested target does not exist on the host *right now*. **This is a normal answer, not an error.** The fix is on the caller side: re-enumerate at snapshot time, treat absence as data, do not retry-loop. Surfacing `NOT_FOUND` as a bug is the single most common first-app misinterpretation. |
| `DOCA_ERROR_NOT_SUPPORTED` | Capability query (`doca_apsh_cap_*`), or enumerator first call | The requested introspection target is not available for this host OS / kernel version against the current App Shield + DOCA install. Re-run the matching `doca_apsh_cap_*` query; if it returns false, that *is* the answer — the user's host pair does not carry that target right now. |
| `DOCA_ERROR_INVALID_VALUE` | Enumerator with malformed input (wrong PID type, wrong identifier shape) | The input passed to the enumerator is malformed. The fix is to inspect the user-side input against the public App Shield headers in the install's actual include directory (resolved via `pkg-config --variable=includedir`, commonly `/opt/mellanox/doca/include/` or `/opt/mellanox/doca/infrastructure/include/` depending on profile); per the headers-win-over-docs rule in [`doca-version`](../../doca-version/SKILL.md), the headers describe what *this* install can accept. |
| `DOCA_ERROR_DRIVER` | `doca_apsh_system_create`, first enumerator call | The layer below DOCA reported failure on the PCIe path the DPU uses to read host memory. Capture state and route to env-class debug ([`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)) — the layer below DOCA is the suspect, not the App Shield program. |

The agent's rule: **never recommend a retry loop on
`DOCA_ERROR_*` without first identifying which of the rows above
is the cause**. None of the App Shield rows wants a blind retry;
`NOT_FOUND` wants a re-snapshot intent at the caller; the others
want investigation.

## Observability

App Shield's observability surface is per-query / per-snapshot,
not event-driven. There is no PE-based completion stream like the
data-plane DOCA libraries; the visibility comes from inspecting
each enumerator's return value and the per-object data it surfaces.

Three primary signals the agent should reach for:

1. **Per-enumerator return + populated object list.** Every
   enumerator (`doca_apsh_processes_get`, module / lib / thread
   variants) returns a `doca_error_t` plus a sized list of
   per-object handles. The agent must inspect both: the error
   value carries the diagnosis (per [`## Error taxonomy`](#error-taxonomy)),
   and the populated list is the per-snapshot reality.
2. **Capability snapshot at configure time.** The output of every
   `doca_apsh_cap_*` query is a snapshot of *what App Shield said
   was possible* before any enumerator was called. Save it as the
   baseline; if a later enumerator returns `DOCA_ERROR_NOT_SUPPORTED`
   the diff against this snapshot is the bug, not the enumerator
   call itself.
3. **Lifecycle / state transitions.** Trace-level DOCA logs
   (`DOCA_LOG_LEVEL=trace`) show when the `doca_apsh_system`
   context moved from `INIT` to `STARTING` to `RUNNING`. An
   enumerator that *appears* to silently return an empty list is
   almost always the context not being in `RUNNING` at call time
   — confirm via the trace log before suspecting the host's
   process / module / library / thread set is empty.

For the cross-cutting observability primitives
(`--sdk-log-level`, the `doca-<lib>-trace` build flavor, the
`DOCA_LOG_LEVEL` env var) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package layout)
defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

App Shield's safety surface is **DPU-side-privilege + symbol-map**.
The library introspects host kernel memory over PCIe from the DPU
side; an incorrect privilege state silently fails the enumerator,
and a missing or wrong symbol map produces results that look
plausible but are not anchored to the host's real kernel layout.

The **DPU-side prerequisite matrix** the agent must walk for any
new App Shield setup:

| Prerequisite | Required state on the DPU side | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| DPU privilege level | The App Shield process can perform the raw PCIe + DMA-style host memory access the introspection path needs — typically the process runs with sudo on the DPU side | `id` confirms the user is root or in the privileged group the install profile expects; the first `doca_apsh_system_create` call surfaces the gap as `DOCA_ERROR_NOT_PERMITTED` | [`doca-setup`](../../doca-setup/SKILL.md) for the env-side privilege story; do not modify the program to "downgrade" to a less-privileged path |
| Host kernel symbol map | A host-OS-version-matching kernel symbol map (the "VMA / OS symbols" file, sometimes shipped as a PDB or kernel-symbol blob) is present on the DPU side and loaded into the `doca_apsh_system` before `doca_ctx_start()` | The user can point to the map file on the DPU side; `doca_ctx_start()` succeeds for the configured `doca_apsh_system` | User-side artifact management; this skill does NOT ship a symbol map. Route to [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) and the App Shield public guide for the artifact's expected shape and freshness rules |
| Host PCIe path | The DPU can enumerate the BlueField PCIe path that reaches the host being introspected | `doca_caps --list-devs` on the DPU side surfaces the path; the configured `doca_apsh_system` accepts it without `DOCA_ERROR_INVALID_VALUE` | [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability) for env-side device-enumeration |

- **The host side runs nothing.** Do not invent a "host agent" for
  App Shield; the entire library is a DPU-side observer and any
  recommendation that adds host-side install is wrong for every
  release.
- **Refresh the symbol map when the host kernel is upgraded.** The
  symbol map is bound to a specific host kernel version. Treat a
  host kernel upgrade as an event that invalidates the symbol map;
  validate the next enumerator run BEFORE inferring that "App Shield
  broke".
- **Validate with a known-running process before broad scans.** A
  smoke enumerate-one-known-target call (e.g. asking for `init` /
  `systemd` by name on a Linux host) is the cheapest way to confirm
  the privilege + symbol-map + PCIe path are all correct. If the
  smoke passes, broad scans inherit that confidence; if the smoke
  returns `NOT_FOUND` for a process that you can `ps` on the host,
  the symbol map is the prime suspect.

## Deferred topic boundaries

This skill scopes itself to the DOCA App Shield library. Adjacent
topics the agent will get asked but should route elsewhere:

- **Host kernel symbol map authoring / packaging** — outside this
  skill. The map is host-OS-version-specific; its shape and
  freshness are documented in the public DOCA App Shield guide
  reachable through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **DOCA Core context and progress engine internals** — owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the Core context lifecycle; it does not
  redefine it.
- **Bulk host ↔ DPU memory movement** — owned by
  [`doca-dma`](../doca-dma/SKILL.md). When the workload is moving
  bytes, not observing kernel state, App Shield is not the answer.
- **Packet I/O / dataplane offload** — owned by the network-side
  DOCA libraries (Ethernet, Flow). Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  when the user's question is really about packet steering.
- **Real-time host event streams** — App Shield is poll-based, not
  event-driven. When the user needs an event-per-fork stream, the
  answer is a host-resident solution coordinated over
  [`doca-comch`](../doca-comch/SKILL.md), not App Shield.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the App Shield overlay (including the
  `NOT_FOUND`-is-normal rule), not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build /
  link / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug). This
  skill's `## debug` overlays the runtime + program layers.
