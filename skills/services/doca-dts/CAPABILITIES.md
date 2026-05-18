# DOCA Telemetry Service — Capabilities

**Where to start:** The pattern overview below names the recurring
DTS-class operational patterns. Pick the pattern first, then drill
into the H2 that owns the substance. For the *how* of executing
each pattern, jump to [TASKS.md](TASKS.md).

This file enumerates DTS's documented capabilities, deployment
shapes, configuration surface, and operational behaviors as
described in the public DTS guide on `docs.nvidia.com`. Treat it as
a *map of what is documented*, not a substitute for reading the
live page when standing up a real deployment.

## Pattern overview

Every DTS-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
deployment shape and every downstream-consumer choice, not just one
specific topology.

| DTS pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Recognise this is a SERVICE (deploy / operate), not a library (link / compile) | The user runs a container; the user does NOT link `libdts.so`. The custom-collector path is [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md), the publisher path is [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md) | [`## Capabilities and modes`](#capabilities-and-modes) triple-skill-split table |
| 2. Pick the deployment-runtime path | `crictl` / `kubelet` (BlueField runs k8s); SystemD container unit (standalone); manual container-runtime invocation (lab use). All three are anchored on the public DOCA Container Deployment Guide | [`## Capabilities and modes`](#capabilities-and-modes) deployment-shape table |
| 3. Author the YAML/JSON config that wires sources → DTS → sinks | Config governs which publishers DTS pulls from, which downstream sinks/forwarders it attaches to, sampling rates, schema-version pinning | [`## Capabilities and modes`](#capabilities-and-modes) config-surface table |
| 4. Honor the start-order rule | DTS up BEFORE publishers; otherwise publishers either drop events or buffer bounded per the exporter's own contract | [`## Safety policy`](#safety-policy) start-order row |
| 5. Read DTS's observability surface | Container runtime logs (`crictl logs`, `journalctl -u <unit>`), DTS-side counters, downstream-consumer reception as the end-to-end signal | [`## Observability`](#observability) |
| 6. Map a DTS failure back to its layer | Container failed to start vs. publisher socket not mounted (no ingest) vs. downstream sink misconfigured (consumer doesn't receive) vs. library-internal `DOCA_ERROR_*` | [`## Error taxonomy`](#error-taxonomy) layered split |

Two cross-cutting rules that apply to *every* pattern above:

- **Operate the documented path; do not invent one.** Image
  names, image tags, config field names, sink protocols, and
  container-runtime invocations all come from the public DTS
  guide and the DOCA Container Deployment Guide reached through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  Inventing an image string like
  `nvcr.io/nvidia/doca/doca-telemetry-service:latest` from
  memory is the most common hallucination failure for this
  skill.
- **Triple-skill split first, every time.** Before recommending
  any DTS deploy step, the agent must surface the three-way
  distinction: publishers
  ([`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md))
  emit events into DTS; DTS aggregates and re-publishes onto
  the configured sinks; downstream consumers (Prometheus /
  NetFlow / IPFIX / the DOCA Log Service / custom dashboards)
  receive the aggregate. Confusing any two of the three is the
  load-bearing first-app failure.

## Capabilities and modes

### Deployment shape — container on BlueField Arm

DTS is a **long-running container / daemon** that runs on the
BlueField Arm cores. The DOCA host packages do not provide a DTS
binary the operator launches directly; the canonical artifact is
the container image listed on the public DTS guide and reachable
through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
Operators do NOT link a `lib<dts>.so` into their own program.

| Property | What it means for the operator |
| --- | --- |
| Shape | Container image (one container = one DTS instance). Same model as other DOCA services per the public DOCA Container Deployment Guide. |
| Where it runs | On the BlueField Arm cores. Not on the host. The host is a downstream consumer of what DTS forwards, not a place DTS runs. |
| What it does | Pulls telemetry from configured sources (DOCA applications using [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md), system metrics, DPU hardware counters), aggregates, and re-publishes onto configured sinks (Prometheus / NetFlow / IPFIX collectors, custom dashboards, the DOCA Log Service). |
| What it does NOT do | Publish telemetry from its own application logic; provide a custom collector API a user binary links against (use [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) for that); replace the downstream-consumer ecosystem (Prometheus / Grafana / NetFlow analyzers all remain governed by their own ecosystems). |

### Triple-skill split — publisher / aggregator / downstream consumer

The DOCA telemetry pipeline is THREE distinct artifacts, and the
agent MUST surface the split before any DTS-specific guidance.

| Role | Artifact | Where it lives | Skill |
| --- | --- | --- | --- |
| Publisher | DOCA application linking `doca-telemetry-exporter` to emit events (counters / gauges / events) shaped by a registered schema | Inside the user's own DOCA-using program, running as that program's user | [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md) |
| Aggregator (THIS skill) | DTS container on BlueField Arm — pulls from one or more publishers, aggregates / samples / forwards | Container on BlueField Arm, deployed via `crictl` / `kubelet` / SystemD container unit / manual runtime per the DOCA Container Deployment Guide | this skill, `doca-dts` |
| Downstream consumer | Prometheus scrape endpoint / NetFlow or IPFIX collector / Grafana dashboard / custom analyzer / the DOCA Log Service | Wherever the operator wants — typically on the host, sometimes on a separate observability stack | downstream ecosystems (not a DOCA skill) |

The custom-collector path is distinct: if the user wants their own
binary to *receive* DOCA telemetry events directly (without DTS in
the middle), the right artifact is the
[`doca-telemetry`](../../libs/doca-telemetry/SKILL.md) library —
*rarely* needed if DTS is acceptable as the aggregator. The
agent's job is to surface the choice, not pre-pick it.

### Container-runtime path inventory

The DOCA Container Deployment Guide documents three runtime paths
DTS deployments inherit; this skill does NOT re-invent the
deployment pattern, it points at the guide and overlays the
DTS-specific touchpoints.

| Runtime path | When to use | DTS-specific touchpoint |
| --- | --- | --- |
| `crictl` + `kubelet` | BlueField runs a small k8s control plane (the default for fleet deployments per the DOCA Container Deployment Guide) | The DTS YAML pod manifest names the image (per the public guide), mounts the config file, and mounts the host telemetry sockets so publishers on the same DPU can write to them |
| SystemD container unit | BlueField runs standalone (no k8s) and the operator wants persistent restart-on-failure semantics | The unit file invokes the documented container runtime with the documented image, the config-file mount, and the socket mounts |
| Manual container-runtime invocation | Lab use / bring-up only | The operator runs the documented container runtime by hand with the documented mounts; not appropriate for production |

For every runtime path, the canonical deployment pattern lives in
the DOCA Container Deployment Guide reached through
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
This skill cross-links there rather than re-documenting the
pattern; the DTS overlay is the config-file mount + socket-mount
contract above.

### Config-surface shape — YAML/JSON

DTS's behavior is governed by a YAML/JSON config file mounted into
the container. The public DTS guide is the source of truth for the
exact field names and schema; the table below names the *classes*
of knob the operator must reason about.

| Config class | What it governs | DTS-specific consideration |
| --- | --- | --- |
| Sources | Which publishers DTS pulls from (typically local-socket ingest from `doca-telemetry-exporter`-using apps on the same DPU; system-metrics ingest; DPU hardware-counter ingest) | The socket the publisher writes to must be mounted into the DTS container; the publisher's user must be able to write to it, the DTS container's user must be able to read it |
| Sinks / forwarders | Which downstream consumers DTS pushes the aggregate to (Prometheus scrape endpoint / NetFlow collector / IPFIX collector / custom dashboard / the DOCA Log Service) | The downstream consumer must be reachable from the BlueField; its protocol and port must match the sink config; the consumer must accept the schema DTS forwards |
| Sampling rates | How often DTS pulls / pushes; per-source sample rate; aggregation window | Lower sample rate = less DTS / network load but coarser-grained downstream view; the right value is workload-bound and the agent should NOT default to one without asking |
| Schema-version pinning | Which event schema version(s) DTS accepts from publishers and which it forwards to downstream sinks | A schema-version mismatch (publisher emits v2, DTS pinned to v1, consumer expects v2) is silent the same way the publisher / collector schema mismatch is — see the matching schema-must-match contract in [`doca-telemetry CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-telemetry/CAPABILITIES.md#capabilities-and-modes) |

The public DTS guide is the contract for the exact field names and
nested structure; quote field names from there, do not infer them
from generic YAML/JSON intuition.

### Authentication / permission model

DTS inherits the BlueField host-OS permission model. There is no
DTS-specific auth surface (PAM / mTLS / credentials) the operator
configures inside DTS itself; the access boundary is at the
container's mounts and the BlueField host OS.

- The DTS container needs **read access** to the host telemetry
  sockets so publishers can write into them and DTS can ingest.
  This is the most common operational error: the publisher
  emits, DTS sees nothing, because the socket is not mounted
  into the container or the container user cannot read it.
- The DTS container needs **network reach** to the configured
  downstream consumers. If the consumer is on the host, the
  container's networking must allow that egress.
- The agent does NOT prescribe sudo as a universal rule. The
  permission boundary is the container's mount + network spec
  per the DOCA Container Deployment Guide, not a missing
  capability on the DTS process.

### Path selection — when to deploy DTS vs adjacent options

| Use DTS when … | Use a different artifact when … |
| --- | --- |
| The user wants bundled telemetry collection on BlueField (no in-house collector code) | The user wants a CUSTOM in-process collector linked into their own binary — that is [`doca-telemetry`](../../libs/doca-telemetry/SKILL.md), the C library a custom consumer links against |
| The user wants to integrate DOCA telemetry into Prometheus / NetFlow / IPFIX dashboards via a pre-baked aggregator | The user is PUBLISHING events from their own DOCA app — that is [`doca-telemetry-exporter`](../../libs/doca-telemetry-exporter/SKILL.md), the publisher; DTS is the receiver, not the emitter |
| Multi-source telemetry aggregation on BlueField (one DTS pulling from many publishers + system + hardware counters) | The user's telemetry need is limited to one app's plain logs — that is [`doca-log`](../../libs/doca-log/SKILL.md) + `journalctl`; DTS's schema / sink / sampling discipline is overhead the user does not need |
| The telemetry source is DOCA / the DPU | The user wants pure host-side metrics with no DPU context — use a regular Prometheus / OpenTelemetry stack on the host directly; DTS only makes sense when the DPU is part of the telemetry picture |

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The DTS-specific overlay** is:

- **DTS is shipped as a container; the relevant version anchor
  is the container tag, not the host DOCA package version.**
  When the user is operating DTS, `pkg-config --modversion
  doca-common` on the host is NOT authoritative for what DTS
  contains; the DTS image tag pulled from the public catalog is.
  Confirm BOTH the host DOCA install version (per
  [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure))
  AND the DTS container tag, and treat a mismatch as a known
  partial-install pattern routed to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2.
- **The DTS container tag and the publisher's host DOCA
  package version must be compatible across the schema
  contract.** Per the schema-must-match contract documented in
  [`doca-telemetry CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-telemetry/CAPABILITIES.md#capabilities-and-modes),
  schema-version drift between publisher (host DOCA install)
  and DTS (container tag) is a silent ingest-loss / wrong-
  decode failure. Align the two sides' DOCA versions or run
  them at versions the install's compatibility policy
  guarantees.
- **Always verify against the live public DTS guide whose
  version corresponds to the container tag pulled.** Config
  field names and sink-protocol options can change between DTS
  releases; agent-memory quotes are not authoritative.

## Error taxonomy

DTS errors fall into FOUR layers, each with its own owner. The
agent walks the layers in this order; conflating them wastes debug
time and blames the wrong layer.

1. **Container-lifecycle layer.** The DTS container failed to
   start, or is in a restart loop. Symptoms: `crictl ps` shows
   the container exited or restarting; `crictl logs` shows a
   config-parse error, an image-pull error, or a mount error;
   `journalctl -u <unit>` shows the SystemD container unit
   failing to start. Causes: container image not present /
   wrong tag / unreachable registry; mounted config file
   missing or malformed; mounted socket path does not exist on
   the host; image version incompatible with installed DOCA
   per the version overlay above. Resolution: walk the
   container-class debug rail in
   [`TASKS.md ## debug`](TASKS.md#debug) layer Container and
   route to env-class debug in
   [`doca-setup`](../../doca-setup/SKILL.md) when the failure
   is at the host / image-pull / runtime layer.
2. **Publisher-ingest layer.** DTS is running but no telemetry
   is arriving. Symptoms: `crictl logs` shows DTS healthy and
   waiting, but the per-source counter stays at zero; the
   downstream consumer is empty. Causes: the publisher's
   socket is NOT mounted into the DTS container (the most
   common case); the publisher's user cannot write to the
   mounted socket; the publisher and DTS disagree on schema
   version (silent decode loss per the schema-must-match
   contract); the publisher has not started yet (staging
   issue — see [`## Safety policy`](#safety-policy)).
   Resolution: walk the publisher-side per-emit return on the
   publisher and the per-source counter in DTS together; the
   smoke loop in [`TASKS.md ## test`](TASKS.md#test) is the
   cheapest way to surface this BEFORE bulk traffic.
3. **Downstream-sink layer.** DTS is forwarding but the
   downstream consumer is empty. Symptoms: `crictl logs`
   shows DTS forwarding events; the Prometheus / NetFlow /
   IPFIX / Grafana / custom-analyzer consumer is flat.
   Causes: the consumer-side config does not point at the
   correct port / endpoint / auth; the consumer-side scrape
   protocol does not match DTS's sink protocol; the
   consumer-side schema expectation does not match what DTS
   forwards; network egress from BlueField to the consumer
   is blocked. Resolution: confirm reception on the consumer
   side independently (consumer logs / counters / scrape
   endpoint); the downstream consumer ecosystem owns the
   resolution from there.
4. **DOCA-library layer.** If DTS internally calls into a DOCA
   library that returns `DOCA_ERROR_*`, the cross-library
   taxonomy in
   [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy)
   becomes relevant on the *aggregator* side. In particular,
   if DTS's ingest layer reports back-pressure (the matching
   `DOCA_ERROR_AGAIN` overlay on the collector library), the
   publisher's own
   [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../../libs/doca-telemetry-exporter/CAPABILITIES.md#safety-policy)
   hot-path-drop-not-block rule says the publisher MAY drop
   instead of slowing down — the under-load loss is a
   two-sided concern and not solvable inside DTS alone.

DTS does not return `DOCA_ERROR_*` to the operator's shell — its
outward surface is a container's exit code, the runtime's logs,
and the per-source / per-sink counters DTS itself exposes. The
DOCA error taxonomy is for the operator diagnosing why an
internal ingest or forwarding step failed.

## Observability

Documented observability surfaces:

- **Container runtime logs.** The first place the agent looks
  for any DTS misbehavior. Reach via `crictl logs <id>` (when
  the runtime is `crictl` / `kubelet`), `journalctl -u <unit>`
  (when the runtime is a SystemD container unit), or the
  matching container-runtime command for the manual lab path.
  The public DTS guide names the log component the user is
  reading; this skill names the runtime command, not the
  in-DTS log format.
- **Per-source / per-sink counters DTS itself exposes.** Per
  the public DTS guide, DTS exposes its own operational
  counters (events ingested per source, events forwarded per
  sink, drops). These are the load-bearing signal for
  "publisher emitted but DTS saw nothing" vs "DTS ingested but
  consumer sees nothing"; quote the documented counter names
  from the public guide rather than inferring them.
- **Downstream-consumer reception (end-to-end).** The DTS-side
  observability is *necessary* but not *sufficient* — the
  user's true success signal is the downstream consumer
  receiving events with the expected schema. The smoke loop in
  [`TASKS.md ## test`](TASKS.md#test) (start DTS → start ONE
  publisher → emit ONE event → confirm the configured
  downstream consumer received it intact) is the bundle's
  end-to-end check before any bulk traffic.

For continuous detailed telemetry of the publisher's OWN
per-emit behavior, route to
[`doca-telemetry-exporter CAPABILITIES.md ## Observability`](../../libs/doca-telemetry-exporter/CAPABILITIES.md#observability).
For a custom in-process collector's per-consume status, route to
[`doca-telemetry CAPABILITIES.md ## Observability`](../../libs/doca-telemetry/CAPABILITIES.md#observability).

## Safety policy

DTS's safety surface is operational, not programmatic. The
documented posture:

- **Start-order rule: DTS up BEFORE publishers.** The
  load-bearing operational invariant for this service. If the
  DTS container is not running when a publisher starts emitting,
  the publisher either drops events or buffer-bounded per its
  own [`doca-telemetry-exporter CAPABILITIES.md ## Safety policy`](../../libs/doca-telemetry-exporter/CAPABILITIES.md#safety-policy)
  hot-path-drop-not-block rule. The agent MUST teach this rule
  before recommending any deploy step; "I deployed DTS after
  starting the app, why am I missing events" is the canonical
  first-app failure.
- **Single-event smoke BEFORE scaling.** A single emit on one
  publisher + a single confirmed reception at the configured
  downstream consumer, with the schema intact, is the cheapest
  way to prove the entire pipeline (mount + socket permission +
  schema + sink + downstream consumer) is correct. Skipping
  this step and going straight to bulk traffic is the most
  common reason "everything looks healthy but the dashboard is
  flat".
- **Do not invent container image names / tags.** Image
  strings come from the public DOCA Container Deployment Guide
  and the NGC catalog reached through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  Inventing one from memory is the load-bearing first-app
  failure; the operator will pull the wrong image, or fail to
  pull at all, and waste debug time on a fixable error.
- **Schema-version pinning is a safety choice.** The DTS
  config's schema-version field decides which publisher
  schemas DTS accepts; a permissive pin can accept events DTS
  will mis-decode, a strict pin will silently drop events from
  a publisher that drifted. Decide the policy explicitly when
  authoring the config, do not accept the default without
  understanding it.
- **The downstream consumer ecosystem owns its own safety.**
  Prometheus / NetFlow / IPFIX / Grafana / custom analyzers
  all have their own auth and rate-limit surfaces; DTS does
  not enforce them on the consumer's behalf. The agent
  surfaces this boundary so the operator does not assume DTS
  is the entire trust path.

## Public-source pointer

The single canonical public source for DTS is the **DOCA
Telemetry Service Guide** on `docs.nvidia.com` at
[`https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Service-Guide/index.html`](https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Service-Guide/index.html),
reachable through
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
The canonical deployment pattern lives in the **DOCA Container
Deployment Guide** at
[`https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html`](https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html);
this skill cross-links there rather than re-inventing the
deployment shape. Verify that the version of each guide matches
the DOCA install on the BlueField target and the DTS container
tag pulled — DTS surface is documented to evolve, so config field
names and sink protocols can change between releases.
