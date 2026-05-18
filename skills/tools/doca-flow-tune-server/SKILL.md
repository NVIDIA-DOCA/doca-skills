---
name: doca-flow-tune-server
description: NVIDIA DOCA Flow Tune Server — the server-side runtime that lives inside a DOCA Flow application and exposes the application's pipeline state to Flow Tune client tools over an inter-process channel so operators can observe and (where the server is configured to allow it) tune pipes from outside the application. Per the public guide, the documented deployment shape is in-process (linked into the DOCA Flow application via the documented Flow Tune Server API and the Flow / Flow Tune Server trace-build flavor); any sidecar / container packaging the operator chooses around that application is a separate runtime concern routed to doca-container-deployment. The server pairs with the doca-flow-tune-tool client skill and rides the doca-flow library version (server ↔ client ↔ Flow library three-way match). Exposing a tuning server is an admin attack surface — recommend non-mutating mode by default and gate any state-changing tuning on a clean inspection of the server's read-only view first.
kind: library
---

# DOCA Flow Tune Server

**Where to start:** This is a tool skill for deploying and operating
the **server side** of the DOCA Flow Tune pair — the runtime that
lives inside a DOCA Flow application and exposes its pipeline state
to the Flow Tune client. Open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) when picking the deployment
shape, [`## run`](TASKS.md#run) when bringing the server up alongside
a known-good Flow app, or [`## debug`](TASKS.md#debug) when a client
cannot connect. Open [`CAPABILITIES.md`](CAPABILITIES.md) when the
question is *what state the server exposes, on which deployment
shapes, and under what auth / transport posture*. If the user has
not stood up `doca-flow` yet, route to
[`doca-flow`](../../libs/doca-flow/SKILL.md) FIRST — the server
exposes the pipes that the Flow library created, not pipes of its
own. If DOCA is not installed at all, route to
[`doca-setup`](../../doca-setup/SKILL.md) first.

## Example questions this skill answers well

The CLASSES of Flow Tune Server questions this skill is built to
answer, each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"How do I bring up a Flow Tune Server alongside my DOCA Flow
  application so a Flow Tune client can observe it?"** — worked
  example: *"I have a DOCA Flow app on a BlueField and I want the
  Flow Tune client tool to be able to list pipes against it"*.
  Answered by the deployment-shape decision + start sequence in
  [`TASKS.md ## configure`](TASKS.md#configure) and
  [`TASKS.md ## run`](TASKS.md#run) plus the three-axis configuration
  surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
- **"Should the Flow Tune Server be in-process (linked into the Flow
  app) or sidecar (separate process / container alongside it)?"** —
  worked example: *"my Flow app is shipped as a container; do I
  containerize the server alongside, or link it in?"*. Answered by
  the *deployment-shape decision* discussion in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing to
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md)
  when any container packaging is in scope.
- **"Which pipes does the server expose, and which mutations should I
  allow the client to perform?"** — worked example: *"I want clients
  to be able to read counters but not to delete entries"*. Answered
  by the access-surface axis in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the non-mutating-by-default safety posture in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
- **"How do I prove one client can connect end-to-end before I expose
  the server to a fleet of clients?"** — worked example: *"smoke a
  single client against the server before declaring it ready for the
  operator dashboard"*. Answered by the
  start → bind → client-smoke loop in
  [`TASKS.md ## test`](TASKS.md#test) +
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  smoke-before-bulk rule.
- **"My Flow Tune client cannot connect — is the server up, the
  endpoint wrong, or the version mismatched?"** — worked example:
  *"the client times out connecting but the Flow application is
  running"*. Answered by the layered diagnosis ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) +
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
- **"Is this server, client, and Flow library set actually consistent
  in version?"** — worked example: *"the server starts cleanly but
  the client reports a protocol-level error"*. Answered by the
  three-way-match overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  which redirects to [`doca-version`](../../doca-version/SKILL.md).

## Audience

This skill serves **external operators, DOCA Flow application
developers, and AI agents who need to bring up the SERVER side of
the DOCA Flow Tune pair** alongside a real DOCA Flow application
and expose it to a Flow Tune client. Concretely:

- A DOCA Flow application developer who wants the in-process Flow
  Tune Server linked into their application so operators can later
  observe pipes from outside the process.
- A platform operator deploying a DOCA Flow workload who needs to
  decide on the deployment shape (in-process vs sidecar packaging),
  the access surface the server exposes, and the auth / transport
  posture the server is brought up under.
- An AI agent driving a *"is the Flow Tune surface healthy on this
  host"* triage step before recommending a client-side investigation
  or a Flow-side code change.

It is **not** for users debugging the Flow Tune Server library
itself, **not** a substitute for the live public DOCA Flow Tune
Server guide, and **not** the right place for users learning the
DOCA Flow API — that audience belongs in
[`doca-flow`](../../libs/doca-flow/SKILL.md). For the client-side
counterpart (the Flow Tune client tool the server pairs with),
load [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md)
alongside this skill.

The server is shipped as a **DOCA Flow subcomponent** — the API
is linked into a DOCA Flow application via the documented Flow
Tune Server symbols, and the Flow Tune Server trace-build flavor
of `doca-flow` is required for the symbols to be present. The
skill uses the same `kind: library` three-file shape as the rest
of the bundle so the agent's task-verb contract
(`configure / build / modify / run / test / debug`) is uniform
across libraries, services, and tools.

## When to load this skill

Load this skill when the user is — or the agent needs to — bring
up the SERVER side of a Flow Tune pair against a real DOCA Flow
application (or inside the public NGC DOCA container with the
right Flow + Flow Tune Server trace-build flavor) on a host or
BlueField. Concretely:

- Linking the documented Flow Tune Server API into a DOCA Flow
  application and starting it under the documented modes.
- Picking the deployment shape (in-process vs sidecar packaging
  around the same in-process API) for an application that the
  operator will later expose to a Flow Tune client.
- Setting the access surface (which pipes are exposed, whether
  client-driven mutations are allowed) before exposing the server
  to any client.
- Choosing the auth / transport posture for the server endpoint
  the public guide documents, before any client is pointed at it.
- Smoke-testing one client → server connection before exposing
  the server to a fleet of clients.
- Capturing a side-effect-free server-state snapshot as
  prerequisite evidence for a later debug session that crosses
  client / server / Flow library layers.

Do **not** load this skill for general DOCA Flow programming, for
the client-side tool, for the Flow Connection Tracking layer, for
DOCA install, or for general container deployment. For those, route
to [`doca-flow`](../../libs/doca-flow/SKILL.md),
[`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md),
[`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or
[`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what the Flow Tune Server reports and
  exposes: the documented deployment shape (in-process API), the
  three-axis configuration surface (deployment shape × access
  surface × auth / transport posture), the version-availability
  overlay that redirects to [`doca-version`](../../doca-version/SKILL.md)
  for the canonical detection chain (with the
  server ↔ client ↔ Flow library three-way match as the Flow Tune
  Server-specific overlay), the layered error taxonomy
  (server-not-started / server-binding-failed / wrong-version /
  unauthorized-client / pipeline-not-exposed / version /
  cross-cutting), the tool's role as an observability primitive
  for the [`doca-flow`](../../libs/doca-flow/SKILL.md) pipeline
  surface, and the safety policy that treats any tuning server as
  an admin attack surface and recommends non-mutating mode by
  default.
- `TASKS.md` — step-by-step workflows for the in-scope task verbs:
  `configure` (pick deployment shape, access surface, auth /
  transport), `build` (route to the Flow Tune Server trace-build
  flavor + the in-process API), `modify` (route to the Flow
  application that links the API), `run` (start the server
  alongside a known-good Flow app), `test` (smoke-before-bulk
  with one client), `debug` (the layered diagnosis ladder), plus
  a `Deferred task verbs` block and a `Command appendix` that
  honors the bundle's
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  preamble.

The skill assumes a host where DOCA is already installed (or the
public NGC DOCA container is running) with the Flow and Flow Tune
Server trace libraries available, a working DOCA Flow application
to link the server into (or to colocate the server with), and
the operator's awareness that exposing a tuning server is a
high-stakes posture.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts bundle.
To keep the boundary clean, it deliberately does not contain —
and pull requests should not add:

- **Verbatim API symbol catalogues, JSON config key inventories,
  or default endpoint paths quoted as the contract.** The public
  DOCA Flow Tune Server guide on `docs.nvidia.com` (reached via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
  and the installed headers on the user's version are the joint
  source of truth; copying them here pins the skill to one
  release and silently rots when the API evolves. The skill
  routes the agent at those sources instead.
- **Pre-baked DOCA Flow application source code that links the
  server API**, in any language. The verified reference is the
  shipped DOCA Flow samples plus the public Flow Tune Server
  guide's API listing on the user's installed version; the
  agent's job is to route the user to those files and prescribe
  a minimum-diff modification via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the Flow-specific overrides in
  [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build).
- **A pre-baked production posture (which clients are trusted,
  which mutations are allowed, which transport security to use).**
  That posture is a deployment-environment decision — route it
  to the operator's own security review and the safety policy
  in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
  not to invented defaults.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (the user wants to bring up the SERVER side of the
   Flow Tune pair, not the client tool, and not the Flow library
   itself).
2. **For what the server exposes, the three-axis configuration
   surface, the deployment-shape decision, version availability,
   the layered error surface, observability, and safety posture,
   see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented start sequence and the
   smoke-before-expose workflow — `configure`, `build`, `modify`,
   `run`, `test`, `debug`, plus the `Command appendix` — see
   [TASKS.md](TASKS.md).**

## Related skills

- [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) — the
  client-side tool the server pairs with. Pair them in every
  Flow Tune triage session: a server-side reading without the
  client-side confirmation (or vice versa) is half the picture.
- [`doca-flow`](../../libs/doca-flow/SKILL.md) — the **base
  library** whose pipes this server exposes. The server is a
  Flow subcomponent; it has no pipes of its own. Port bring-up,
  pipe creation, the validate-before-commit rule, and the Flow
  counter / inspector surface all live in `doca-flow` and are
  not re-explained here.
- [`doca-flow-ct`](../../libs/doca-flow-ct/SKILL.md) — the Flow
  Connection Tracking extension that layers on top of
  `doca-flow`. When a user runs Flow + Flow CT and asks the Flow
  Tune Server to surface state, both the underlying Flow pipes
  and the CT context state are in scope; load `doca-flow-ct`
  alongside this skill in that case.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source.
  The canonical public guide for this skill is the **DOCA Flow
  Tune Server** page, reached via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links here for the canonical detection chain and adds
  the Flow Tune Server-specific *three-way-match*
  (server ↔ client ↔ Flow library) overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's detect → prefer → fall back → report contract for
  structured helper tools. The Command appendix in
  [`TASKS.md`](TASKS.md) honors this contract.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the *I have no install yet* path
  with the public NGC DOCA container. This skill assumes its
  preconditions are satisfied.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. The Flow Tune Server slots in at the *runtime*
  layer as the in-process observability surface that pairs with
  the client-side inspection before any code change is
  recommended.
- [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md) —
  routing target when the operator's deployment shape involves
  containerizing the DOCA Flow application (and therefore the
  in-process Flow Tune Server). Container-runtime concerns
  (kubelet standalone, static-pod manifests directory, mount
  contracts) live there; the Flow Tune Server skill does not
  duplicate them.
