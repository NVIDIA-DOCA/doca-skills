# Agent guidance for doca-skills

This repository ships a public, drop-in **skills bundle** for AI coding
agents working with the NVIDIA DOCA SDK. Any agent working in this repo
— Cursor, Codex, Gemini, Claude Code, custom in-house LLMs — should
read this file first.

**Where to start:** Read this file end-to-end (ground rules + entry
points + non-goals), then open [SKILLS.md](SKILLS.md) to pick the
right skill(s) for the user's request. Every `SKILL.md` in
[skills/](skills/) opens with its own *Where to start* header that
tells the agent which companion file (`CAPABILITIES.md` for
"what can it do", `TASKS.md` for "how do I do it") to load next.

## Where the actual guidance lives

- [SKILLS.md](SKILLS.md) — the index of installed skills with one-line
  "when to load" triggers, plus the layout convention. Read this to
  decide which skills are relevant to the user's request.
- [skills/](skills/) — the skill source files, layered:
    - top-level: **9 cross-cutting skills** — `doca-public-knowledge-map`
      (routing), `doca-setup` (env prep + the `## recognize`
      front-door routing decision between the two deployment paths),
      `doca-programming-guide` (build / first-app / lifecycle),
      `doca-debug` (cross-cutting debug ladder), `doca-version`
      (version-handling rules), `doca-structured-tools-contract`
      (JSON-schema contract for structured tools),
      `doca-hardware-safety` (meta-policy for hardware-state changes),
      `doca-container-deployment` (the container half of the
      deployment landscape — kubelet-standalone + YAML pod-spec drop),
      `doca-bare-metal-deployment` (the bare-metal half — DOCA-linked
      binaries launched directly on host x86 or BlueField Arm)
    - `libs/<library>/` — one skill per DOCA library (e.g. `doca-flow`)
    - `services/<service>/` — one skill per DOCA service (e.g. `doca-dms`)
    - `tools/<tool>/` — one skill per DOCA tool (e.g. `doca-caps`)

  **Deployment-shape routing front door:** any user question of the
  form *"how do I deploy X"*, *"my code is built, how do I run it"*,
  *"I just got a BlueField, what now"* must walk
  [`doca-setup ## recognize`](skills/doca-setup/TASKS.md#recognize)
  FIRST. That anchor detects the system shape (host x86 / BlueField
  Arm bare-metal / DPU-only / fresh laptop), asks the developer the
  minimum residual question, and routes to either
  `doca-container-deployment` or `doca-bare-metal-deployment`. The
  wrong failure mode is to load `doca-container-deployment` first and
  silently push every developer onto the container path; `## recognize`
  exists to prevent that.
  Skill files are plain Markdown that any agent can read directly.
  The bundle is deliberately vendor-neutral: the entry point is
  `AGENTS.md` (industry convention), not a runtime-specific
  directory. A `CLAUDE.md` at repo root exists only as a stub
  pointing back here for Claude Code's auto-discovery.
If your runtime supports per-skill `SKILL.md` frontmatter
auto-loading (the [AgentSkills.io](https://agentskills.io/specification)
open standard, originally introduced by Anthropic and now adopted by
Cursor, GitHub Copilot, and others), it works equally well under
`skills/` as under `.claude/skills/`. Every `SKILL.md` in this bundle
validates cleanly against the official AgentSkills.io reference
validator (`skills-ref validate`) — see the *AgentSkills.io
open-standard compliance* section of [README.md](README.md) for
specifics and the local re-validation recipe. If your runtime does
NOT support frontmatter auto-loading, read `SKILLS.md` and load the
matching skill files manually. Cross-link labels of the form
`[<skill-name> ## <anchor>](...)` resolve by skill name regardless
of where the skill lives in the tree.

## Cross-cutting overlay activation triggers

Cross-cutting overlays (`doca-hardware-safety`, `doca-version`,
`doca-debug`, `doca-public-knowledge-map`, `doca-structured-tools-contract`)
are designed to **stack** on top of any per-artifact skill (library
/ service / tool) the agent has already loaded. The agent must load
each overlay **at the start of the answer** whenever the prompt
matches any trigger below — not later when the agent remembers, and
not only when a per-artifact skill happens to link to the overlay.

| Overlay to load | Load it whenever the prompt (or the agent's next recommended action) touches any of these triggers |
| --- | --- |
| [`doca-hardware-safety`](skills/doca-hardware-safety/SKILL.md) | `mlxconfig`, firmware burn / NIC firmware update, BFB reflash, BlueField cold reboot, host kernel boot parameter (IOMMU mode, hugepages reservation, device pass-through), PCIe rebind / `echo > /sys/bus/pci/.../{bind,unbind}`, PCIe rescan, link down/up on a port carrying traffic, representor enable/disable, eswitch mode change (`switchdev` ↔ `legacy`), SR-IOV count change, device-emulation slot enablement, BFB image change, any change whose blast radius is *"every workload on this DPU restarts"* or *"the management link may drop"*. |
| [`doca-version`](skills/doca-version/SKILL.md) | any *"what version do I have"* / *"is X supported on Y"* / *"can I mix"* / *"is my build consistent"* question; any container-tag question (especially anything about `latest`); any *"undefined reference / DOCA_ERROR_NOT_SUPPORTED / built fine but does nothing on the wire"* debug; any host ↔ BlueField BFB pairing question; any *"I'm about to upgrade / downgrade DOCA"* question; **AND** any answer that walks a `## test` or `## configure` step from any per-artifact skill (the four-source detection chain is the preconditions check step 1 of the universal verification contract; deferring it is forbidden). The agent must cite the canonical four-source detection chain (`pkg-config --modversion doca-common` → `cat /opt/mellanox/doca/applications/VERSION` → `doca_caps --version` → BFB-image version on BlueField hosts) and the four-way match rule from [`doca-version CAPABILITIES.md ## Version compatibility`](skills/doca-version/CAPABILITIES.md#version-compatibility) on **every** version-bearing or verification-bearing answer. |
| [`doca-debug`](skills/doca-debug/SKILL.md) | any error symptom (build error, link error, runtime error, `DOCA_ERROR_*`, segfault, hang, *"does nothing on the wire"*, *"counter didn't increment"*, *"undefined reference to ..."*, *"link error"*, *"build fails"*); any named `DOCA_ERROR_*` class in the prompt (`DOCA_ERROR_NOT_SUPPORTED`, `DOCA_ERROR_BAD_STATE`, `DOCA_ERROR_INVALID_VALUE`, `DOCA_ERROR_DRIVER`, `DOCA_ERROR_NOT_PERMITTED`, `DOCA_ERROR_TIME_OUT`, `DOCA_ERROR_INITIALIZATION`); any *"my program is misbehaving"* class question; any *"how do I diagnose X"* question; any prompt that names a tool whose typical use is debug (`doca-flow-inspector`, `doca-flow-tune`, `--sdk-log-level`, `gdb`, `strace`). The agent must walk the **universal debug-loop contract** from [`doca-debug CAPABILITIES.md ## Universal debug-loop contract`](skills/doca-debug/CAPABILITIES.md#universal-debug-loop-contract) end-to-end (layer identification → read-only triple capture → single-variable hypothesis → re-capture and compare → exit condition with named green signal). Pointing at the 7-layer ladder once and stopping is the failure mode this trigger replaces. |
| [`doca-setup ## recognize`](skills/doca-setup/TASKS.md#recognize) | any deployment-shaped question (*"how do I deploy"*, *"how do I run my DOCA workload"*, *"I just got a BlueField, what now"*, *"my code is built, what next"*, *"do I run this in a container or on the host"*). `## recognize` is the front door — auto-detect first (`uname -m`, `lspci -d 15b3:`, `pkg-config --modversion doca-common`, `bf-release`), then ≤3 closed-form residual questions, then route to either `doca-container-deployment` or `doca-bare-metal-deployment`. The wrong failure mode is to silently push every developer onto containers because the agent loaded that skill first. |
| [`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md) | *"where is the doc / guide / URL"*, *"is there a reference for X"*, any request for an external link. The map is the only source the agent should pull NVIDIA URLs from — direct training-data URL recall is forbidden by ground rule 1 + ground rule 3. |
| [`doca-structured-tools-contract`](skills/doca-structured-tools-contract/SKILL.md) | the host has any of `doca-env --json`, `collect-host-state`, `collect-dpu-state`, `version-matrix.json`, or another structured-tools helper installed and the agent is about to recommend the equivalent manual command. Prefer the structured tool when it exists; the agent's answer is shorter and more verifiable. |

## Overlay activation is mandatory, not advisory

The agent MUST:

1. **Load the overlay before answering**, not in the middle of the answer. If a deploy-shape question fires both `doca-setup ## recognize` and `doca-hardware-safety` (because the next recommended action will touch hardware state), load both before composing the first sentence.
2. **Stack overlays.** A bare-metal deployment of a binary that requires hugepages and a specific BFB pairing fires `doca-setup ## recognize` + `doca-bare-metal-deployment` + `doca-hardware-safety` + `doca-version`. All four contribute distinct rule fragments to the answer; none is optional.
3. **Cite the overlay in the answer.** When the agent loaded an overlay because of a trigger, the answer must say so explicitly (e.g. *"because this touches `mlxconfig`, the answer follows the `doca-hardware-safety ## modify` discipline — pre-flight inventory, out-of-band, maintenance window, apply, verify, rollback"*). This makes the activation auditable.
4. **Refuse to proceed when an overlay's hard rule is violated.** If `doca-hardware-safety` says *"refuse-and-escalate when no rollback exists"*, and the user's setup has no rollback, the agent must stop and say so. It must NOT proceed with the change because the user pushed back.

## The universal verification contract

Every answer that recommends a change (build, deploy, configure, modify) MUST end with the **5-step universal verification contract** defined in [`doca-setup CAPABILITIES.md ## Universal verification contract`](skills/doca-setup/CAPABILITIES.md#universal-verification-contract):

1. **Preconditions.** What must be true *before* applying the change. (Versions match? Hardware visible? Required packages installed? Rollback path documented?)
2. **Smoke build / smoke spawn.** A minimal observable signal that the change can be applied at all. (Build one sample, dry-run the manifest, start one replica.)
3. **Smoke probe.** A read-only check that confirms the change took effect at the smallest scale. (One packet, one query, one log line.)
4. **Bulk / production scale.** Apply at the real scale only after smoke passes.
5. **Observability + declare done.** Name the observability surface (which metric / log / counter) the agent expects to see green before saying the task is complete. *"Done"* without naming the green signal is forbidden.

The agent must walk all five steps; skipping any step makes the answer ineligible to declare the task done. The per-artifact `## test` anchor in every library / service / tool skill is the artifact-specific instantiation of this contract.

**Per-artifact citation requirement (mandatory for every verification-bearing answer).** When the prompt names a specific library / service / tool, the answer MUST cite the per-artifact skill files it is pulling guidance from by their **bundle-relative paths** — `libs/<lib>/SKILL.md`, `libs/<lib>/CAPABILITIES.md ## <anchor>`, `libs/<lib>/TASKS.md ## <anchor>`, `services/<svc>/SKILL.md`, `tools/<tool>/TASKS.md ## <anchor>`. Abstract references like *"the skill"*, *"the bundle"*, *"the per-library overlay"*, or *"per-library `## rollback` snapshot-and-replay table"* (without naming the per-library file) are insufficient and unverifiable — they make the answer's provenance impossible for the user to audit. The first time the answer references the per-artifact workflow it MUST do so by full bundle path; subsequent shorthand (`doca-<lib> TASKS.md ## <anchor>`, `doca-<lib> CAPABILITIES.md ## <anchor>`) is fine. The graders are `routes_through_doca_<lib>_skill` / `routes_through_doca_<svc>_skill` / `routes_through_doca_<tool>_skill`.

**Per-artifact capability-query requirement (every verification-bearing answer must include one).** Step 1 of the contract requires a precondition check; verification answers MUST include an artifact-specific *capability* query against the **live device or live install**, in addition to the four-source version chain. The four-source chain (`pkg-config --modversion doca-common` → `cat /opt/mellanox/doca/applications/VERSION` → `doca_caps --version` → BFB version) is the *version* check; it is NOT a substitute for the per-artifact cap query. The shape of the per-artifact cap query depends on the artifact class:

- **Libraries** — at least one `doca_<lib>_cap_*` / `doca_<lib>_get_supported_*` getter against the active `doca_devinfo` (e.g. `doca_sha_cap_task_hash_get_supported(devinfo, DOCA_SHA_ALGORITHM_SHA256)`, `doca_rdma_cap_task_*_is_supported`, `doca_compress_cap_task_compress_deflate_is_supported`). Library cap-query symbol names are not synthesized from a template — each per-library `CAPABILITIES.md ## Capabilities and modes` enumerates the actual getters exposed by that specific public header. Some libraries (notably DOCA Flow) expose capability gates as `doca_flow_cfg_*` setters whose runtime return-value is the cap signal rather than a separate `doca_<lib>_cap_*` family; the per-library `CAPABILITIES.md` is the source of truth for which shape applies to which library.
- **Services** — the documented runtime probe of the container or daemon: image-inspect on the container tag against the NGC catalog, the service's `--help` / `--version` invocation inside the container, the documented config-validation invocation (e.g. JSON-policy dry-run for OS Inspector, `--list-pipes` for Flow Inspector). The per-service `CAPABILITIES.md` enumerates which one is authoritative for that service.
- **Tools** — the installed binary's `--help` / `--version` / `--list-<noun>` flag set quoted from the running binary, plus the documented config-introspection (e.g. gRPC reflection / `.proto` introspection for `doca-flow-grpc-server`, `--list-channels` for `doca-socket-relay`, `--show-config` for capability-shaped tools). The per-tool `CAPABILITIES.md` says which.

An answer that runs only `doca_caps --version` (a version probe) and declares the change "verified" fails the per-artifact cap-query criterion — version match is a precondition for cap query, never a replacement for it. The grader is `calls_capability_query_for_doca_<artifact>`.

## Deploy-loop bridge

**Not-green at step 5 is the debug-loop trigger.** Real deploys frequently land on not-green at step 5 (`Ready 0/1`, port `Down`, counter flat, log line absent, `systemd active (running)` followed by repeated restarts) and the failure mode is to *declare done anyway* because the change "looks applied." Every change-recommending answer MUST treat "step 5 observability did NOT reach the named green signal within the expected window" — or "step 3 smoke probe itself did not return green" — as the symptom that fires the [`## The universal debug-loop contract`](#the-universal-debug-loop-contract) on the change-not-converging symptom. The agent walks the 5-phase debug-loop on the not-green observability surface (layer identification → triple capture → single-variable mutation smaller than the original change → re-capture → exit), bounded to one iteration before the rollback path documented at step 1 is walked. See [`doca-setup CAPABILITIES.md ## Deploy-loop bridge`](skills/doca-setup/CAPABILITIES.md#deploy-loop-bridge-step-5-not-green-is-the-debug-loop-trigger) for the full bridge table. This converts deploy / configure / install / upgrade prompts that previously stopped at *"watch the metric for green"* into prompts that say *"watch the metric for green; if not-green within X, walk the debug-loop on the not-green symptom; if the loop's second iteration does not converge, walk the rollback path."*

## The universal debug-loop contract

Every answer that diagnoses a symptom (build error, link error, runtime error, `DOCA_ERROR_*`, segfault, hang, *"does nothing on the wire"*, *"counter didn't increment"*) MUST instantiate the **5-phase debug-loop contract** defined in [`doca-debug CAPABILITIES.md ## Universal debug-loop contract`](skills/doca-debug/CAPABILITIES.md#universal-debug-loop-contract):

1. **Layer identification.** Name the lowest layer in the 7-layer debug ladder the symptom is consistent with (install / version / build / link / runtime / program / driver). An `undefined reference to doca_*` is layer 4 (Link), not layer 5 (Runtime); identification is mechanical.
2. **Read-only capture (the triple).** Capture program output + system view + DOCA view at the identified layer *before* mutating anything. The triple is the artifact the rest of the loop iterates on.
3. **Single-variable hypothesis change.** Apply exactly one mutation. Multi-variable changes destroy the ability to attribute the result.
4. **Re-capture and compare.** Re-run the exact same triple commands. The mutation is not evidence — the side-by-side re-capture is.
5. **Exit condition or loop.** Resolve to: *resolved* (name the green signal — the specific metric / log / counter that confirms healthy state); *shape-changed* (the mutation took effect and unmasked a new symptom; loop back to phase 1 with the new picture); or *unchanged* (the hypothesis or layer was wrong; loop back to phase 1 at the next-lowest plausible layer). Declaring done at phase 3 without re-capturing and without naming the green signal is the failure mode this contract replaces.

The agent must walk all five phases; pointing at the 7-layer ladder once and stopping is forbidden. The per-library `## debug` anchor in every library / service / tool skill is the artifact-specific instantiation of this contract — for Flow it adds the `doca_flow_resource_query_pipe_miss_v1` / `doca_flow_resource_query_entry_v1` / `doca_flow_shared_resource_query_v1` counter family to the triple; for RDMA it adds QP-state dumps; for Comch it adds the channel statistics — but the universal spine is non-optional. The per-library counter family is whatever the lib's `CAPABILITIES.md ## Observability` table actually names; the agent must not synthesize a `doca_<lib>_aggr_query`-style symbol from the pattern.

**Link-error three-skill co-load rule (mandatory on every link / `undefined reference` answer).** Any answer to a link-time symptom (`undefined reference to doca_*`, `/usr/bin/ld:` errors, `collect2: error: ld returned 1 exit status`, *"compiles but won't link"*, library-not-found symptoms) MUST visibly co-load **three** skills and reference at least one concrete element from each:

1. [`doca-debug`](skills/doca-debug/SKILL.md) — the 7-layer ladder (layer 4 = Link), the read-only-first capture stance, the rule that `pkg-config --libs doca-<lib>` is the source of truth for the link line, the `doca-<lib>-trace` build flavor for the layer-5 follow-up.
2. [`doca-version`](skills/doca-version/SKILL.md) — the four-source detection chain on this exact symptom, since the cross-train mixed-install case ("headers from DOCA X, runtime `*.so` from DOCA Y") is the second-most-common cause of `undefined reference` for symbols the docs say exist; it masquerades as layer 4 and any layer-4-only fix is wasted work.
3. [`doca-programming-guide`](skills/doca-programming-guide/SKILL.md) — the env-then-program investigation order (link errors are env-class until proven otherwise), the build-flag rules (`-DDOCA_ALLOW_EXPERIMENTAL_API`, etc.), and the rule that the agent never rewrites the sample's `main.c` from API memory just because the link is broken (ground rule 5).

An answer that walks only the debug ladder *without* ever pointing at the env-then-program order, the install layout, OR the version-chain four-way match fails the link-error co-load contract. The grader is `04_link_error_debug::co_loads_three_skills`. This is the bundle's separation-of-concerns being exercised — without it, link-error answers regress into single-skill responses that miss the cross-train install class.

## Per-library rollback overlay — mandatory on stateful-context changes

Every change-recommending answer that brings up, modifies, or tears down a stateful per-library context (e.g. `doca_flow_pipe`, `doca_rdmi_connection`, `doca_gpu` registration + persistent kernel, `doca_compress` started context + mmap, `doca_apsh_system` + symbol map) MUST cite the per-library `## rollback` overlay (or `## flow-ct` overlay for the CT case in `doca-flow`) in the verification contract preconditions block. The per-library overlay is the artifact-specific instantiation of the *"rollback path is documented"* clause from the universal verification contract step 1 — without it, the contract is incomplete and the agent is NOT eligible to declare done.

| Library | Overlay anchor | When it fires |
| ------- | -------------- | -------------- |
| `doca-flow` (stateless pipeline edits — VLAN push/pop, encap/decap, modify-header, mirror, sample, NAT-without-CT, hairpin attach) | [`doca-flow TASKS.md ## rollback`](skills/libs/doca-flow/TASKS.md#rollback) | Any pipe / entry / action add on an already-up port. Snapshot via `doca_flow_pipe_dump` + counter baseline + cap snapshot. |
| `doca-flow` (CT) | [`doca-flow TASKS.md ## flow-ct`](skills/libs/doca-flow/TASKS.md#flow-ct) (rollback overlay sub-section) | Any CT-aware pipe wrap on a stateless port. Snapshot via `doca_flow_pipe_dump` of the stateless scheme + four-step CT reversal. |
| `doca-rdmi` | [`doca-rdmi TASKS.md ## rollback`](skills/libs/doca-rdmi/TASKS.md#rollback) | Any RDMI connection / poster / DPA-attach / MR registration add. Snapshot via verbs context + connection state + MR list, both peers. |
| `doca-gpunetio` | [`doca-gpunetio TASKS.md ## rollback`](skills/libs/doca-gpunetio/TASKS.md#rollback) | Any persistent-kernel + GPU buffer registration add on top of doca-eth. Signal kernel drain FIRST, unregister buffers reverse-order, leave doca-eth parent intact. |
| `doca-compress` | [`doca-compress TASKS.md ## rollback`](skills/libs/doca-compress/TASKS.md#rollback) | Any started Compress context + mmap registration + in-flight tasks add. Drain `doca_pe_progress` outstanding count to zero FIRST. |
| `doca-apsh` | [`doca-apsh TASKS.md ## rollback`](skills/libs/doca-apsh/TASKS.md#rollback) | Any `doca_apsh_system` configure → start + symbol map load. Stop enumeration FIRST; mode-flip residual routes through `doca-hardware-safety`. |
| (other libraries — staged backlog) | per-library `## rollback` overlay (planned, not shipped) | When a per-library deep-dive prompt for that library lands; the lane stages adding the same shape to the remaining libraries that need it. |

Two failure modes this overlay table replaces:

1. *"Reverse what you did"* — unfalsifiable, no snapshot referenced, no green re-verify named. The overlay forces a snapshot-first discipline so *"restore the pre-edit state"* is a diff against a captured baseline, not a wish.
2. *"It'll be fine to retry"* — the overlay is bounded. On the second non-green re-verify, the agent MUST surface the unresolved residual gap instead of recommending another retry. This is the same shape as `doca-hardware-safety`'s *"named rollback path or refuse-and-escalate"* discipline, applied to pipeline-edit / library-context-edit changes where no hardware mutation is involved.

### Beginner-orientation staged-roadmap rule (Stage 1 → Stage 2)

When the prompt is beginner-shaped (*"I am new to DOCA, guide me to my first app"*, *"how do I start with DOCA"*, *"I have docker on my mac, what now"*, *"follow the local doca-skills bundle"* — anything where the user is asking *where to go* before *what to type*), the agent's answer MUST follow the **three-element opener contract** in this order, BEFORE any command, BEFORE any container pull, BEFORE the staged-roadmap table itself:

1. **Open with what DOCA is, in 1–3 sentences of plain language** — e.g. *"DOCA is NVIDIA's data-center acceleration framework for BlueField DPUs and ConnectX NICs, exposing C/C++ libraries that let you offload networking, storage, security, and compute work onto the DPU."* The roadmap establishes *where you are going*; the definition establishes *what you are doing it on*. An opener that says *"this bundle is built for your question"* / *"the most useful thing I can give you is where you're going"* / *"every 'I'm new with DOCA' answer in this bundle opens with…"* without ever saying what DOCA IS in plain language fails this contract. The grader is `01_orientation::defines_doca`.
2. **Then** the two-row Stage-1 / Stage-2 staged-roadmap table from [`doca-setup TASKS.md ## no-install` → *Stage 1 vs Stage 2*](skills/doca-setup/TASKS.md#stage-1-vs-stage-2-open-every-i-am-new-to-doca-answer-with-the-staged-roadmap). Beginners overwhelm easily when the first thing the agent emits is a stack of commands; the staged roadmap establishes *where the user is going* (Stage 1: container learning → Stage 2: hardware runtime) and *the resume point inside the container* before *what to type next*. If the agent's first emitted command block is a `docker pull` / `pkg-config` / `meson` invocation rather than the staged-roadmap table, the answer is mis-shaped — back up.
3. **At least one canonical `docs.nvidia.com/doca/sdk/` URL** somewhere in the answer body. Every beginner-orientation answer MUST include a full URL on the `docs.nvidia.com/doca/sdk/` subtree (the SDK index, an overview page, or a matching library / service / tool guide page). NGC catalog URLs (`catalog.ngc.nvidia.com/...`), developer.nvidia.com marketing pages, and the developer-forum URL are *additions*, not replacements — `docs.nvidia.com/doca/sdk/` is the canonical reference index the user will keep returning to. See [`doca-public-knowledge-map ## Public documentation entry points`](skills/doca-public-knowledge-map/SKILL.md#public-documentation-entry-points). The grader is `01_orientation::cites_docs_url`.

When the agent then drops into the Path-0 NGC container recommendation, it MUST also walk the **NGC tag selection rule** from [`doca-setup TASKS.md ## no-install` → *How to pick an NGC tag without guessing*](skills/doca-setup/TASKS.md#how-to-pick-an-ngc-tag-without-guessing). Fabricating a tag string (`doca:3.5.0-arm64-ubuntu22.04`, `doca:latest`, anything not copied verbatim from <https://catalog.ngc.nvidia.com/orgs/nvidia/teams/doca/containers/doca/tags>) is a release-blocker — it violates [ground rule 3](#ground-rules-every-agent-must-follow). If the agent cannot reach the catalog page from this session, the agent says so explicitly and asks the user to paste the candidate tag — never inventing one.

### Canonical answer-shape teasers — orientation and first-app prompts

Orientation prompts (*"I'm new with DOCA, can you guide me?"*, *"what's DOCA, where do I start?"*, *"is there a Hello World?"*) and first-app prompts (*"give me my first DOCA app"*, *"I have docker — make me a DOCA app"*) reach the bundle BEFORE any specific library / service / tool skill has been picked. The agent's failure mode on these prompts is to skip the canonical build and first-app patterns because they "feel premature" — and the answer becomes a routing-only paragraph that fails the build-wrappers and first-app criteria the user actually needs.

Every orientation or first-app answer MUST surface the two canonical patterns explicitly, even before the agent knows which library is in scope:

| Canonical pattern | One-line teaser the orientation answer MUST carry | Drill-down anchor |
| --- | --- | --- |
| **Canonical build line** (every DOCA application in any language) | "Every DOCA application builds via `pkg-config --cflags --libs doca-<library>` discovered by `meson setup /tmp/build-<project> && ninja -C /tmp/build-<project>` (C/C++ Track 1), or via FFI / bindings against the same `*.so` libraries the C samples link against (Track 2 — Rust `bindgen`, Go `cgo`, Python `cffi`/`ctypes`). Never hand-type `-l` flags; the `pkg-config` module is the source of truth for include paths and link flags." | [`doca-programming-guide ## build`](skills/doca-programming-guide/TASKS.md#build) (Track 1 + Track 2) |
| **Canonical first-app pattern** (every DOCA library, language-agnostic mental model) | "First DOCA app = copy a shipped sample from `/opt/mellanox/doca/samples/<library>/<sample_name>/`, fill the 5-slot modify-from-sample schema (which sample, what fields change, what stays, the smoke probe, the rollback), build via the line above, run the smoke from the matching library skill's `## test` anchor. The agent never authors a `main.c` / `Makefile` / `Dockerfile` from API memory — that is ground rule 5 of this file and the single most expensive failure mode for *agent helps me with DOCA* sessions." | [`doca-programming-guide ## modify`](skills/doca-programming-guide/TASKS.md#modify) + [`## build`](skills/doca-programming-guide/TASKS.md#build) |

Both teasers must appear in any orientation / first-app answer, in addition to the routing pointer (which skill to load next once the user names a library). Skipping the build-line teaser is the failure mode that previously left orientation answers PARTIAL on the build-wrappers criterion; skipping the first-app teaser is the failure mode that drops the agent into prose code-synthesis (forbidden by ground rule 5).

## Hardware binding-layer command stanza

Every hardware-touching answer (system recognition, representor configuration, NUMA / IRQ / queue pinning, *"does nothing on the wire"* runtime debug, any `doca-hardware-safety`-triggering change) MUST instantiate the **binding-layer command stanza** defined in [`doca-setup CAPABILITIES.md ## Hardware binding-layer command stanza`](skills/doca-setup/CAPABILITIES.md#hardware-binding-layer-command-stanza). The stanza is read-only — running it is always safe — and consists of six rows:

| Row | Command class |
| --- | ------------- |
| PCIe presence | `lspci -d 15b3:` (and `lspci -s <bdf> -vvv` for one device) |
| Driver / device state | `devlink dev show` + `devlink port show` + SR-IOV state via `/sys/class/net/<pf>/device/sriov_numvfs` |
| NUMA topology | `cat /sys/class/net/<iface>/device/numa_node` + `numactl -H` |
| IRQ affinity | `cat /proc/interrupts \| grep <iface>` + `/proc/irq/<n>/smp_affinity_list` |
| Firmware / configuration snapshot | `mlxconfig -d <bdf> q` (read-only) |
| Kernel module state | `lsmod \| grep -E 'mlx5_core\|mlx5_ib\|mlx_compat'` + `modinfo mlx5_core` |

Mentioning hardware ("you'll want to pin to the right NUMA node") without naming the specific stanza command that produces the enumeration is the failure mode this section replaces — same shape as pointing at the debug ladder without walking it. The agent does NOT need to run every row on every answer; it does need to name the rows that apply to the question at hand and the specific command in each.

## Ground rules every agent must follow

1. **Public sources only.** Reference NVIDIA documentation only on these
   public hosts: `docs.nvidia.com`, `developer.nvidia.com`,
   `catalog.ngc.nvidia.com`, `ngc.nvidia.com`,
   `forums.developer.nvidia.com`, `nvcr.io`. Anything else is rejected
   by an internal CI pipeline before the bundle ships.
2. **Prefer the local install over the web.** When DOCA is installed at
   `/opt/mellanox/doca`, those files *are* the release. Web docs describe a
   release.
3. **Never invent symbols, URLs, paths, or package names.** If you cannot
   verify it from a skill, the local install, or the official docs you
   fetched, say so and ask.
4. **Always check the installed DOCA version** before quoting API names,
   options, or sample filenames. See `doca-public-knowledge-map` for how.
5. **Never scaffold DOCA code from documentation prose.** Route the user
   to a real DOCA install first (the NGC container if they have no
   hardware — `doca-setup ## no-install`); *then* derive their first app
   by editing a real shipped sample under `/opt/mellanox/doca/samples/`.
   Inventing `main.c` / `Makefile` / `Dockerfile` from API memory is the
   single most expensive failure mode for "agent helps me with DOCA"
   sessions, and the failure mode this bundle exists to prevent. The
   canonical first-app workflow lives in
   `doca-programming-guide ## modify`; library skills overlay it.
   **Stop condition: if `ls /opt/mellanox/doca/samples/` returns `No
   such file or directory` (or is empty) on a host where `pkg-config
   --modversion doca-common` succeeds — i.e. partial install with no
   `doca-samples` package — the modify-from-sample workflow cannot
   apply on this host.** Say so explicitly to the user, do NOT
   scaffold a sample from memory, and route to one of the unblock
   paths in [`doca-setup CAPABILITIES.md ## Error taxonomy`](skills/doca-setup/CAPABILITIES.md#error-taxonomy)
   (install `doca-samples`, pivot to NGC container, or both).
6. **Never hardcode install-layout values; delegate to the install's own
   source of truth.** The DOCA install layout can drift across versions
   and install profiles (host vs DPU, full vs minimal, container vs
   bare-metal). Skills must teach the agent *which* source of truth to
   consult, not what the value will be on any specific install:
   - **Include paths** — derive via `pkg-config --variable=includedir
     doca-<lib>` (or `pkg-config --cflags doca-<lib>` if the agent only
     needs the compiler flag). Never quote `/opt/mellanox/doca/<...>/include`
     as if it were universal.
   - **Link flags** — derive via `pkg-config --libs doca-<lib>`. Never
     predict the `-l<name>` form by hand: `.so` basenames use
     underscores on every DOCA release where we have ground truth
     (`libdoca_flow.so`, `libdoca_common.so`), while `.pc` package names
     use hyphens (`doca-flow.pc`, `doca-common.pc`). Hand-crafted `-l`
     lines silently break the moment DOCA upgrades; `pkg-config` is the
     only translator that survives.
   - **Shared-object filenames** — confirm via `ldconfig -p | grep
     doca_<lib>` rather than asserting a specific `libdoca*.so` name.
   - **`PKG_CONFIG_PATH`** — common location is
     `/opt/mellanox/doca/infrastructure/lib/pkgconfig/`, but if that
     path does not exist the bundle's `doca-setup` skill walks the
     agent through `find /opt -name 'doca-*.pc' -path '*/pkgconfig/*'`
     to discover the real location.
   - **DOCA version** — always derive via `pkg-config --modversion
     doca-<lib>` + `doca_caps --version`; never hardcode a "current"
     version in skill prose.

   The bundle's anti-pattern is the line *"Includes resolve under `/opt/...`;
   libs include `-ldoca-foo -ldoca-common`"* in a build table. That line
   purports to tell the agent what `pkg-config` will output — but the
   bundle has no way to know the install profile, the DOCA major, or the
   underlying packaging convention. The correct shape is *"Whatever
   `pkg-config --cflags --libs doca-foo` produces on this install;
   do not predict or hand-craft."*

## Conformance

An internal CI pipeline enforces — on every commit, before each
bundle release — three layers of conformance over every skill file
in `skills/`:

1. **Structural.** Frontmatter validity, required H2 anchors in
   `SKILL.md` / `CAPABILITIES.md` / `TASKS.md`, cross-anchor labels in
   `TASKS.md` resolve, no symlinks.
2. **Public-sources** (skill body content scope). Any `*.nvidia.com`
   URL whose host isn't on the small public allowlist
   (`docs.nvidia.com`, `developer.nvidia.com`,
   `catalog.ngc.nvidia.com`, `ngc.nvidia.com`,
   `forums.developer.nvidia.com`, `nvcr.io`) fails when it appears in
   any agent-facing **skill body content** — `SKILL.md` /
   `CAPABILITIES.md` / `TASKS.md`, the bundle's CI prompt fixtures,
   or any string the agent would cite back to the user as a *fact
   about DOCA*. Internal-tooling vocabulary in URL or path context
   (`gerrit`, `nvbugs`, `*.internal.*`, `gitlab-master`, `labhome`,
   …) fails under the same scope. **Exempt from this gate:** the
   top-level `README.md` install-path blocks (Quickstart clone URLs,
   `--repo` argument of the curl-pipe-bash form, manual-install
   clone command, Repository Structure callouts), since the README
   is the install path for the bundle itself and must name the host
   the bundle currently lives on (during the internal-tester drop
   the bundle is hosted on the NVIDIA-internal GitLab — see README
   `## Install (one-liner)` *"Repository host"* callout for the
   current URL and the public-mirror plan). This exemption is
   intentionally narrow: it covers ONLY the bundle's own install URL
   in the README, not any other surface. This is the automated
   counterpart to ground rules 1 and 3 above with the README install
   path carved out.
3. **URL HEAD validity.** Every URL in every skill file HEAD-checks
   to a `2xx`/`3xx`. Catches the *page renamed* / *page deleted*
   failure mode (e.g. the pre-3.x DOCA Samples Overview URL).

What this means for you as a consumer: every released bundle has
already passed those gates. You do not need to run any of them
yourself.

## Non-goals (questions the agent should recognize and refuse politely)

This bundle is the **public, vendor-shipped** skills bundle for the NVIDIA DOCA SDK. It is deliberately scoped, and it deliberately does not try to be every kind of advisor. When a user asks a question that falls into one of the classes below, the agent should recognize the class, name it honestly, and route the user to the right out-of-bundle source — *not* synthesize an answer from training knowledge.

1. **Cross-vendor comparisons.** *"DOCA vs DPDK vs OvS-DPDK vs kernel offload vs Intel IPU SDK vs AMD Pensando vs …"* The bundle is DOCA-specific by design and does not ship competitive content. A vendor-shipped skills bundle synthesizing comparisons against competing stacks would be inappropriate; refer the user to independent sources (their own benchmarks, third-party analyst reports, the NVIDIA Developer Forum for architectural questions on the DOCA side).
2. **Commercial support contracts, SLAs, and procurement.** The bundle's support-surface coverage is the **public** NVIDIA DOCA Developer Forum at <https://forums.developer.nvidia.com/c/infrastructure/doca/370>. Commercial support contracts, response-time SLAs, escalation paths to NVIDIA engineering, and license pricing are out of scope; refer the user to NVIDIA sales for that conversation.
3. **Internal NVIDIA tools, bug trackers, source trees.** Anything inside the NVIDIA firewall (NVBugs, internal Gerrit, internal GitLab, `*.nvidia.internal`, labhome, etc.) is rejected by the bundle's CI gates and is not what this bundle is for. The bundle ships only public surfaces.
4. **Pre-release or unreleased DOCA content.** The bundle's URL allowlist (rule 1) is the *public* documentation set; if a release is not yet public, the bundle has nothing to say about it. Refer the user to the public release-notes channel.
5. **Code synthesis from prose.** Ground rule 5 above. The agent never scaffolds DOCA code from doc prose. *This is a methodology constraint, not a question-class refusal* — but it is the most operationally important non-goal in practice and so is listed here for visibility.
6. **Security architecture claims the bundle is not authorized to make.** Side-channel guarantees, isolation guarantees on shared accelerators, FIPS / Common Criteria assertions, and similar properties of the DOCA crypto / DPA engines are not the bundle's to assert. Frame the question; route to NVIDIA security architecture material (Confidential Computing mode pages, BlueField secure-boot guides) and the Developer Forum; do not synthesize an isolation claim.
7. **Externally-productized NVIDIA networking software not in the DOCA monorepo.** This bundle is **strictly 1:1 with `doca/{libs,services,tools}`** at the currently-aligned DOCA release. Products that NVIDIA productizes externally to the monorepo — DOCA Telemetry Service (DTS) as-deployed, DOCA HBN Service, DOCA BlueMan Service, DOCA SNAP Services, DOCA Virtio-net Service, DOCA-DPACC-Compiler, DPA-Tools (GDB Server / PS / Statistics), DOCA-DPU-CLI, DOCA-Ngauge, the `doca-hugepages` helper, the BlueField BSP / BFB / `bfb-install` / RShim / TMFIFO / `bf.cfg` layer, DOCA Platform Framework (DPF), NVIDIA Network Operator, MLNX_OFED (as a separately-installed package distinct from DOCA-OFED via the DOCA installer), NVIDIA UFM (Unified Fabric Manager for InfiniBand), NVIDIA Cumulus Linux (Spectrum switch OS), NVIDIA Firmware Tools (MFT: `mst` / `flint` / `mlxconfig` / `mlxfwmanager` / `mlxlink` / `mlxcables` / `mstflint`), the NVIDIA Rivermax SDK + license layer (distinct from the in-tree `doca-rmax` wrapper), BlueField BMC software (Redfish / IPMI / OOB recovery), the DOCA Privileged Executor (DPE) daemon, NIC Configuration Operator (Kubernetes), NVIDIA NetQ (fabric validation), NVIDIA NVOS (Spectrum-4 / NVLink switch OS), the NVIDIA Spectrum-X Validated Solution Stack, NVIDIA GPU Operator (Kubernetes), and similar — are out of scope by design. Do NOT synthesize answers about these products from training knowledge. The required response shape is **all three** of: (a) recognize the class and name the product as out-of-scope for this bundle, (b) name the boundary honestly (strict-1:1 with the monorepo; externally-productized = excluded), and (c) **route with substance** — the authoritative `docs.nvidia.com/doca/sdk/` URL for the specific product, the most-common gotcha class the user's symptom is likely hitting, and the Developer Forum entry point. A response that does only (a) and (b) but skips (c) violates this rule and counts as a bundle bug. The authoritative routing table — with per-product docs URL, common-gotcha classes, and Developer Forum search hint — lives at [`doca-public-knowledge-map ## Externally-productized DOCA software — not in this bundle, but here is where to route`](skills/doca-public-knowledge-map/SKILL.md#externally-productized-doca-software--not-in-this-bundle-but-here-is-where-to-route) and ships in every release; agents MUST consult that table before answering.

   **Worked example (SNAP).** *User asks: "how do I use DOCA SNAP to provision a host server — the host server never seems to be able to properly enumerate the NVMe device, or if it does it never is able to actually boot."* A compliant response: (a) names DOCA SNAP Services as externally-productized and out-of-scope for this bundle; (b) cites the strict-1:1 alignment rule; (c) names the four most-common SNAP-enumeration gotcha classes from the routing table (NIC firmware `mlxconfig`, SNAP container running on BF, fabric target reachability from BF management VRF, BF BSP / SNAP version match), gives the authoritative URL <https://docs.nvidia.com/doca/sdk/DOCA-SNAP-Services/index.html>, and gives the forum URL <https://forums.developer.nvidia.com/c/infrastructure/doca/370> with the "SNAP" search hint. A response that stops after (a) and (b) — "this bundle does not cover SNAP, see public docs" — fails the bundle's own contract.

The shape of a good agent response to **any** non-goal class question is *"this bundle does not cover X (here is why); the right next step is Y (here is the route, with the specific URL or table row, and the symptom-matching gotcha class if the user described a symptom)"* — not silence and not improvisation. For non-goal #7 specifically, "the route" must be the per-product row in the `doca-public-knowledge-map` routing table, not a generic "see public docs."
