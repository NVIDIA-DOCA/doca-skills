# DOCA Flow Tune Server — Tasks

**Where to start:** The verbs that carry real workflow content
are `## configure` (deployment shape + access surface + auth /
transport posture), `## run` (start the server alongside a
known-good Flow application), `## test` (smoke-before-expose),
and `## debug` (layered diagnosis). The other two (`## build`,
`## modify`) are documented routing stubs because the server is
linked into the surrounding DOCA Flow application — `build` and
`modify` belong to that application's skill. The `## test` verb
is the smoke-before-expose loop, not a one-shot pass — see the
eval-loop overlay in `## test` below.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent through
the six task verbs every artifact in this bundle exposes
(`configure / build / modify / run / test / debug`), explicitly
defers task verbs that do not belong here, and ends with the
`Command appendix` honoring the bundle's
[`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
preamble.

## configure

`configure` for the Flow Tune Server is *"decide the three-axis
configuration BEFORE starting the server"*. The three axes are
laid out in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
deployment shape, access surface, and auth / transport posture.

Steps the agent should walk the user through:

1. **Confirm the DOCA install is healthy and the Flow library is
   present.** Run
   [`doca-setup ## test`](../../doca-setup/TASKS.md#test) and
   confirm `pkg-config --modversion doca-flow` resolves. If the
   user has no install yet, route to
   [`doca-setup ## no-install`](../../doca-setup/TASKS.md#no-install)
   for the public NGC DOCA container path before any Flow Tune
   Server discussion.
2. **Decide the deployment shape.** The public guide documents
   the Flow Tune Server as an in-process API linked into a DOCA
   Flow application. Whether the application is packaged as a
   bare process, a host service, or a container is a packaging
   decision around the same in-process API; route any container
   packaging concern (kubelet standalone, static-pod manifests
   directory, mount contracts) to
   [`doca-container-deployment ## configure`](../../services/doca-container-deployment/TASKS.md#configure).
   The agent must NOT invent a separately-shipped server daemon.
3. **Decide the access surface (which pipes, which operational
   mode).** Per the public guide, the server supports multiple
   documented operational modes that govern who owns the IPC
   polling loop. Read the modes off the user's installed guide
   (route via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools));
   do NOT invent mode names. The pipe surface the server can
   expose is whatever the Flow application has created per
   [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify).
4. **Decide the auth / transport posture.** The documented
   client ↔ server transport per the public guide is a local
   inter-process channel. The endpoint configuration field name
   and its default value live in the installed guide on the
   user's version; quote from there, do NOT infer from generic
   IPC intuition. On top of the documented transport, decide
   *who can reach the host / namespace the endpoint lives in*
   per the safety policy in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
5. **Sanity check before any start.** Confirm with the user: is
   the access surface read-only or state-changing? Who is
   trusted to reach the endpoint? Which operational mode owns
   the polling loop? If any of those answers is unclear, stop
   and ask — do NOT start a tuning server against a fuzzy
   posture.

If the user is already past steps 1-4 and ready to start the
server, proceed to [`## run`](#run). If a step surfaces a
`DOCA_ERROR_*`, route through the error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

The Flow Tune Server is **not a separately built binary** — it
is a set of API entry points linked into the user's DOCA Flow
application via the documented Flow Tune Server trace-build
flavor of `doca-flow`.

Routing for nearby "build" questions:

- *"How do I get the server symbols into my application?"* →
  build (or rebuild) the Flow application against the Flow
  Tune Server trace-build flavor per the public guide on the
  user's installed version, with the meson / `pkg-config`
  pattern owned by
  [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build).
  This skill does NOT duplicate the Flow build recipe.
- *"The server symbols are missing on my version — do I need to
  build the server itself?"* → no. The server is part of DOCA;
  the fix is to install (or re-install) DOCA with the Flow Tune
  Server trace flavor present, or to confirm the installed
  version per
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
  and upgrade if the version pre-dates the symbols.
- *"I want to write my own tuning server"* → out of scope for
  this skill. The Flow Tune Server is a documented in-process
  API; writing an alternative is a Flow programming exercise
  that belongs in
  [`doca-flow`](../../libs/doca-flow/SKILL.md) plus the
  cross-library patterns in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

The
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship)
block forbids shipping a build recipe for the Flow Tune Server
or wrappers around it; revisit that policy before changing this
section.

## modify

`modify` for the Flow Tune Server means *"change which pipes the
server exposes, which mutations are allowed, or which endpoint
the server is bound to"*. The server itself is read-only by
default and is configured by the surrounding DOCA Flow
application; there is no in-place "edit the server" verb.

Routing for nearby "modify" questions:

- *"Change which pipes the server exposes"* → this is a Flow
  application modification, owned by
  [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify).
  The server reflects whatever the application has built; it
  does not curate its own subset.
- *"Allow client-driven mutations through the server"* → change
  the access surface decided in [`## configure`](#configure)
  step 3. Per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
  this is a deliberate posture flip the agent must call out as
  high-stakes before any change.
- *"Change the endpoint the server binds to"* → modify the
  application's Flow Tune Server configuration field per the
  public guide on the user's installed version. The agent must
  NOT invent the field name; confirm it from the installed
  guide.
- *"Patch the shipped Flow Tune Server symbols"* → out of scope.
  This skill is for consumers of the shipped DOCA Flow Tune
  Server API, not contributors to it.

In every case: a modification to the server's exposed surface
re-opens the smoke-before-expose loop in [`## test`](#test). A
stale smoke from before the change is exactly the failure mode
the loop is here to prevent.

## run

Bring the Flow Tune Server up inside a known-good DOCA Flow
application and confirm it bound the documented endpoint, before
any client is pointed at it. The agent should walk the user
through the following sequence when the request is *"start the
tuning server"*:

1. **Confirm the surrounding Flow application is healthy.** Run
   the Flow application's own smoke per
   [`doca-flow TASKS.md ## test`](../../libs/doca-flow/TASKS.md#test) —
   the application's port is up, at least one pipe is created
   and validated, counters are wired. The server has no value
   if the Flow side is not yet useful.
2. **Confirm the Flow Tune Server trace-build flavor is the
   one actually linked.** Per
   [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build),
   the server symbols are gated on the trace flavor. If the
   application was built against the release flavor, the server
   init call will surface as
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 1 (server-not-started); rebuild before continuing.
3. **Call the documented server init from the Flow application
   per the public guide on the user's installed version.** The
   exact symbol names, configuration-struct creation calls, the
   operational-mode selection, the configuration-file path
   setter, and the destroy call live in the public DOCA Flow
   Tune Server guide and in the installed headers; route via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
   Do NOT quote symbol names from prose memory; read them off
   the installed version.
4. **Confirm the server bound the documented endpoint.** On
   success the application's log should show the server bound;
   on failure see the binding-failed layer in
   [`## debug`](#debug). The agent must NOT assume bound; it
   must require evidence.
5. **STOP here.** Do NOT point any client at the server until
   the smoke-before-expose loop in [`## test`](#test) has
   passed. The
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   smoke-before-bulk rule is mandatory.

When recording the run for downstream consumers, write down:
the DOCA version (per
[`doca-version`](../../doca-version/SKILL.md)), the host the
Flow application is running on (host x86 / Arm, BlueField Arm,
or NGC container), the Flow application's build flavor, the
configured access surface and operational mode, and the
documented endpoint the server bound. The
[`## test`](#test) and [`## debug`](#debug) workflows depend on
those fields.

## test

The Flow Tune Server's `## test` is **the canonical
smoke-before-expose loop** for the Flow Tune pair. *"Test"* in
this skill means *"prove one client can connect end-to-end and
list pipelines before the server is exposed to a fleet of
clients or to any state-changing client"*, not *"unit-test the
server"*.

**`## test` is an iterative loop, not a one-shot pass.** Every
mutation — a Flow-side pipe change, an access-surface change, a
build-flavor change, a deployment-shape repackaging, a
driver / firmware change under the Flow application — re-opens
the smoke. Treating it as a one-shot pass is the failure mode
this loop replaces.

The smoke-before-expose shape:

1. **Start the server in a known-good Flow application.** Walk
   [`## run`](#run) steps 1-4 and capture the application's log
   showing the server bound.
2. **Connect ONE client end-to-end.** Use the Flow Tune client
   tool per
   [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) to
   connect to the server's documented endpoint from the same
   host (or the same container namespace) the server is
   running in. The client must connect cleanly and list
   pipelines that match the Flow application's own view per
   [`doca-flow TASKS.md ## test`](../../libs/doca-flow/TASKS.md#test).
   Quote the listing; do not paraphrase.
3. **Confirm the listed pipes match the application's own
   view.** A mismatch surfaces a wrong-version-with-Flow-library
   finding per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   layer 3 — walk the debug ladder, do NOT widen the access
   surface to make the symptom go away.
4. **Only after steps 1-3 read clean** may the agent recommend
   exposing the server to additional clients, to a fleet, or
   (if the access surface is configured for it) to a
   state-changing client. If any step surfaces a finding, the
   agent walks the debug ladder in [`## debug`](#debug) instead.

Eval-loop overlay (rows apply to every Flow Tune Server
deployment, not just one):

| Step | Why this is a loop, not a step | Where the substance lives |
| --- | --- | --- |
| 1 → ## debug | Server did not bind; walk the binding-failed layer, then re-run step 1 | [`## debug`](#debug) layer 2 |
| 2 → ## debug | Client cannot connect or times out; walk the unauthorized / pipeline layers, then re-run step 1 | [`## debug`](#debug) layers 4-5 |
| 3 → ## debug | Listed pipes disagree with the application's own view; walk the wrong-version layer, then re-run step 1 | [`## debug`](#debug) layer 3 |
| 1 → access-surface change → 1 | After widening / narrowing the access surface, re-run the smoke; the prior smoke is stale | [`## configure`](#configure) step 3 + [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) |
| 1 → Flow-side pipe change → 1 | After the Flow application creates or destroys pipes, re-run the smoke to confirm the server's listing reflects the change | [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify) |
| 1 (clean) → save → debug session | Once clean, the server-side reading is saved and consumed by the cross-cutting debug ladder | [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) |

The agent's rule: every state-changing action on the server
(configuration, exposure, Flow-side pipe change) re-opens the
smoke. Saving a stale reading from before a mutation is exactly
the failure mode this loop is here to prevent.

This skill does **not** ship a "test fixture" or pre-recorded
expected output. The expected output is install-, version-, and
application-state-specific; pinning one would mislead operators
on a different platform / version. See
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## debug

When the user reports a stuck client connection, a missing
pipe listing, or a wrong-version protocol error, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Server-not-started.** The Flow application is running but
   the Flow Tune Server init was never called (or the
   application built against a Flow flavor without the server
   symbols). Confirm DOCA is installed (e.g.
   `pkg-config --modversion doca-flow`,
   `cat /opt/mellanox/doca/applications/VERSION`), confirm the
   trace-build flavor is the one linked per
   [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build),
   and confirm the application's source includes the documented
   server init call. Route to
   [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
   when the install layer is at fault.
2. **Server-binding-failed (port / socket).** The init call ran
   but the server could not claim the documented IPC endpoint.
   The application's own error log and `dmesg` are ground
   truth; do not guess at causes. Common drivers — another
   process already holds the endpoint, the documented endpoint
   path is not writable from the application's process,
   operator-supplied endpoint configuration contradicts the
   public guide's documented shape. Confirm the documented
   endpoint shape on the user's installed version via
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools);
   do NOT invent a path.
3. **Wrong-version-with-Flow-library.** The server bound but
   its view of pipes disagrees with the Flow application's own
   `doca_flow_*` view. Walk the three-way match per
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
   and the four-way match in
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2. The fix is a consistent reinstall / rebuild
   against one DOCA train, not a server reconfiguration.
4. **Unauthorized-client (transport / posture).** The client
   reached the server but a request was rejected by the
   configured access surface (asked for a pipe not exposed,
   asked for a mutation not allowed, came from a transport
   posture not enabled). Re-read the configured access surface
   per [`## configure`](#configure) step 3 and the safety
   policy in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
   Bypassing or widening the configured posture is NOT on the
   table without an explicit operator opt-in.
5. **Pipeline-not-exposed.** The client connected, but the
   requested pipe is missing from the server's listing.
   Confirm the Flow application created the pipe per
   [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify),
   confirm it created the pipe on the port the server
   currently exposes, and confirm the access surface does not
   filter the pipe out. If the pipe genuinely is not created,
   route the next move to
   [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify) —
   do NOT keep re-running the client list.
6. **Version layer.** Three-way match (server ↔ client ↔ Flow
   library) is not the same as the four-way match (host ↔ BFB
   ↔ install ↔ headers). If layers 1-5 read clean, walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 with all four version sources captured. A version
   mismatch one layer down explains a clean tuning-server
   reading that disagrees with the surrounding application.
7. **Cross-cutting layer.** All layers above are clean and the
   client still cannot use the server. The cause is below the
   Flow Tune Server layer — driver, firmware, BlueField mode,
   underlying Flow library, transport namespace. Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured server-side reading plus the client-side
   trace and the Flow application's logs as evidence. Looping
   on server restart at this layer is the wrong move.

In every case: **quote what the server reported.** Do not
paraphrase the pipe listing, do not reorder fields, do not
summarize into prose. The whole point of inspecting the server
before touching the Flow application is to break the agent out
of the inference-from-symptom trap.

## Deferred task verbs

The four verbs below are not Flow Tune Server work and should
be routed out before the agent does any of them under this
skill's name.

- **install** ⇒ [`doca-setup ## install`](../../doca-setup/TASKS.md#install)
  (and [`## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). The Flow Tune
  Server is shipped by the DOCA install when the Flow library
  Trace flavor is present; this skill does not own the install
  workflow.
- **write a DOCA Flow program** (in any language) ⇒
  [`doca-flow`](../../libs/doca-flow/SKILL.md), layered on
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  The Flow Tune Server is linked into a Flow application; it
  is not a template for creating Flow applications.
- **library-internal pipe / counter / inspector deep dive** ⇒
  [`doca-flow`](../../libs/doca-flow/SKILL.md). The Flow Tune
  Server transports the same data the Flow library exposes
  programmatically; the deeper per-pipe semantics belong to
  the library.
- **container-runtime deployment of the surrounding Flow
  application** ⇒
  [`doca-container-deployment ## configure`](../../services/doca-container-deployment/TASKS.md#configure).
  Packaging the Flow application (and therefore the in-process
  server) as a container on the BlueField uses the shared
  DOCA service container runtime; the Flow Tune Server skill
  does not duplicate those steps.

## Command appendix

Flow Tune Server-specific actions the verbs above reach for.
Every row is a CLASS — the agent must not invent API symbol
names, configuration-file field names, default endpoint paths,
or operational-mode names beyond what the public guide on the
user's installed version documents. The
in-process / read-only-default / smoke-before-expose symmetry
is the load-bearing piece.

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
| Confirm the Flow library version on the application host | `pkg-config --modversion doca-flow` | [`## configure`](#configure) step 1 + [`## debug`](#debug) layers 3, 6 | Matches the version pinned in `doca_caps --version` and in the client tool's `--version`-equivalent per [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md); disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2). |
| Confirm the Flow application links the trace-build flavor | The trace-flavor `pkg-config` module per [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build) | [`## run`](#run) step 2 + [`## debug`](#debug) layer 1 | The application binary depends on the trace-flavor `*.so`; the Flow Tune Server init call resolves at link time. |
| Read the documented Flow Tune Server API / config surface | The public DOCA Flow Tune Server guide (slug: `DOCA-Flow-Tune-Server`) plus the installed headers on the user's version | [`## configure`](#configure) steps 2-4 + [`## run`](#run) step 3 + [`## debug`](#debug) layer 2 | The agent quotes the documented symbol names, configuration-file field names, default endpoint, and operational-mode names from the user's installed version — not from prose memory. |
| Confirm the surrounding Flow application is healthy | Whatever the application's own smoke is, per [`doca-flow TASKS.md ## test`](../../libs/doca-flow/TASKS.md#test) | [`## run`](#run) step 1 + [`## test`](#test) step 1 | The Flow port is up, at least one pipe is created and validated, counters move under expected traffic. |
| Smoke ONE client → server end-to-end | The Flow Tune client's documented connect + list-pipelines operation per [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) | [`## test`](#test) step 2 | The client connects cleanly; the listed pipes match the application's own view; no protocol-version mismatch is reported. |
| Save a server-side reading for debug | Redirect the client's listing output captured against this server to a file (`> server-state.txt`) | [`## test`](#test) save step + [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) | The saved file is consumed by the cross-cutting debug ladder as the server-side half of the evidence pair. |
| Inspect the Flow application's own logs around server init / bind | Whatever the application's own log surface is, per [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability) | [`## debug`](#debug) layers 1, 2 | The init line is present; the bind line is present; subsequent client connections are logged without `DOCA_ERROR_*` on the application side. |
| Re-confirm after any state-changing action | Any of the rows above, re-run after access-surface change, Flow-side pipe change, build-flavor change, or container repackaging | [`## test`](#test) eval loop | The post-change reading reflects the change; a stale reading is the failure mode. |

Three cross-cutting rules for this appendix:

- **Never invent an API symbol, configuration field, endpoint
  path, or operational-mode name.** The public DOCA Flow Tune
  Server guide on `docs.nvidia.com` plus the installed
  headers / installed config examples on the user's version
  are the joint contract; prose-derived names are the most
  common hallucination failure for this skill.
- **State-changing actions re-open the smoke.** Access-surface
  changes, Flow-side pipe changes, build-flavor changes, and
  container repackaging are not retryable in place; after any
  of them, the agent re-runs the smoke per [`## test`](#test).
- **Cross-link instead of duplicate.** Cross-cutting commands
  (`pkg-config --modversion`, `dmesg`, `mlxconfig -d <bdf> q`)
  live in
  [`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
  the Flow application build / port / pipe commands live in
  [`doca-flow TASKS.md ## Command appendix`](../../libs/doca-flow/TASKS.md#command-appendix);
  the client-side commands live in
  [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md);
  this appendix names only the server-side actions on top.

## Cross-cutting

A few rules that apply across every verb in this file,
restated here so they are visible at the point of action and
not buried in [`SKILL.md`](SKILL.md):

- The **public DOCA Flow Tune Server guide** plus the installed
  headers / installed config examples are the joint source of
  truth. When they disagree (e.g. a field landed in a release
  this skill was not written against), the *installed* version
  wins for the user's actual run.
- The **server is read-only by default**; any state-changing
  access surface is a deliberate, operator-opted-in posture
  the agent must call out as high-stakes before recommending
  it, and must gate on a clean smoke per [`## test`](#test).
- **Quote, do not paraphrase.** The server's pipe listing and
  counter readings are the artifact downstream debug consumes;
  reformatting them loses fidelity that the rest of the
  bundle's procedures depend on.
- This skill **assumes a healthy DOCA install** (or the public
  NGC DOCA container) and a working DOCA Flow application
  with the Flow Tune Server trace-build flavor linked. If the
  install or the Flow side is in doubt, route to
  [`doca-setup`](../../doca-setup/SKILL.md) and
  [`doca-flow`](../../libs/doca-flow/SKILL.md) before running
  anything else here. For the client side, load
  [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md)
  alongside.
