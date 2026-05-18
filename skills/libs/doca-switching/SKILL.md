---
name: doca-switching
description: NVIDIA DOCA Switching on BlueField — the abstraction for programming the BlueField embedded switch dataplane (the substrate doca-flow programs sit on top of), per-switch context lifecycle, port objects (PF / VF / SF / representor), switching tables and bridge primitives, capability discovery via the `doca_switching_cap_*` family for port types / switching modes / max ports / overlay encapsulations, the NIC-mode-vs-switch-mode transition (a high-stakes operation that may require BFB reconfiguration and reboot), permission rules (root / sudo on the DPU), the IN_USE / BAD_STATE / NOT_SUPPORTED / INVALID_VALUE / NOT_PERMITTED error overlay, and debugging mode-vs-flow boundary failures.
kind: library
---

# DOCA Switching

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on switch-dataplane topology work** on a
BlueField host. Open [`TASKS.md`](TASKS.md) if the user wants to *do*
something (configure / build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what can
the BlueField switch dataplane express* on this version. If the
user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. **If the user is
asking how to write a packet-steering rule** (5-tuple match → action,
pipe / pipeline programming), route to
[`doca-flow`](../doca-flow/SKILL.md) — that is the *rules* layer that
sits ON TOP OF the switching topology this skill configures.

## Example questions this skill answers well

The CLASSES of switching-dataplane questions this skill is built to
answer, each with one worked example. The agent should treat the
*class* as the load-bearing piece — the worked example is a single
instance.

- **"What's the difference between doca-switching and doca-flow?"** —
  worked example: *"I want to bridge two host PFs through the
  BlueField — is that a switching question or a flow question?"*.
  Answered by the layering rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (topology FIRST, flows ON TOP) + the routing-to-`doca-flow` block in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"How do I set up representors on the BlueField switch and bridge
  them at the switch level?"** — worked example: *"expose two host
  PFs as representors on the DPU and bridge them so doca-flow rules
  can later target them"*. Answered by the port-enumeration +
  bridging workflow in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  port-type table.
- **"My BlueField is in NIC mode but I need switch mode — how do I
  switch over?"** — worked example: *"can I flip NIC ↔ switch mode
  from the DOCA Switching API at runtime?"*. Answered by the
  mode-transition section in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  (high-stakes: typically requires firmware reconfiguration and
  reboot) + the env-side routing in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"Which port types and switching modes does my BlueField actually
  support?"** — worked example: *"is SF-as-representor available on
  my BlueField-3 install"*. Answered by the
  `doca_switching_cap_*` capability-query rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the cap-discovery step in
  [`TASKS.md ## configure`](TASKS.md#configure) step 3.
- **"What does this `DOCA_ERROR_*` from a switching call mean and
  which layer caused it?"** — worked example: *"`DOCA_ERROR_IN_USE`
  when I try to reconfigure a port"*. Answered by the switching
  overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).
- **"Is this switching feature available on my installed DOCA
  version?"** — worked example: *"is the VXLAN-at-switch overlay
  available on my install"*. Answered by the version-compatibility
  section in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the version-discovery rule (`pkg-config --modversion
  doca-switching`) pinned in
  [`TASKS.md ## configure`](TASKS.md#configure).

## Audience

This skill serves **external developers building applications that
configure the BlueField embedded switch dataplane** — i.e., users
whose code calls `doca_switching_*` (directly in C/C++, or through
FFI/bindings from another language) to set up the topology that
packet-steering rules will later be programmed against. It is *not*
for NVIDIA developers contributing to DOCA Switching itself, or for
users asking about Linux software switching (OVS, Linux bridge,
network namespaces) — those are different stacks entirely.

**Language scope.** DOCA Switching ships as a C library with
`pkg-config` module name `doca-switching`. The shipped samples that
this skill points the agent at (when present at the install path
below) are written in C. C and C++ consumers are the canonical case;
the worked examples in `TASKS.md` assume that path. Other-language
consumers (Rust, Go, Python, …) consume the same `*.so` through
FFI or language-specific bindings; the skill's contribution in that
case is to keep the topology-vs-rules layering, lifecycle,
capability-discovery, permission-and-mode-transition rules, and
error-taxonomy guidance language-neutral, and to route the agent
to the public C ABI as the authoritative surface that any wrapper
will eventually call.

## When to load this skill

Load this skill when the user is doing **hands-on switching-topology
work on a BlueField host with DOCA already installed**, in any
language. Concretely:

- Initializing a per-switch context (`doca_switching`) on the DPU
  side and confirming the BlueField is in the right mode for the
  intended topology.
- Enumerating port objects (PF / VF / SF / representor) on the
  switch domain and binding them to a topology spec.
- Setting up bridges or switching-table primitives between host PFs
  / VFs / SFs and DPU representors — i.e., deciding which ports
  belong to which switching domain *before* `doca-flow` rules are
  programmed on top.
- Querying the device's switching capability surface
  (`doca_switching_cap_*` for max ports, supported port types,
  supported switching modes, supported overlay encapsulations) on
  the active `doca_devinfo`.
- Planning a NIC-mode ↔ switch-mode transition — and routing the
  user through the high-stakes (firmware-reconfiguration / reboot)
  warning *before* they execute it.
- Debugging a `DOCA_ERROR_*` returned from a switching API call
  (`BAD_STATE`, `NOT_SUPPORTED`, `INVALID_VALUE`, `NOT_PERMITTED`,
  `IN_USE`) and deciding whether the cause is a permission gap, a
  mode mismatch, a reconfiguration of a live port, or an
  unsupported feature on this BlueField generation / firmware.
- Designing or extending non-C bindings (Rust, Go, Python, …) that
  wrap the Switching C ABI — for the API-surface, lifecycle,
  permission, mode-transition, and capability-discovery rules the
  wrapper has to honor.

Do **not** load this skill for general DOCA orientation, install of
DOCA itself, packet-steering rule programming (use
[`doca-flow`](../doca-flow/SKILL.md)), software switching at the
Linux layer (OVS, Linux bridge, netns), or non-switching library
questions. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive
switching-specific material lives in two companion files:

- `CAPABILITIES.md` — what BlueField switching can express on this
  version: the topology-vs-rules layering rule (substrate first,
  flows on top), the port-type taxonomy (PF / VF / SF /
  representor), the NIC-mode-vs-switch-mode axis, the supported
  switching-table and bridge primitives, the
  `doca_switching_cap_*` capability-query surface for max ports /
  supported port types / supported modes / supported overlay
  encapsulations, the switching error taxonomy (mapped onto the
  cross-library `DOCA_ERROR_*` set, with the `IN_USE` overlay for
  live-port reconfiguration), the observability surface (port
  state, representor enumeration, switching-table inspection), and
  the safety policy that gates the high-stakes mode transitions.
- `TASKS.md` — step-by-step workflows for the six in-scope
  switching verbs: `configure`, `build`, `modify`, `run`, `test`,
  `debug`. Plus a `Deferred task verbs` block that points
  install / deploy / rollback questions at the right next skill.

The skill assumes a BlueField host where DOCA is already installed
at the standard location and the user has root / sudo access on
the DPU (switching-topology calls typically require it; mode
transitions always do). It does not cover installing DOCA — that
path goes through [`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA Switching application source code, in any
  language.** The Switching API surface evolves between releases
  and code written from documentation prose cannot be verified
  without compiling it against the live library on a real install.
  The verified Switching source code is the shipped C sample at
  `/opt/mellanox/doca/samples/doca_switching/<name>/` when present
  on the install; the agent's job is to route the user to that
  file and prescribe a minimum-diff modification via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the switching-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, …) parked inside the skill. The agent constructs
  the build manifest *in the user's project directory* against the
  user's installed DOCA, where `pkg-config --modversion
  doca-switching` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.
- **Topology recipes for specific data-center patterns** (e.g. an
  "east-west bridging" reference). Those are instance-shaped per
  the classes-over-instances rule in
  [`AUTHORING.md` § 1a](../../../../devops/AUTHORING.md) and
  rejected by the class-shape filename gate; route any such
  request to the topology *primitives* taught here plus the
  packet-steering layer in [`doca-flow`](../doca-flow/SKILL.md).

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope (and *not* a packet-steering question, which routes to
   [`doca-flow`](../doca-flow/SKILL.md)).
2. **For the topology-vs-rules layering rule, the port-type
   taxonomy, the NIC-vs-switch mode axis, the capability-query
   surface, the switching error taxonomy, observability, and the
   safety policy gating mode transitions, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules,
[`doca-flow`](../doca-flow/SKILL.md) for the rules layer that
programs ON TOP OF the topology this skill configures, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or the
installed package layout" rather than "switching-specific guidance".

## Related skills

- [`doca-flow`](../doca-flow/SKILL.md) — the *rules* layer that sits
  on top of the switching topology this skill configures. Same
  shape (DOCA Core lifecycle, capability-query rule, validate /
  smoke-before-scale, env preconditions); different concern
  (packet steering rules vs switch topology). The agent must teach
  the layering: configure switching topology FIRST with this skill,
  then program flows ON TOP with `doca-flow`. The
  [`DOCA Switching` public guide](https://docs.nvidia.com/doca/sdk/DOCA-Switching/index.html)
  is the authoritative source on the topology surface; the
  [`DOCA Flow` public guide](https://docs.nvidia.com/doca/sdk/DOCA-Flow/index.html)
  is the authoritative source on the rules surface.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  routing table for every public DOCA documentation source and the
  on-disk layout of an installed DOCA package. Always available
  alongside this skill; this skill expects to be able to defer
  documentation-finding and install-layout questions there instead
  of duplicating them.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, representor visibility checks, the BlueField
  runtime-mode (SmartNIC / DPU / switch) check, and the *I have no
  install yet* path with the public NGC DOCA container. This skill
  assumes its preconditions are satisfied; a mode-transition
  request also routes here for the env-side reconfiguration steps.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule and adds the switching
  per-library overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer /
  fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, and the
  program-side debug order. This skill layers switching specifics
  on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). Switching-specific debug (mode mismatches,
  live-port `IN_USE`, representor permission gaps) overlays on top
  of that ladder.
