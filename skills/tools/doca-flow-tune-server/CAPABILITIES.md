# DOCA Flow Tune Server — Capabilities

**Where to start:** The Flow Tune Server is a DOCA Flow subcomponent
that lives inside a DOCA Flow application; the pattern overview
below names the recurring server-side questions. Pick the pattern
first, then drill into the H2 that owns the substance. For the
*how* of executing each pattern, jump to [TASKS.md](TASKS.md). For
the underlying Flow pipes the server exposes, see
[`doca-flow CAPABILITIES.md`](../../libs/doca-flow/CAPABILITIES.md).
For the client side that connects to this server, see
[`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
state the server exposes*, *what deployment shapes the public
guide documents*, *what versions it ships in*, *the layered error
and observability surfaces*, and *the safety policy that treats
the server as an admin attack surface*. For step-by-step
invocations and the smoke-before-expose workflow, see
[`TASKS.md`](TASKS.md).

## Pattern overview

Every Flow Tune Server question this skill teaches resolves into
one of FIVE patterns. The patterns are CLASSES — they apply
across every DOCA Flow application that links the server, not
just one specific deployment.

| Flow Tune Server pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide the deployment shape | In-process API linked into the Flow application is the documented shape; any sidecar packaging the operator adds is a container-runtime concern around the same in-process API | [`## Capabilities and modes`](#capabilities-and-modes) deployment-shape bullet + [TASKS.md ## configure](TASKS.md#configure) |
| 2. Decide the access surface | Which pipes the server exposes, whether client-driven mutations are allowed, what the documented operational modes mean for who must own the polling loop | [`## Capabilities and modes`](#capabilities-and-modes) access-surface bullet + [TASKS.md ## configure](TASKS.md#configure) |
| 3. Decide the auth / transport posture | The endpoint the public guide documents for the client to reach (a local IPC channel by default per the public guide); on top of that, the operator owns who can reach the host / namespace that endpoint lives in | [`## Capabilities and modes`](#capabilities-and-modes) auth-transport bullet + [`## Safety policy`](#safety-policy) |
| 4. Smoke-before-expose | Start → bind → confirm one client can connect and list pipelines, before exposing to a fleet of clients or to any state-changing client | [TASKS.md ## test](TASKS.md#test) + [`## Safety policy`](#safety-policy) smoke-before-bulk rule |
| 5. Diagnose stuck / unreachable / wrong-version output | Map the symptom (server-not-started, server-binding-failed, wrong-version, unauthorized-client, pipeline-not-exposed) to the right layer before any code change | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Read-only by default; state-changing only after a clean
  inspection.** The server's read-only surface (enumerate pipes,
  read counters, surface KPIs) is the agent's default reach. Any
  configuration that lets clients mutate Flow state through the
  server is a separate, deliberately-enabled access surface and
  must be gated on the smoke-before-expose loop in
  [`TASKS.md ## test`](TASKS.md#test).
- **The server is one half of the Flow Tune pair.** The other
  half is the client tool per
  [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md). An
  agent that quotes the server's view without the client side
  (or vice versa) is missing half the evidence; the
  three-way-match in [`## Version compatibility`](#version-compatibility)
  is the rule that keeps the two halves consistent with the
  Flow library underneath.

## Capabilities and modes

The DOCA Flow Tune Server is a **DOCA Flow subcomponent** — the
public guide documents it as a set of `doca_flow_tune_server_*`
API entry points that a DOCA Flow application links in and calls
from its own process. There is no separately-shipped server
binary the operator runs as a daemon; the server lives inside
the Flow application's address space, and the client tool
reaches it through a documented inter-process communication
channel.

The three-axis configuration surface every Flow Tune Server
deployment must decide before exposing:

- **Deployment shape (in-process vs sidecar packaging around the
  same in-process API).** The public guide documents the
  in-process API. There is no documented "sidecar server"
  runtime — what operators often call a "sidecar" is the same
  in-process API inside a Flow application that the operator
  has chosen to containerize. The deployment-shape decision is
  therefore *"how do I package the Flow application that hosts
  the server"*, not *"do I run a separate server process"*. When
  the operator's packaging involves containers, route the
  container-runtime concerns (kubelet standalone, static-pod
  manifests directory, mount contracts, image-pull reachability)
  to
  [`doca-container-deployment`](../../services/doca-container-deployment/SKILL.md) —
  this skill stays focused on the in-process server itself.
- **Access surface (which pipes, which operational mode).** The
  server exposes the Flow pipes the surrounding Flow application
  has created. Per the public guide, the server supports
  multiple documented operational modes that govern who owns the
  IPC polling loop (server-internal vs application-owned).
  Picking the mode also picks who is responsible for keeping the
  channel responsive — read the public guide on the user's
  installed version for the documented mode names and
  responsibilities before quoting them.
- **Auth / transport (endpoint security posture).** Per the
  public guide, the documented client ↔ server transport is a
  local inter-process channel; the agent should consult the
  installed guide and the application's configuration surface
  for the exact endpoint shape and configuration field names,
  rather than invent endpoint paths from memory. On top of the
  documented transport, the operator owns *who can reach the
  host or namespace the endpoint lives in* — this is the
  security posture the [`## Safety policy`](#safety-policy)
  section treats as load-bearing.

The exact API symbol inventory, configuration-file field names,
default endpoint path, and operational-mode names live in the
public DOCA Flow Tune Server guide and in the installed headers
on the user's version. The skill deliberately does not pin them
— see
[`SKILL.md ## What this skill deliberately does not ship`](SKILL.md#what-this-skill-deliberately-does-not-ship).

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The Flow Tune Server-specific overlay** is:

- **The Flow Tune Server is bound to the Flow library it links
  against.** Per the public guide, the server symbols are
  available only when the Flow application is built against the
  documented Flow Tune Server trace-build flavor of
  `doca-flow`. Operators who built their Flow application
  against the release-flavor library will not see the server
  symbols even on a DOCA version that ships them; the right
  answer for *"the server API is missing"* is to confirm the
  build flavor per
  [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build)
  and re-build with the trace flavor, not to recommend
  alternative tools.
- **Three-way version match (server ↔ client ↔ Flow library).**
  The Flow Tune Server's view of pipes, the Flow Tune client's
  protocol, and the underlying `doca-flow` library version
  MUST agree as a strict subset of the four-way match rule per
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
  When in doubt, run `pkg-config --modversion doca-flow` on the
  application side, capture the Flow Tune client's
  `--version`-equivalent per the client skill, and quote the
  DOCA install version per
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
  Disagreement on any of the three is a partial-install or
  mixed-train hazard the agent must surface rather than paper
  over.
- **Where it runs.** The server runs inside the DOCA Flow
  application's process — that means it runs wherever the Flow
  application runs (host x86 / Arm, BlueField Arm, or inside
  the public NGC DOCA container with the Flow Tune Server
  trace flavor present). The set of pipes it exposes is
  whatever the Flow application has created on the active
  steering mode per
  [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-flow/CAPABILITIES.md#capabilities-and-modes).

## Error taxonomy

The Flow Tune Server's error surface is broader than `doca_caps`
because it both serves client connections and exposes Flow state
that the surrounding application owns. The error layers the agent
should distinguish, in escalating order:

1. **Server-not-started.** The Flow application is running, but
   the Flow Tune Server initialization call was never made (or
   the application built against a Flow flavor that does not
   include the server symbols). Cause: the application omitted
   the documented init call, or the build linked the
   release-flavor Flow library instead of the Flow Tune Server
   trace flavor. Routing:
   [`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build)
   to re-build with the trace flavor, then re-confirm the init
   call per the public guide. The agent must not assume the
   server is up just because the surrounding Flow application
   is.
2. **Server-binding-failed (port / socket).** The server init
   call ran but could not claim the IPC endpoint the public
   guide documents (or the endpoint the operator configured for
   it). Cause: another process already holds the endpoint, the
   filesystem path or socket namespace the public guide
   documents is not writable from the application's process,
   or the operator-supplied endpoint contradicts the public
   guide's documented shape. The application's own error log
   and `dmesg` are ground truth; do not guess. Routing: confirm
   the documented endpoint shape on the user's installed
   version per
   [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
   and the application's own configuration surface.
3. **Wrong-version-with-Flow-library.** The server initialized
   and bound, but its view of pipes disagrees with what the
   Flow application reports (e.g. the client sees pipe counts
   or pipe identifiers that do not match the application's
   own `doca_flow_*` view). Cause: the server symbols and the
   Flow library `*.so` came from different DOCA installs, or
   the build linked one train against another's headers. This
   is a partial-install hazard; routing belongs in
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 plus the three-way overlay in
   [`## Version compatibility`](#version-compatibility) above.
4. **Unauthorized-client (transport / posture).** The server
   bound, but a client request is rejected by the access
   surface the operator configured (the request asks for a
   pipe that is not exposed, asks for a mutation the access
   surface forbids, or comes from a transport posture the
   operator declined to enable). The right move is to confirm
   the configured access surface on the application side, not
   to widen it as a workaround. See
   [`## Safety policy`](#safety-policy) for the
   non-mutating-by-default posture this layer enforces.
5. **Pipeline-not-exposed.** The client successfully connected
   but the pipe it asked about is missing from the server's
   listing. Cause: the Flow application never created the pipe
   (route to
   [`doca-flow TASKS.md ## modify`](../../libs/doca-flow/TASKS.md#modify)
   for pipe creation), the application created the pipe on a
   different port the server does not currently expose, or the
   access surface filters that pipe out by design.
6. **Version layer.** The Flow application, the server's view
   of pipes, the client's view of pipes, and the
   `pkg-config --modversion doca-flow` reading on the
   application's host fail the three-way match in
   [`## Version compatibility`](#version-compatibility). Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   layer 2 with the captured versions; the fix is a consistent
   reinstall / rebuild, not a tuning-server reconfiguration.
7. **Cross-cutting layer.** All layers above are clean and the
   client still cannot use the server. The cause is below the
   Flow Tune Server layer — driver, firmware, BlueField mode,
   underlying Flow library state, or a transport-namespace
   problem the operator owns. Escalate to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   with the captured server-side state plus the client-side
   trace as evidence; do not loop on server restart hoping for
   a different outcome.

The Flow Tune Server's API returns `DOCA_ERROR_*` values per the
cross-library taxonomy owned by
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the layers above describe the *operational* symptom classes the
agent maps each `DOCA_ERROR_*` into, not a new error family.

## Observability

The Flow Tune Server is itself an **observability primitive** for
the rest of the Flow surface — it is *what other skills load to
observe* a DOCA Flow application's pipeline state from outside
the program. Specifically:

- [`doca-flow TASKS.md ## debug`](../../libs/doca-flow/TASKS.md#debug)
  step 3 prescribes reading the programmed-entry table /
  inspector dump as ground truth; the Flow Tune Server is the
  documented way to expose that view to a Flow Tune client
  running outside the application's process, and pairs with
  [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) for
  the client-side capture.
- [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
  consumes the captured Flow Tune Server reading (a server-side
  list of pipes + counters + KPIs as exposed to the client) as
  the *server-side half* of the cross-cutting debug ladder,
  paired with the client-side capture per
  [`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) and
  (when present) the BlueField driver / firmware view via
  [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
- The server itself does not emit metrics, traces, or DOCA logs
  of its own beyond the data the client reads from it; the
  surrounding DOCA Flow application's own logs (per
  [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability))
  are the right place to look for the application-side view of
  what the server saw.

For the program-side observability surface (`DOCA_LOG_LEVEL`,
`--sdk-log-level`, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)
and the trace-flavor build rule in
[`doca-flow TASKS.md ## build`](../../libs/doca-flow/TASKS.md#build).

## Safety policy

Exposing a tuning server in production is a **deliberately
high-stakes posture** — it is an admin attack surface attached
to the dataplane:

- **Non-mutating by default.** The server's read-only access
  surface (list pipes, read counters, surface KPIs) is the
  default reach. Any access surface that lets a client mutate
  the Flow state through the server changes the security
  posture of the surrounding application. The agent must
  recommend non-mutating mode by default and require explicit
  operator opt-in before enabling any client-driven mutation,
  and must say which class an operation belongs to before
  recommending it.
- **Smoke-before-expose is mandatory.** Before pointing a fleet
  of clients (or any production client) at the server, the
  agent runs the start → bind → one-client → list-pipes
  sequence in [`TASKS.md ## test`](TASKS.md#test). A server
  exposed without that sequence is a guess against a possibly-
  unbound endpoint or a mis-configured access surface — exactly
  the failure mode this rule exists to prevent.
- **Treat the endpoint as a privileged surface.** The operator
  owns *who can reach the host / namespace the documented IPC
  endpoint lives in*. Recommend operator review of that reach
  set (filesystem permissions on a socket path, container
  namespace boundary, host network access) before declaring the
  server "exposed", regardless of how benign the access surface
  looks.
- **Never widen access as a workaround.** If a client cannot
  read what it expected, the right answer is to walk the
  taxonomy in [`## Error taxonomy`](#error-taxonomy) — not to
  enable a wider access surface or a state-changing access
  surface so the symptom goes away.
- **Quote what the server reported. Do not paraphrase pipe
  state.** When the user later asks *"is this pipe healthy"*,
  the correct answer is to point at the line of the server's
  reading the client captured, not to summarize it. The Flow
  counter / inspector contract in
  [`doca-flow CAPABILITIES.md ## Observability`](../../libs/doca-flow/CAPABILITIES.md#observability)
  still applies — the server is a transport for the same data,
  not a different fidelity.
- **Do not invent API symbol names, config field names, or
  endpoint paths.** The documented surface is the surface; the
  public guide plus installed headers / installed config
  examples are the joint source of truth. If the user asks for
  a field the public guide does not list, the safe answer is
  *"the installed guide on your version is the source of
  truth — let me check it there"*, not a guess based on
  generic IPC conventions.

## Public-source pointer

The single canonical public source for the DOCA Flow Tune Server
is the **DOCA Flow Tune Server** page on `docs.nvidia.com`,
reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
Do not invent API symbol names, configuration-file field names,
default endpoint paths, or operational-mode names beyond what
that page documents. For the Flow library the server exposes,
the public source is the **DOCA Flow** page, reached the same
way and named on the [`doca-flow`](../../libs/doca-flow/SKILL.md)
skill. For the Flow Tune client the server pairs with, the
public source is the **DOCA Flow Tune Tool** page, named on the
[`doca-flow-tune-tool`](../doca-flow-tune-tool/SKILL.md) skill.
