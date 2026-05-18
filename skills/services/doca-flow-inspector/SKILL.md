---
name: doca-flow-inspector
description: NVIDIA DOCA Flow Inspector Service — long-running container/daemon on BlueField that consumes mirrored flow traffic from a doca-flow (or doca-flow-ct) pipeline and exposes it for hardware-level inspection / debug of what the steering plane is actually doing. Covers the pipeline-side mirror-action contract (the user's pipeline MUST be programmed to mirror traffic to the inspector — the service does NOT capture unmirrored traffic on its own), the container deployment shape on BlueField Arm, inspection-depth modes (per-packet metadata vs per-flow aggregate vs raw sampling), the output destinations (Inspector CLI / JSON export / downstream consumer such as DTS), the smoke-before-bulk discipline for a paired pipeline + inspector setup, the mirror-overhead cost that requires disabling mirror in production once debug is over, and the cross-link to doca-debug as the broader debug toolkit Flow Inspector is one entry in.
kind: library
---

# DOCA Flow Inspector Service

**Where to start:** This skill is for *operating* the DOCA Flow
Inspector Service as a debug tool that pairs with a doca-flow /
doca-flow-ct pipeline the user already has — *not* for linking
against a library. If the user wants to *deploy* the inspector
container and wire their pipeline to mirror traffic to it, open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is Flow Inspector and what inspection depths does
it expose*, start at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA
is not installed on the BlueField yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user has
not stood up a doca-flow pipeline yet, route to
[`doca-flow`](../../libs/doca-flow/SKILL.md) FIRST — Flow
Inspector is meaningful only when there is a pipeline whose
traffic the user wants to mirror into it.

## Example questions this skill answers well

The CLASSES of Flow Inspector questions this skill is built to
answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"My doca-flow pipeline is dropping packets that should match —
  how do I see what the hardware is actually doing?"** — worked
  example: *"I added a match-and-forward entry, but the
  representor sees nothing; counters say zero; I want to mirror
  the traffic into Flow Inspector and see whether the hardware
  even saw the packet shape I think it did."* Answered by the
  mirror-action contract in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the pipeline-side wiring step in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`TASKS.md ## run`](TASKS.md#run).
- **"Where does Flow Inspector run, and how do I deploy the
  container?"** — worked example: *"BlueField-3 in DPU mode, DOCA
  installed, I want the inspector running on the Arm side so it
  can ingest mirrored traffic locally."* Answered by the
  deployment-shape rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the container-launch workflow in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Per-packet view, per-flow aggregate, or raw sample — which
  inspection depth do I pick?"** — worked example: *"I want to
  know whether ONE specific 5-tuple is being seen by the hardware
  vs whether a class of flows is reaching the pipe in expected
  volume."* Answered by the inspection-depth surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the depth-selection step in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"My doca-flow pipeline mirrors to the inspector but the
  inspector still shows nothing — what's wrong?"** — worked
  example: *"container is up, pipeline has a mirror action wired
  to the inspector target, no traffic appears in the inspector
  CLI."* Answered by the layered debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) (mirror-not-wired vs
  inspection-depth-wrong vs sampling-drop) +
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
- **"How do I keep the inspector in production without paying the
  full mirror cost?"** — worked example: *"steady-state telemetry
  on real traffic, not a debug session."* Answered by the
  mirror-overhead rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the production-disable step in
  [`TASKS.md ## modify`](TASKS.md#modify) — the documented answer
  is *"disable the mirror for production, route long-term
  observation to DTS"*, not *"leave the inspector wired all the
  time"*.
- **"Is Flow Inspector the right tool, or do I want tcpdump / DTS
  / DOCA Log instead?"** — worked example: *"my pipeline looks
  fine but I'm not sure whether the bug is in the pipeline or
  upstream."* Answered by the path-selection table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the cross-link to
  [`doca-debug`](../../doca-debug/SKILL.md) for the broader
  symptom-triage ladder.

## Audience

This skill serves **external operators and developers debugging
DOCA Flow / DOCA Flow CT dataplanes on BlueField** — concretely,
people who have a working doca-flow pipeline (or are about to
have one) and need hardware-level visibility into what the
steering plane is actually doing with the packets they're
sending. They want to confirm or refute hypotheses like *"is the
hardware even seeing this 5-tuple"*, *"is my mirror action
actually firing"*, or *"is my CT entry being matched in the
direction I expect"* using a real on-device observation rather
than guessing from documentation.

It is **not** for NVIDIA developers contributing to Flow
Inspector itself, and it is **not** a programming guide for
*building applications on top of* DOCA libraries (that is
`doca-programming-guide` plus the matching `libs/<library>` skill).
Flow Inspector is a **service**, not a library: the user runs a
container on the BlueField and observes what their separately-
programmed doca-flow / doca-flow-ct pipeline mirrors to it; they
do not link against a `libdoca_flow_inspector.so` to write their
own program.

It is also **not** for steady-state production observation. Flow
Inspector is a debug-time tool because every mirrored packet
costs cycles on the device; for long-term in-production
visibility, the documented answer is to route through the DOCA
Telemetry Service (DTS) instead — see the path-selection table
in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

## When to load this skill

Load this skill when the user is doing **hands-on Flow /
Flow CT debug** on a BlueField where DOCA is already installed
and the user either has a doca-flow (or doca-flow-ct) pipeline
in place OR is about to add a mirror action to one so the
inspector can observe its traffic. Concretely:

- Deciding *whether* to deploy Flow Inspector at all (vs
  `tcpdump` on a representor, vs reading per-pipe counters, vs
  routing to DTS for steady-state telemetry).
- Bringing up the Flow Inspector container on the BlueField Arm
  side (the documented deployment shape per the public Container
  Deployment Guide pattern).
- Wiring the user's existing doca-flow / doca-flow-ct pipeline
  to MIRROR traffic to the inspector (the prerequisite the
  inspector cannot do on its own).
- Choosing an inspection depth (per-packet metadata, per-flow
  aggregate, raw packet content sampling) for the user's debug
  question.
- Reading the inspector's output (CLI, JSON export, downstream
  consumer) and matching it against the user's pipeline's intent.
- Debugging *"container is up but the inspector sees nothing"*
  (almost always: the user's pipeline is not actually mirroring;
  see [`TASKS.md ## debug`](TASKS.md#debug)).
- Tearing the mirror down once the debug session is over — the
  inspector adds runtime overhead and stays wired only while
  someone is actively looking at it.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, library-API questions, or production telemetry
collection. For those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), the matching
`libs/<library>` skill, or — for steady-state telemetry — the
DOCA Telemetry Service entry in
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — Flow Inspector's architecture (long-running
  BlueField-side service / container that consumes mirrored
  traffic from a separately-programmed doca-flow pipeline), the
  mirror-action contract between the inspector and the user's
  pipeline, the inspection-depth surface (per-packet vs per-flow
  aggregate vs raw sampling), the output destinations (CLI, JSON
  export, downstream consumer), the deployment shape (container
  on BlueField Arm, Container Deployment Guide pattern), the
  version-compatibility overlay that pairs the inspector with the
  doca-flow / doca-flow-ct version that programmed the mirror,
  the error taxonomy ("container up but no traffic", "wrong
  inspection depth", "mirror rate too high"), the observability
  surface, and the safety policy that gates mirror-overhead in
  production.
- `TASKS.md` — step-by-step workflows for the in-scope Flow
  Inspector verbs: `configure` (BlueField env + container + the
  pipeline-side mirror wiring), `build`, `modify` (adapt the
  documented deploy recipe; switch inspection depth; disable the
  mirror for production), `run` (start the inspector, send a
  known matching packet, observe it in the CLI), `test` (the
  smoke-before-bulk loop), `debug` (layered ladder: container →
  mirror wired → inspection depth → sampling drop), plus a
  `Deferred task verbs` block that routes out-of-scope questions.

The skill assumes a BlueField where DOCA is already installed and
the user has the privileges the public Container Deployment Guide
documents for launching DOCA containers. It does not cover
installing DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md). It does not cover
authoring the underlying doca-flow / doca-flow-ct pipeline either
— that lives in the matching library skill.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or
sample-config bundle. To keep the boundary clean, it deliberately
does not contain — and pull requests should not add:

- **Container image names or tag strings.** The canonical name +
  tag for the Flow Inspector container lives on the public NGC
  catalog page reachable via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
  Quoting a guessed `nvcr.io/...:latest` string is the most
  common hallucination failure for service-shaped skills; the
  agent's job is to route the user to the live NGC catalog page
  for the verified image string, not to ship one in this skill.
- **Pre-baked mirror-action snippets, pipeline source code, or
  ready-to-paste inspector configs.** Mirror actions are
  pipeline-specific (which pipe; which match; which rate-limit);
  inspector configs are deployment-specific (which inspection
  depth; which output destination). The agent's job is to
  prescribe the procedure and the contract between the two, not
  to ship a config the user might run unmodified against
  production traffic.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: operators will read it
  as production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (Flow Inspector debug-time use on top of a separately-
   programmed doca-flow / doca-flow-ct pipeline; not steady-state
   telemetry; not library-internal work).
2. **For Flow Inspector's deployment shape, the mirror-action
   contract, inspection-depth surface, output destinations, the
   version-compatibility overlay, error taxonomy, observability,
   and safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-flow`](../../libs/doca-flow/SKILL.md) — the **base
  library** Flow Inspector is paired with. The mirror action that
  feeds the inspector is programmed *in* the user's doca-flow
  pipeline, not in the inspector itself; without a doca-flow
  pipeline that is set up to mirror traffic, Flow Inspector has
  nothing to observe. The agent should ALWAYS load `doca-flow`
  alongside this skill, because every Flow Inspector workflow
  starts from a working doca-flow setup that someone has decided
  to instrument.
- `doca-flow-ct` — the **CT
  companion** library that Flow Inspector is also commonly used
  to debug. Mirror actions on CT-wrapped pipes carry per-
  connection state plus 5-tuple match information; inspecting
  that surface is one of the highest-value Flow Inspector
  workflows. The same layering rule applies: doca-flow + doca-
  flow-ct must already be programming the dataplane the user
  wants to inspect.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug skill Flow Inspector is one entry in. The 7-layer debug
  ladder there is the broader context; Flow Inspector is the
  Layer 5 (runtime) / Layer 6 (program) inspector tool reached
  for once a doca-flow symptom has been narrowed to *"the
  hardware is not doing what I think it is"*.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule and adds the inspector-
  specific overlay (the inspector container tag is paired with
  the doca-flow / doca-flow-ct version that programmed the
  mirror; mismatches make the inspector's interpretation of the
  mirrored packets unreliable).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table to the public DOCA documentation set,
  including the
  [DOCA Flow Inspector Service Guide](https://docs.nvidia.com/doca/sdk/DOCA-Flow-Inspector-Service-Guide/index.html)
  and the DOCA services index. Verify that the version of the
  guide matches the DOCA install on the BlueField — service
  surfaces evolve, and inspection-depth options can change
  between releases.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation
  and install verification on the BlueField where the inspector
  container will run. This skill assumes its preconditions are
  satisfied (DOCA is installed on the BlueField; the user has
  the privileges the Container Deployment Guide requires).
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA patterns. Flow Inspector is service-shaped not
  library-shaped, so the build / modify / first-app pattern there
  does not apply directly, but the cross-library `DOCA_ERROR_*`
  taxonomy and the layered-debug order remain useful when the
  underlying doca-flow / doca-flow-ct calls that program the
  mirror itself return errors.
