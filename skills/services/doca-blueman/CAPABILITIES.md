# DOCA BlueMan Service — Capabilities

**Where to start:** The pattern overview below names the recurring
BlueMan-class operational patterns. Pick the pattern first, then
drill into the H2 that owns the substance. For the *how* of executing
each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates BlueMan's documented capabilities, deployment
shape, configuration surface, and operational behaviors as described
in the public BlueMan guide on `docs.nvidia.com`. Treat it as a *map
of what is documented*, not a substitute for reading the live page
when configuring a real deployment.

## Pattern overview

Every BlueMan-class question this skill teaches resolves into one of
FIVE patterns. The patterns are CLASSES — they apply across every
deployment topology, not just one specific BlueField.

| BlueMan pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick BlueMan vs DMS vs DTS vs BMC | Human-via-browser vs programmatic-via-gRPC vs streaming-telemetry vs host-side lights-out — audience and shape decide | [`## Capabilities and modes`](#capabilities-and-modes) path-selection |
| 2. Plan the four config axes | Listen interface + port, TLS, authentication backend, RBAC / role assignment — each is a separate decision | [`## Capabilities and modes`](#capabilities-and-modes) config schema |
| 3. Honor the read-mostly framing | BlueMan is the OBSERVABILITY surface; configuration CHANGES belong to DMS — do not route change requests here | [`## Safety policy`](#safety-policy) |
| 4. Read BlueMan's observability surface | Container logs + dashboard's own state views + documented audit / login logs | [`## Observability`](#observability) |
| 5. Map an error back to its layer | Container lifecycle vs unreachable-dashboard vs auth-failure vs missing-feature — each has its own owner | [`## Error taxonomy`](#error-taxonomy) |

Two cross-cutting rules that apply to *every* pattern above:

- **Operate the documented path; do not invent one.** Quote the
  public BlueMan guide for image names, container flags, config
  fields, and auth backends; do not infer from generic container or
  generic-dashboard knowledge.
- **Read-mostly framing, every time.** BlueMan is for *looking at*
  BlueField state. Any user request that boils down to "change a
  BlueField setting" must be routed to
  [`doca-dms`](../doca-dms/SKILL.md), not handled in BlueMan. The
  agent's role is to teach this split, not to walk a config-change
  path through a UI that is not the canonical change surface.

## Capabilities and modes

### Service shape

BlueMan is a **long-running container/daemon on the BlueField Arm**
that exposes an HTTP(S) management dashboard for human operators.
Documented properties:

- Deployment shape: a container, deployed per the canonical DOCA
  **Container Deployment Guide** (routing via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).
  The BlueMan service guide layers on top — it is not a separate
  deployment pattern.
- Runtime location: BlueField Arm side. BlueMan is BlueField-side
  management; it is **not** a host-side BMC / IPMI / iLO equivalent
  (those operate on the *host* baseboard, not the BlueField).
- User-facing surface: a web browser. Users do not link a library
  or hand-craft gRPC clients to interact with BlueMan; they navigate
  to the dashboard's URL and read pages.
- Read-mostly by design: BlueMan is the documented dashboard for
  monitoring BlueField state (link status, port counters, services
  running, logs, basic health). It is **not** the canonical
  configuration-change surface — that is DMS.

The intent is documented: a human operator (or a mixed-skill team
where not everyone uses the CLI) gets a browser view onto the
BlueField; automation gets a separate, programmatic surface
(DMS / gRPC).

### Path selection (BlueMan vs DMS vs DTS vs BMC)

The four candidate management surfaces and when each applies:

| Surface | Audience | Shape | Use when |
|---------|----------|-------|----------|
| **BlueMan** (this skill) | Human operators | Web dashboard (HTTP/HTTPS UI), read-mostly | Operators need a browser view of BlueField state; mixed-skill team; lightweight troubleshooting. |
| **DMS** ([`doca-dms`](../doca-dms/SKILL.md)) | Automation / scripts | gRPC (gNMI for config, gNOI for system operations) | Programmatic / scripted configuration changes; CI / CD wiring; lights-out automation with no human in the loop. |
| **DTS** (route via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)) | Downstream telemetry consumers | Telemetry collection + forwarding | Continuous streaming telemetry, Prometheus / NetFlow / IPFIX fan-out; not interactive. |
| **Host-side BMC / IPMI / iLO** (not a DOCA artifact) | Host platform operators | Host-side lights-out | The thing to manage is the *host* baseboard (power, BIOS, host RAM), not the BlueField. BlueMan does not replace this. |

Documented path-selection rules the agent must teach:

- **Choose BlueMan when** the audience is a human operator with a
  browser AND the workload is read-mostly (monitoring, status
  pages, ad-hoc troubleshooting).
- **Do NOT choose BlueMan when** the workload is pure programmatic
  management → route to [`doca-dms`](../doca-dms/SKILL.md). BlueMan
  is not the canonical change surface even though a dashboard may
  expose some operator-facing buttons.
- **Do NOT choose BlueMan when** the deployment is lights-out (no
  human ever interacts) → again, [`doca-dms`](../doca-dms/SKILL.md).
- **Do NOT choose BlueMan when** the BlueField is resource-
  constrained AND the dashboard is rarely used in steady state — the
  container costs resources for a feature humans use rarely.

The skill MUST refuse to recommend BlueMan as the place to make
configuration *changes*: even if the dashboard exposes a control,
the canonical change-control surface is DMS, and that is where the
agent routes change-class questions.

### Four-axis config schema

Every BlueMan deployment commits to four orthogonal configuration
decisions. The public BlueMan guide is the source of truth for the
concrete field names; the agent's job is to surface the four axes
and route to the live guide for the per-field syntax.

| Axis | What it decides | Documented options |
|------|-----------------|--------------------|
| **Listen interface + port** | Which BlueField NIC / IP the dashboard binds to, and which TCP port the HTTP(S) listener uses | The OOB management interface (common production choice) vs an in-band interface; port per the public guide. Binding to the wrong interface is the most common cause of *"container is up but the dashboard is unreachable"*. |
| **TLS** | Whether the dashboard speaks HTTPS or plain HTTP | Production posture is HTTPS with operator-supplied certificate material per the public guide; lab can run plain HTTP per the public guide's documented allowance. TLS misconfiguration is a common cause of *"dashboard URL hangs"*. |
| **Authentication backend** | How an operator proves identity to the dashboard | Per the public guide: basic / local accounts, or LDAP / SSO depending on the deployment. The agent must quote the guide, not infer from generic web-app auth knowledge. |
| **RBAC / role assignment** | Which dashboard pages and (read / interact) capabilities each operator role gets | Per the documented role model in the public guide. Too-restrictive role assignments are the most common cause of *"dashboard works but features are missing for this user"*. |

Documented constraints the agent must surface:

- The four axes are **orthogonal** — getting one right does not
  protect the others. The smoke-before-scale workflow in
  [`TASKS.md ## test`](TASKS.md#test) exercises one axis per step on
  purpose.
- TLS and authentication interact: plain HTTP plus production auth
  backends is not a coherent production posture; HTTPS plus a
  weak / lab auth backend is also not a coherent production
  posture. The public guide's *Security Best Practices* (or
  equivalent) is the source of truth for the documented coherent
  combinations.

### Deployment shape

BlueMan is deployed as a container on the BlueField Arm per the
canonical DOCA **Container Deployment Guide**:

- The Container Deployment Guide governs the *how* of deploying any
  DOCA service container; the public BlueMan Service Guide layers
  the BlueMan-specific config, image name/tag, and exposed port
  conventions on top.
- The agent routes through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for both URLs rather than re-inventing the deployment pattern in
  this skill.
- BlueMan does not need a host-side companion process; the
  dashboard speaks HTTP(S) and any browser on a host that can reach
  the BlueField's listen interface can be the client.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The BlueMan-specific overlay** is:

- **BlueMan container tags can lag DOCA host-package versions.**
  The BlueMan container shipped from NGC carries its own tag that
  may not match the host's `pkg-config --modversion doca-common`.
  When the user is using BlueMan-as-a-container (which is the only
  documented deployment shape), the relevant version anchor is the
  container tag pulled, not the host install — confirm both and
  route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 if they diverge.
- **The public BlueMan guide version must match the deployed
  container tag.** A common failure mode is reading a newer or
  older guide than the deployed container — the documented config
  fields and the documented auth backends can shift between
  releases. Always confirm the version of the
  guide matches the deployed BlueMan version.

## Error taxonomy

BlueMan errors fall into five layers, each with its own owner:

1. **Container lifecycle layer** — the BlueMan container failed to
   start or is in a restart loop. Symptoms: `crictl ps` shows the
   container as `Exited` / `Created` rather than `Running`; the
   container's documented log stream shows config-parse errors,
   image-pull failures, or missing-mount errors. Resolution: walk
   the canonical DOCA Container Deployment Guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
   first; if the failure is env-class (image pull, kernel module,
   container runtime), drop to
   [`doca-setup`](../../doca-setup/SKILL.md).
2. **Unreachable-dashboard layer** — the container is `Running`
   but the browser cannot reach the dashboard URL. Symptoms:
   browser timeout, connection refused, TLS handshake failure.
   Causes per the documented BlueMan failure modes:
   - BlueMan is bound to the wrong listen interface for where the
     operator's browser is coming from (in-band vs OOB).
   - A firewall on the path is blocking the listen port.
   - TLS certificate material is missing / wrong / expired and the
     browser refuses the handshake.
   Resolution: walk the layered ladder in
   [`TASKS.md ## debug`](TASKS.md#debug) layer 2.
3. **Authentication layer** — the dashboard is reachable but login
   fails. Symptoms: documented login-rejected response on the
   dashboard; documented audit / login log line shows the rejection.
   Causes: wrong credentials, auth backend mis-wired (LDAP / SSO
   endpoint unreachable, basic-auth account does not exist),
   credential mismatch between what the operator typed and what the
   backend has. Resolution: walk the auth backend's troubleshooting
   in the public BlueMan guide for the specific backend in use.
4. **Authorization / missing-feature layer** — the operator logs
   in successfully but the dashboard page they expect is empty,
   missing, or refused. Causes: the operator's RBAC role does not
   grant access to that page; OR the DOCA service that BlueMan
   tries to monitor for that page is not running on the BlueField.
   Resolution: confirm the role assignment first (against the
   documented role model in the public guide); if the role is
   correct, confirm the underlying DOCA service the page reads from
   is up.
5. **Underlying-service / library layer** — BlueMan reports a page
   render error sourced from a service it monitors, or a DOCA
   library it calls into returns `DOCA_ERROR_*`. The cross-library
   taxonomy in
   [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy)
   becomes relevant on the *server* side. The library-specific
   overlay (e.g. for Flow) lives in the matching `libs/<library>`
   skill.

The agent's rule: walk these layers **in this order**. Layer 1
before layer 2 (container has to be running before reachability is
even a question); layer 2 before layer 3 (dashboard has to be
reachable before login is even attempted); layer 3 before layer 4
(login has to succeed before role-based feature visibility matters).

## Observability

Documented observability surfaces:

- **Container logs.** The BlueMan container emits a documented log
  stream readable via the container runtime (`crictl logs <id>` or
  the documented SystemD / `journalctl` integration on the
  BlueField, per the public BlueMan guide). The agent's first move
  for container-lifecycle and unreachable-dashboard questions is
  this log stream.
- **The dashboard's own state views.** Once the dashboard is
  reachable and an operator is logged in, the documented pages
  themselves are the observability surface for the BlueField:
  link status, port counters, services running, basic health.
  This is BlueMan's primary purpose.
- **Audit / login logs.** Per the public BlueMan guide, login
  attempts and (where the guide documents them) audit events are
  recorded. These are the surface for diagnosing the
  authentication layer in
  [`## Error taxonomy`](#error-taxonomy).

BlueMan does **not** provide streaming telemetry to downstream
consumers; that is the DOCA Telemetry Service (DTS), reachable
through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
BlueMan is a *snapshot dashboard* — it queries underlying services
for the current state when an operator opens a page.

## Safety policy

BlueMan's safety surface is operational, not programmatic. The
documented posture:

- **Read-mostly framing is non-negotiable.** BlueMan is the
  documented observability surface; the canonical place to make
  configuration *changes* is DMS. Any user request that boils down
  to "change a BlueField setting" must be routed to
  [`doca-dms`](../doca-dms/SKILL.md), regardless of whether some
  dashboard control might exist for it.
- **TLS is the production posture.** Plain HTTP is documented as
  acceptable only for lab use. Exposing a plain-HTTP BlueMan on a
  shared network is unsafe; the agent must route any production
  deployment through HTTPS.
- **Listen-interface choice is a security decision.** The OOB
  management interface and an in-band interface have different
  threat models; exposing the dashboard on an interface reachable
  from an untrusted network is exactly the *Network Exposure*
  failure mode the public BlueMan guide warns about. Quote the
  guide's network-exposure best practices; do not paraphrase.
- **Authentication-backend choice is a security decision.** Basic
  / local accounts, LDAP, and SSO each carry documented trade-offs
  in the public guide; reads of the *Security Best Practices*
  subsection (or equivalent) are mandatory before prescribing a
  production deployment.
- **RBAC is the per-user safety boundary.** The dashboard's role
  model is the per-operator authorization boundary; assigning a
  more-privileged role than the operator needs widens the impact
  of a credential leak. The agent's safe default is least-privilege
  per the documented role catalog.

## Public-source pointer

The single canonical public source for BlueMan is the **DOCA BlueMan
Service Guide** on `docs.nvidia.com`, reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
Verify that the version of the guide matches the deployed BlueMan
container tag — the documented config fields, the auth backends, and
the role model can shift between releases, so the live page is the
contract, not agent memory.
