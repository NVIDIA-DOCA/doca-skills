---
name: doca-container-deployment
description: >
  Use this skill when the user is hands-on deploying an in-bundle DOCA
  service container (Argus, DMS, Firefly, Flow-Inspector, OS-Inspector,
  UROM service) on a BlueField — kubelet standalone watching a
  static-pod manifests directory, YAML pod-spec drop, kubelet status /
  ENTRYPOINT logs / per-service liveness, smoke-before-bulk, and the
  layered error taxonomy (pod-spec, scheduling, image pull, runtime,
  mount, network, version, host). Trigger even when the user does not
  say "container deployment" — typical implicit phrasings include "how
  do I run my built service on the BlueField?", "where do I drop the
  pod-spec YAML?", "pod stuck in Pending / ImagePullBackOff /
  CrashLoopBackOff", "container Running but service isn't ready", "pod
  restart-loops after edit", or "DMS and Firefly together". Refuse and
  route elsewhere for per-service config schemas, DOCA install,
  library-API questions, external NVIDIA services (BlueMan, HBN, SNAP,
  Virtio-net), or full Kubernetes-cluster ops — those belong to other
  skills.
metadata:
  kind: library
compatibility: >
  No DOCA install required to read this skill (it is an overlay loaded
  against any DOCA artifact skill); the validation steps within DO
  require a live DOCA install at /opt/mellanox/doca.
---

# DOCA container deployment

**Where to start:** This skill is for *operating* the cross-cutting
DOCA container-deployment runtime — the shared pattern every DOCA
service on the BlueField uses to come up (kubelet standalone agent
on the BlueField Arm watching a static-pod manifests directory; the
operator drops a YAML pod spec into that directory; kubelet schedules
the pod and runs the container).

**If the developer has NOT yet decided container vs. bare-metal**
(*"I just got a BlueField, what now?"*, *"my code is built, how do I
run it?"*, *"how do I deploy this?"*), route them BACK to
[`doca-setup ## recognize`](../doca-setup/TASKS.md#recognize) first.
That is the front-door routing decision. The wrong failure mode is
to silently push every developer onto the container path because the
agent loaded this skill first. `## recognize` detects the system
shape, asks the minimum residual question, and lands the developer on
either this skill (when the workload is a packaged DOCA service to
drop on a BlueField) or the bare-metal-path sibling
[`doca-bare-metal-deployment`](../doca-bare-metal-deployment/SKILL.md)
(when the workload is a DOCA-linked application binary the developer
launches directly).

**If the developer is already on the container path**, open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what shape
of runtime is this and what does the deployment contract look like*,
start at [`CAPABILITIES.md`](CAPABILITIES.md). For per-service
overlays, follow the per-service skill under `skills/services/` that
layers on top of this one — the DOCA monorepo ships six service
skills (Argus, DMS, Firefly, Flow-Inspector, OS-Inspector, UROM
service); externally-productized NVIDIA services (BlueMan, HBN, SNAP,
Virtio-net, DOCA Telemetry Service as productized, …) are out of
scope for this bundle by the strict-to-DOCA invariant — route those
to the public NVIDIA docs at `docs.nvidia.com/doca/sdk/`. If DOCA is
not installed on the BlueField target yet, route to
[`doca-setup`](../doca-setup/SKILL.md) first.

## Example questions this skill answers well

The CLASSES of container-deployment questions this skill is built to
answer, each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"How is a DOCA service container actually run on the BlueField —
  what is the runtime, who watches what, how does a pod-spec get
  picked up?"** — worked example: *"I have the DOCA Management
  Service (DMS) container image on the BlueField — what do I do with
  it?"*. Answered by the kubelet-standalone pattern in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the pod-spec-drop walkthrough in
  [`TASKS.md ## run`](TASKS.md#run).
- **"Where do I put the YAML pod spec so kubelet picks it up, and
  what shape does the spec have to be?"** — worked example: *"I have
  a YAML manifest for the Firefly container — where on the BlueField
  filesystem does it go?"*. Answered by the static-pod-manifests
  directory rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the documented-recipe rule in
  [`TASKS.md ## modify`](TASKS.md#modify) (the agent quotes the
  pod-spec shape from the public DOCA Container Deployment Guide via
  [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md);
  it does NOT invent YAML field names).
- **"My pod spec is in the directory but the pod never starts — how
  do I diagnose it?"** — worked example: *"I dropped the OS-Inspector
  pod-spec YAML into the documented manifests directory and nothing
  happens"*. Answered by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (pod-spec syntax → pod scheduling → image pull → runtime → volume
  mount → network policy → version → cross-cutting host) + the
  layered debug ladder in [`TASKS.md ## debug`](TASKS.md#debug).
- **"How do I find the logs of a DOCA service container, and what
  does 'healthy' look like before I put real workload on the
  BlueField?"** — worked example: *"the Flow-Inspector pod is
  `Running`, but I do not yet know whether the mirrored-flow capture
  inside is actually ready"*. Answered by the smoke-before-bulk loop in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the eval-loop overlay in [`TASKS.md ## test`](TASKS.md#test).
- **"My pod was Running and crashed; should I just have kubelet
  restart it, or is that exactly the wrong thing?"** — worked
  example: *"the DMS pod went into a restart loop after a config
  edit; should I leave it looping or step in?"*. Answered by the
  failed-pod-restart-is-high-stakes rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the *"clear the root cause first"* layer in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"Does this same pattern carry over to every other DOCA service,
  or is each service deployed in a different way?"** — worked
  example: *"I have DMS deployed; what changes for Firefly,
  Flow-Inspector, OS-Inspector, UROM service, and Argus?"*.
  Answered by the cross-service generalization in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the per-service overlay routing in
  [`TASKS.md ## Deferred task verbs`](TASKS.md#deferred-task-verbs)
  (the runtime pattern is uniform; the per-service config schema,
  precondition, observability surface, and "healthy" definition
  layer on top via the matching per-service skill).

## Audience

This skill serves **external operators and platform teams who deploy
DOCA service containers on BlueField** — i.e., people who have a
BlueField with DOCA installed on the Arm side, a container runtime
plus the kubelet standalone agent already present per the BlueField
OS image, and the host-OS permissions the public DOCA Container
Deployment Guide names for the chosen service. The skill is the
shared deployment runtime; each per-service skill in the bundle
(see the list in [`## Related skills`](#related-skills)) supplies
the service-specific config schema, paired-workload contract, and
"healthy" definition.

It is **not** for NVIDIA developers contributing to the BlueField
container runtime or to kubelet itself, and it is **not** a generic
Kubernetes tutorial. Kubelet runs on the BlueField in *standalone*
mode here — no full Kubernetes control plane, no `kubectl` against
a cluster API server — and the substantive answer to most
container-deployment questions on the BlueField is the public DOCA
Container Deployment Guide. This skill teaches the agent which
guide to quote, in what order to walk it, and how to map a symptom
to a layer; it does NOT re-invent kubelet flags, pod-spec field
names, or static-pod path strings. The shared deployment runtime
described here is the cross-cutting layer; the per-service skill
(`doca-argus`, `doca-dms`, `doca-firefly`, `doca-flow-inspector`,
`doca-os-inspector`, `doca-urom-svc`) supplies the per-service
config schema, paired-workload contract, and "healthy" definition.

## When to load this skill

Load this skill when the user is doing **hands-on container
deployment of any DOCA service** on a BlueField target, or asking a
cross-service deployment question that is not specific to one
service's config schema. Concretely:

- Dropping a YAML pod spec into the documented static-pod manifests
  directory on the BlueField Arm so kubelet standalone schedules the
  pod and runs the DOCA service container.
- Inspecting pod status, container logs, and the documented
  liveness signal for any in-bundle DOCA service container — Argus,
  DMS, Firefly, Flow-Inspector, OS-Inspector, UROM service — so the
  agent answers "did the container come up, and is the service
  inside actually ready" the same way for every service.
- Walking the smoke-before-bulk loop (pod reaches `Running`;
  ENTRYPOINT logs are clean; service answers a trivial liveness
  probe) BEFORE the BlueField is put under workload.
- Diagnosing a deployment that is misbehaving — pod-spec YAML is in
  the directory but the pod never schedules; pod schedules but
  image-pull fails; image pulls but container ENTRYPOINT
  immediately exits; container runs but the service inside never
  answers; container is in a restart loop after a config edit; a
  volume mount the pod spec names is missing on the host; a network
  policy or host-firewall rule is blocking the service.
- Cross-service questions: *"can I have DMS and Firefly on the
  same BlueField"*, *"how do I list every DOCA service pod that is
  currently running"*, *"what is the documented stop / restart
  semantics if I edit a pod-spec file in place"*.

Do **not** load this skill for per-service config schema questions
(those belong to the matching per-service skill); for installing
DOCA itself or preparing the BlueField env (use
[`doca-setup`](../doca-setup/SKILL.md)); for library-API
questions (use the matching `libs/<library>` skill); or for general
Kubernetes-cluster operations (this skill covers kubelet *standalone*
mode on the BlueField, not a full Kubernetes control plane).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — the cross-cutting DOCA container-deployment
  runtime contract on the BlueField (kubelet standalone agent on
  BlueField Arm watching a documented static-pod manifests
  directory; YAML pod-spec drop is the unit of operator input; the
  same pattern applies across every DOCA service), the BlueField
  preconditions (DOCA install, container runtime, BFB version,
  per-service firmware slot when the service emulates a device,
  image-pull reachability to NGC, host-OS permissions), the
  observability surface (kubelet status, container logs, service-
  side liveness signal — three layers, each with its own owner),
  the cross-cutting error taxonomy (pod-spec syntax → pod
  scheduling → image pull → runtime → volume mount → network policy
  → version → cross-cutting host) covering ≥ 6 layers, and the
  safety policy (smoke before bulk; failed pod is high-stakes —
  clear the root cause before letting kubelet restart-loop the
  pod; do NOT invent pod-spec field names / kubelet flags / image
  tags from memory).
- `TASKS.md` — step-by-step workflows for the in-scope deployment
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`,
  plus a `Deferred task verbs` block routing per-service config
  questions, host-firmware-slot work, paired-workload work, and
  full-Kubernetes-cluster work out to their owning skills.

The skill assumes a BlueField target where DOCA is already installed
on the Arm side, the BlueField OS image ships kubelet standalone +
the container runtime per the public DOCA Container Deployment
Guide, and the operator has the host-OS permissions that guide
names. It does not cover installing DOCA — that path goes through
[`doca-setup`](../doca-setup/SKILL.md) — and it does not
re-document the per-service config schema, which is the canonical
concern of each DOCA service's public guide reached through
[`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-pod-spec
bundle. To keep the boundary clean, it deliberately does not contain
— and pull requests should not add:

- **Pre-baked pod-spec YAML files** (full pod specs, ready-to-drop
  mount / image / command bundles for Argus / DMS / Firefly / etc.)
  intended to be copy-pasted into production. Pod specs are
  deployment-specific (per-service image tag, mount paths, host
  paths the operator picks) and the safe answer for an external
  operator is to derive them from the public DOCA Container
  Deployment Guide plus the matching per-service guide against
  their own target. The agent's job is to prescribe the *procedure*
  and quote the documented field names, not to ship a YAML the user
  might run unmodified.
- **Container image names and tags.** The canonical image source
  for any DOCA service container is the public DOCA Container
  Deployment Guide and the NGC catalog; the agent routes through
  [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)
  for the current image string and tag rather than quoting one
  from memory. Inventing an image name (e.g. a fictional
  `nvcr.io/nvidia/doca/<service>:latest`) is the load-bearing
  first-app failure for this skill.
- **Static-pod-manifests-directory path strings, kubelet flag
  names, and pod-spec field names invented from generic Kubernetes
  knowledge.** Kubelet standalone mode picks pod specs up from the
  documented directory the BlueField OS / DOCA Container Deployment
  Guide names. The agent quotes the documented path string, flag
  name, or field name from the guide; the agent does NOT infer it
  from upstream Kubernetes prose. When in doubt, route to
  [`doca-public-knowledge-map ## DOCA services`](../doca-public-knowledge-map/SKILL.md#doca-services)
  for the public Container Deployment Guide URL.
- **A `samples/`, `templates/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: operators will read it as
  production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope (cross-cutting deployment runtime, NOT a per-service
   config-schema question).
2. **For the kubelet-standalone-mode runtime shape, the static-pod
   manifests directory rule, the host-OS / BFB / firmware-slot /
   image-pull preconditions, the error taxonomy (≥ 6 layers), the
   observability surface, and the safety / smoke-before-bulk
   policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DOCA Container Deployment Guide
  (cross-service deployment pattern), the per-service public guides
  for the in-bundle services (Argus, DMS, Firefly, Flow-Inspector,
  OS-Inspector, UROM service), and the NGC catalog. This skill does
  not duplicate URLs; it points at them and adds the
  deployment-runtime overlay. See in particular
  [`doca-public-knowledge-map ## DOCA services`](../doca-public-knowledge-map/SKILL.md#doca-services)
  for the per-service URL set and the cross-service Container
  Deployment Guide row at the bottom of that section.
- [`doca-setup`](../doca-setup/SKILL.md) — env preparation and
  install verification on the BlueField target where the DOCA
  service container will run, including the *I have no install yet*
  path via the public NGC DOCA container and the BFB version check.
  (`doca-setup` also documents the firmware-slot enable workflow
  for externally-productized NVIDIA services that emulate a
  host-facing PCIe device; none of the six in-bundle services need
  that workflow — see the firmware-slot disclaimer in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).)
  This skill assumes its preconditions are satisfied at the
  BlueField target.
- [`doca-version`](../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule plus the container-tag-vs-
  host-package overlay; the body of those rules lives in
  `doca-version`.
- [`doca-structured-tools-contract`](../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract — the agent probes the
  BlueField container manager's structured status output first and
  falls back to the documented manual commands when the probe
  fails.
- [`doca-debug`](../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). Container-deployment-specific debug (pod never
  scheduled, image pull failed, ENTRYPOINT exited, volume mount
  missing, network policy blocking, restart loop) layers on top of
  the cross-cutting ladder.
- [`doca-bare-metal-deployment`](../doca-bare-metal-deployment/SKILL.md)
  — the SIBLING deployment path: bare-metal hardware (host x86 OR
  BlueField Arm direct launch — systemd / tmux / direct invocation,
  hardware-resource binding, per-tenant isolation, restart
  discipline). This skill (container deployment) owns the
  kubelet-standalone + YAML pod-spec path; that skill owns the
  bare-metal binary-launch path. Both are routed to from
  [`doca-setup ## recognize`](../doca-setup/TASKS.md#recognize).
- Per-service skills layered on top of this one (the six DOCA
  services in the bundle, 1:1 with `doca/services/`):
  [`doca-argus`](../services/doca-argus/SKILL.md) (runtime
  security / monitoring),
  [`doca-dms`](../services/doca-dms/SKILL.md) (DOCA Management
  Service — gNMI / gNOI),
  [`doca-firefly`](../services/doca-firefly/SKILL.md) (PTP time
  sync),
  [`doca-flow-inspector`](../services/doca-flow-inspector/SKILL.md)
  (mirrored flow inspection),
  [`doca-os-inspector`](../services/doca-os-inspector/SKILL.md)
  (DPU-side host-OS introspection),
  [`doca-urom-svc`](../services/doca-urom-svc/SKILL.md) (Unified
  Communication Remote Memory Operations). Each of those skills
  shares this skill's deployment runtime and adds its own config
  schema, paired-workload contract, and "healthy" definition. The
  cross-service generalization rule is *"every DOCA service in the
  bundle uses this deployment runtime — the per-service skill is
  the overlay, not a re-statement of the runtime"*.
- **Non-goals (externally-productized NVIDIA services not in the
  DOCA monorepo and therefore not in this bundle):** BlueMan, HBN,
  SNAP, Virtio-net, DOCA Telemetry Service (as productized), and
  any future external NVIDIA networking software not under
  `doca/services/`. A user asking *"how do I deploy BlueMan?"* is
  routed to the public NVIDIA docs at `docs.nvidia.com/doca/sdk/`
  for that specific product, NOT silently extrapolated from this
  skill's contract. The strict-to-DOCA invariant is documented at
  `AGENTS.md ## Non-goals` row 7.
- [`doca-programming-guide`](../doca-programming-guide/SKILL.md)
  — general DOCA patterns. Container-deployment is service-shaped
  not library-shaped, so the build / modify / first-app pattern
  there does not apply directly, but the cross-library debug
  discipline (frontend-before-backend, env-before-program) remains
  useful when a service container surfaces an error that originated
  in a DOCA library it called.
