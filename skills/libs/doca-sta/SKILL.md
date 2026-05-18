---
name: doca-sta
description: NVIDIA DOCA STA (Storage Transport Acceleration) on BlueField — hardware-offloaded transport layer for NVMe-over-Fabrics (NVMe-oF) initiators and targets, the per-instance `doca_sta` DOCA Core context, the NVMe queue-pair shape (one admin queue plus N I/O queues per NVMe-oF connection), the integration boundary with the user's NVMe stack (SPDK or kernel-nvme keep the NVMe semantics; doca-sta accelerates the transport handshake and per-IO encapsulation/decapsulation), capability discovery via the `doca_sta_cap_*` family for supported transport type (NVMe-over-RDMA vs NVMe-over-TCP), max I/O queue depth, max number of I/O queues, max in-flight IOs per queue, and supported NVMe-oF feature set, the substrate dependency on `doca-rdma` for NVMe-over-RDMA transport and `doca-flow` for steering NVMe traffic to the right queues, the universal DOCA Core context lifecycle, permission preconditions on the underlying `doca_dev`, and debugging `DOCA_ERROR_*` returns from the STA API.
kind: library
---

# DOCA STA (Storage Transport Acceleration)

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on NVMe-over-Fabrics transport work** on
a BlueField-class device with DOCA. Open [`TASKS.md`](TASKS.md) if
the user wants to *do* something (configure / build / modify / run
/ test / debug); open [`CAPABILITIES.md`](CAPABILITIES.md) when the
question is *what can DOCA STA express* on this version. If the
user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user is
asking *"do I still need SPDK or kernel-nvme on top of this?"*, the
answer is yes — doca-sta is the transport layer, not a complete
NVMe stack; the integration boundary lives in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

## Example questions this skill answers well

The CLASSES of DOCA STA questions this skill is built to answer,
each with one worked example. The agent should treat the *class*
as the load-bearing piece — the worked example is a single
instance.

- **"How do I bring up an NVMe-oF initiator that uses the BlueField
  to offload the transport layer?"** — worked example: *"set up an
  NVMe-over-RDMA initiator-side admin queue plus a single I/O
  queue against a remote target, with SPDK still owning the NVMe
  semantics on top"*. Answered by the integration-and-lifecycle
  workflow in [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  integration-boundary table.
- **"Which transport type fits my NVMe-oF deployment — RDMA or
  TCP?"** — worked example: *"my data center is RoCE end-to-end;
  is NVMe-over-RDMA available on this BlueField, or do I have to
  fall back to NVMe-over-TCP?"*. Answered by the
  capability-query rule (`doca_sta_cap_*` against a
  `doca_devinfo`) in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the discovery step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How deep can I size my I/O queues, and how many I/O queues
  per connection?"** — worked example: *"I want 16 I/O queues at
  depth 1024 each — does this device support that?"*. Answered by
  the queue-sizing capability surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the queue-sizing step in
  [`TASKS.md ## configure`](TASKS.md#configure) which gates on
  the matching `doca_sta_cap_*` query.
- **"Which other DOCA libraries do I need alongside doca-sta?"** —
  worked example: *"do I need doca-rdma directly, or does doca-sta
  hide it from me?"*. Answered by the substrate-library rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the env-prep checklist in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1, which
  routes the steering side to
  [`doca-flow`](../../doca-flow/SKILL.md) and the RDMA substrate
  to [`doca-rdma`](../../doca-rdma/SKILL.md).
- **"Is this STA capability available on my installed DOCA?"** —
  worked example: *"is NVMe-over-TCP transport supported on this
  BlueField + DOCA version?"*. Answered by the version-and-device
  overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md) and adds the
  STA-specific cap-query rule (`pkg-config --modversion doca-sta`
  is the build-time anchor; the runtime cap-query is the truth).
- **"What does this `DOCA_ERROR_*` from a STA call mean and which
  layer caused it?"** — worked example: *"`DOCA_ERROR_IO_FAILED`
  on a submitted NVMe read I/O against a target I can ping"*.
  Answered by the STA overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).

## Audience

This skill serves **external developers building NVMe-over-Fabrics
applications that consume DOCA STA on BlueField** — i.e., users
whose code calls `doca_sta_*` (directly in C/C++, or through
FFI/bindings from another language) to offload the transport layer
of an NVMe-oF initiator or target onto the BlueField hardware.
Typical consumers run an SPDK-based NVMe-oF stack (initiator or
target) on the BlueField Arm cores or on the host, with doca-sta
plugged in as the transport provider; some deployments instead
front the kernel `nvme` stack with doca-sta. The skill is *not*
for NVIDIA developers contributing to DOCA STA itself.

**Language scope.** DOCA STA ships as a C library with
`pkg-config` module name `doca-sta`. The shipped samples are
written in C. C and C++ consumers are the canonical case; the
worked examples in `TASKS.md` assume that path. Other-language
consumers (Rust, Go, Python, …) consume the same `*.so` through
FFI or language-specific bindings; the skill's contribution in
that case is to keep the integration-boundary, lifecycle,
capability-discovery, queue-pair shape, substrate-dependency,
and error-taxonomy guidance language-neutral, and to route the
agent to the public C ABI as the authoritative surface that any
wrapper will eventually call.

## When to load this skill

Load this skill when the user is doing hands-on DOCA STA work,
in any language. Concretely:

- Initializing a `doca_sta` instance on a `doca_dev` opened
  against a BlueField PF / SF and configuring the NVMe-oF
  transport before `doca_ctx_start()`.
- Establishing one or more NVMe-oF connections (admin queue plus
  N I/O queues per connection) on the initiator side, or
  accepting them on the target side, with the user's higher-
  level NVMe stack (SPDK or kernel-nvme) owning the NVMe
  protocol semantics on top.
- Reading or setting STA properties via the `doca_sta_set_*`
  family and querying device capability via `doca_sta_cap_*`
  (transport type support, max I/O queue depth, max number of
  I/O queues, max in-flight IOs per queue, NVMe-oF feature set
  presence).
- Picking between **NVMe-over-RDMA** (which lands on the
  `doca-rdma` substrate) and **NVMe-over-TCP** as the transport,
  based on what the device cap-query reports and what the
  fabric supports.
- Wiring DOCA Flow rules so that NVMe-oF traffic actually
  reaches the STA-managed queues — the steering boundary is
  `doca-flow`, not `doca-sta`.
- Debugging a `DOCA_ERROR_*` returned from a STA call (lifecycle
  vs. capability vs. transport-layer I/O failure vs.
  driver-below) and the per-queue events on the DOCA Core
  progress engine.
- Designing or extending non-C bindings (Rust, Go, Python, …)
  that wrap the DOCA STA C ABI — for the lifecycle, queue-pair,
  cap-query, and substrate-dependency rules the wrapper must
  honor.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, raw RDMA data movement (use
[`doca-rdma`](../../doca-rdma/SKILL.md)), raw packet I/O on
Ethernet queues (use [`doca-eth`](../../doca-eth/SKILL.md)),
flow-rule programming (use [`doca-flow`](../../doca-flow/SKILL.md)),
or NVMe protocol-stack development above the transport layer
(SPDK or kernel-nvme own that, not this skill). For DOCA
documentation orientation, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive STA-specific
material lives in two companion files:

- `CAPABILITIES.md` — what DOCA STA can express on this
  version: the integration boundary with SPDK / kernel-nvme,
  the NVMe queue-pair shape (admin queue + I/O queues), the
  transport-type taxonomy (NVMe-over-RDMA vs NVMe-over-TCP),
  the capability-query surface (`doca_sta_cap_*`), the STA
  error taxonomy (mapped onto the cross-library `DOCA_ERROR_*`
  set), the observability surface (per-queue progress engine
  events, capability snapshots), and the safety policy that
  gates substrate-library, permission, and steering
  preconditions.
- `TASKS.md` — step-by-step workflows for the six in-scope
  STA verbs: `configure`, `build`, `modify`, `run`, `test`,
  `debug`. Plus a `Deferred task verbs` block that points
  out-of-scope questions at the right next skill, and a
  `Command appendix` of the recurring commands the agent
  reaches for.

The skill assumes a BlueField (with DOCA installed at the
standard location) plus an NVMe-oF peer (target if the user is
building an initiator, initiator if the user is building a
target) reachable on the fabric. It does not cover installing
DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md). It does not cover
SPDK installation or NVMe protocol semantics — the SPDK or
kernel-nvme integration point is named, but the NVMe stack
itself is owned by the upstream project.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA STA application source code, in any
  language.** The verified STA source code is the shipped C
  samples at `/opt/mellanox/doca/samples/doca_sta/<name>/`.
  The agent's job is to route the user to those files and
  prescribe a minimum-diff modification on them via the
  universal modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the STA-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Pre-written SPDK or kernel-nvme integration glue.** SPDK
  and the kernel `nvme` stack are upstream projects with their
  own integration patterns; this skill names the boundary
  (where doca-sta plugs in as the transport provider) but
  does not ship the glue itself.
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, …) parked inside the skill. The agent
  constructs the build manifest *in the user's project
  directory* against the user's installed DOCA, where
  `pkg-config --modversion doca-sta` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree,
  even one labeled "reference", is misleading: users will
  read it as buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope.
2. **For the STA capability matrix, integration boundary,
   queue-pair shape, transport-type taxonomy, capability-query
   rules, error taxonomy, observability, and safety policy,
   see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify,
   run, test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules,
[`doca-rdma`](../../doca-rdma/SKILL.md) for the RDMA substrate
that NVMe-over-RDMA transport lands on,
[`doca-flow`](../../doca-flow/SKILL.md) for the steering rules
that direct NVMe traffic to STA-managed queues, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "STA-specific
guidance".

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The
  STA URL slug is `DOCA-STA`.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, BlueField mode checks, and the
  permission / group-membership requirements for opening a
  `doca_dev`. This skill assumes its preconditions are
  satisfied.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  only the STA-specific overlay (transport-type availability
  windows, NVMe-oF feature-set device-conditional support).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library:
  the canonical `pkg-config` + meson build pattern, the
  universal modify-a-shipped-sample first-app workflow, the
  universal lifecycle, the cross-library `DOCA_ERROR_*`
  taxonomy, and the program-side debug order. This skill
  layers STA specifics on top.
- [`doca-rdma`](../../doca-rdma/SKILL.md) — the RDMA substrate
  that NVMe-over-RDMA transport lands on. STA hides most of
  the RDMA queue-pair details from the consumer, but the user
  still needs `doca-rdma` linked in and the device's RDMA
  capabilities discoverable for the NVMe-over-RDMA path to
  work.
- [`doca-eth`](../../doca-eth/SKILL.md) — the queue-pair
  shape that STA's per-connection queue model echoes. Reach
  here if the user is asking general questions about how
  DOCA exposes queue-pairs that don't have an STA-specific
  answer.
- [`doca-flow`](../../doca-flow/SKILL.md) — the steering
  surface that decides which NVMe-oF packets land on which
  STA-managed queue. DOCA STA does *not* program steering
  itself; an NVMe-oF target whose connections never come up
  is often a missing or wrong Flow rule, not a STA bug.
- [`doca-debug`](../../doca-debug/SKILL.md) — the
  cross-cutting debug ladder (install / version / build /
  link / runtime / program / driver). STA-specific debug
  (transport-type mismatches, queue-depth oversize,
  IO-failed transport errors) overlays on top of that
  ladder.
