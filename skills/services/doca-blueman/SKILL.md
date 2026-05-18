---
name: doca-blueman
description: NVIDIA DOCA BlueMan Service — long-running container on BlueField that exposes a web-based management DASHBOARD (HTTP/HTTPS UI) for human operators to read BlueField state (link status, port counters, services running, logs, basic health). Distinct from DMS (gRPC programmatic management — automation audience) and DTS (telemetry collection / forwarding); BlueMan is observability-oriented for HUMAN operators via a browser, NOT the canonical place to make configuration CHANGES. Covers the four-axis config schema (listen interface + port, TLS, authentication backend, RBAC / role assignment), the container deployment shape (Container Deployment Guide pattern), the read-mostly framing, the path-selection rule (BlueMan for humans vs DMS for automation), and the operational error taxonomy (unreachable dashboard / auth failures / missing features).
kind: library
---

# DOCA BlueMan Service

**Where to start:** This skill is for *deploying and operating* the
BlueMan dashboard service on a BlueField target — not for linking
against a library. If the user wants to *deploy* the container and
bring up the dashboard, open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what shape
of service is BlueMan and how is it different from DMS / DTS*, start
at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA is not installed on
the BlueField target yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user actually
wants to *change* device state programmatically (not just look at it),
the right destination is
[`doca-dms`](../doca-dms/SKILL.md) — see the path-selection rule in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
BEFORE deploying BlueMan.

## Example questions this skill answers well

The CLASSES of BlueMan questions this skill is built to answer, each
with one worked example. The class is the load-bearing piece; the
worked example is one instance.

- **"What is BlueMan and when do I want it vs DMS?"** — worked
  example: *"I have a BlueField and a mixed-skill operator team — do
  I deploy BlueMan, DMS, or both?"*. Answered by the path-selection
  rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (human-via-browser vs programmatic-via-gRPC; read-mostly vs
  full-config) + the configure workflow in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Where does BlueMan run and how do I deploy it?"** — worked
  example: *"I have a BlueField-3 with DOCA on the Arm side; how do
  I pull, configure, and start the BlueMan container?"*. Answered by
  the deployment-shape note in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + [`TASKS.md ## configure`](TASKS.md#configure) routing to the
  canonical DOCA Container Deployment Guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **"Which four config axes do I have to plan before launch?"** —
  worked example: *"listen interface, TLS, auth backend, RBAC — how
  do I think about each?"*. Answered by the four-axis config schema
  in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the wiring step in [`TASKS.md ## configure`](TASKS.md#configure).
- **"My BlueMan container is up but the dashboard is unreachable in
  my browser — where do I start?"** — worked example: *"`crictl ps`
  shows the container Running but my browser times out"*. Answered
  by the unreachable-dashboard layer in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in [`TASKS.md ## debug`](TASKS.md#debug).
- **"The dashboard loads but my operator can't log in / can't see
  the page they expect"** — worked example: *"login fails for the
  one local operator account I created"*. Answered by the
  auth-and-RBAC layer in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the auth-wiring step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"What smoke do I run after deploy, before I add operators / open
  it on a shared network?"** — worked example: *"container up,
  dashboard reachable, one operator logs in, one device-state page
  renders — what's the minimum sweep?"*. Answered by the smoke loop
  in [`TASKS.md ## test`](TASKS.md#test) + the read-mostly safety
  framing in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).

## Audience

This skill serves **external operators and platform teams who deploy
and operate the BlueMan dashboard** on a BlueField target so a human
operator (or a mixed-skill team) can view BlueField state through a
web browser. Concretely: people pulling the BlueMan container,
choosing a listen interface, wiring TLS, picking an authentication
backend, assigning RBAC roles, and pointing operators at the dashboard
URL.

It is **not** for NVIDIA developers contributing to BlueMan itself,
and it is **not** a programming guide for *building applications on
top of* DOCA libraries (that is `doca-programming-guide` plus the
matching library skill under `libs/`). BlueMan is a **service**, not
a library: the operator deploys a container and users interact with
it through a web browser; the user does not link a `libblueman.so`
into their own program. If the user actually needs **programmatic /
scripted management** rather than a human-facing dashboard, route to
[`doca-dms`](../doca-dms/SKILL.md). If the user wants **continuous
telemetry streaming or forwarding** rather than a snapshot dashboard,
route to [`doca-dts`](../doca-dts/SKILL.md) via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## When to load this skill

Load this skill when the user is doing **hands-on BlueMan deployment
or operation work** against a BlueField target where DOCA is already
installed and a container runtime is available. Concretely:

- Deploying the BlueMan container on BlueField Arm via the documented
  container runtime path (per the DOCA Container Deployment Guide).
- Choosing which network interface on the BlueField the dashboard
  binds to (OOB management interface vs in-band interface) and which
  port the HTTP(S) listener uses.
- Wiring TLS for the dashboard (the production posture; lab can run
  plain HTTP per the public guide).
- Picking an authentication backend (per the public BlueMan guide:
  basic auth / LDAP / SSO options depending on the deployment) and
  understanding the trade-offs.
- Assigning RBAC roles so each operator account sees the pages it
  needs and no more.
- Smoke-testing the deployment (container up → dashboard reachable
  in a browser → operator login works → at least one device-state
  page renders) BEFORE adding more users or exposing it on a wider
  network.
- Diagnosing a BlueMan deployment that is misbehaving — container
  failed to start, container running but dashboard unreachable,
  dashboard reachable but auth fails, dashboard works but features
  missing.
- Choosing between deploying BlueMan and adjacent options
  ([`doca-dms`](../doca-dms/SKILL.md) for programmatic management;
  `doca-dts` for telemetry collection; a host-side BMC / IPMI tool
  for *host-side* lights-out management, which BlueMan is not).

Do **not** load this skill for general DOCA orientation, install of
DOCA itself, library-API questions, or programmatic configuration
changes. For those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md),
[`doca-dms`](../doca-dms/SKILL.md), or the matching `libs/<library>`
skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two companion
files:

- `CAPABILITIES.md` — the BlueMan deployment shape (container, runs
  on BlueField Arm, exposes an HTTP(S) UI on a configurable
  interface), the path-selection rule against DMS / DTS / BMC, the
  four-axis config schema (listen interface + port, TLS, auth
  backend, RBAC / roles), the read-mostly framing (BlueMan is the
  observability surface, not the canonical change-control surface),
  the operational error taxonomy (container lifecycle / unreachable
  dashboard / auth failure / missing-feature layers), the
  observability surface (container logs, the dashboard's own views,
  audit / login logs per the public guide), and the documented
  safety / network-exposure posture.
- `TASKS.md` — step-by-step workflows for the in-scope BlueMan
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`,
  plus a `Deferred task verbs` block routing out-of-scope questions
  (making configuration CHANGES → DMS; installing DOCA →
  `doca-setup`; building a custom DOCA app → `doca-programming-guide`
  + the matching `libs/<library>` skill).

The skill assumes a BlueField target where DOCA is already installed,
a container runtime is available, and the operator has the host-OS
permissions the DOCA Container Deployment Guide names for the chosen
runtime path. It does not cover installing DOCA — that path goes
through [`doca-setup`](../../doca-setup/SKILL.md) — and it does not
re-document the container deployment pattern, which is the canonical
concern of the DOCA Container Deployment Guide reached through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not contain
— and pull requests should not add:

- **Pre-baked BlueMan configuration files** (full TLS-wired YAML
  configs, ready-to-mount auth-backend fragments, RBAC role
  bundles) intended to be copy-pasted into production. Configs are
  deployment-specific and the safe answer for an external operator
  is to derive them from the public BlueMan guide against their own
  target. The agent's job is to prescribe the *procedure* and quote
  the documented config fields, not to ship a config the user might
  run unmodified.
- **Container image names and tags.** The canonical image source
  for any DOCA service container is the public DOCA Container
  Deployment Guide and the NGC catalog; the agent routes through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the current image string and tag rather than quoting one from
  memory. Inventing an image name is the load-bearing first-app
  failure for this skill.
- **TLS material, credentials, LDAP / SSO stanzas, or
  certificate bundles.** These are user-environment artifacts; the
  skill points at the documented configuration knobs and the
  documented security best practices and stops there.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: operators will read it as
  production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in scope.
2. **For the BlueMan deployment shape, the path-selection rule (vs
   DMS / DTS / BMC), the four-axis config schema, the read-mostly
   framing, the error taxonomy, the observability surface, and the
   safety / network-exposure policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public BlueMan guide
  (<https://docs.nvidia.com/doca/sdk/DOCA-BlueMan-Service-Guide/index.html>),
  the public DOCA Container Deployment Guide, the NGC catalog page
  for the BlueMan container image, and the rest of the public DOCA
  documentation set. This skill does not duplicate either guide; it
  points at them and adds the BlueMan-operator overlay.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation and
  install verification on the BlueField target where BlueMan will
  run, including the *I have no install yet* path via the public
  NGC DOCA container. This skill assumes its preconditions are
  satisfied at the BlueField target.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule + the headers-win-over-docs
  rule and adds the BlueMan-specific container-tag-vs-host-package
  overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-dms`](../doca-dms/SKILL.md) — the **programmatic** sibling.
  Same management problem space, different audience: BlueMan is a
  human-facing dashboard, DMS is a gRPC API for automation. Same
  shape (BlueField service, container, deployment pattern,
  configuration schema, smoke-before-scale); different shape
  (web UI vs gRPC, read-mostly vs full-config). The path-selection
  rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  routes between them.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. BlueMan is service-shaped not
  library-shaped, so the build / modify / first-app pattern there
  does not apply directly, but the cross-library `DOCA_ERROR_*`
  taxonomy and the layered-debug order remain useful when BlueMan
  surfaces errors that originated in a DOCA library or in a service
  it is monitoring.
