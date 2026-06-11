---
name: doca-flow
description: >
  Use this skill when the user is doing hands-on DOCA Flow programming
  on a BlueField DPU or ConnectX NIC — defining match/action pipes,
  configuring ports / representors, validating a pipe before hardware
  programming, reading flow counters and traces, picking the right
  Flow version against an installed DOCA, or debugging DOCA_ERROR_*
  failures from the Flow API. Trigger even when the user does not
  explicitly mention "DOCA Flow" or "pipe" — typical implicit phrasings
  include "packets aren't reaching my representor", "rule isn't
  matching on the BF", "PMD reports init failed", "match/action drop
  on egress", "how do I steer this 5-tuple to a queue", "ConnectX
  hairpin routing on Linux", or any flow-steering / packet-classifier
  question where DOCA is installed. Refuse and route elsewhere for
  questions about non-Flow pipelines (DPDK rte_flow without DOCA,
  kernel TC offload, OVS), BFB bring-up, or DPU OS install — those
  belong to other skills.
metadata:
  kind: library
compatibility: >
  Requires DOCA SDK installed at /opt/mellanox/doca on Linux (Ubuntu
  22.04/24.04 or RHEL/SLES) with a BlueField DPU or ConnectX NIC
  attached. Reads the user's local install via `pkg-config doca-flow`
  and inspects /opt/mellanox/doca/{lib,include,samples,applications}.
---

# DOCA Flow

## Non-negotiable: the deliverable uses DOCA Flow, not kernel tc/iptables

When this skill is in scope, the user is asking for **DOCA Flow**. The
program you produce **must link `libdoca_flow` and call the
`doca_flow_*` API** — bring up a port, create a pipe
(`doca_flow_pipe_create`), add the match/action entry
(`doca_flow_pipe_add_entry`), and prove it in hardware by reading the
entry counters (`doca_flow_query_entry`). Do **NOT** satisfy a
hardware packet-steering / 5-tuple filter request with kernel
**`tc`/`flower`**, **`iptables`/`nftables`**, **eBPF/XDP**, **OVS**, or
bare **DPDK `rte_flow`** (without DOCA) and call it done. Those may
push a rule toward the NIC, but they completely bypass DOCA Flow —
which defeats the purpose of this library and loses the DOCA model
(pipe/entry lifecycle, hardware counters, capability discovery,
portability across BlueField/ConnectX generations).

"`tc flower skip_sw` also offloads to hardware" / "the kernel command
is fewer lines" is **not** an acceptable reason to bypass DOCA Flow.
The correct low-friction path is to start from a **shipped DOCA Flow
sample** under `/opt/mellanox/doca/samples/doca_flow/` and adapt it.

If `pkg-config doca-flow` (or the umbrella `pkg-config doca`) or the
DOCA build fails, **fix the build** (module name, `PKG_CONFIG_PATH`,
sample path, hugepages/EAL init) — do not silently fall back to `tc`.
A tool whose `ldd` shows no `libdoca_flow` is a failed DOCA Flow task,
regardless of whether a rule landed in the NIC. Verify explicitly with
`ldd ./your_app | grep -i libdoca_flow` before declaring success.

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on Flow work** on a BlueField / ConnectX
host. Open [`TASKS.md`](TASKS.md) if the user wants to *do* something
(configure / build / modify / run / test / debug); open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what can
Flow express* on this version. If the user has not installed DOCA
yet, route to [`doca-setup`](../../doca-setup/SKILL.md) first.

## Example questions this skill answers well

The CLASSES of Flow questions this skill is built to answer, each
with one worked example. The agent should treat the *class* as the
load-bearing piece — the worked example is a single instance.

- **"How do I bring up a Flow port on a representor?"** — worked
  example: *"port-init order for `pf0vf0` on the DPU"*. Answered by
  the port/representor verb sequence in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  steering-mode selection.
- **"How do I express *<match X, do Y>* as a Flow pipe?"** — worked
  example: *"match outer IPv4 dst, push VLAN, fwd to rep"*. Answered
  by the match/action schema in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the pipe-creation workflow in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"Will this pipe spec actually program the HW, or will commit
  fail?"** — worked example: *"my pipe validates but commit returns
  `DOCA_ERROR_NOT_SUPPORTED`"*. Answered by the validate-before-commit
  rule in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the validate→commit step in
  [`TASKS.md ## test`](TASKS.md#test).
- **"How do I read Flow counters / traces to investigate observed
  traffic?"** — worked example: *"per-pipe hit count and per-entry
  counter for entry N"*. Answered by the counter/observability surface
  in [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
  + the inspector workflow in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Is this Flow feature available on my installed DOCA
  version?"** — worked example: *"is the symmetric-RSS hash mode in
  2.6.0?"*. Answered by the version-compatibility section in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the version-discovery rule (`pkg-config --modversion doca-flow`)
  pinned in [`TASKS.md ## configure`](TASKS.md#configure).
- **"What does this `DOCA_ERROR_*` from a Flow call mean and which
  layer caused it?"** — worked example: *"`DOCA_ERROR_BAD_STATE` from
  `doca_flow_port_start`"*. Answered by the Flow overlay on the
  cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).
- **"My Flow port won't start at all — `Failed to get hws cap` /
  `dest action ROOT … err -121`."** — worked example: *"every
  `doca_flow_port_start` fails the HWS capability query on my
  BlueField host, in both vnf and switch mode"*. This is the
  **device-placement** signature, not a pipe bug: the steering plane
  is unavailable to the opened function (typically host-side against a
  `SEPARATED_HOST` / NIC-mode BlueField, where Flow belongs on the DPU
  Arm). Answered by the device-placement bullet in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the placement row in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the placement gate in [`TASKS.md ## configure`](TASKS.md#configure)
  step 2 and Step 0 of [`TASKS.md ## debug`](TASKS.md#debug).
- **"How do I add hardware-accelerated stateful 5-tuple connection
  tracking (with aging timers and NAT-aware actions) on top of my
  existing doca-flow setup?"** — worked example: *"I have a
  working doca-flow port and pipes; I want to add connection
  tracking that tracks TCP / UDP connections, ages out idle entries
  after 30s, and applies SNAT on outbound traffic"*. Answered by
  the CT layering rule, the `doca_flow_ct_cap_is_dev_supported`
  device-support query, the global CT module model
  (`doca_flow_ct_init` before port start), 5-tuple match shape,
  CT-specific error overlay (`_BAD_STATE` on layering violations,
  `_FULL` on table saturation, `_INVALID_VALUE` on NAT conflicts),
  and CT version pairing (CT ships inside `doca-flow`) in
  [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct) +
  the configure / build / modify / run / test / debug overlay in
  [`TASKS.md ## flow-ct`](TASKS.md#flow-ct).

## Audience

This skill serves **external developers building applications that consume
the DOCA Flow library** — i.e., users whose code calls
`doca_flow_*` (directly in C/C++, or through FFI/bindings from another
language) to program packet steering on a BlueField DPU or ConnectX NIC.
It is *not* for NVIDIA developers contributing to DOCA Flow itself, or
for users asking about the library's internals.

**Language scope.** DOCA Flow ships as a C library with `pkg-config`
module name `doca-flow`. The shipped samples that this skill points the
agent at are written in C (NVIDIA's choice). C and C++ consumers are
the canonical case and the worked examples in `TASKS.md` assume that
path. Other-language consumers (Rust, Go, Python, …) consume the same
`*.so` library through FFI or language-specific bindings; the skill's
contribution in that case is to keep the API-surface, lifecycle,
capability-discovery, error-taxonomy, and safety-policy guidance
language-neutral, and to route the agent to the public C ABI as the
authoritative surface that any wrapper will eventually call. The skill
does *not* author wrappers in any language and does *not* claim that
NVIDIA ships official non-C bindings unless that has been verified at
the time the agent answers.

## When to load this skill

Load this skill when the user is doing **hands-on DOCA Flow work on a
BlueField or ConnectX host with DOCA already installed**, in any
language. Concretely:

- Bringing up a DOCA Flow port and selecting devices or representors.
- Creating a pipe, defining match criteria and actions, programming entries.
- Validating a pipe specification *before* programming the hardware.
- Reading pipe counters or traces to investigate observed traffic behavior.
- Checking which Flow features and API symbols are available on a specific
  installed DOCA version.
- Debugging a `DOCA_ERROR_*` returned from a Flow API call and deciding
  whether the cause is a configuration mistake, a missing prerequisite, or
  an unsupported feature on this hardware or steering mode.
- Designing or extending non-C bindings (Rust, Go, Python, …) that wrap
  the Flow C ABI — for the API-surface, lifecycle, and version-compat
  guidance the wrapper has to honor.
- Adding hardware-accelerated stateful 5-tuple connection
  tracking, aging-timer-driven entry eviction, or NAT-aware
  actions (SNAT / DNAT / combined) on top of an existing
  doca-flow port via the connection-tracking module of
  **`doca-flow`** (header `doca_flow_ct.h`).
  The CT layering rule (CT extends doca-flow; it does not
  replace it), the `doca_flow_ct_cap_is_dev_supported`
  device-support query, the global CT module model
  (`doca_flow_ct_init` before port start), the 5-tuple match
  shape (with VRF / VNI for overlays), the CT-specific error
  overlay, and the configure / build / modify / run / test /
  debug workflow live in
  [`CAPABILITIES.md ## flow-ct`](CAPABILITIES.md#flow-ct) and
  [`TASKS.md ## flow-ct`](TASKS.md#flow-ct) under this same
  skill.

Do **not** load this skill for general DOCA orientation, "where do I find
docs", install-layout, or non-Flow library questions. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed to
pick the right next file. The substantive Flow-specific material lives in
two companion files:

- `CAPABILITIES.md` — what Flow can express on this version: HW versus
  software steering, supported match and action kinds, Flow API symbol
  availability per DOCA version, the DOCA error taxonomy with Flow
  overlays, the Flow observability surface (counters, pipe statistics),
  and the safety policy that gates HW programming.
- `TASKS.md` — step-by-step workflows for the six in-scope Flow verbs:
  `configure`, `build`, `modify`, `run`, `test`, `debug`. Plus a
  `## flow-ct` rollback overlay (stateful-CT teardown with
  `doca_flow_pipe_dump` snapshot) and a `## rollback` overlay for
  non-CT pipeline-edit-class changes (VLAN push, encap, decap,
  modify-header, mirror, sample, NAT-without-CT, hairpin attach) —
  both invoked from the deploy-loop bridge on non-green smoke. Plus
  a `Deferred task verbs` block that points install/deploy questions
  at the right next skill.

The skill assumes a host where DOCA is already installed at the standard
location and the user has root access to bring up devices. It does not
cover installing DOCA — that path goes through the knowledge-map skill.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates bundle. To
keep the boundary clean, it deliberately does not contain — and pull
requests should not add:

- **Pre-written DOCA Flow application source code, in any language.**
  This includes C / C++ files (`.c`, `.cpp`, `.h`), Rust crates, Go
  packages, Python modules, or wrapper code for any other language.
  The Flow API surface evolves between releases and code written from
  documentation prose cannot be verified without compiling it against
  the live library on a real install. The verified Flow source code is
  the shipped C sample at `/opt/mellanox/doca/samples/doca_flow/<name>/`;
  the agent's job is to route the user to that file and prescribe a
  minimum-diff modification on it via the universal modify-a-sample
  workflow in [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the Flow-specific overrides in
  [`TASKS.md ## build`](TASKS.md#build) "first Flow app" block — for
  C/C++ users — or to route non-C users to the public C ABI surface
  that their bindings will call, *not* to author the wrapper.
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, `setup.py`, `go.mod`, …) parked inside the skill. The
  agent constructs the build manifest *in the user's project directory*
  against the user's installed DOCA, where `pkg-config --modversion
  doca-flow` is the source of truth — not from a template pinned to a
  specific release inside this skill.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any kind. A
  mock or incomplete artifact in this skill's tree, even one labeled
  "reference", is misleading: users will read it as buildable.

If a contributor ever wants to add a *minimal install smoke-test
program* (e.g. a 30-line "did my install link cleanly" check that calls
only the most stable lifecycle entry points, in any language), that is
a different artifact with a different purpose — it belongs under
`doca-setup/` or `doca-programming-guide/` or the contributor's own
out-of-tree project, not here.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in scope.
2. **For the full pipe specification schema, the Flow capability matrix,
   the Flow error taxonomy, observability, and safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run, test,
   debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other and to
`doca-public-knowledge-map` whenever the right answer is "look it up in
the public docs or the installed package layout" rather than "Flow-specific
guidance".

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) — the
  routing table for every public DOCA documentation source and the on-disk
  layout of an installed DOCA package. Always available alongside this
  skill; this skill expects to be able to defer documentation-finding and
  install-layout questions there instead of duplicating them.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation, install
  verification, and the *I have no install yet* path with the public
  NGC DOCA container (`nvcr.io/nvidia/doca/doca`) as the universal
  Stage-1 fallback for any user on macOS, Windows, or Linux without
  DOCA. This skill assumes its preconditions are satisfied.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow (which Flow extends with
  Flow-specific overrides in this skill's `## build` "first Flow app"
  block), the universal lifecycle, the cross-library `DOCA_ERROR_*`
  taxonomy, and the program-side debug order. This skill layers Flow
  specifics on top.
