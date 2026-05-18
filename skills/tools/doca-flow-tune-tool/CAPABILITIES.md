# DOCA Flow Tune Tool — Capabilities

**Where to start:** The Flow Tune Tool is a CLI client that talks
to a colocated Flow Tune Server; the pattern overview below names
the recurring Flow-Tune-class questions. Pick the pattern first,
then drill into the H2 that owns the substance. For the *how* of
executing each pattern, jump to [TASKS.md](TASKS.md). For the
doca-flow API surface that created the pipelines this tool tunes,
see [`doca-flow CAPABILITIES.md`](../../libs/doca-flow/CAPABILITIES.md);
for the CT extension when the pipelines wrap stateful tracking,
see [`doca-flow-ct CAPABILITIES.md`](../../libs/doca-flow-ct/CAPABILITIES.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
the tool reports and tunes*, *the client/server split*, *the
three-axis configuration model*, *what versions it ships in and
the client/server version-match rule*, *the layered error and
observability surfaces*, and *the safety policy that makes any
mutating tuning operation high-stakes because it touches live
dataplane state*. For step-by-step invocations and the
smoke-before-bulk workflow, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every Flow-Tune-Tool question this skill teaches resolves into one
of FIVE patterns. The patterns are CLASSES — they apply across
every DOCA Flow application a Flow Tune Server can be colocated
with, not just one app or one pipeline.

| Flow Tune Tool pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pair tool and server | Confirm this skill is the CLIENT side and that a Flow Tune Server is reachable on the side where the doca-flow application runs | [`## Capabilities and modes`](#capabilities-and-modes) client/server split + [TASKS.md ## configure](TASKS.md#configure) |
| 2. Three-axis configure | Commit to target Flow pipeline × tuning axis × measurement BEFORE any tuning operation; skipping this is the canonical Flow-Tune failure mode | [`## Capabilities and modes`](#capabilities-and-modes) three-axis table + [TASKS.md ## configure](TASKS.md#configure) |
| 3. Connect → list → inspect | Read-only smoke that always runs before any tune; the tool cannot refer to a real pipeline identifier without it | [TASKS.md ## run](TASKS.md#run) connect / list / inspect steps + [`## Safety policy`](#safety-policy) smoke-before-bulk |
| 4. Tune (mutating) only after smoke | Any tuning operation that changes live Flow state is high-stakes; gate it on a clean inspection plus a clean client/server version check | [`## Safety policy`](#safety-policy) high-stakes posture + [TASKS.md ## debug](TASKS.md#debug) layer 4 |
| 5. Diagnose unreachable / mismatched / unsound | Map the symptom (cannot reach server, pipeline missing, version mismatch, measurement noise, cross-cutting) to its layer before any code or config change | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **The Flow Tune Tool is one half of the picture.** The other
  half is the Flow Tune Server colocated with the doca-flow
  application (the sibling
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
  skill owns the server side). An agent that runs the client
  without confirming the server is reachable, or that quotes the
  client's view without saying which server it came from, is
  missing half the evidence.
- **Mutating tuning operations are dataplane-affecting.** Live
  Flow rule placement, resource hints, and hardware-offload mode
  changes can disrupt traffic. The agent must label every
  operation as read-only or state-changing and gate every
  state-changing operation on a clean smoke per
  [`## Safety policy`](#safety-policy).

## Capabilities and modes

The DOCA Flow Tune Tool ships as a CLI binary in the DOCA install,
documented on the public DOCA Flow Tune Tool guide (reached via
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)).
The user's interaction model is *configure the session, connect
the client to a reachable server, list pipelines, inspect one,
optionally apply a tuning operation, read the resulting
measurement*.

### Client/server split

The load-bearing property of Flow Tune is that it is a
**client/server pairing**, not a single binary that talks to the
device directly:

- **This skill is the CLIENT side.** The user invokes the Flow
  Tune Tool from wherever it is convenient (typically the same
  side as the running doca-flow application, but it does not have
  to be on the exact same process). The client takes no
  measurements on its own; everything it reports is what the
  server told it.
- **The SERVER side** is the DOCA Flow Tune Server, brought up
  per the sibling
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
  skill. The server is **colocated with the doca-flow
  application** so it can read live Flow state from the same DOCA
  context the application is using; the application does NOT have
  to be re-linked to expose the server, but the server has to be
  brought up alongside it.
- **The client cannot tune a pipeline the server does not
  expose**, and the server cannot expose a pipeline that
  doca-flow never created. The full chain is `doca-flow app →
  Flow Tune Server → Flow Tune Tool client → operator`; any
  break in that chain is the layered diagnosis ladder in
  [`## Error taxonomy`](#error-taxonomy).

### Three-axis configuration

Every concrete Flow Tune Tool session is configured along three
independent axes. Get any one wrong and the session inspects or
tunes the wrong thing, or measures something the user did not ask
for; the agent's job is to force the explicit decision on each
axis before the tool is invoked.

| Axis | Class shape | Examples (class-level only; quote specific names from `--help` and the public guide, do NOT invent values) | Why a wrong choice fails |
| --- | --- | --- | --- |
| **1. Target Flow pipeline** | WHICH pipeline of the running doca-flow application is being inspected or tuned. Pick exactly one per session — the tool reports and tunes one pipeline at a time. Pipelines map back to pipes the doca-flow program created per [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes) | A specific named basic / hairpin / control / ordered pipe the app created (when CT is in use, a CT-extended pipeline per [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md)); the identifier shape comes from the public guide + `--help`, not from agent memory | Inspecting the wrong pipeline answers a different question; tuning the wrong pipeline can disrupt a dataplane path the user did not intend to touch |
| **2. Tuning axis** | WHAT class of change is being explored — rule placement (where rules live, which steering tier), resource hints (cache / table sizing / aging), or hardware-offload mode (HWS vs SWS vs hybrid where applicable). Pick exactly one per tuning operation; mixing axes per op hides which one moved the measurement | A rule-placement hint that asks the server to re-place a specific subset of rules; a resource-hint change that suggests a different per-pipe sizing target; a hardware-offload-mode change that switches the pipeline between supported steering modes | A tuning operation that mixes axes makes the resulting measurement ambiguous; an axis the server does not expose for this pipeline reads as a precondition failure |
| **3. Measurement** | WHAT is being measured against the chosen axis — rule-install rate (rules / sec the server can program through doca-flow), lookup latency (per-packet time-in-pipe for the chosen pipeline), or hardware-counter delta (per-pipe / per-entry counter movement against a baseline window) | A rule-install-rate question asking how fast the server can apply N rules to the chosen pipeline; a lookup-latency question over a steady traffic profile already present on the device; a hardware-counter-delta question pinned to a defined baseline window | A measurement axis that does not match the tuning axis (e.g. lookup-latency for a rule-install-rate change) hides the effect of the tuning operation; a latency measurement under saturating traffic measures queueing, not lookup |

The three axes interact: a rule-placement change measured by
hardware-counter delta requires a baseline window before and
after; a hardware-offload-mode change measured by lookup latency
requires steady traffic during the measurement. The agent's rule
is to commit to all three axes explicitly — the user's question,
the chosen pipeline, the chosen tuning axis, the chosen
measurement — before any operation runs.

### CT extension

When the doca-flow application uses doca-flow-ct, the Flow Tune
Tool may also surface CT-table state (aging, NAT counters, per-CT
entry hit / miss) and may expose CT-related tuning hints. The
client/server pairing and the three-axis configuration are
unchanged; what changes is the per-pipeline surface the server
exposes. For the CT API behind that surface, route to
[`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md). For the rule
that CT layers on top of doca-flow (and does not replace it), see
[`doca-flow-ct CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow-ct/CAPABILITIES.md#capabilities-and-modes).

The exact, current subcommand inventory, flag names, pipeline
identifier shape, tuning-axis identifiers, and output column names
live in the public guide and in the tool's own `--help` on the
installed version. The skill deliberately does not pin them — see
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The Flow-Tune-Tool-specific overlay** is:

- **Client/server version match is the FIFTH leg of the four-way match for this tool.** The Flow Tune Tool client's `--version`, the Flow Tune Server's reported version per [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md), `pkg-config --modversion doca-flow` (and `pkg-config --modversion doca-flow-ct` when CT is in use) on the side the server runs, and the host package version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure) MUST all agree. A client connected to a server from a different DOCA train can list pipelines, can inspect them, and can produce a tuning measurement that is silently meaningless. When the user reports a pipeline-state field that does not match what the app sees, the FIRST hypothesis is a client/server version mismatch — confirm before assuming the tool or the server is wrong.
- **Confirm the tool is present before assuming availability.** If the user reports the client binary is absent on the side they want to invoke it from, the right answer is to confirm the installed DOCA version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure) and route to [`doca-setup`](../../doca-setup/SKILL.md) for an upgrade or reinstall, not to recommend a wrapper script that simulates the tool from outside.
- **Where it runs:** the client binary runs on the x86 / Arm host that has DOCA installed, *or* on the BlueField Arm side. The server runs on the side colocated with the doca-flow application. The two sides do not have to be the same host; what matters is that the server is reachable from where the client runs, and that the two sides' DOCA versions agree.
- **Output format stability is not contractually frozen.** The documented per-pipeline state fields and tuning-axis identifiers are stable across the recent DOCA train, but agents that need to consume the client's output programmatically should prefer the structured helpers per [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md#schemas) when present, and re-verify the textual layout against the user's installed version when absent.

## Error taxonomy

The Flow Tune Tool's error surface is broader than a single-binary
introspection tool because it depends on a colocated server, on a
running doca-flow application behind that server, and on a version
chain that crosses both sides. The error layers the agent should
distinguish, in escalating order:

1. **Tool-not-installed.** The Flow Tune Tool client binary does
   not exist on the side the user invoked it from. Cause: DOCA is
   not installed on this side, the install does not include the
   Flow Tune Tool subpackage, or the install version pre-dates
   the tool's availability. Routing:
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   and the version-compatibility overlay above.
2. **Server-not-running.** The client is present, the operator
   gave it an endpoint, but the Flow Tune Server is not up on the
   doca-flow side. Cause: the doca-flow application is running
   but the colocated server was never started, the server
   crashed, or the application itself is not running so there is
   nothing to expose. Routing: the sibling
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   skill's `## debug`; if the application itself is down,
   [`doca-flow`](../../libs/doca-flow/SKILL.md) before the server.
3. **Server-unreachable.** The server is up but the client cannot
   reach it. Cause: wrong endpoint (host / interface / port
   mismatch), network reachability problem, firewall, permission
   layer on the side the server runs. The tool's own message is
   ground truth for *what* failed; the env-side fix lives in
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug). The
   wrong move is to keep retrying the same endpoint without
   confirming the server is bound where the client is asking.
4. **Pipeline-not-found.** The client reaches the server, lists
   pipelines, but the pipeline the user asked about is absent.
   Cause: the doca-flow application never created that pipeline,
   the pipeline was destroyed by a previous program-side action,
   or the user is using the wrong pipeline identifier. The agent
   must NOT assume *"no pipeline"* means *"the tool is broken"*
   without checking the program side per
   [`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug).
5. **Wrong-version-with-server.** The client connects, lists
   pipelines, but the per-pipeline output disagrees with what the
   doca-flow application reports — typically because the client,
   the server, and the doca-flow `*.so` came from different DOCA
   installs. This is the Flow-Tune-specific shape of the
   partial-install hazard from
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility);
   routing belongs in
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 plus the overlay in
   [`## Version compatibility`](#version-compatibility) above.
6. **Measurement-unsound.** The session runs to completion and
   produces a measurement, but the measurement does not support
   the user's quoted number. Sub-cases the agent must
   distinguish: the measurement was taken without a baseline
   window (hardware-counter delta cannot be defended without a
   before/after pair); the lookup-latency measurement was taken
   under saturating traffic and measures queueing, not lookup;
   the rule-install-rate measurement was taken across a tuning-
   axis change so the *"rate"* mixes two configurations. The fix
   is to re-run with the soundness rule from
   [`## Safety policy`](#safety-policy) honored — quoting the
   raw aggregate is not the same as defending it.
7. **Cross-cutting.** All layers above are clean, the client
   reaches the server, the version chain agrees, the pipeline is
   present, the measurement is sound — and the tuning still does
   not move the metric the user cares about. The cause is below
   the Flow Tune layer — driver, firmware, BlueField mode,
   hardware path, host CPU governor, NUMA placement — and not a
   Flow Tune knob. Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured client output, the server-side trace, and
   the version chain as evidence; do not loop on tuning hoping
   for a different number.

The Flow Tune Tool client does **not** itself emit `DOCA_ERROR_*`
values to a calling program — those are owned by the
[`doca-flow`](../../libs/doca-flow/SKILL.md) and
[`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) library APIs,
surfaced into the server's messages and from there into the
client's printed output. The client's CLI exit codes and printed
messages are its own narrow surface; the agent maps those into the
layers above before interpreting any underlying program-side
`DOCA_ERROR_*`.

## Observability

The Flow Tune Tool is itself an **observability primitive** for
the Flow side of every doca-flow application a Flow Tune Server
can be colocated with — it is *what other skills point to when the
user's question becomes "what is this Flow pipeline actually
doing right now"*. Specifically:

- [`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug)
  routes to this tool when the user's question crosses the
  *"inspect the live pipeline from outside the program"*
  boundary; the per-pipeline state the tool reports is the
  documented way to produce that evidence without re-instrumenting
  the doca-flow program.
- [`doca-flow-ct TASKS.md ## debug`](../../libs/doca-flow-ct/TASKS.md#debug)
  routes to this tool for the same reason on CT-extended
  pipelines; the per-CT-entry surface the tool reports complements
  the program-side CT capability-query family without requiring a
  code change.
- [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  consumes the captured client output (per-pipeline state plus the
  chosen-tuning-axis measurement) as the *Flow-side* half of the
  cross-cutting debug ladder, paired with the BlueField driver /
  firmware view via
  [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability)
  and (when present) the program-side log surface via
  [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
- The client's own output is the artifact downstream debug
  consumes. Save it (file, paste buffer, conversation artifact)
  alongside the server-side trace per
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md);
  without both sides, the next debug step starts guessing which
  side reported what.

The tool does not emit metrics, traces, or DOCA logs of its own
beyond the printed CLI output and whatever the server forwards to
it. For the program-side observability surface (`DOCA_LOG_LEVEL`,
`--sdk-log-level`, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For env-side counters that bound the measurement (port stats,
hugepage state, NUMA topology), reach for
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).

## Safety policy

The Flow Tune Tool is the **most dataplane-sensitive** tool this
bundle currently teaches an agent to drive directly: a single
mutating tuning operation against the wrong pipeline can disrupt
the live dataplane the doca-flow application is serving.

- **Read-only operations are safe; tuning operations are not.**
  Connect, list, and inspect do not change Flow state and can be
  re-run freely. Any operation that pushes a rule-placement
  change, a resource-hint change, or a hardware-offload-mode
  change to the server DOES change live Flow state, can disrupt
  in-flight traffic, and may surface to the doca-flow program
  side as a counter discontinuity or a temporary lookup miss
  per [`doca-flow CAPABILITIES.md ## Error taxonomy`](../../libs/doca-flow/CAPABILITIES.md#error-taxonomy).
  The agent must say which class an operation belongs to before
  recommending it.
- **Smoke-before-bulk is mandatory.** Before any tuning operation,
  the agent runs the connect → confirm-version → list →
  inspect-one sequence in [`TASKS.md ## test`](TASKS.md#test).
  A tuning operation issued without that sequence is a guess
  against a possibly-healthy pipeline on a possibly-mismatched
  client/server pair — exactly the failure mode this rule
  exists to prevent.
- **Client/server version match is a hard precondition.** A
  tuning operation issued under a client/server version mismatch
  is not just unsupported, it is undefined; the server may
  silently re-interpret the operation. The version check per
  [`## Version compatibility`](#version-compatibility) runs
  before any state-changing operation, every time, not just on
  the first connect.
- **Never retry a tuning operation as a workaround.** If a tuning
  operation does not move the measurement, the cause is in a
  layer below the tool (the chosen axis was wrong, the
  measurement was unsound, the server-side application has a
  precondition the operation does not address, or the cause is
  cross-cutting per [`## Error taxonomy`](#error-taxonomy)
  layer 7). Re-issuing the same tuning operation is the wrong
  move; route to [`TASKS.md ## debug`](TASKS.md#debug) and walk
  the layers instead.
- **Quote what the tool said. Do not paraphrase pipeline state
  or measurement output.** When the user later asks *"did this
  tuning help"*, the correct answer is to point at the lines of
  the inspection / measurement that show the before / after, not
  to summarize them. Paraphrasing Flow-Tune output is how stale
  evidence ends up justifying a state-changing operation against
  a live dataplane.
- **Do not invent flags, subcommand names, tuning-axis
  identifiers, or output columns.** The documented surface is the
  surface; the public DOCA Flow Tune Tool guide plus installed
  `--help` are the joint source of truth. If the user asks for a
  flag, a tuning-axis name, or a column the public guide does
  not list, the safe answer is *"the installed `--help` is the
  source of truth — let me check it there"*, not a guess based
  on generic CLI conventions.

## Public-source pointer

The single canonical public source for the DOCA Flow Tune Tool is
the **DOCA Flow Tune Tool** page on `docs.nvidia.com`, reachable
through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
The companion server-side public source is the **DOCA Flow Tune
Server** page, reached the same way and owned by the sibling
[`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
skill. Do not invent flags, subcommand names, tuning-axis
identifiers, output columns, or pipeline-state field names beyond
what those pages document. For the doca-flow API surface behind
the pipelines being tuned, the source of truth is
[`doca-flow`](../../libs/doca-flow/SKILL.md) plus the public DOCA
Flow guide reached through the same map; for the CT extension,
[`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md).
