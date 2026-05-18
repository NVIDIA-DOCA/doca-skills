---
name: doca-flow
description: NVIDIA DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counter and trace inspection, version compatibility, and debugging DOCA_ERROR_* failures from the Flow API.
kind: library
---

# DOCA Flow

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
  `Deferred task verbs` block that points install/deploy/rollback questions
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
