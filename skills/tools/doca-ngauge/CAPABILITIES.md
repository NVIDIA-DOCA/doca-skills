# DOCA NGauge — Capabilities

**Where to start:** NGauge is a two-sided CLI — a server side
plus a client side that measures the path between them. The
pattern overview below names the recurring NGauge-class
questions. Pick the pattern first, then drill into the H2 that
owns the substance. For the *how* of executing each pattern,
jump to [TASKS.md](TASKS.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents
*what NGauge is*, *what it can measure across the network*,
*what versions it ships in*, *what its layered error and
observability surfaces look like*, and *the safety posture* the
public guide stakes out (notably that NGauge is a measurement
tool, not a production data plane, and that its server side
exposes a network socket and a bound DOCA device on whichever
side the agent runs it on). For step-by-step invocations and
the smoke-before-bulk workflow, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every NGauge-class question this skill teaches resolves into
one of SIX patterns. The patterns are CLASSES — they apply
across every DOCA transport NGauge can drive, not just one
fabric.

| NGauge pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick the target transport | Network-level — NGauge measures over whichever transports the public DOCA NGauge guide documents on the installed version (typically a raw-ethernet path via the [`doca-eth`](../../libs/doca-eth/SKILL.md) library and an RDMA path via the [`doca-rdma`](../../libs/doca-rdma/SKILL.md) library; other transports may be documented on the user's version). Picking the target transport is axis 1 of the three-axis configuration. | [`## Capabilities and modes`](#capabilities-and-modes) target-transport table + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 2. Pick the workload shape | The workload shape is axis 2 — one-way vs round-trip vs fan-in vs fan-out, with the data sizing, batching, queue-depth, and (for multi-process / multi-core runs) the affinity choices that go with it. | [`## Capabilities and modes`](#capabilities-and-modes) workload-shape rules + [TASKS.md ## configure](TASKS.md#configure) step 4 |
| 3. Pick the measurement axis | Throughput vs latency vs op-rate vs loss is axis 3. The class of question the user is asking decides which axis is load-bearing; reporting one without naming it is ambiguous. | [`## Capabilities and modes`](#capabilities-and-modes) measurement-axis table + [TASKS.md ## configure](TASKS.md#configure) step 5 |
| 4. Smoke-before-bulk | Confirm NGauge can stand up its server side, that the client side reaches the server, and that *one* short measurement round-trips with a finite result before kicking off a long or swept run. | [TASKS.md ## run](TASKS.md#run) smoke flow + [TASKS.md ## test](TASKS.md#test) eval-loop overlay |
| 5. Diagnose an NGauge failure | Walk the layered error taxonomy in [`## Error taxonomy`](#error-taxonomy) — tool-not-installed / server-not-running / server-unreachable / device-binding / measurement-soundness / version / cross-cutting — instead of guessing at causes from a single error line. | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret an NGauge number | An NGauge number is only meaningful with the (two-sided command lines + DOCA version + device targets on both sides + as-deployed environment) four-tuple. Quoting one without the other three is the cross-version regression-hunt failure mode. | [`## Observability`](#observability) + [TASKS.md ## test](TASKS.md#test) baseline-capture rule |

Three cross-cutting rules that apply to *every* pattern above:

- **NGauge is two-sided. The server side and the client side
  are both NGauge.** They communicate over the network the
  user is measuring (and, depending on the transport, over an
  out-of-band channel for control). Recommendations that
  describe NGauge as a one-sided CLI are categorically wrong;
  an agent that only walks the client side has shipped half a
  workflow.
- **NGauge measures the network, not the library API.** This
  is the load-bearing distinction from
  [`doca-bench`](../doca-bench/SKILL.md): DOCA Bench drives a
  DOCA library inside one host and reports the library's
  surface throughput / latency; NGauge drives a documented
  transport across two endpoints and reports what the
  *network path* delivers. An agent that confuses the two
  surfaces will recommend the wrong tool for the user's
  question.
- **Warm-up, MTU, and steady-state are part of the
  measurement, not part of the bug.** Network paths exhibit
  cold-cache / cold-queue / slow-start effects on first
  iterations; MTU / MSS mismatches silently shrink throughput
  and inflate per-packet overhead; short runs report
  transient numbers. Treating any of these as
  "the bench is broken" instead of "the measurement is not
  yet sound" is the canonical NGauge-class failure mode.

## Capabilities and modes

The documented NGauge binary is shipped by DOCA as part of the
public DOCA tools surface. There is no daemon — the agent
*runs* the binary on each side, in a server / client pair, for
the duration of the measurement. The two halves communicate
over the network being measured (and, depending on the
transport, over an additional out-of-band control channel
documented in the public guide). The entire interaction model
is *invoke the server on one side, invoke the client on the
other side pointing at the server, read the output on each
side*.

The agent must not invent the exact binary name, the exact
flag surface, the exact transport identifiers, or the exact
output column names. The public DOCA NGauge guide on
`docs.nvidia.com` (reachable via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
plus `--help` on the installed binary are the joint source of
truth for those.

**Three-axis configuration model — the load-bearing concept.**
Every NGauge invocation commits to a point in this space;
omitting any axis produces an ambiguous result.

| Axis | What it picks | Why the agent must name it |
| --- | --- | --- |
| 1. Target transport | Which DOCA transport is the unit under test on this network path. Class shape: a raw-ethernet path (driven by [`doca-eth`](../../libs/doca-eth/SKILL.md) on each side), an RDMA path (driven by [`doca-rdma`](../../libs/doca-rdma/SKILL.md) on each side), or whichever other transport the public DOCA NGauge guide documents on the installed version. The agent enumerates what the installed version exposes from the public guide + `--help`. | The network-level number is only interpretable in the context of the transport. *"NGauge throughput"* without naming whether it is raw-ethernet or RDMA is ambiguous; the two transports have wildly different per-op cost profiles and per-MTU behaviors. |
| 2. Workload shape | The *shape* of the traffic NGauge drives — one-way (client → server only) vs round-trip (client ↔ server with a synchronization at each iteration) vs fan-in (multiple clients into one server) vs fan-out (one client to multiple servers), with the sizing (message / buffer size), batching / queue depth, and core / NUMA affinity choices that go with it. | Two runs against the *same* transport can report wildly different numbers if the workload shape differs; *"RDMA throughput"* without naming whether it is one-way or round-trip, the message sizing, and the queue depth is ambiguous. |
| 3. Measurement axis | Throughput vs latency vs op-rate vs loss. Each axis is a different question about the same run and is reported differently by NGauge; the modes are *not interchangeable* and a single number reported without naming the axis is ambiguous. | Throughput and op-rate optimize for pipeline occupancy; latency requires per-op timing and typically a serialized workload; loss is a counter, not a rate. Comparing a throughput number to a latency number is the cross-axis apples-to-oranges failure. |

**Two-sided interaction model — the load-bearing operating
shape.** Per the public DOCA NGauge guide on the installed
version:

| Side | Role | Class shape of what it does |
| --- | --- | --- |
| Server | The *listener* on the network being measured. Started first; stays up for the duration of the measurement. Binds a DOCA device on its host (per the chosen transport's preconditions documented in the matching `libs/<transport>` skill) and waits for a client. | Without the server running, the client cannot measure anything; *server-not-running* is the most common first-contact failure mode (see [`## Error taxonomy`](#error-taxonomy) layer 2). |
| Client | The *driver* of the workload. Started second; connects to the server, drives the configured workload shape for the configured duration / iteration count, prints the measurement on completion. | The client side is where the three-axis configuration is committed and where the measurement result lives. A failed connect is the *server-unreachable* layer (see [`## Error taxonomy`](#error-taxonomy) layer 3), not a measurement failure. |

**Cross-library scope at the transport layer — what NGauge can
drive.** The public DOCA NGauge guide enumerates the supported
transports explicitly; the agent treats that enumeration as
the authoritative list for the installed version. The
transport set on any given install is the intersection of
*"documented by NGauge on this version"* and *"installed and
exposed by this DOCA package selection"* — the agent must
confirm against the public guide, not assume.

**Distinction from doca-bench — load-bearing.** DOCA Bench and
NGauge are both measurement tools shipped by DOCA, and the
agent must never collapse them:

- DOCA Bench measures **DOCA library micro-performance
  in-process on one host** — it drives a DOCA library through
  a pipeline of documented operations and reports per-library
  throughput / latency / op-rate. The unit under test is the
  library surface on the local device. See
  [`doca-bench`](../doca-bench/SKILL.md).
- NGauge measures **network-level end-to-end performance
  across two hosts / DPUs** — it drives a documented transport
  between a server and a client across the network and
  reports what the path delivers. The unit under test is the
  network path between two DOCA-side endpoints.

They are *complementary*: the agent often answers the question
*"is DOCA RDMA fast enough for my workload"* by running DOCA
Bench on each side to confirm the library is delivering its
documented surface throughput locally, then running NGauge
between the two sides to confirm the network path delivers
what the libraries can hand it. Choosing one without the other
narrows the answer.

**Affinity / multi-core scaling.** Where applicable per the
public guide, NGauge accepts CPU-affinity and queue-depth
inputs on each side; their exact spellings are install-version-
specific and live in `--help`. The number of cores / threads /
queue depth and their NUMA placement is part of axis 2
(workload shape) for any number a later run is going to be
compared against. Re-confirm against `--help`; do not invent.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The NGauge-specific overlay** is:

- **NGauge ships with DOCA on the platforms where it is
  documented.** The public DOCA NGauge guide reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  is the authoritative source for *"available since which
  DOCA version"* and *"on which BlueField generation / host
  platform"*. Do not quote a hardcoded *"available since"*
  version from memory; route the agent to the public guide on
  the installed version per
  [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test).
- **Both sides must come from the same DOCA train.** NGauge
  is two-sided; mixing an NGauge binary from one DOCA version
  on the server with one from another DOCA version on the
  client is unsupported and falls into the partial-install
  layer of
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
  The agent's rule: confirm `pkg-config --modversion
  doca-common` and `doca_caps --version` on *both* hosts, and
  surface any disagreement before recommending a run.
- **Per-platform support matrix.** Whether a given transport
  works on a given BlueField generation / host platform is
  documented per the public DOCA NGauge guide and the matching
  per-transport library guide
  ([`doca-eth`](../../libs/doca-eth/SKILL.md),
  [`doca-rdma`](../../libs/doca-rdma/SKILL.md)). Do not copy
  a transport-availability claim from one BlueField generation
  to another; re-read the public matrix on the installed
  version.
- **Output format stability is not contractually frozen.**
  Within a DOCA train the stdout layout and any structured
  output documented on the installed version are the
  authoritative surfaces; across major versions the layout can
  shift. Agents that need to consume NGauge output
  programmatically should prefer the structured helper per
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md#schemas)
  when present and re-verify the textual layout against the
  user's installed version when absent.

## Error taxonomy

NGauge's error surface is **broader than a single-sided tool**
because it has two halves, and either half can fail
independently. The error layers the agent should distinguish,
in escalating order:

1. **Tool-not-installed.** The documented NGauge binary is
   not present under
   `/opt/mellanox/doca/tools/` on the side the agent tried to
   invoke it from. Cause: DOCA is not installed on this host,
   the install does not include the NGauge tooling
   subpackage, or the install version pre-dates the tool's
   availability on this platform. Routing:
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   to confirm the installed version, then
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   for the install / upgrade path, or
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path on a user without
   hardware.
2. **Server-not-running.** The NGauge binary is installed and
   the client side is invoked, but the server side was never
   started, has exited, or is not bound to the device /
   interface the client expects. Cause: the agent forgot
   step 1 of [`TASKS.md ## run`](TASKS.md#run) (start the
   server first, *then* the client), the server process
   crashed and the agent did not notice, or the server is
   running on a different device than the client is pointed
   at. Routing: re-walk
   [`TASKS.md ## run`](TASKS.md#run) steps 1-3; confirm the
   server is up and listening on the side the agent intends
   before troubleshooting the client.
3. **Server-unreachable.** Both sides are running but the
   client cannot reach the server. Cause: a firewall, a
   routing / VLAN / VXLAN misconfiguration, an MTU mismatch
   on a path that requires a specific MTU, a representor /
   SR-IOV path that is not wired through to the peer, or the
   server is bound to a device that is up at the driver layer
   but is not actually carrying packets to the client side.
   Routing: confirm L2 / L3 reachability with cross-cutting
   env-side checks per
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   and the env-side observability primitives there; do not
   change the NGauge invocation until reachability is proven.
4. **Device-binding layer.** Either side runs but cannot bind
   the DOCA device the chosen transport needs. Cause: the
   device PCIe address / IB name / representor name does not
   exist on this host, the underlying driver stack
   (`mlx5_core`, IB stack, etc.) is not loaded, the BlueField
   mode is incompatible with the requested transport, or the
   process lacks the documented privileges (sudo / `mlnx`
   group). Routing: first verify the device is visible to DOCA
   at all via
   [`doca-caps ## run`](../doca-caps/TASKS.md#run) and
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test); for
   the per-library precondition matrix (port up, mmap
   permissions, RX-type support) see
   [`doca-eth CAPABILITIES.md ## Safety policy`](../../libs/doca-eth/CAPABILITIES.md#safety-policy)
   or
   [`doca-rdma CAPABILITIES.md ## Safety policy`](../../libs/doca-rdma/CAPABILITIES.md#safety-policy)
   depending on the chosen transport.
5. **Measurement-soundness.** Both sides connect and the run
   completes with finite numbers, but the numbers are unsound
   and must not be quoted as-is. Four sub-layers, all
   documented by the public DOCA NGauge guide and the broader
   networking-measurement folklore:
    - *Warm-up not applied / too short.* Reported numbers
      include cold-cache / cold-queue / TCP-slow-start /
      RDMA-CM-handshake iterations and are lower than
      steady-state. Fix: confirm the warm-up configuration
      matches the public guide's documented default and is
      appropriate for the chosen transport / axis.
    - *Steady-state not reached.* Run duration / iteration
      count is too small for the path to settle, and the
      reported number is in the transient region. Fix:
      lengthen the run via the documented duration /
      iteration-count knobs and re-iterate per
      [`TASKS.md ## test`](TASKS.md#test).
    - *MTU / MSS mismatch.* The two sides disagree on the
      effective frame / segment size; the path silently
      fragments or refuses, depressing throughput and
      inflating per-op cost. Fix: confirm `ip link` MTU on
      both sides matches the chosen transport's
      configured frame size, and re-run; this is one of the
      most common silent-bad-measurement causes on
      raw-ethernet paths.
    - *Outliers / distribution unreported.* A single
      throughput average hides a heavy tail; a latency mean
      hides a 99.99-percentile spike that the consumer
      workload will actually feel. Fix: report the
      distribution (whatever the installed version
      documents as the distribution / percentile surface)
      alongside any single number.
6. **Version.** Cross-cutting partial-install / mixed-version
   layer per
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
   Symptoms: NGauge binary version disagrees with `doca_caps
   --version` or `pkg-config --modversion doca-common`,
   server-side and client-side versions disagree across the
   two hosts, the public guide version the operator is
   reading disagrees with the install. Routing: walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   on both sides before any further investigation.
7. **Cross-cutting.** The cause is below DOCA — driver /
   firmware / fabric / NUMA / congestion / OS. Symptoms that
   do not fit layers 1-6 (e.g. throughput numbers that fall
   sharply only on one NUMA node, latency spikes correlated
   with kernel-thread scheduling, loss spikes correlated with
   competing traffic on the same fabric, throughput tied to
   firmware version independent of DOCA version). Routing:
   hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
   the NGauge surface has reached its limit.

NGauge does not *itself* participate in the cross-library
`DOCA_ERROR_*` taxonomy that DOCA libraries return through
their C API; NGauge is a CLI driving libraries on each side,
not a library call. For the cross-library `DOCA_ERROR_*`
taxonomy and the program-side debug order, see
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).

## Observability

NGauge's observability surface is **the measurement output on
both sides**, plus any structured / file output the installed
version documents. Specifically:

- **Stdout summary on the client side.** The client side
  prints the aggregate result of the measurement when the run
  completes — the documented examples include duration,
  iteration count, the throughput / latency / op-rate / loss
  numbers per the chosen measurement axis, and (depending on
  the axis) a distribution or per-bucket breakdown. The exact
  textual layout is install-version-specific; re-verify
  against the user's run rather than against memory.
- **Stdout summary on the server side.** The server side
  prints what it observed of the same run — typically the
  *server-side counterpart* of the measurement axis the
  client requested. The two summaries together are the
  measurement; an agent that quotes only one half is missing
  half the evidence and a healthy run shows both sides
  agreeing within the expected envelope.
- **Optional structured / file output.** Per the public DOCA
  NGauge guide on the installed version, NGauge may document
  a structured (e.g. CSV, JSON) output path for machine
  consumption. When the installed version exposes one, the
  agent's rule for any baseline that will be re-read by a
  later run is *capture the structured output, not just
  stdout*. Confirm against `--help`.
- **Reported invocation echo.** Per the public guide,
  NGauge typically echoes the configured values at the start
  of the run so a captured log self-documents the (command
  line + effective defaults) the numbers belong to. The agent
  must preserve this echo on *both* sides in any captured
  baseline; it is the *"what command produced this number on
  each side"* leg of the four-tuple in
  [`## Pattern overview`](#pattern-overview) pattern 6.
- **Two-sided correlation.** The single most useful
  observability signal NGauge produces is *"did the two
  sides agree"*. When the client side reports a number that
  the server side does not corroborate, the agent must not
  paper over the discrepancy — it is the surface form of a
  reachability / MTU / loss / version mismatch and routes to
  the relevant layer of [`## Error taxonomy`](#error-taxonomy).

For the cross-cutting env-side observability primitives
(`devlink dev show`, `ip -j link show`, `ethtool`,
`mlxconfig`, `dmesg`) see
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
For the program-side observability surface (DOCA log levels,
`DOCA_LOG_LEVEL`, `--sdk-log-level`) see
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability).

## Safety policy

NGauge is a measurement tool that drives network traffic
between two hosts / DPUs and binds DOCA devices on both
sides. The safety rules:

- **Lab / non-production segments only.** NGauge will saturate
  the network path under test by design; running it on a
  fabric that also carries production traffic is the canonical
  noisy-neighbor failure mode. The agent must surface this
  whenever the user proposes running NGauge on a fabric whose
  other traffic is not under the user's control, and must not
  recommend the run without the user explicitly confirming a
  non-production segment is available.
- **Both sides are NGauge.** Recommendations that only walk
  the client side and assume the server side comes up by
  magic are categorically broken — the *server-not-running*
  layer in [`## Error taxonomy`](#error-taxonomy) is the
  failure mode that follows. The agent's rule: name both
  sides explicitly in every walk-through.
- **Smoke-before-bulk; never run a long sweep first.** A
  swept run on the wrong transport, wrong workload shape, or
  wrong measurement axis consumes minutes-to-hours and
  produces unusable data. The agent's rule is the
  [`TASKS.md ## run`](TASKS.md#run) smoke step (trivial
  workload, short duration, single iteration) before any
  sweep or long run.
- **Quote the (two-sided command lines + version + device
  targets + environment) four-tuple, not just the number.**
  An NGauge number quoted without the four-tuple is
  unreplicable and unfalsifiable. This rule applies to every
  output of this skill — the *most common* downstream misuse
  of NGauge is quoting a screenshot from one platform as if
  it described another.
- **Do not invent the binary name, flags, scenario / transport
  identifiers, attribute names, metric names, or output column
  names.** The documented invocations and the installed
  `--help` are the authoritative surface. Prose-derived flags
  are the most common hallucination failure for this skill;
  see the cross-cutting rule in
  [`TASKS.md ## Command appendix`](TASKS.md#command-appendix).
- **Host vs BlueField Arm vs host ↔ DPU placement rule.** Per
  the public guide the binary is the same on every supported
  platform; the *measured* numbers differ because the path
  differs. An agent comparing a host-to-host number to a
  host-to-DPU number without naming where each side ran is
  making the cross-platform apples-to-oranges mistake.

## Public-source pointer

The single canonical public source for the documented NGauge
binary is the **DOCA NGauge** page on `docs.nvidia.com`,
reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
Do not invent the binary name, flags, transport identifiers,
workload-shape names, measurement-axis names, or output column
names beyond what that page documents — and re-verify against
`--help` on the user's installed binary, since the *available*
surface on a given install can be a subset of the *documented*
surface across DOCA versions.
