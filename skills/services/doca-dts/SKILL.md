---
name: doca-dts
description: NVIDIA DOCA Telemetry Service (DTS) — long-running container/daemon on BlueField that COLLECTS telemetry from multiple sources (DOCA applications via doca-telemetry-exporter, system metrics, DPU hardware counters) and FORWARDS/EXPOSES the aggregate to downstream consumers (Prometheus / NetFlow / IPFIX collectors, custom dashboards, the DOCA Log Service). Covers the triple-skill split (exporter publishes → DTS aggregates → downstream consumer), the container deployment shape (crictl/kubelet, SystemD container unit, manual runtime), the YAML/JSON config shape that governs sources / sinks / sampling / schema-version pinning, the start-order rule (DTS up BEFORE publishers), the host-OS permission model and socket-mount requirements, and the operational error taxonomy (container fails to start / no telemetry arriving / consumer doesn't receive).
kind: library
---

# DOCA Telemetry Service (DTS)

**Where to start:** This skill is for *operating* DTS, not for
*linking against* a library. If the user wants to *deploy* or *run*
the container, open [`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure). If the question is *what
shape of service is DTS and what does it do in the DOCA telemetry
ecosystem*, start at [`CAPABILITIES.md`](CAPABILITIES.md). If DOCA
is not installed on the BlueField target yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. If the user is
confused about whether they want this service, the
[`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) library
(custom collector), or the
[`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
library (publisher), read the triple-skill split in
[`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
BEFORE deploying anything.

## Example questions this skill answers well

The CLASSES of DTS questions this skill is built to answer, each
with one worked example. The class is the load-bearing piece; the
worked example is one instance.

- **"Which artifact do I want — DTS, doca-telemetry, or
  doca-telemetry-exporter?"** — worked example: *"I have a DOCA
  application emitting events on the DPU; I want a bundled
  Prometheus-friendly aggregator on the same DPU; do I deploy a
  service, or do I link a library?"*. Answered by the triple-
  skill split in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the path-selection bullet, which names DTS as the
  pre-baked aggregator the user *deploys* and routes the
  publisher / custom-collector questions to the matching
  library skills.
- **"Where does DTS run, and what does deploying it actually
  mean?"** — worked example: *"I have a BlueField-3 with DOCA
  installed on the Arm side; what container do I pull, where do
  I mount its config, and which container runtime do I use?"*.
  Answered by the deployment-shape table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the workflow in [`TASKS.md ## configure`](TASKS.md#configure)
  step 3 (which cross-links the canonical DOCA Container
  Deployment Guide rather than re-inventing the deployment
  pattern).
- **"How do I wire up the YAML/JSON config to tell DTS which
  sources to collect from and which sinks to forward to?"** —
  worked example: *"I want DTS to ingest from a local
  doca-telemetry-exporter-using app on the same DPU and forward
  to a Prometheus consumer on the host"*. Answered by the
  config-shape walkthrough in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  config-surface table + the per-source / per-sink wiring in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"My publisher emits but DTS sees nothing — where do I
  start?"** — worked example: *"my doca-telemetry-exporter app
  reports every emit as success but DTS's forwarded stream is
  empty"*. Answered by the publisher-up vs DTS-up staging rule
  in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the publisher-socket mount row in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the end-to-end single-event smoke loop in
  [`TASKS.md ## test`](TASKS.md#test).
- **"DTS is forwarding but my Prometheus / NetFlow / IPFIX
  consumer doesn't see anything — was it the sink config or the
  consumer?"** — worked example: *"DTS container logs show
  events flowing, but my Grafana dashboard is flat"*. Answered
  by the layered error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the consumer-side layer in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"My DTS container failed to start — where do I look?"** —
  worked example: *"`crictl ps` shows the container in a
  restart loop; `crictl logs` shows a config-parse error"*.
  Answered by the container-lifecycle row in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the runtime-class debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) layer Container, plus
  the env-class fallback in
  [`doca-setup`](../../doca-setup/SKILL.md) when the failure is
  at the host / image-pull / runtime layer.

## Audience

This skill serves **external operators and platform teams who
deploy and operate DTS** as the bundled DOCA telemetry collector
on BlueField — i.e., people pulling the DTS container image,
mounting its YAML/JSON config, picking a container runtime
(`crictl` / `kubelet` / SystemD container unit / manual runtime),
wiring DOCA-using applications as publishers, and pointing one or
more downstream consumers (Prometheus / NetFlow / IPFIX / custom
dashboards / the DOCA Log Service) at the DTS sink surface.

It is **not** for NVIDIA developers contributing to DTS itself,
and it is **not** a programming guide for *building applications
on top of* DOCA libraries (that is `doca-programming-guide` plus
the matching library skill under `libs/`). DTS is a **service**,
not a library: the user *deploys* a container and operates it; the
user does NOT link `libdts.so` to write their own program. If the
user genuinely needs a custom collector built into their own
binary, route to
[`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) (the C
library a custom consumer would link against). If the user needs
to PUBLISH events from their own DOCA application, route to
[`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md).
This skill is the middle of that triple: a pre-baked aggregator
operators deploy rather than write.

## When to load this skill

Load this skill when the user is doing **hands-on DTS deployment
or operation work** against a BlueField target where DOCA is
already installed and a container runtime is available.
Concretely:

- Deploying the DTS container on BlueField Arm via `crictl` /
  `kubelet`, via a SystemD container unit, or via manual
  container-runtime invocation for lab use.
- Authoring the YAML/JSON config file that governs which
  telemetry sources DTS pulls from, which sinks/forwarders it
  attaches to, sampling rates, and schema-version pinning.
- Mounting the host telemetry sockets (under `/var/run/...` or
  similar) into the container so DTS can ingest from local
  publishers (apps linking
  [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)).
- Wiring DTS as the aggregator feeding a Prometheus exporter,
  NetFlow / IPFIX collector, a custom dashboard, or the DOCA
  Log Service downstream.
- Sequencing service bring-up under the **start-order rule**:
  DTS up BEFORE publishers, so that publishers do not drop or
  buffer-bounded events while DTS is missing.
- Diagnosing a DTS deployment that is misbehaving — container
  failed to start, container running but no telemetry arriving
  from publishers, telemetry arriving but downstream consumer
  not receiving.
- Choosing between deploying DTS and an adjacent option (linking
  [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) for a
  custom in-app collector; using
  [`doca-log`](../../libs/doca-log/SKILL.md) + journalctl for
  one app's plain logs; a pure host-side metrics stack with no
  DPU context).

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, library-API questions, or the application-side
publish or custom-collect surfaces. For those, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the matching
`libs/<library>` skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — the DTS deployment shape (container, runs
  on BlueField Arm), the triple-skill split (exporter publishes
  → DTS aggregates → downstream consumer) that operators MUST
  understand before deploying, the supported container-runtime
  paths (`crictl` / `kubelet`, SystemD container unit, manual
  runtime — all anchored on the public DOCA Container
  Deployment Guide rather than re-invented here), the YAML/JSON
  config-surface shape (sources / sinks / sampling / schema-
  version pinning), the host-OS permission model and socket-
  mount requirements, the operational error taxonomy (container
  lifecycle / publisher ingest / downstream sink / library), the
  observability surface (container logs, DTS-side counters,
  downstream consumer reception), and the safety / staging
  policy (DTS up before publishers, single-event smoke before
  scaling, do not invent container image names).
- `TASKS.md` — step-by-step workflows for the in-scope DTS
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`,
  plus a `Deferred task verbs` block routing out-of-scope
  questions (writing the publisher, writing a custom collector,
  installing DOCA, configuring the downstream consumer's own
  dashboard).

The skill assumes a BlueField target where DOCA is already
installed, a container runtime is available, and the operator has
the host-OS permissions the DOCA Container Deployment Guide names
for the chosen runtime path. It does not cover installing DOCA —
that path goes through
[`doca-setup`](../../doca-setup/SKILL.md) — and it does not
re-document the container deployment pattern, which is the
canonical concern of the DOCA Container Deployment Guide reached
through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a templates or sample-config
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-baked DTS configuration files** (full YAML/JSON config
  files, ready-to-mount source/sink wirings, schema-version-
  pinned fragments) intended to be copy-pasted into production.
  Configs are deployment-specific and the safe answer for an
  external operator is to derive them from the public DTS guide
  against their own target. The agent's job is to prescribe the
  *procedure* and quote the documented config fields, not to
  ship a config the user might run unmodified.
- **Container image names and tags.** The canonical image
  source for any DOCA service container is the public DOCA
  Container Deployment Guide and the NGC catalog; the agent
  routes through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the current image string and tag rather than quoting one
  from memory. Inventing an image name (e.g.
  `nvcr.io/nvidia/doca/doca-telemetry-service:latest`) is the
  load-bearing first-app failure for this skill.
- **Downstream-consumer dashboards** (Prometheus scrape configs,
  Grafana dashboards, NetFlow / IPFIX analyzer rules). Those
  are governed by the downstream-consumer ecosystem and out of
  scope here. The skill teaches the agent to confirm reception
  on the consumer side as the end-to-end smoke; it does not
  ship the dashboard.
- **A `samples/`, `templates/`, or `reference/` subtree** of
  any kind. A mock or incomplete artifact in this skill's tree,
  even one labeled "reference", is misleading: operators will
  read it as production-ready.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in scope.
2. **For the DTS deployment shape, the triple-skill split
   (exporter → DTS → downstream consumer), the container-runtime
   path inventory, the YAML/JSON config surface, the host-OS
   permission model, the error taxonomy, the observability
   surface, and the safety / staging policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  — the routing table to the public DTS guide
  (`https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Service-Guide/index.html`),
  the public DOCA Container Deployment Guide
  (`https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html`),
  the NGC catalog page for the DTS container image, and the
  rest of the public DOCA documentation set. This skill does
  not duplicate either guide; it points at them and adds the
  DTS-operator overlay.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation
  and install verification on the BlueField target where DTS
  will run, including the *I have no install yet* path via the
  public NGC DOCA container. This skill assumes its
  preconditions are satisfied at the BlueField target.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule + the
  headers-win-over-docs rule and adds the DTS-specific
  container-tag-vs-host-package overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  — the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) — the
  **collector** library a CUSTOM consumer would link against to
  receive telemetry directly. Rarely needed when DTS is the
  collector. This skill's path-selection rule routes there when
  the user actually needs a bespoke in-process collector rather
  than a pre-baked aggregator.
- [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md)
  — the **publisher** library DOCA applications use to emit
  events that DTS then collects. The agent MUST teach the
  triple-skill split (exporter publishes → DTS aggregates →
  downstream consumer) before configuring DTS sources, and MUST
  teach the start-order rule (DTS up BEFORE publishers).
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  — general DOCA patterns. DTS is service-shaped not
  library-shaped, so the build / modify / first-app pattern
  there does not apply directly, but the cross-library
  `DOCA_ERROR_*` taxonomy and the layered-debug order remain
  useful when DTS surfaces errors that originated in a DOCA
  library or in a publisher's exporter context.
