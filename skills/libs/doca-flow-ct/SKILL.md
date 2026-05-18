---
name: doca-flow-ct
description: NVIDIA DOCA Flow Connection Tracking on BlueField and ConnectX hosts — the stateful CT layer (`pkg-config` module `doca-flow-ct`) that EXTENDS DOCA Flow with hardware-accelerated 5-tuple connection tracking, aging timers, and NAT-aware actions (SNAT / DNAT) for stateful firewall offload and per-connection telemetry tied to flow rules. Covers the layering rule (doca-flow must be set up and running FIRST; doca-flow-ct attaches a per-port context on top and wraps existing pipes with CT semantics), capability discovery via the `doca_flow_ct_cap_*` family (max concurrent flows, aging-timer range, NAT variants, overlay encapsulations), the CT entry lifecycle layered on top of the doca-flow pipe lifecycle, aging-table sizing as a load-bearing safety concern, the distinction from stateless steering (`doca-flow` alone) and from Linux kernel conntrack, and the CT-specific `DOCA_ERROR_*` overlay (BAD_STATE, NOT_SUPPORTED, FULL / NO_MEMORY, INVALID_VALUE, IN_USE).
kind: library
---

# DOCA Flow Connection Tracking

**Where to start:** This skill assumes DOCA is already installed,
the user already has a working `doca-flow` setup (port up, at least
one pipe created and validated), and the user is doing **hands-on
CT work** that layers stateful connection tracking on top of that
existing doca-flow setup. Open [`TASKS.md`](TASKS.md) if the user
wants to *do* something (configure / build / modify / run / test /
debug); open [`CAPABILITIES.md`](CAPABILITIES.md) when the question
is *what can CT express* on top of a given doca-flow setup on this
version. If the user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user has
not stood up `doca-flow` yet, route to
[`doca-flow`](../doca-flow/SKILL.md) FIRST — doca-flow-ct does NOT
replace doca-flow, it EXTENDS it. If the user is asking about
purely stateless steering (no per-connection state), the right
answer is `doca-flow` alone, not this skill.

## Example questions this skill answers well

The CLASSES of CT questions this skill is built to answer, each
with one worked example. The agent should treat the *class* as the
load-bearing piece — the worked example is a single instance.

- **"How do I add stateful connection tracking to my existing
  doca-flow pipeline?"** — worked example: *"I already have a
  doca-flow port and a basic match-and-forward pipe; I want to
  track connections so I can express 'allow established, drop
  new'"*. Answered by the layering rule + CT-context-on-top-of-flow-port
  workflow in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  layering table.
- **"How do I express a hardware-accelerated NAT gateway with
  per-flow state?"** — worked example: *"SNAT outbound traffic from
  10.0.0.0/8 to a single public IP, track each connection,
  reverse-NAT inbound traffic"*. Answered by the NAT-action
  surface + 5-tuple match schema in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the CT-aware pipe workflow in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"How many concurrent CT flows can this device hold, and how
  long can the aging timer be?"** — worked example: *"I expect
  ~250k simultaneous TCP connections at peak; will the device
  hold them?"*. Answered by the cap-query rule
  (`doca_flow_ct_cap_*` family) in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the cap-query step in
  [`TASKS.md ## configure`](TASKS.md#configure) step 2, with the
  aging-table sizing rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **"Should I use doca-flow-ct, plain doca-flow, or Linux kernel
  conntrack for this?"** — worked example: *"I want to drop packets
  that don't belong to an established connection; do I need CT?"*.
  Answered by the path-selection rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the deferred-topic boundaries in
  [`CAPABILITIES.md ## Deferred topic boundaries`](CAPABILITIES.md#deferred-topic-boundaries).
- **"Is this CT capability on my installed DOCA version?"** —
  worked example: *"is the overlay-aware CT (CT over VXLAN) in
  the version I have?"*. Answered by the version-compatibility
  overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md) and adds the
  CT-specific *doca-flow-ct rides the doca-flow version* overlay.
- **"What does this `DOCA_ERROR_*` from a `doca_flow_ct_*` call
  mean and which layer caused it?"** — worked example: *"`DOCA_ERROR_FULL`
  on the CT entry add after 200k entries"*. Answered by the CT
  overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).

## Audience

This skill serves **external developers building applications that
consume the DOCA Flow Connection Tracking library** — i.e., users
whose code calls `doca_flow_ct_*` (directly in C/C++, or through
FFI/bindings from another language) on top of an existing
`doca_flow_*` setup to track per-connection state, age out idle
connections, and apply NAT-style rewrites in hardware on a
BlueField DPU or ConnectX NIC. It is *not* for NVIDIA developers
contributing to DOCA Flow CT itself, and it is not for users who
need only stateless steering — those users belong in
[`doca-flow`](../doca-flow/SKILL.md) alone.

**Language scope.** DOCA Flow CT ships as a C library with
`pkg-config` module name `doca-flow-ct`. The shipped samples that
this skill points the agent at are written in C (NVIDIA's choice),
under `/opt/mellanox/doca/samples/doca_flow_ct/`. C and C++
consumers are the canonical case and the worked examples in
`TASKS.md` assume that path. Other-language consumers (Rust, Go,
Python, …) consume the same `*.so` library through FFI or
language-specific bindings; the skill's contribution in that case
is to keep the layering rule, lifecycle, capability-discovery,
error-taxonomy, and safety-policy guidance language-neutral, and
to route the agent to the public C ABI as the authoritative
surface that any wrapper will eventually call. The skill does
*not* author wrappers in any language and does *not* claim that
NVIDIA ships official non-C bindings unless that has been
verified at the time the agent answers.

## When to load this skill

Load this skill when the user is doing **hands-on DOCA Flow CT
work on a BlueField or ConnectX host with DOCA already installed
AND a working doca-flow setup already in place**, in any
language. Concretely:

- Attaching a `doca_flow_ct` CT context to an already-up
  `doca-flow` port and starting it under the doca-flow lifecycle.
- Building or modifying CT-aware pipes on top of an existing
  doca-flow pipe configuration so that the dataplane tracks
  connection state per 5-tuple (src IP, dst IP, src port, dst
  port, protocol), plus VRF / VNI for overlay scenarios.
- Choosing aging-timer values and per-CT-entry behaviour against
  the device's advertised aging-timer range.
- Adding NAT-aware actions (SNAT, DNAT, or both) tied to a
  tracked connection, after confirming the device advertises the
  requested NAT variant via the capability surface.
- Checking which CT features and capabilities are available on a
  specific installed DOCA version (concurrent flow ceiling,
  aging-timer range, NAT variant set, overlay encapsulation set).
- Debugging a `DOCA_ERROR_*` returned from a `doca_flow_ct_*`
  call and deciding whether the cause is a layering mistake
  (doca-flow not yet started), a CT-spec mistake, an aging /
  capacity mistake, or an unsupported feature on this hardware.
- Designing or extending non-C bindings (Rust, Go, Python, …)
  that wrap the CT C ABI on top of a doca-flow wrapper — for the
  layering rule, lifecycle, and capability-discovery guidance
  the wrapper has to honor on top of the doca-flow surface.

Do **not** load this skill for:

- General doca-flow questions (port bring-up, stateless pipes,
  match/action with no per-connection state). Use
  [`doca-flow`](../doca-flow/SKILL.md) alone.
- General DOCA orientation, install / build / link questions
  unrelated to CT. Use
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  and [`doca-setup`](../../doca-setup/SKILL.md).
- Linux kernel conntrack questions. CT in this skill is the
  hardware-accelerated DOCA path; kernel conntrack
  (`nf_conntrack`, `iptables -m state`, …) is a different code
  path with different semantics. Route those to upstream Linux
  documentation, not this skill.

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive CT-specific
material lives in two companion files:

- `CAPABILITIES.md` — what CT can express on top of doca-flow on
  this version: the layering rule (doca-flow first, CT on top),
  the 5-tuple match shape, the aging-timer surface, the NAT
  action surface (SNAT, DNAT, both), the overlay-CT surface
  (CT over VXLAN / GENEVE / …), the capability-query surface
  (`doca_flow_ct_cap_*`), the CT-specific error taxonomy mapped
  onto the cross-library `DOCA_ERROR_*` set, the observability
  surface (per-CT-entry counters and per-connection state
  transitions), the path-selection rule that decides when CT is
  the right artifact at all (vs `doca-flow` alone vs Linux
  kernel conntrack), and the safety policy that gates aging-
  table sizing and NAT-translation conflicts.
- `TASKS.md` — step-by-step workflows for the six in-scope CT
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`.
  Plus a `Deferred task verbs` block that points install / deploy
  / rollback questions at the right next skill.

The skill assumes a host where DOCA is already installed at the
standard location, doca-flow is already brought up against the
target port, and the user has root access to bring up devices.
It does not cover installing DOCA, bringing up the doca-flow
port, or designing the underlying stateless pipe layout — those
paths go through [`doca-setup`](../../doca-setup/SKILL.md) and
[`doca-flow`](../doca-flow/SKILL.md) respectively.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA Flow CT application source code, in any
  language.** This includes C / C++ files (`.c`, `.cpp`, `.h`),
  Rust crates, Go packages, Python modules, or wrapper code for
  any other language. The CT API surface evolves between
  releases and code written from documentation prose cannot be
  verified without compiling it against the live library on a
  real install. The verified CT source code is the shipped C
  samples at `/opt/mellanox/doca/samples/doca_flow_ct/`; the
  agent's job is to route the user to those files and prescribe
  a minimum-diff modification on them via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the CT-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **A specific firewall rule set, NAT policy, or connection-
  tracking algorithm.** This library *tracks* connections and
  *applies* the NAT translations the user asks for; it does
  *not* define a policy. Policy design (which connections to
  allow, which subnets to NAT to which public IPs, how long is
  the right aging timer for the user's workload) is a
  domain-specific question — route it to the user's own
  networking / security expertise, not to invented defaults.
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, `setup.py`, `go.mod`, …) parked inside the skill.
  The agent constructs the build manifest *in the user's project
  directory* against the user's installed DOCA, where
  `pkg-config --modversion doca-flow-ct` (alongside
  `pkg-config --modversion doca-flow`) is the source of truth —
  not from a template pinned to a specific release inside this
  skill.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (CT on top of an existing doca-flow setup, not
   stateless steering and not kernel conntrack).
2. **For the layering rule, CT capability matrix, 5-tuple match
   schema, aging-timer surface, NAT action surface, overlay-CT
   surface, capability-query surface, CT error taxonomy,
   observability, and safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-flow`](../doca-flow/SKILL.md) for every concern that is
owned by the underlying stateless layer (port bring-up, basic
pipe spec, validate-before-commit, counters),
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "CT-specific guidance".

## Related skills

- [`doca-flow`](../doca-flow/SKILL.md) — the **base library** that
  this skill EXTENDS. doca-flow-ct does not replace doca-flow; it
  attaches a CT context to an already-up doca-flow port and wraps
  doca-flow pipes with CT semantics. The agent should ALWAYS load
  doca-flow alongside doca-flow-ct, because every CT workflow
  starts from a working doca-flow setup. Port bring-up, basic
  pipe construction, the validate-before-commit rule, and the
  Flow counter / inspector surface all live in doca-flow and are
  not re-explained here.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The CT
  public guide URL slug is `DOCA-Flow-Connection-Tracking`. Always
  available alongside this skill; this skill expects to be able
  to defer documentation-finding and install-layout questions
  there instead of duplicating them.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the *I have no install yet* path with
  the public NGC DOCA container (`nvcr.io/nvidia/doca/doca`) as
  the universal Stage-1 fallback for any user without DOCA. This
  skill assumes its preconditions are satisfied.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule and adds the CT-specific
  *doca-flow-ct rides the doca-flow version* overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  Core-context lifecycle, the cross-library `DOCA_ERROR_*`
  taxonomy, and the program-side debug order. This skill layers
  CT specifics on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). CT-specific debug (CT context started
  before doca-flow port up, CT entry table full, NAT-translation
  conflict, aging-timer out of range) overlays on top of that
  ladder.
