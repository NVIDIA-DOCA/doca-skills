---
name: doca-flow-tune-tool
description: NVIDIA DOCA Flow Tune Tool — operator-facing CLI CLIENT shipped with the DOCA SDK that connects to a DOCA Flow Tune Server colocated with a running DOCA Flow application and lets an operator profile, inspect, and tune that app's live Flow pipelines (pipes, entries, rules created via doca-flow / doca-flow-ct). Every session commits to a three-axis configuration — target Flow pipeline × tuning axis (rule placement, resource hints, hardware-offload mode) × measurement (rule-install rate, lookup latency, hardware-counter delta) — plus the client/server version match that gates the session, plus the smoke-before-bulk loop (connect, confirm version, list pipelines, inspect one, then tune) that gates any mutating tuning op because mutating live Flow state can disrupt the dataplane. Pairs with doca-flow-tune-server (server sibling colocated with the app), doca-flow (the library whose pipelines are tuned), doca-flow-ct (CT extension), doca-version, doca-structured-tools-contract, doca-setup, doca-debug.
kind: library
---

# DOCA Flow Tune Tool (client)

**Where to start:** This is a tool skill for invoking the DOCA Flow
Tune Tool — the operator-facing CLI CLIENT that connects to a DOCA
Flow Tune Server colocated with a running DOCA Flow application.
Open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) for the three-axis decision
(target Flow pipeline × tuning axis × measurement), at
[`## run`](TASKS.md#run) for the connect → list → inspect → tune
flow once the axes are committed, or at
[`## debug`](TASKS.md#debug) when the user reports that the client
cannot reach the server or that a pipeline is missing. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
state can this tool report and tune* on a Flow pipeline. If DOCA
is not installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user has
no DOCA Flow application running yet, route to
[`doca-flow`](../../libs/doca-flow/SKILL.md) FIRST — the Flow Tune
Tool tunes pipelines the doca-flow library already created, it
does not create them. For the canonical URL of the Flow Tune Tool
public guide, route through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## Example questions this skill answers well

The CLASSES of Flow Tune Tool questions this skill is built to
answer, each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"Which DOCA Flow pipelines does this running app expose, and
  how do I see them from outside?"** — worked example: *"a doca-flow
  service is running on this BlueField and I want to enumerate the
  pipes it created without changing anything"*. Answered by the
  client/server connect + pipeline-enumeration surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the list-first invocation in
  [`TASKS.md ## run`](TASKS.md#run).
- **"What is the per-pipeline state — rule counts, hardware
  counters, hit / miss — before I touch anything?"** — worked
  example: *"I picked one pipe from the listing and want to inspect
  its current state and counters"*. Answered by the per-pipeline
  inspection surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the inspect-one step in
  [`TASKS.md ## run`](TASKS.md#run).
- **"Which tuning axis answers my actual question — rule placement,
  resource hints, or hardware-offload mode?"** — worked example:
  *"my Flow app's rule-install rate is lower than expected; is that
  a placement question or a resource-hint question?"*. Answered by
  the three-axis configuration in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the configure walk in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"My Flow app uses doca-flow-ct — can the Flow Tune Tool tune CT
  state too, and what changes about the session?"** — worked
  example: *"the pipelines I want to tune wrap stateful CT tables;
  is that in scope and what does it change for me"*. Answered by
  the CT-extension overlay in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the CT routing in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"The client cannot reach the server — is the server down, am I
  on the wrong endpoint, or am I a version off?"** — worked
  example: *"the tool prints a connection failure when I try to
  list pipelines"*. Answered by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"How do I know my Flow Tune Tool client and the Flow Tune
  Server my Flow app is colocated with came from the same DOCA
  install?"** — worked example: *"the client connects, lists
  pipelines, but the per-pipeline output disagrees with what the
  app reports"*. Answered by the client/server version-match
  overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
  which redirects to
  [`doca-version`](../../doca-version/SKILL.md) for the canonical
  rules.

## Audience

This skill serves **external operators, performance engineers, and
AI agents who need to inspect or tune a running DOCA Flow
application's pipelines from outside the application** — after the
[`doca-flow`](../../libs/doca-flow/SKILL.md) library has been used
to bring the application's Flow ports / pipes / entries up from a
program, and after a DOCA Flow Tune Server has been colocated with
that application per the sibling
[`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) skill.
Concretely:

- A platform operator who runs a Flow-using service on BlueField
  and wants a read-only snapshot of which pipelines exist and how
  their counters are progressing before declaring the service
  ready.
- A performance engineer who wants to commit to a single tuning
  axis (rule placement, resource hints, or hardware-offload mode)
  for one specific Flow pipeline on this device and DOCA version,
  rather than guessing at flag strings.
- An AI agent driving an operational triage step *"is this Flow
  pipeline behaving as expected, and would a non-mutating tuning
  hint help"* before recommending a code change to the doca-flow
  program.

It is **not** for users debugging the Flow Tune Tool itself, **not**
a substitute for the live public DOCA Flow Tune Tool guide on
`docs.nvidia.com`, **not** the place to learn the doca-flow
programming API (that belongs to
[`doca-flow`](../../libs/doca-flow/SKILL.md)), and **not** the
place to deploy or operate the Flow Tune Server itself (that
belongs to the sibling
[`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md)
skill).

The Flow Tune Tool is shipped as a CLI binary, not a library you
link against. The skill uses the same `kind: library` three-file
shape as the rest of the bundle so the agent's task-verb contract
(`configure / build / modify / run / test / debug`) is uniform
across libraries, services, and tools — even when individual verbs
collapse to a routing stub for a shipped CLI.

## When to load this skill

Load this skill when the user is — or the agent needs to — drive
the DOCA Flow Tune Tool client against a running DOCA Flow
application that has a colocated DOCA Flow Tune Server. Concretely:

- Connecting the Flow Tune Tool client to a Flow Tune Server on
  the side (host or BlueField Arm) where the doca-flow application
  is running.
- Listing the Flow pipelines the server exposes so the agent can
  refer to real pipeline identifiers, not invented ones.
- Inspecting one specific pipeline's per-pipe state, counters, and
  rule-install / lookup behavior before deciding whether to tune.
- Walking the three-axis configuration (target Flow pipeline ×
  tuning axis × measurement) before issuing any tuning operation.
- Cross-checking the tool's view of a pipeline against the
  program-side doca-flow / doca-flow-ct view when the two appear
  to disagree.
- Diagnosing a session that fails to connect, finds the server but
  cannot enumerate pipelines, or produces measurements that do
  not support the user's quoted number.

Do **not** load this skill for general DOCA orientation, the
doca-flow programming API, doca-flow-ct API, library install, or
Flow Tune Server deployment. For those, route to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-flow`](../../libs/doca-flow/SKILL.md),
[`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the sibling
[`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what the Flow Tune Tool reports and tunes:
  the client/server pairing (this skill is the client; the server
  is colocated with the doca-flow application), the read-only vs
  state-changing operation split, the three-axis configuration
  model (target Flow pipeline × tuning axis × measurement), the
  version-availability overlay that redirects to
  [`doca-version`](../../doca-version/SKILL.md) and includes the
  client/server version-match rule, the layered error taxonomy
  (tool-not-installed / server-not-running / server-unreachable /
  pipeline-not-found / wrong-version-with-server /
  measurement-unsound / cross-cutting), the tool's role as an
  observability primitive for [`doca-flow`](../../libs/doca-flow/SKILL.md)
  / [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) debug
  sessions, and the safety policy that makes any mutating tuning
  operation high-stakes (dataplane disruption) and gated on a
  clean read-only inspection first.
- `TASKS.md` — step-by-step workflows for the in-scope task verbs:
  `configure` (the three-axis decision plus client/server pairing),
  `build` (route to install), `modify` (refuse), `run` (connect →
  list → inspect → tune), `test` (smoke-before-bulk loop with the
  client/server version check), `debug` (the layered diagnosis
  ladder), plus a `Deferred task verbs` block routing out-of-scope
  questions and a `Command appendix` honoring the bundle's
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  preamble.

The skill assumes a host or BlueField where DOCA is already
installed, a DOCA Flow application is already running and has
created at least one pipeline, and a DOCA Flow Tune Server has
already been brought up colocated with that application per
[`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts bundle.
To keep the boundary clean, it deliberately does not contain — and
pull requests should not add:

- **Verbatim flag inventories, subcommand names, output column
  names, or tuning-axis identifiers.** The public DOCA Flow Tune
  Tool guide on `docs.nvidia.com` and the installed `--help` on
  the user's version are the joint source of truth; copying them
  here pins the skill to one DOCA release and silently rots when
  the tool evolves. The skill routes the agent at those sources
  instead.
- **Pre-baked example output or specific tuning hints.** Output
  and hint applicability are install-, device-, firmware-,
  pipeline-, and DOCA-version-specific. A captured example pinned
  to one platform misleads operators on a different platform /
  version. The agent quotes what the tool emitted on the user's
  session.
- **Wrappers, parsers, or scripts** in any language that consume
  Flow Tune Tool output. The output format is documented; users
  who want to script against it should read the live guide and
  write the parser against their installed version per
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md).
- **A `samples/`, `templates/`, or `reference/` subtree.** A mock
  or incomplete tuning recipe in this skill's tree, even one
  labeled *"reference"*, is misleading: operators will read it as
  production-grade and apply it to a different Flow pipeline that
  it was never written against.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope (the user wants to drive the Flow Tune Tool client
   against a server colocated with a doca-flow application — not
   learn the doca-flow API, deploy the server, or install DOCA).
2. **For the client/server pairing, the three-axis configuration
   model, version availability and the client/server version
   match, the layered error surface, observability, and safety
   posture, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented invocations and the smoke-before-bulk
   workflow — `configure`, `build`, `modify`, `run`, `test`,
   `debug`, plus the `Command appendix` — see
   [TASKS.md](TASKS.md).**

## Related skills

- [`doca-flow-tune-server`](../doca-flow-tune-server/SKILL.md) —
  the SERVER half of the Flow Tune pairing, colocated with the
  doca-flow application. Pair them in every session: the tool
  cannot enumerate or tune anything without a reachable server,
  and the server is meaningless without a client to ask it
  questions.
- [`doca-flow`](../../libs/doca-flow/SKILL.md) — the library whose
  pipelines the Flow Tune Tool tunes. The pipe / entry / rule
  surface this tool reports on is created by doca-flow program
  code; for the API behind that surface (and for debugging a
  doca-flow program independently of the tool), route there.
- [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) — the
  stateful CT extension on top of doca-flow. When the doca-flow
  application uses CT, the Flow Tune Tool may also surface
  CT-table state and tune CT-related hints; the API behind the
  CT surface lives here.
- [`doca-comm-channel-admin`](../doca-comm-channel-admin/SKILL.md)
  — a sibling observability-paired tool with the same
  "operator CLI paired with a DOCA library, list → inspect →
  decide, smoke-before-bulk before any state-changing operation"
  shape. The shape generalizes; the pairing changes (Flow Tune
  Tool pairs with doca-flow / doca-flow-ct via a colocated
  server; the Comm Channel Admin Tool pairs with doca-comch
  directly).
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA Flow Tune Tool guide (and the
  Flow Tune Server guide) and the rest of the public DOCA
  documentation set.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. The
  [`## Version compatibility`](CAPABILITIES.md#version-compatibility)
  section in [`CAPABILITIES.md`](CAPABILITIES.md) is a concise
  overlay that redirects here for the body (four-way match, NGC
  semantics, headers-win-over-docs) and adds the Flow-Tune-
  specific client/server version-match rule.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's detect → prefer → fall back → report contract
  for structured helper tools. The Command appendix in
  [`TASKS.md`](TASKS.md) honors this contract.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, representor / device visibility checks,
  and the *I have no install yet* path with the public NGC DOCA
  container. This skill assumes its preconditions are satisfied.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. Flow Tune Tool failures route into this ladder
  at the runtime layer as the read-only inspection surface
  before any code change is recommended.
