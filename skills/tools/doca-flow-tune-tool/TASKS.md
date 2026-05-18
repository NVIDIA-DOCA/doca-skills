# DOCA Flow Tune Tool — Tasks

**Where to start:** The verbs that carry real workflow content are
`## configure` (the load-bearing three-axis decision plus the
client/server pairing), `## run` (connect → list → inspect → tune),
`## test` (smoke-before-bulk loop with the client/server version
check), and `## debug` (the layered diagnosis ladder). The other
two verbs (`build`, `modify`) are documented routing stubs that
exist because the bundle's verb contract is uniform. The `## test`
verb is the smoke-before-bulk loop, not a one-shot pass — see the
eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), explicitly
defers task verbs that do not belong here, and ends with the
`Command appendix` honoring the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

For the Flow Tune Tool, the verbs that carry real workflow content
are `configure`, `run`, `test`, and `debug`. The other two verbs
*exist as anchors* because the agent's task-verb contract is
uniform across libraries, services, and tools — and each one
carries a meaningful **routing stub** that names where the user's
question really belongs.

## configure

The Flow Tune Tool's `## configure` is the **load-bearing verb**
for this skill: it is where the client/server pairing is named and
where the three-axis decision (target Flow pipeline × tuning axis
× measurement) is made explicit, *before* any flag string is
chosen and *before* the client is invoked. Skipping this verb and
jumping to `## run` is the canonical Flow-Tune failure mode — it
produces a session that inspects or tunes the wrong thing under
unstated assumptions.

The agent walks the user through three configure-time concerns,
in order:

1. **Client/server pairing.** Confirm this skill is the CLIENT
   side and that a Flow Tune Server is reachable on the side
   where the doca-flow application runs. If the user has not
   brought up a server yet, route to the sibling
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   skill FIRST — the tool cannot list or tune anything without a
   reachable server. The full chain is `doca-flow app → Flow
   Tune Server → Flow Tune Tool client → operator`; pin all four
   links before moving on per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   client/server split.
2. **Three-axis decision.**
   - **Axis 1 — target Flow pipeline.** Confirm exactly one
     pipeline of the running doca-flow application is being
     inspected or tuned. If the user names two (*"compare these
     two pipes"*), tell them the tool inspects and tunes one
     pipeline at a time and the agent will run two configured
     sessions in series. For the pipe-level surface this pipeline
     maps back to, route to
     [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes);
     for CT-extended pipelines, also
     [`doca-flow-ct CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow-ct/CAPABILITIES.md#capabilities-and-modes).
   - **Axis 2 — tuning axis.** Name the class of change being
     explored — rule placement, resource hints, or hardware-
     offload mode — class-level (not flag-level). Do **not**
     invent specific tuning-axis identifiers; the public DOCA
     Flow Tune Tool guide via
     [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
     plus the installed `--help` are the joint source of truth.
   - **Axis 3 — measurement.** Rule-install rate vs lookup
     latency vs hardware-counter delta. Each is a different
     question and each may require a different baseline.
     Decide explicitly with the user; the three-axis table in
     [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
     names the symmetry. The agent's job is to pick exactly one
     primary measurement per session.
3. **Client/server version check.** Quote
   `pkg-config --modversion doca-common`,
   `cat /opt/mellanox/doca/applications/VERSION`, the client's
   own `--version`, and the server's reported version per the
   sibling
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   skill; per the Flow-Tune-specific overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
   plus
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility),
   the client/server version match is a hard precondition for any
   tuning operation. Do this once at configure time so the smoke
   in [`## test`](#test) does not re-derive it.

Do not invent configuration values — flag strings, subcommand
names, tuning-axis identifiers, pipeline-identifier syntax — that
the public DOCA Flow Tune Tool guide does not document on the
user's installed version. If the public guide does not document a
knob, it does not exist for this skill's purposes.

## build

The Flow Tune Tool is **shipped pre-built** as part of every DOCA
install that includes the Flow Tune Tool subpackage. There is no
source tree the external user is expected to compile, no build
flags, no `meson` or `make` workflow.

Routing for nearby "build" questions:

- *"The client binary isn't there — do I need to build it?"* →
  no. Route to
  [`doca-setup ## install`](../../doca-setup/TASKS.md#install).
  The fix is to install (or re-install) DOCA with the right
  package profile, or to use the public NGC DOCA container per
  [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install).
- *"I want to build my own client that talks to the Flow Tune
  Server programmatically"* → not a Flow Tune Tool question. The
  documented client surface is the public guide; an alternative
  client is out of scope for this skill. For programmatic access
  to the doca-flow / doca-flow-ct API the server exposes, route
  to [`doca-flow`](../../libs/doca-flow/SKILL.md) /
  [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md).
- *"I want to bring up the Flow Tune Server itself"* → not this
  skill. Route to the sibling
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
  skill; this skill is the client side only.

The `## What this skill deliberately does not ship` block in
[`SKILL.md`](SKILL.md) explicitly forbids adding a build recipe
for the Flow Tune Tool or shipping wrappers around it; revisit
that policy before changing this section.

## modify

**Do not modify the shipped Flow Tune Tool client binary.** It is
an NVIDIA-shipped CLI; there is no documented public way to
change its behavior, output format, or supported tuning-axis
surface, and none should be invented.

Routing for nearby "modify" questions:

- *"The output format is inconvenient — can I change it?"* → no,
  not inside this skill. The documented surface is the surface.
  If the user wants structured output, the right answer is
  *"check whether the installed version exposes one per `--help`,
  otherwise write a parser against the documented format on your
  installed version"* — and even the parser is out of scope per
  [`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).
- *"I need to tune something the tool does not expose for this
  pipeline"* → not a `## modify` question for this skill. The
  right answer is to read the matching library skill's
  capability surface (e.g.
  [`doca-flow ## modify`](../../libs/doca-flow/TASKS.md#modify)
  or
  [`doca-flow-ct ## modify`](../../libs/doca-flow-ct/TASKS.md#modify))
  and, if needed, change what the doca-flow program itself
  creates, then defer the Flow Tune question to a future DOCA
  release if the tool should grow that axis.
- *"Can I patch the tool to add a flag?"* → out of scope for
  external users; this skill is for consumers of the shipped
  client, not contributors to it.

## run

When the configure-time concerns (client/server pairing,
three-axis decision, version check) are committed, the run flow
the agent walks the user through is:

1. **Confirm the client binary is present** on the side the user
   is invoking it from. If absent, route to
   [`## configure`](#configure) above and to
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install).
2. **Connect to the Flow Tune Server.** Point the client at the
   endpoint the sibling
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   skill reports the server is bound to. Capture the connect
   message verbatim — any failure here belongs in
   [`## debug`](#debug) layers 1-3, not in a retry loop.
3. **List the Flow pipelines the server exposes.** This is the
   read-only entry point and the only safe first move after
   connecting. Capture the listing verbatim; it is the
   pipeline-identifier set the inspect step needs. The agent
   must NOT invent pipeline identifiers from the doca-flow
   program's source; the server's listing is the contract.
4. **Inspect the specific pipeline the user is asking about.**
   Use the pipeline identifier from step 3; do not guess one.
   The inspection output is the per-pipeline state surface from
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   and is the evidence the rest of the workflow consumes.
5. **Stop here unless the user has committed to a tuning
   operation.** If the user's question was *"is this pipeline
   behaving as expected"*, step 4 is the answer; do NOT escalate
   to a tuning operation just because the tool exposes one.
6. **Only after steps 2-4 read clean and the three-axis decision
   from [`## configure`](#configure) is committed,** apply the
   chosen tuning operation. Capture the before / after
   measurement per axis 3; the measurement is meaningless without
   a baseline window.
7. **For the exact, current invocation surface — subcommand
   names, flag names, pipeline-identifier shape, tuning-axis
   identifiers, output columns** read `--help` on the installed
   client and the public DOCA Flow Tune Tool guide via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   Do **not** invent any of these; the public guide and `--help`
   are the joint source of truth, see
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).

When recording the session for downstream consumers, write down:
the DOCA version (per
[`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)),
the side the client was run on (host vs BlueField Arm), the side
the server was run on, the chosen target pipeline, the chosen
tuning axis, the chosen measurement, the exact command line, and
the full unredacted client output. The downstream
[`## test`](#test) and [`## debug`](#debug) workflows depend on
all of those.

## test

The Flow Tune Tool's `## test` is **the canonical smoke-before-
bulk loop plus the client/server version check** for any tuning
operation against a live Flow pipeline. *"Test"* in this skill
means *"confirm the session is sound enough to defend the
measurement and to gate any state-changing tuning"*, not
*"unit-test the client"*.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation — a tuning operation, a server restart, a doca-flow
program restart, a driver reload, a BlueField mode change —
re-opens the smoke. Treating it as a one-shot pass is the failure
mode this loop replaces.

The smoke-before-bulk shape:

1. **Connect.** Run the client against the server endpoint per
   [`## run`](#run) step 2. The connect step is also the
   cheapest confirmation that the client and server can talk at
   all.
2. **Confirm client/server version match.** Quote the client's
   `--version`, the server's reported version per
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md),
   and the host-side `pkg-config --modversion doca-flow` (and
   `doca-flow-ct` when CT is in use). All must agree per the
   four-way match in
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
   plus the Flow-Tune-specific overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   Disagreement is a hard fail for any tuning operation — route
   to [`## debug`](#debug) layer 5 before proceeding.
3. **List pipelines.** Confirm the listing includes the pipeline
   identifier the user expected; if it does not, walk
   [`## debug`](#debug) layer 4 (pipeline-not-found) rather than
   guessing an identifier from program source.
4. **Inspect one pipeline.** Pick the pipeline the user is about
   to touch and confirm the per-pipeline state from
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   reads as expected. Quote the state lines; do not paraphrase.
5. **Only after steps 1-4 read clean** may the agent proceed to a
   tuning operation per [`## debug`](#debug) layer 4 routing or
   per the user's explicit go-ahead. If any of 1-4 surfaces a
   finding, the agent walks the debug ladder instead — a tuning
   operation issued before the smoke is clean is a guess against
   a possibly-mismatched or possibly-missing pipeline.

Eval-loop overlay (rows apply to every doca-flow application a
Flow Tune Server can be colocated with, not just one):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → 2 → ## debug | Client cannot reach the server, or the server reports a version that does not match the client; walk the debug ladder, then re-run step 1 | [`## debug`](#debug) layers 2-3, 5 |
| 1 → 2 → 3 → ## debug | List succeeds but the user's expected pipeline is absent; the right answer is the program side, not a retry of list | [`## debug`](#debug) layer 4 |
| 1 → 2 → 3 → 4 → tune → 1 | After a tuning operation, re-run the smoke to confirm the pipeline is still healthy and the measurement reflects the change (and not, say, a server-side restart triggered by the tuning op) | [`## debug`](#debug) layer 4 plus [`## Safety policy`](CAPABILITIES.md#safety-policy) |
| 1 → driver / firmware / mode change → 1 | After a driver reload or BlueField mode change, the per-pipeline view may have changed; re-run step 1 | [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) |
| 1..4 (clean) → save → debug session | Once clean, the inspection + measurement is saved and consumed by the cross-cutting debug ladder | [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) |

The agent's rule: every state-changing action on a Flow pipeline
re-opens the smoke. Saving a stale inspection from before a
mutation is exactly the failure mode this loop is here to prevent.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is install-, version-,
application-, and pipeline-specific; pinning one would mislead
operators on a different platform / version. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When the client cannot reach the server, when a pipeline the user
expected is absent, when a tuning measurement does not move, or
when the per-pipeline state disagrees with what the doca-flow
program reports, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Tool-not-installed.** The client binary does not exist on
   the side the user invoked it from. Confirm DOCA is installed
   (e.g. `pkg-config --modversion doca-common`,
   `cat /opt/mellanox/doca/applications/VERSION`) and that the
   install profile included the Flow Tune Tool subpackage.
   Route to
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   if not.
2. **Server-not-running.** The client is present but the server
   is not up on the doca-flow side. If the doca-flow application
   itself is down, fix that first via
   [`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug)
   — there is nothing for the server to expose otherwise. If the
   application is running but the server is not, route to
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   for the server-side bring-up and debug. Re-listing pipelines
   from the client while the server is down is the wrong move.
3. **Server-unreachable.** The server is up but the client cannot
   reach it. Confirm the endpoint the client is using matches
   what the server is bound to, confirm network reachability,
   confirm permission / firewall layers. The client's own message
   and the server-side logs per
   [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
   are ground truth; route env-side issues to
   [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug).
4. **Pipeline-not-found.** The client reaches the server and
   lists pipelines, but the pipeline the user asked about is
   absent. Confirm the doca-flow program reached the pipe-create
   step per
   [`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug),
   confirm no previous program-side action destroyed the
   pipeline, and confirm the user is using the identifier the
   server reported (not one inferred from the program source).
   If a tuning operation is the next step, gate it on a clean
   inspection per [`## test`](#test) step 4 — never tune a
   pipeline whose identity is in doubt.
5. **Wrong-version-with-server.** The client connects but its
   per-pipeline view disagrees with what the doca-flow program
   reports — typically because the client, the server, and the
   doca-flow `*.so` came from different DOCA installs. Walk the
   four-way match per
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2, applied with the Flow-Tune-specific overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility).
   The fix is a consistent reinstall on the side that is out of
   train, not a tuning operation that tries to *"correct"* the
   discrepancy from the client side.
6. **Measurement-unsound.** The session produces a measurement
   but the measurement does not support the user's quoted
   number. Walk the sub-cases per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 6 — baseline window missing for a hardware-counter
   delta, latency measured under saturating traffic, rule-
   install-rate measured across a tuning-axis change. The fix
   is to re-run with the soundness rule from
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   honored; re-quoting the unsound aggregate is the wrong move.
7. **Cross-cutting.** All layers above are clean and the tuning
   operation still does not move the metric the user cares
   about. The cause is below the Flow Tune layer — driver,
   firmware, BlueField mode, hardware path, host CPU governor,
   NUMA placement. Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured client output, the server-side trace, and
   the version chain as evidence. Looping on tuning at this
   layer is the wrong move.

In every case: **quote what the tool said.** Do not paraphrase
pipeline-state or measurement output, do not reorder fields, do
not summarize into prose. The whole point of inspecting a
pipeline from outside the program is to break the agent out of
the inference-from-symptom trap.

## Deferred task verbs

The four verbs below are not Flow Tune Tool work and should be
routed out before the agent does any of them under this skill's
name.

- **install** ⇒ [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  (and [`## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). The Flow Tune Tool
  client is shipped by the install; this skill does not own the
  install workflow.
- **bring up the Flow Tune Server** ⇒
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md).
  This skill is the CLIENT side; the server bring-up, deploy,
  and debug live in the sibling skill.
- **write or modify a doca-flow application** ⇒
  [`doca-flow`](../../libs/doca-flow/SKILL.md) (plus
  [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) when CT is
  in use), layered on
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  The Flow Tune Tool tunes pipelines the program created; it is
  not a template for creating them.
- **streaming telemetry / live metrics export** ⇒ not a Flow
  Tune Tool feature. The DOCA Telemetry Service (DTS) is the
  documented telemetry surface; routing belongs in
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).

## Command appendix

Flow-Tune-Tool-specific invocations the verbs above reach for.
Every row is a CLASS — the agent must not invent flags,
subcommand names, tuning-axis identifiers, or output columns
beyond `--help` on the installed client and the public DOCA Flow
Tune Tool guide. The connect → list → inspect → (tune) symmetry
is the load-bearing piece; one worked example per family is
shown.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
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
| Discover available subcommands, flags, tuning-axis identifiers, output columns | The client's own `--help` (the documented inventory comes from here, not from prose) | [`## configure`](#configure) axes 1-3 + [`## run`](#run) step 7 | Prints the documented inventory; the agent uses this as the only source of truth for subcommand / flag / tuning-axis / column names. |
| Confirm client version against host package and server | The client's `--version`, cross-checked with `pkg-config --modversion doca-flow`, `pkg-config --modversion doca-common`, and the server's reported version per [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) | [`## test`](#test) step 2 + [`## debug`](#debug) layer 5 | All version strings agree per the four-way match in [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility) plus the Flow-Tune-specific overlay in [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility); disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2). |
| Connect the client to a Flow Tune Server | The client's documented connect invocation against the endpoint the sibling [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) reports the server is bound to | [`## run`](#run) step 2 + [`## test`](#test) step 1 | Exit 0; connect message confirms a session with the server; the server-side log per [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) records the same session. |
| Enumerate Flow pipelines on the connected server | The client's documented list-pipelines subcommand, run after a successful connect | [`## run`](#run) step 3 + [`## test`](#test) step 3 | Exit 0; the listing includes the pipeline identifier the user expected, or surfaces an empty listing the agent treats as a pipeline-not-found finding per [`## debug`](#debug) layer 4. |
| Inspect one pipeline by identifier | The client's documented inspect-pipeline subcommand, given the identifier from the enumeration | [`## run`](#run) step 4 + [`## test`](#test) step 4 | Exit 0; the per-pipeline state reads as the public guide documents for an active pipeline of this kind on this DOCA version. |
| Apply a non-mutating tuning hint | The client's documented tuning-axis invocation in a non-mutating / dry-run mode (when the public guide exposes one); used to surface what a tuning op would change before any state is touched | [`## run`](#run) step 6 (when supported) | Exit 0; the client reports the proposed change without changing live Flow state; the post-call inspection is byte-identical to the pre-call inspection. |
| Apply a mutating tuning operation (HIGH-STAKES) | The client's documented tuning-axis invocation against a single pipeline identifier, after the smoke in [`## test`](#test) reads clean and the user has explicitly accepted the dataplane risk | [`## debug`](#debug) layer 4 routing (after smoke; after non-mutating hint did not answer the question) | The post-op re-inspection reflects the change; the captured before / after measurement supports the user's quoted number; never chained without a re-inspection per [`## test`](#test) eval loop. |
| Save a session snapshot for debug | Redirect the client's output to a file (e.g. `> flow-tune-session.txt`) plus the version-state quote captured at configure time | [`## test`](#test) save step + [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) | The saved file is consumed by the cross-cutting debug ladder as the Flow-side half of the evidence pair (the server-side trace per [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) is the other half). |
| Re-confirm after a server / app / env change | Any of the read-only rows above, re-run after a tuning operation, server restart, doca-flow application restart, driver / firmware / mode change, or DOCA reinstall | [`## test`](#test) eval loop + [`## debug`](#debug) layer 7 | The post-change output reflects the change; a stale snapshot is the failure mode. |

Three cross-cutting rules for this appendix:

- **Never invent a subcommand, flag, tuning-axis identifier, or
  output column name.** `--help` on the installed client plus
  the public DOCA Flow Tune Tool guide via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
  are the joint contract; prose-derived names are the most
  common hallucination failure for this skill.
- **Mutating tuning operations re-open the smoke.** They are
  not retryable in place; after any state-changing operation,
  the agent re-runs the read-only smoke per
  [`## test`](#test) before issuing anything else.
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `dmesg`, `mlxconfig -d <bdf> q`)
  live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  the env-side representor / PCIe enumeration lives in
  [`doca-setup TASKS.md ## Command appendix`](../../doca-setup/TASKS.md#command-appendix);
  the version-handling commands live in
  [`doca-version TASKS.md ## Command appendix`](../../doca-version/TASKS.md#command-appendix);
  the server-side bring-up commands live in
  [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md);
  this appendix names only Flow-Tune-Tool-client-specific
  invocations on top.

## Cross-cutting

A few rules that apply across every verb in this file, restated
here so they are visible at the point of action and not buried in
[`SKILL.md`](SKILL.md):

- The **public DOCA Flow Tune Tool guide** plus the installed
  `--help` are the joint source of truth. When they disagree
  (e.g. a flag landed in a release this skill was not written
  against), the *installed* `--help` wins for the user's actual
  session.
- The **client and server are one pairing**; neither half is
  meaningful in isolation. The agent must say which side it is
  on, where the other side is, and that the two are on the same
  DOCA train before issuing any tuning operation.
- The **read-only operations are safe**; the **mutating tuning
  operations are not**. The agent must say which class an
  operation belongs to before recommending it, and must gate
  every state-changing operation on a clean smoke per
  [`## test`](#test).
- **Quote, do not paraphrase.** The per-pipeline state and the
  before / after measurement are the artifacts downstream debug
  consumes; reformatting them loses fidelity that the rest of
  the bundle's procedures depend on.
- This skill **assumes a healthy DOCA install** (or the public
  NGC DOCA container with the right device passthrough) on
  both the client side and the server side. If either install
  is in doubt, route to
  [`doca-setup`](../../doca-setup/SKILL.md) before running
  anything else here. For the doca-flow programming surface
  that created the pipelines being tuned, see
  [`doca-flow`](../../libs/doca-flow/SKILL.md) (plus
  [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) for CT).
