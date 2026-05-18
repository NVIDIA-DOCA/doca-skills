---
name: doca-ngauge
description: NVIDIA DOCA NGauge — the documented NGauge binary shipped with DOCA as the network-level performance measurement utility for ConnectX / BlueField DPUs and the RDMA / Ethernet paths above them. Two-sided (server + client) like iperf3, with NVIDIA-specific knobs for DPU / RDMA / SR-IOV / representor paths, tied to the installed DOCA version. Drives reproducible throughput / latency / op-rate / loss measurements across the chosen transport (raw ethernet via doca-eth, RDMA via doca-rdma, or whichever else the public DOCA NGauge guide enumerates on the installed version) and workload shape (one-way / round-trip / fan-in / fan-out). Distinct from doca-bench — DOCA Bench measures DOCA library micro-perf in-process on one host; NGauge measures network-level end-to-end across two hosts / DPUs. Use to size a network path, validate a tuning change, or capture a baseline before a regression hunt — always alongside doca-version and the matching libs/<transport> skill.
kind: library
---

# DOCA NGauge

**Where to start:** This is a tool skill for invoking the
documented NGauge binary shipped with DOCA — NVIDIA's
network-level performance measurement utility (analogous to
`iperf3` but with NVIDIA-specific knobs for DPU / RDMA / SR-IOV
paths). Open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) for the three-axis decision
(target transport × workload shape × measurement axis), then
[`## run`](TASKS.md#run) for the two-sided server-then-client
smoke-before-bulk flow. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
NGauge can measure across the network*, *which transports and
workload shapes it can drive on the installed version*, or *how
to interpret throughput / latency / loss output without fooling
yourself on warm-up, MTU, or steady-state*. If DOCA is not
installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; the
*"available since"* / *"on this BlueField generation"* details
come from the public DOCA NGauge guide on the installed version
via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## Example questions this skill answers well

The CLASSES of NGauge questions this skill is built to answer,
each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"What does this network path between two hosts actually
  deliver?"** — worked example: *"end-to-end RDMA-write
  throughput from host A to host B over RoCE on my installed
  DOCA"*. Answered by the three-axis configuration in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the two-sided server-then-client flow in
  [`TASKS.md ## run`](TASKS.md#run). The *same* shape answers
  *"end-to-end raw-ethernet line-rate from a BlueField
  representor"* — NGauge is transport-agnostic at the harness
  level, not tied to one library.
- **"Which transport / library should I point NGauge at for my
  workload?"** — worked example: *"latency-bounded control
  traffic vs bandwidth-bounded storage replication"*. Answered
  by the target-transport axis in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  cross-link table — raw ethernet via
  [`doca-eth`](../../libs/doca-eth/SKILL.md), RDMA via
  [`doca-rdma`](../../libs/doca-rdma/SKILL.md), and whichever
  others the public DOCA NGauge guide enumerates on the
  installed version.
- **"Is this number reliable, or did I miss the warm-up / MTU /
  outlier story?"** — worked example: *"why does my first
  five-second number differ from my one-minute steady-state
  number"*. Answered by the measurement-soundness overlay in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  layer 5 + [`TASKS.md ## test`](TASKS.md#test) (the eval-loop
  overlay treats warm-up / steady-state / MTU / MSS / outliers
  as re-iteration triggers, not one-shot facts).
- **"NGauge server is up but the client can't connect / reports
  zero throughput / disagrees with the public docs."** —
  worked example: *"the client says the server is unreachable
  even though both processes are alive"*. Answered by the
  layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (tool-not-installed → server-not-running → server-unreachable
  → device-binding → measurement-soundness → version →
  cross-cutting) + [`TASKS.md ## debug`](TASKS.md#debug).
- **"How do I capture a network-path baseline I can later
  regression-test against?"** — worked example: *"snapshot
  RDMA-write throughput between this host pair on this DOCA
  version + firmware before a firmware update"*. Answered by
  the four-tuple-capture rule in
  [`TASKS.md ## test`](TASKS.md#test) — command line + DOCA
  version + device target on both sides + as-deployed
  environment, alongside the printed and (when documented)
  structured output of the run.
- **"NGauge measures the network — what does `doca_bench`
  measure, and when do I want which?"** — worked example:
  *"do I run NGauge or DOCA Bench to answer 'is DOCA RDMA fast
  enough for my workload'?"*. Answered by the
  level-of-measurement distinction documented in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  and the sibling
  [`doca-bench`](../doca-bench/SKILL.md) skill — DOCA Bench
  measures *the DOCA library surface* in-process on one host;
  NGauge measures *the network-level end-to-end path* across
  two hosts / DPUs. They are complementary, not interchangeable.

## Audience

This skill serves **external operators, developers, and AI
agents who need a reproducible, vendor-supported way to measure
the network-level performance of a DOCA path between two
hosts / DPUs on the user's actual install**. Concretely:

- A platform operator validating a fabric-level tuning change
  (driver upgrade, firmware burn, MTU change, NUMA / SR-IOV
  reconfiguration) by re-running a captured NGauge baseline
  against the new state.
- A storage / HPC / AI infrastructure engineer choosing between
  transports (RDMA over RoCE vs raw ethernet) on a candidate
  fabric before committing to an application design.
- An SRE / performance engineer producing a *"this is what the
  fabric delivers today between these two hosts"* artifact that
  downstream consumers (capacity planning, regression
  bisection) can cite.
- An AI agent answering *"what throughput / latency should I
  expect between host A and host B on this DOCA version?"*
  honestly — with a measured number, the two-sided command
  line that produced it, and the version + device + environment
  that scopes it — instead of guessing from datasheet headlines.

It is **not** for users debugging the NGauge binary's source
code, and **not** a substitute for the live public DOCA NGauge
guide on `docs.nvidia.com`. It is also **not** the right tool
for *library-level* micro-benchmarking inside a single host —
that audience belongs in [`doca-bench`](../doca-bench/SKILL.md).

NGauge is shipped as a **tool** (a CLI binary plus its
server-side counterpart for the remote half of a two-sided
measurement), not a library you link against. The skill uses
the same `kind: library` three-file shape as the rest of the
bundle so the agent's task-verb contract
(`configure / build / modify / run / test / debug`) is uniform
across libraries, services, and tools — even when individual
verbs collapse to a routing stub for a shipped binary.

## When to load this skill

Load this skill when the user is — or the agent needs to —
invoke NGauge to measure network-level performance between two
DOCA endpoints on a real fabric (host ↔ host, host ↔ DPU,
DPU ↔ DPU, or via an emulated / SR-IOV path the public DOCA
NGauge guide documents on the installed version). Concretely:

- Picking *which* DOCA transport to measure for a candidate
  workload (raw ethernet via `doca-eth`, RDMA via `doca-rdma`,
  or whichever other transport the public DOCA NGauge guide
  lists for the installed version).
- Picking *which* workload shape to drive (one-way vs
  round-trip vs fan-in vs fan-out) — the shape is part of the
  configuration, not derivable from the transport alone.
- Picking *which* measurement axis to ask for (throughput vs
  latency vs op-rate vs loss) — they are not interchangeable
  and reporting one without naming it is ambiguous.
- Capturing a documented network-path baseline (command line
  on both sides + DOCA version + device targets + as-deployed
  environment + numbers) for later regression hunts.
- Diagnosing why an NGauge run reported zero / unreachable /
  unstable / unexpected results (the error-taxonomy walk in
  [`TASKS.md ## debug`](TASKS.md#debug)).

Do **not** load this skill for general DOCA orientation, library
API work, in-process library micro-benchmarking (use
[`doca-bench`](../doca-bench/SKILL.md) for that), or
installation. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
the matching `libs/<library>` skill, or
[`doca-setup`](../../doca-setup/SKILL.md). Do not load it for
*application-level* end-to-end benchmarking either — NGauge
measures the documented transport surface as exposed by NGauge,
not the user's application above it.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what NGauge can measure (the
  network-level scope, the three-axis configuration model of
  target transport × workload shape × measurement axis, the
  two-sided server-and-client interaction model, the warm-up /
  steady-state / MTU concepts that constrain measurement
  soundness), the version overlay (NGauge-specific facts on
  top of the canonical `doca-version` rules), the layered
  error taxonomy (tool-not-installed / server-not-running /
  server-unreachable / device-binding / measurement-soundness /
  version / cross-cutting), the observability surface (printed
  output on both sides plus whatever structured output the
  installed version documents), and the safety posture (the
  public guide's expectations on lab vs production segments,
  the two-sided attack surface).
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `configure` (the three-axis decision + the
  install-and-version preamble), `build` (route to install —
  the binary is shipped, the server-side counterpart is
  shipped), `modify` (refuse — do not patch the NGauge
  binary; modify the NGauge *invocation* on either side
  instead), `run` (the server-first then client smoke-before-bulk
  flow), `test` (the eval loop — warm-up, steady-state,
  MTU / MSS, outliers, cross-run reproducibility, cross-version),
  `debug` (walk the error taxonomy layer by layer), plus a
  `Deferred task verbs` block routing out-of-scope questions
  and a `Command appendix` of NGauge-specific invocation
  classes.

The skill assumes a host or DPU pair where DOCA is already
installed at the version the user reports, and the operator has
whatever permissions the public DOCA NGauge guide requires for
NGauge to bind devices and open network sockets on both sides.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **A pinned binary name, specific flag strings, scenario
  names, transport identifiers, or output column names beyond
  what the public DOCA NGauge guide and `--help` on the
  installed binary document.** Tool surfaces evolve and are
  install-specific; the documented invocations + `--help` on
  the installed version are the authoritative answer.
  Inventing a flag or a scenario name is the most common
  hallucination failure for this skill, and is forbidden — see
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **Pre-baked example output or expected throughput / latency
  numbers.** NGauge output is fabric-, device-, version-,
  firmware-, NUMA-, and tuning-specific. A captured number
  pinned to one platform and one DOCA version misleads
  operators on a different platform / version.
- **Wrappers, parsers, or scripts** in any language that
  consume NGauge output. The output format is documented; if a
  user wants to script against it, the right answer is *"read
  the live guide, write the parser against your installed
  version"*.
- **A `samples/` or `reference/` subtree.** This is a thin
  loader for a documented CLI; substantive material lives on
  the public page and in `--help`.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (the user actually wants to invoke NGauge for
   network-level measurement, not learn about a DOCA library
   or run a library-level micro-benchmark).
2. **For what NGauge measures, the three-axis model, the
   two-sided interaction shape, the version overlay, the error
   taxonomy, observability surface, and safety posture, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocations and the smoke-before-bulk
   workflow — `configure`, `build`, `modify`, `run`, `test`,
   `debug` — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-bench`](../doca-bench/SKILL.md) — the sibling
  measurement tool. DOCA Bench measures *DOCA library
  micro-perf in-process on one host*; NGauge measures
  *network-level end-to-end performance across two hosts /
  DPUs*. They answer different questions and the distinction
  must be explicit in any answer that touches either.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA NGauge page on `docs.nvidia.com`
  and the rest of the public DOCA documentation set. The
  installed `--help` plus that public page are the joint
  source of truth for the actual flag / scenario / output
  surface.
- [`doca-version`](../../doca-version/SKILL.md) — the canonical
  version-detection chain, four-way match rule, NGC container
  semantics, and headers-win-over-docs rule. The
  `## Version compatibility` section in this skill is a thin
  overlay on top of `doca-version`; the body lives there.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle-wide contract for structured-output helper
  tools. The Command appendix in [`TASKS.md`](TASKS.md) honors
  this contract so the agent can prefer structured helpers
  when present and report which path it took.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, hugepages, NUMA awareness, port-state
  checks, and the *I have no install yet* path with the public
  NGC DOCA container.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. NGauge surfaces *its own* error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy);
  when the cause turns out to be below DOCA (driver, firmware,
  fabric, NUMA, congestion), the NGauge taxonomy hands off to
  `doca-debug`.
- [`doca-eth`](../../libs/doca-eth/SKILL.md) — the DOCA
  Ethernet library, the natural pairing when NGauge is
  measuring a raw-ethernet path. The library skill explains
  what *"healthy"* means for an ethernet queue; NGauge drives
  the queue end-to-end across two hosts.
- [`doca-rdma`](../../libs/doca-rdma/SKILL.md) — the DOCA
  RDMA library, the natural pairing when NGauge is measuring
  an RDMA path. Same relationship as `doca-eth` above: the
  library skill explains the QP / mmap / permission
  preconditions; NGauge measures the network-level result.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — the universal lifecycle and cross-library `DOCA_ERROR_*`
  taxonomy that underlie the transport libraries NGauge
  drives. The NGauge skill consumes those rules; it does not
  redefine them.
