# DOCA NGauge — Tasks

**Where to start:** The verbs that carry real workflow content
are `## configure`, `## run`, `## test`, and `## debug`. The
other two substantive verbs (`build`, `modify`) carry routing
stubs because the documented NGauge binary is shipped, not a
source artifact the user compiles or patches. The `## test`
verb is an iterative loop, not a one-shot pass — see the
eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent
through the six task verbs every artifact in this bundle
exposes (`configure / build / modify / run / test / debug`),
then explicitly defers task verbs that do not belong here, and
ends with a Command appendix that honors the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

For NGauge, the verbs that carry real workflow content are
`configure`, `run`, `test`, and `debug`. The other two verbs
*exist as anchors* because the agent's task-verb contract is
uniform across libraries, services, and tools — and each one
carries a meaningful **routing stub** that names where the
user's question really belongs.

## configure

NGauge's *configuration* is the invocation on each side: there
is no separate config file, no daemon, no env knob the public
guide documents as required (DOCA-wide env vars like
`DOCA_LOG_LEVEL` still apply, but they are owned by
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability),
not by NGauge). What the agent has to *configure* is the
three-axis decision documented in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
and it has to do that decision *on both sides*.

Steps the agent should walk the user through, in order:

1. **Confirm DOCA is installed on both sides and the
   documented NGauge binary is present.** If not, route to
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   for the detection chain and
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   for the install / upgrade path (or
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path on a user without
   hardware). Do not propose alternative tools when the
   binary is absent; on an install too old to ship NGauge the
   right move is to upgrade.
2. **Confirm the DOCA version matches on both sides.** Run
   `pkg-config --modversion doca-common` and `doca_caps
   --version` on the server host *and* the client host, and
   surface any disagreement per
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
   A measurement run with mismatched versions is in the
   version-layer of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   before it has produced a single number.
3. **Axis 1 — pick the target transport.** Per the
   target-transport table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   commit explicitly to which DOCA transport NGauge will
   drive: raw ethernet (preconditions in
   [`doca-eth CAPABILITIES.md ## Safety policy`](../../libs/doca-eth/CAPABILITIES.md#safety-policy)),
   RDMA (preconditions in
   [`doca-rdma CAPABILITIES.md ## Safety policy`](../../libs/doca-rdma/CAPABILITIES.md#safety-policy)),
   or whichever other transport the public DOCA NGauge guide
   enumerates on the installed version. Confirm the chosen
   transport against the public guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools);
   if `--help` on the installed binary does not list it, it
   is not available on this install regardless of what the
   prose says.
4. **Axis 2 — pick the workload shape.** One-way (client →
   server) vs round-trip vs fan-in vs fan-out (class shape per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes);
   the exact identifiers come from the public guide and
   `--help` on the installed binary). Commit to the message /
   buffer sizing, the batching / queue depth, and the core /
   NUMA placement on each side. Re-cross-check against the
   per-platform support matrix in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility);
   not every shape is documented on every BlueField
   generation.
5. **Axis 3 — pick the measurement axis.** Throughput vs
   latency vs op-rate vs loss per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   Quote back to the user *why* you picked the axis —
   *"throughput because the user asked about bandwidth"*,
   *"latency because the user asked about per-op tail
   timing"* — so the user can challenge the framing if it
   does not match intent. The axes are not interchangeable
   and the agent must name the axis whenever quoting the
   resulting number.
6. **Plan the device target on each side.** The server side
   binds a DOCA device on its host; the client side binds a
   DOCA device on its host. Confirm both devices are visible
   to DOCA per
   [`doca-caps ## run`](../doca-caps/TASKS.md#run) and that
   the port-state preconditions documented for the chosen
   transport (per
   [`doca-eth CAPABILITIES.md ## Safety policy`](../../libs/doca-eth/CAPABILITIES.md#safety-policy)
   or
   [`doca-rdma CAPABILITIES.md ## Safety policy`](../../libs/doca-rdma/CAPABILITIES.md#safety-policy))
   are met *before* the binary is invoked. A failure here
   surfaces as the device-binding layer of
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
7. **Surface the lab-vs-production safety rule.** Per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   NGauge will saturate the path under test by design; the
   agent must confirm a non-production segment before
   recommending the run.

For the canonical DOCA universal lifecycle that underlies the
transport libraries NGauge drives on each side, see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
This skill is concerned with the *operator*-side configuration
of the NGauge invocation, not the program-side lifecycle of
the transport libraries.

## build

The documented NGauge binary and its server-side counterpart
are **shipped pre-built** as part of every DOCA install that
includes the NGauge tooling subpackage on the platforms the
public guide lists. There is no source tree the external user
is expected to compile, no build flags, no `meson` or `make`
workflow for NGauge itself.

Routing for nearby "build" questions:

- *"The binary isn't there — do I need to build it?"* → no.
  Route to
  [`doca-setup ## install`](../../doca-setup/TASKS.md#install).
  The fix is to install (or re-install) DOCA at a version
  that ships NGauge per the public guide on the installed
  version, or use the public NGC DOCA container per
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  at an equivalent version.
- *"I want to build my own network-measurement program
  against DOCA library X."* → not an NGauge question. Route
  to
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the cross-library build pattern and the matching
  `libs/<library>` skill (e.g.
  [`doca-eth ## build`](../../libs/doca-eth/TASKS.md#build),
  [`doca-rdma ## build`](../../libs/doca-rdma/TASKS.md#build))
  for the library-specific build overlay. NGauge is the
  shipped harness; the user's bespoke harness is a different
  artifact.
- *"I want to extend NGauge with a new transport / shape /
  measurement axis."* → out of scope here; this skill is for
  external operators consuming the shipped NGauge, not for
  contributors extending it.

The `## What this skill deliberately does not ship` block in
[`SKILL.md`](SKILL.md) explicitly forbids adding a build
recipe or wrappers for NGauge; revisit that policy before
changing this section.

## modify

**Do not modify the shipped NGauge binary.** It is an
NVIDIA-shipped CLI; there is no documented public way to
change its behavior, output format, transport set, or
measurement-axis surface, and none should be invented.

What the agent *does* modify, every time, is the **NGauge
invocation** — the flags on each side, the chosen transport,
the workload shape, the measurement axis, the duration /
iteration count, the core / NUMA placement. That is the
configuration loop in [`## configure`](#configure) above and
the iteration loop in [`## test`](#test) below; treat *modify
the invocation, not the binary* as the operating mode.

Routing for nearby "modify" questions:

- *"The output format is inconvenient — can I change it?"* →
  the documented surfaces are stdout on each side plus
  whatever structured / file output the installed version
  exposes per
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).
  If those are insufficient, the right answer is *"write a
  parser against the documented output on your installed
  version"* — not a binary patch — and even that scripting
  is out of scope per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).
- *"Can I patch NGauge to add transport / shape X?"* → out of
  scope for external users; this skill is for consumers of
  the shipped tool, not contributors to it.
- *"I need a *different measurement* than NGauge reports."* →
  re-examine axis 3 (measurement axis) in
  [`## configure`](#configure) first; the documented axes
  cover throughput, latency, op-rate, and loss. If the
  question is genuinely outside NGauge's surface (e.g.
  application-level end-to-end timing including post-receive
  user-space work), route to
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  and the matching `libs/<library>` skill — the user's own
  program is the right place to measure application-level
  end-to-end. If the question is library-level rather than
  network-level, route to
  [`doca-bench ## run`](../doca-bench/TASKS.md#run).

## run

The two-sided server-then-client smoke-before-bulk flow —
every NGauge session goes through it, no exceptions. The full
invocation surface lives in the public DOCA NGauge guide; this
section names the *shape* of the flow, not the verbatim command
lines (per
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
*"do not invent flags"*).

1. **Confirm the binary, version, and device targets on both
   sides.** Per [`## configure`](#configure) steps 1-2 and 6;
   without this the next five steps will burn the operator's
   time on a configuration that the install or the fabric
   does not support.
2. **Start the server side first.** Per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   the server is the *listener* and must be running before
   the client can measure anything. Use the smallest
   defensible workload-shape / duration the public guide
   documents for the chosen transport (the goal here is *"the
   server is up and bound to the device"*, not a useful
   measurement). Confirm the server printed an echoed
   invocation and is awaiting a client; if it exited, jump
   to [`## debug`](#debug) layer 2.
3. **Start the client side smoke.** Pick the smallest
   defensible workload-shape / duration / iteration count for
   the chosen target transport and measurement axis (the goal
   is *"NGauge can bind the device on the client side, reach
   the server, complete one round of the workload, and emit
   numbers"*, not a usable measurement). A failure here is
   not a measurement-soundness issue; it is one of
   [`## debug`](#debug) layers 2-4.
4. **Read the echoed invocations on both sides.** Per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
   each side prints the configured values at the start; this
   is the user's chance to catch a defaulted value that does
   not match intent (wrong device on either side, wrong
   workload shape, wrong measurement axis, warm-up turned
   off) before the run completes.
5. **Inspect the two-sided summary and reject silently-bad
   runs.** Exit 0 + a number on one side is *not enough* —
   verify the server side corroborates the client side,
   verify the number is in a defensible order of magnitude
   for the transport / fabric, verify warm-up actually
   happened, verify the axis in the summary matches the
   requested axis, verify the MTU / MSS reported on each
   side agrees. If anything looks off, loop back to
   [`## debug`](#debug) before sinking time into a longer
   run.
6. **Plan the bulk / swept run** only after the smoke is
   green. The public guide documents whichever sweep / repeat
   knobs the installed version exposes; the agent's rule for
   sweep planning is *enumerate the swept dimension
   explicitly, estimate the total run time, and confirm the
   operator is OK with the wall-clock cost* before
   committing. Re-confirm the lab-vs-production rule per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).

When recording the run for downstream consumers (the
*baseline* pattern), write down on *both* sides: the DOCA
version, the host platform (host vs BlueField Arm, OS, kernel,
firmware), the exact command line used (NGauge's own echo line
covers this), the device target (PCIe address / IB name /
interface name), and the full unredacted summary plus any
structured output the installed version emits. The downstream
`## test` and `## debug` workflows depend on those five fields
on each side.

## test

NGauge is **a measurement tool**, so its `## test` verb is
about *testing the measurement* — i.e. confirming the numbers
are sound, reproducible, and corroborated on both sides — not
unit-testing the NGauge binary itself.

**`## test` is an iterative loop, not a one-shot pass.** An
NGauge run that completes is not the same as an NGauge run
that produced a defensible number; each iteration tightens
one axis of measurement soundness (warm-up, steady-state,
MTU / MSS, outliers, NUMA / queue-depth, two-sided agreement,
cross-version delta) and loops back to [`## run`](#run).

The eval-loop overlay (rows apply to every NGauge run, not
just one transport × shape × axis):

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Smoke completed; number is far below datasheet headline | Could be cold pipeline, wrong workload shape, MTU mismatch, NUMA mis-placement, or actually-right for this path. Do not assume datasheet first. | Confirm warm-up applied per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy) layer 5; re-check axis 2 (workload shape) in [`## configure`](#configure) step 4; confirm MTU / MSS on both sides; only then question hardware. |
| Throughput number swings > X% across short re-runs | Steady-state not reached; outlier-dominated run | Lengthen the run via the documented duration / iteration knob; re-run; if still volatile, switch to a distribution-reporting axis (latency / op-rate as applicable) to surface where the variance lives. |
| Latency mean looks good; the tail (e.g. 99.99th percentile) is huge | Tail-latency story is the actual answer; the mean is misleading | Quote the distribution / percentile breakdown that the installed version reports, not the mean, per [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability). |
| Client side and server side disagree | Reachability / MTU / loss / version layer, not a measurement-soundness issue | Stop tweaking workload shape; walk [`## debug`](#debug) layers 3-6 in order. |
| Same invocation produces different numbers on two host pairs at the same DOCA version | Fabric / firmware / driver / NUMA delta below DOCA | Walk axis 2 environment (cores / threads / NUMA) and the version layer per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) before blaming NGauge. |
| Same invocation produces different numbers on the same host pair across DOCA versions | This *is* a regression signal — provided both four-tuples are captured | Cross-link the two baselines, name the changed fields, route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) for the version-delta diagnosis. |
| Sweep of a parameter shows a discontinuity | Could be a real performance cliff (queue depth, MTU, congestion threshold) or a measurement artefact at the swept value | Re-run the boundary points without the sweep to confirm; if real, that is the answer the user came for. |
| NGauge reports zero / hung after extended wait | Server-not-running, server-unreachable, or device-binding layer; not a measurement-soundness issue | Stop iterating on the workload shape; jump to [`## debug`](#debug) layers 2-4. |

The agent's rule: every change to the invocation on *either*
side re-opens the loop. Re-running with a tweaked flag on the
client side and quoting the new number without re-checking
warm-up / steady-state / MTU / outliers / two-sided agreement
is exactly the failure mode this loop replaces.

**Baseline-capture rule.** When the goal of the NGauge session
is a baseline (vs an ad-hoc question), the captured artifact
must include the *four-tuple* per
[`CAPABILITIES.md ## Pattern overview`](CAPABILITIES.md#pattern-overview)
pattern 6 — two-sided command lines + DOCA version on both
sides + device target on both sides + as-deployed environment
(firmware, kernel, NUMA, hugepages, MTU on each side) —
alongside the stdout summary on both sides and any structured
output the installed version documents. Without all four, the
baseline cannot be regression-tested later; quoting a number
without the four-tuple is the cross-version regression-hunt
failure mode.

Loop termination: stop iterating once two consecutive runs do
not change the picture — the answer is now *"this is what the
network path delivers on this DOCA version / firmware /
driver / fabric state"*. Escalate cross-version or cross-host
comparisons to
[`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test)
or [`doca-debug ## debug`](../../doca-debug/SKILL.md) with the
captured four-tuples as evidence.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is install-, version-,
firmware-, fabric-, and tuning-specific; pinning one would
mislead operators on a different platform / version. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When NGauge fails to start, fails to reach the server, fails
to produce numbers, or produces numbers that do not look
defensible, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Tool-not-installed.** The documented NGauge binary is
   not under `/opt/mellanox/doca/tools/` on the side the
   agent tried it from. Confirm the installed DOCA version
   per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   on both sides and the public DOCA NGauge guide's
   *"available since"* statement per
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   If the version is too old, route to
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install);
   do not propose a wrapper.
2. **Server-not-running.** The client side cannot find the
   server side. Confirm the server side was started first,
   that it is still running (the process is alive on that
   host), that it is bound to the device / interface the
   client is pointed at, and that it printed an echoed
   invocation indicating it is awaiting a client. If the
   server exited, re-walk [`## run`](#run) step 2 with the
   smallest defensible workload-shape; if it exited with a
   device-binding error, jump to layer 4.
3. **Server-unreachable.** Both sides are running but the
   client cannot reach the server. Confirm L2 / L3
   reachability on the chosen transport — `ip -j link show`
   on both sides for MTU and link state per
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug),
   `devlink dev show` on both sides for port state, plus a
   layer-appropriate reachability probe (e.g. `ping` for an
   IP-routed ethernet path, `ibping` / `ucmatose` for an
   RDMA-CM path). Confirm any firewall / VLAN / VXLAN /
   representor wiring between the two sides is consistent
   with the chosen transport. Do not change the NGauge
   invocation until reachability is proven.
4. **Device-binding.** One side runs, reaches the other, but
   cannot bind the DOCA device. Confirm the device is
   visible to DOCA at all via
   [`doca-caps ## run`](../doca-caps/TASKS.md#run); confirm
   the driver stack is loaded
   ([`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   layer *Driver*); confirm the chosen NUMA / core layout
   matches the device's actual NUMA node; confirm the
   transport-specific preconditions per
   [`doca-eth CAPABILITIES.md ## Safety policy`](../../libs/doca-eth/CAPABILITIES.md#safety-policy)
   or
   [`doca-rdma CAPABILITIES.md ## Safety policy`](../../libs/doca-rdma/CAPABILITIES.md#safety-policy)
   for the chosen transport.
5. **Measurement-soundness.** The run completes on both
   sides and reports numbers, but the numbers are unsound.
   Walk the four sub-layers per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 5 — warm-up applied? steady-state reached? MTU /
   MSS agreement on both sides? distribution reported
   alongside the single number? — before quoting any number.
6. **Version.** Cross-cutting partial-install / mixed-version
   on either side or across the two sides. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end on both hosts; the common NGauge-specific
   symptom is a server-side and client-side that came from
   different DOCA trains.
7. **Cross-cutting.** Cause is below DOCA. Hand off to
   [`doca-debug ## debug`](../../doca-debug/SKILL.md) for
   the cross-cutting debug ladder and
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug)
   for the env-side layers (driver / firmware / hugepages /
   NUMA / fabric).

In every case: **quote what NGauge reported on each side.**
Do not paraphrase the summary, do not reorder fields, do not
"summarize" a distribution into a single number, do not drop
one side's output because the other side's looks more
convenient. NGauge is in the loop precisely to break the
agent out of the inference-from-datasheet trap.

## Deferred task verbs

The four verbs below are not NGauge work and should be routed
out before the agent does any of them under this skill's name.

- **install** ⇒
  [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  (and
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). NGauge is shipped
  by the install on the versions / platforms the public
  guide lists; this skill does not own the install workflow.
- **build a custom network-measurement application** ⇒
  [`doca-programming-guide ## build`](../../doca-programming-guide/TASKS.md#build)
  for the cross-library pattern, plus the matching
  `libs/<library>` skill for the transport-specific build
  details. NGauge is the shipped harness; a bespoke harness
  is a different artifact.
- **library-internal micro-benchmarking** (e.g. *"what
  throughput does DOCA RDMA deliver on this host in
  isolation"*) ⇒ [`doca-bench`](../doca-bench/SKILL.md) is
  the right tool. DOCA Bench measures library micro-perf
  in-process on one host; NGauge measures network-level
  end-to-end across two hosts. Choosing the wrong one is the
  canonical class-confusion failure mode.
- **streaming telemetry / live metrics from a production
  workload** ⇒ not an NGauge feature, and NGauge is
  explicitly a measurement tool per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
  The DOCA Telemetry Service (DTS) is the documented
  telemetry surface; routing belongs in
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

## Command appendix

NGauge-specific invocation classes the verbs above reach for.
Every row is a CLASS — the agent must not invent the binary
name, flag strings, transport identifiers, workload-shape
names, measurement-axis names, or output column names beyond
`--help` on the installed binary and the public DOCA NGauge
guide. The smoke-before-bulk + two-sided symmetry below is
the load-bearing piece; one worked example per class is
shown.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability
   flags; `version-matrix.json` for *"available since"* lookups;
   a future network-measurement-runner / snapshot helper for
   the four-tuple-capturing baseline pattern when it lands per
   [`doca-structured-tools-contract ## Relationship to PR2 executables`](../../doca-structured-tools-contract/SKILL.md#relationship-to-pr2-executables)).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the
   row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Purpose (class) | Invocation (shape) | Owning step | Reads as healthy when … |
| --- | --- | --- | --- |
| Discover the documented flag surface | `--help` on the installed NGauge binary (and the public DOCA NGauge guide via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools) for the long-form documentation) | [`## configure`](#configure) step 1; [`## debug`](#debug) layer 1 | Prints the documented flag inventory the agent uses as the only source of truth for flag names; the public guide is the secondary source. |
| Confirm DOCA version on each side | `pkg-config --modversion doca-common` and `doca_caps --version` on both hosts | [`## configure`](#configure) step 2 | Both hosts report the same DOCA train; any disagreement routes to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2. |
| Stand up the NGauge server side (smoke) | The documented NGauge server invocation for the chosen (target transport × workload shape × measurement axis) — flag names re-confirmed against `--help` on the installed binary | [`## run`](#run) step 2 | The server echoes its invocation, binds the chosen DOCA device, and prints that it is awaiting a client; the process stays alive. |
| Drive the NGauge client side (smoke) | The documented NGauge client invocation against the server endpoint, with the smallest defensible duration / iteration count for the chosen axis | [`## run`](#run) step 3; [`## test`](#test) eval loop | The client echoes its invocation, connects to the server, completes one short round of the workload, and prints a finite measurement; the server-side summary corroborates. |
| Capture a baseline alongside stdout | The documented structured / file output knobs the installed version exposes per [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability) — confirm names against `--help` on the installed binary | [`## test`](#test) baseline-capture rule | The structured file is written, the stdout summary on each side matches it, and the captured four-tuple (two-sided command lines + DOCA version on both sides + device target on both sides + environment) accompanies the file. |
| Sweep a parameter across a planned range | The documented repeat / sweep knobs the installed version exposes; the agent estimates total wall-clock cost on the *measured fabric* before committing | [`## run`](#run) step 6 | The smoke for the boundary values passed first; the sweep completes; the resulting series has no implausible discontinuities that disappear when re-running the boundary point without the sweep. |
| Diagnose server-not-running vs server-unreachable | Read both processes' stdout / stderr; confirm the server is alive on its host; confirm reachability via `ip -j link show <dev>` and a layer-appropriate reachability probe on the chosen transport per [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) | [`## debug`](#debug) layers 2-3 | The server process is alive, the client side has a working route to the server, and the next invocation completes the smoke handshake. |
| Diagnose two-sided disagreement | Compare the server-side summary against the client-side summary line by line; cross-check MTU on `ip link show <dev>` on both sides | [`## debug`](#debug) layer 5 | The two summaries agree within the documented envelope; if they do not, the surface form names the layer (reachability / MTU / loss / version). |

Three cross-cutting rules for this appendix:

- **Never invent the NGauge binary name, a flag, a transport
  identifier, a workload-shape name, a measurement-axis name,
  or an output column name.** `--help` on the installed
  binary and the public DOCA NGauge guide are the joint
  contract; prose-derived names are the most common
  hallucination failure for this skill.
- **Server first, then client. Smoke before bulk.** Every row
  above presumes the server side is alive and the smoke row
  succeeded first; running a sweep or a long client-side
  drive without those is the canonical operator-time-waste
  failure mode.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `doca_caps --list-devs`,
  `dmesg`, `mlxconfig -d <bdf> q`, `numactl --hardware`,
  `ip -j link show <dev>`, `devlink dev show`) live in
  [`doca-debug ## debug`](../../doca-debug/SKILL.md) and
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug);
  this appendix names only NGauge-specific invocation
  classes.

## Cross-cutting

A few rules that apply across every verb in this file,
restated here so they are visible at the point of action and
not buried in [`SKILL.md`](SKILL.md):

- The **public DOCA NGauge guide** plus the installed
  `--help` are the joint source of truth on each side. When
  they disagree (e.g. a flag landed in a release this skill
  was not written against), the *installed* `--help` wins
  for the user's actual run.
- NGauge *does* drive network traffic and *does* allocate
  device resources on both sides; smoke-before-bulk is
  mandatory, and re-running a long sweep "to confirm"
  without the smoke step is exactly the failure mode this
  skill is here to prevent.
- **Quote the four-tuple, not just the number.** Two-sided
  command lines + DOCA version on both sides + device
  targets on both sides + as-deployed environment is the
  minimum unit an NGauge number is meaningful in. The agent
  must surface all four whenever reporting a number to the
  user.
- **NGauge measures the network. DOCA Bench measures the
  library.** When the user's question is library-level,
  route to [`doca-bench`](../doca-bench/SKILL.md); when it is
  network-level, stay here. Recommending NGauge for a
  library-level question (or DOCA Bench for a network-level
  question) is a class-confusion failure mode.
- This skill **assumes a healthy DOCA install on both
  sides** (or the public NGC DOCA container at an equivalent
  version). If the install is in doubt on either side, route
  to
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
  and [`doca-setup`](../../doca-setup/SKILL.md) before
  running anything else here.
