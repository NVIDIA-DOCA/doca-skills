---
name: doca-flow-grpc-server
description: NVIDIA DOCA Flow gRPC Server (`doca_flow_grpc_server`) — the shipped DOCA tool that exposes a remote-control gRPC surface in front of `doca-flow`, letting a non-C++ client (Python, Go, Rust, Java, etc., via standard gRPC bindings) program Flow pipes, entries, and rules over RPC instead of linking `libdoca_flow.so` into a process directly. The gRPC contract is defined by the `.proto` files shipped under the tool's source tree on the user's install; that file is the authoritative API surface. Because the server controls live Flow / dataplane state, the gRPC endpoint is an admin attack surface — bind it on a trusted segment, gate it with auth + TLS, and treat every state-changing RPC the same way you would a direct `doca-flow` mutation. Pairs with `doca-flow`, `doca-version`, `doca-debug`, `doca-hardware-safety`.
kind: tool
---

# DOCA Flow gRPC Server (`doca_flow_grpc_server`)

**Where to start:** This is a tool skill for standing up and
operating `doca_flow_grpc_server`, the DOCA-shipped gRPC remote-
control surface for `doca-flow`. Open [`TASKS.md`](TASKS.md) and
start at [`## configure`](TASKS.md#configure) to decide whether a
remote control plane is the right answer at all (vs talking to
`libdoca_flow.so` directly), then [`## run`](TASKS.md#run) for
the start → bind → one-client-smoke sequence, then
[`## test`](TASKS.md#test) for the smoke-before-bulk loop that
gates any RPC that mutates Flow / dataplane state. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
the gRPC contract surface looks like* (the `.proto` files shipped
under the tool's source tree on the user's install), *how the
auth / TLS posture decision is made*, *which language bindings
the gRPC ecosystem covers*, or *how to interpret the server's
own logs alongside the live Flow application's logs*. If DOCA is
not installed, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user has
not stood up `doca-flow` yet, route to
[`doca-flow`](../../libs/doca-flow/SKILL.md) FIRST — the gRPC
server is a remote control plane on top of the Flow library, not
a replacement for it.

## Example questions this skill answers well

The CLASSES of `doca_flow_grpc_server` questions this skill is
built to answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"Do I actually need a remote control plane for my Flow
  pipeline, or should my client just link `libdoca_flow.so`
  directly?"** — worked example: *"my client is a Python
  service on a different host; can it program Flow rules
  remotely?"*. Answered by the *when-to-use-gRPC* decision in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing into
  [`doca-flow`](../../libs/doca-flow/SKILL.md) when a direct
  library link is the better answer.
- **"Where is the gRPC contract surface actually defined on my
  install?"** — worked example: *"I want to generate a Python
  client; where do I get the `.proto` file?"*. Answered by the
  *the-`.proto`-file-is-the-source-of-truth* rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the language-bindings discussion of standard gRPC tooling
  (`protoc` + the language-specific gRPC plugin per the
  [official gRPC docs](https://grpc.io/docs/) on `grpc.io`).
- **"How do I harden the gRPC endpoint so it isn't an open
  door into my dataplane?"** — worked example: *"the server is
  bound on `0.0.0.0`; what should I do before exposing it?"*.
  Answered by the *admin attack surface* posture in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the auth / TLS / network-segment decision in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How do I smoke ONE client end-to-end before opening the
  server to the fleet?"** — worked example: *"my Python client
  can dial the endpoint; what is the first RPC I run to prove
  it talks to the live Flow application?"*. Answered by the
  smoke-before-bulk loop in
  [`TASKS.md ## test`](TASKS.md#test) +
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  smoke-before-bulk rule.
- **"My client cannot reach the server — is the server down,
  the wrong endpoint, a TLS / auth mismatch, or a version
  mismatch?"** — worked example: *"the client times out
  connecting"*. Answered by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Is my non-C++ client (Python / Go / Rust) actually the
  right shape for the gRPC contract, or is there a cleaner
  path?"** — worked example: *"I want a Rust client; what
  does the `.proto`-generated API look like?"*. Answered by the
  language-bindings discussion in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing through standard gRPC tooling.

## Audience

This skill serves **external operators, control-plane developers,
and AI agents who need to program a running DOCA Flow pipeline
from a non-C++ process across a network boundary** instead of
linking `libdoca_flow.so` directly into the controlling process.
Concretely:

- A control-plane engineer writing a Python / Go / Rust client
  that programs Flow rules on a BlueField from outside the
  BlueField's address space.
- A platform operator running a Flow-using service on
  BlueField who wants to expose a remote-control surface to a
  centralized control plane.
- An AI agent driving the *"can I program these Flow rules
  from this client / this network position"* triage step
  before recommending a code change to the surrounding
  doca-flow application.

It is **not** for users debugging the gRPC server's source code,
**not** a substitute for the live public DOCA Flow gRPC Server
guide on `docs.nvidia.com`, and **not** the place to learn the
`doca-flow` API — that audience belongs in
[`doca-flow`](../../libs/doca-flow/SKILL.md).

`doca_flow_grpc_server` is shipped as a **single CLI binary**
plus its companion `.proto` contract files; per the shipped
source tree (`server/`, `dpa_device/`, `packet_buffering/`) the
tool can also be paired with a packet-buffering / DPA-side
helper on configurations that need them. The skill uses the
same `kind: library` three-file shape as the rest of the bundle.

## Language scope

This skill governs deployment, configuration, hardening, and
client-side bring-up across the languages standard gRPC tooling
covers — Python, Go, C++, Rust, Java, Node.js, C#, Kotlin, Ruby,
PHP, Dart — via the language-specific gRPC plugin generated
from the shipped `.proto` files (see the
[gRPC language support](https://grpc.io/docs/languages/) index
on `grpc.io`). The server itself is C++ + DOCA; the client
languages are open, gated only by the standard `protoc` plugin
set. For the `doca-flow` API the server programs, see
[`doca-flow`](../../libs/doca-flow/SKILL.md) — that surface is
C-language.

## When to load this skill

Load this skill when the user is — or the agent needs to — bring
up `doca_flow_grpc_server` against a running `doca-flow`
application (or its preconditions) and connect a non-C++ client
to it. Concretely:

- Deciding whether a remote gRPC control plane is the right
  surface (vs a direct `libdoca_flow.so` link in the client
  process).
- Locating the `.proto` files on the user's install so a
  language-binding client can generate the appropriate
  stubs.
- Picking the auth / TLS posture (mTLS, token, plaintext on
  a trusted segment) and the network segment the endpoint
  lives on.
- Standing up the server alongside a known-good Flow setup
  and smoke-testing one client end-to-end before exposing
  the endpoint to the fleet.
- Diagnosing a connect / version / RPC failure through the
  layered taxonomy.

Do **not** load this skill for general DOCA orientation,
`doca-flow` API work, DOCA install, or general gRPC tooling
(use the [grpc.io](https://grpc.io/) docs directly for those).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what `doca_flow_grpc_server` exposes:
  the gRPC remote-control surface in front of `doca-flow`,
  the `.proto`-files-as-authoritative-contract rule (the
  shipped `.proto` files under the tool's source on the
  user's install are the source of truth), the *when-to-use-
  gRPC vs direct-library-link* decision, the language-
  bindings story (any language standard gRPC tooling covers),
  the auth / TLS / network-segment decision axis, the
  packet-buffering / DPA-side option per the shipped
  `packet_buffering/` and `dpa_device/` subtrees, the
  version overlay (server rides the `doca-flow` library
  version it links against), the layered error taxonomy
  (server-not-started / server-binding-failed / TLS-or-auth-
  rejected / RPC-call-error / Flow-precondition-failed /
  version / cross-cutting), the observability surface (the
  server's own logs + the live Flow application's logs +
  the RPC client's status codes), and the safety policy
  that treats the endpoint as an admin attack surface.
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `install` (route to setup; binary is shipped),
  `configure` (decide remote-vs-direct, pick auth / TLS,
  pick the network segment), `build` (route to install),
  `modify` (refuse — modify the deployment, not the binary),
  `run` (start → bind → smoke), `test` (the
  smoke-before-bulk loop with the client-side stub
  generation step), `debug` (the layered diagnosis ladder),
  `use` (the agent-side workflow for consuming a captured
  gRPC server session), plus a `Deferred task verbs` block
  and a `Command appendix`.

The skill assumes a host where DOCA is already installed (or
the NGC DOCA container is running) with the Flow library
present, a working `doca-flow` application to program against,
and the operator's awareness that exposing a gRPC control plane
is a high-stakes posture.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Verbatim RPC method names, message field inventories, or
  default endpoint paths.** The `.proto` files shipped under
  the tool's source tree on the user's install are the
  authoritative contract; copying them here pins the skill
  to one release and silently rots when the contract
  evolves.
- **Pre-baked client code in any language.** The
  language-specific gRPC plugin + the shipped `.proto` files
  are the contract; client code generated from them on the
  user's installed version is the right answer, not a stub
  pinned to a snapshot.
- **A pre-baked auth / TLS posture (which CA, which token
  source, which mTLS configuration).** That posture is a
  deployment-environment decision — route it to the
  operator's security review and the safety policy.
- **Wrappers, parsers, or scripts** that proxy the gRPC
  endpoint into another protocol. The endpoint is the
  endpoint; if a user wants HTTP/JSON instead, that is a
  separate concern outside this skill's scope.
- **A `samples/`, `bindings/`, or `reference/` subtree.**
  Even one labeled *"reference"* is misleading: operators
  will read it as buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (the user actually wants a remote gRPC control
   plane on top of `doca-flow`, not a direct library link or
   a different DOCA library).
2. **For what the server exposes, the `.proto`-as-contract
   rule, the language-bindings story, the auth / TLS /
   network-segment decision, version availability, the
   layered error surface, observability, and safety posture,
   see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented start sequence and the
   smoke-before-bulk workflow — `install`, `configure`,
   `build`, `modify`, `run`, `test`, `debug`, `use` — see
   [TASKS.md](TASKS.md).**

## Related skills

- [`doca-flow`](../../libs/doca-flow/SKILL.md) — the **base
  library** the server's gRPC contract is a thin remote-
  control wrapper over. Pipe / entry / rule semantics, the
  validate-before-commit rule, the Flow counter / inspector
  surface all live there.
- [`doca-flow-tune`](../doca-flow-tune/SKILL.md) — the Flow
  tuning tool. When a Flow-program change is recommended,
  the change can be applied through the surrounding
  application or — when the control plane is remote —
  through this gRPC server's RPC surface.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — routing to the public DOCA Flow gRPC Server page on
  `docs.nvidia.com` and the rest of the public DOCA
  documentation set.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  version-handling rules. The
  [`## Version compatibility`](CAPABILITIES.md#version-compatibility)
  section in this skill is a thin overlay on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. gRPC server failures route into the ladder at
  the runtime layer.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the NGC DOCA container path.
- [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md) —
  the cross-cutting hardware-safety meta-policy this skill's
  `## Safety policy` overlays. Any state-changing RPC is a
  potential dataplane-affecting change and must respect the
  meta-policy.
