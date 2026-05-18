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
auto-loading (Anthropic Skills convention), it works equally well
under `skills/` as under `.claude/skills/`. If it does not, read
`SKILLS.md` and load the matching skill files manually. Cross-link
labels of the form `[<skill-name> ## <anchor>](...)` resolve by
skill name regardless of where the skill lives in the tree.

## Ground rules every agent must follow

1. **Public sources only.** Reference NVIDIA documentation only on these
   public hosts: `docs.nvidia.com`, `developer.nvidia.com`,
   `catalog.ngc.nvidia.com`, `ngc.nvidia.com`,
   `forums.developer.nvidia.com`, `nvcr.io`. Anything else is rejected
   by `ci/check-skill.sh`.
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

## Conformance

`ci/check-skill.sh` enforces the rules every skill in
`skills/` must satisfy. Three layers, all gating:

1. **Structural.** Frontmatter validity, required H2 anchors in
   `SKILL.md` / `CAPABILITIES.md` / `TASKS.md`, cross-anchor labels in
   `TASKS.md` resolve, no symlinks. Run by default, no network needed.
2. **Public-sources.** Any `*.nvidia.com` URL whose host isn't on a
   small public allowlist (`docs.nvidia.com`, `developer.nvidia.com`,
   `catalog.ngc.nvidia.com`, `ngc.nvidia.com`,
   `forums.developer.nvidia.com`, `nvcr.io`) fails. Internal-tooling
   vocabulary in URL or path context (`gerrit`, `nvbugs`,
   `*.internal.*`, `gitlab-master`, `labhome`, …) fails. This is the
   automated counterpart to ground rules 1 and 3 above. Run by
   default, no network needed.
3. **URL HEAD validity.** Opt-in via `--check-urls`; HEADs every URL
   in every skill file and fails on non-`2xx`/`3xx`. Use this to
   catch the *page renamed* / *page deleted* failure mode (e.g. the
   pre-3.x DOCA Samples Overview URL the agent previously got a 404
   on). Requires outbound network; CI should run with `--check-urls`
   when network is available.

Run locally before opening a PR that touches any skill file:

```bash
ci/check-skill.sh --all                # structural + public-sources
ci/check-skill.sh --all --check-urls   # also URL HEAD validity
ci/check-skill.sh --self-test          # confirm every gating check still trips
```

## Non-goals (questions the agent should recognize and refuse politely)

This bundle is the **public, vendor-shipped** skills bundle for the NVIDIA DOCA SDK. It is deliberately scoped, and it deliberately does not try to be every kind of advisor. When a user asks a question that falls into one of the classes below, the agent should recognize the class, name it honestly, and route the user to the right out-of-bundle source — *not* synthesize an answer from training knowledge.

1. **Cross-vendor comparisons.** *"DOCA vs DPDK vs OvS-DPDK vs kernel offload vs Intel IPU SDK vs AMD Pensando vs …"* The bundle is DOCA-specific by design and does not ship competitive content. A vendor-shipped skills bundle synthesizing comparisons against competing stacks would be inappropriate; refer the user to independent sources (their own benchmarks, third-party analyst reports, the NVIDIA Developer Forum for architectural questions on the DOCA side).
2. **Commercial support contracts, SLAs, and procurement.** The bundle's support-surface coverage is the **public** NVIDIA DOCA Developer Forum at <https://forums.developer.nvidia.com/c/infrastructure/doca/370>. Commercial support contracts, response-time SLAs, escalation paths to NVIDIA engineering, and license pricing are out of scope; refer the user to NVIDIA sales for that conversation.
3. **Internal NVIDIA tools, bug trackers, source trees.** Anything inside the NVIDIA firewall (NVBugs, internal Gerrit, internal GitLab, `*.nvidia.internal`, labhome, etc.) is rejected by `ci/check-skill.sh` and is not what this bundle is for. The bundle ships only public surfaces.
4. **Pre-release or unreleased DOCA content.** The bundle's URL allowlist (rule 1) is the *public* documentation set; if a release is not yet public, the bundle has nothing to say about it. Refer the user to the public release-notes channel.
5. **Code synthesis from prose.** Ground rule 5 above. The agent never scaffolds DOCA code from doc prose. *This is a methodology constraint, not a question-class refusal* — but it is the most operationally important non-goal in practice and so is listed here for visibility.
6. **Security architecture claims the bundle is not authorized to make.** Side-channel guarantees, isolation guarantees on shared accelerators, FIPS / Common Criteria assertions, and similar properties of the DOCA crypto / DPA engines are not the bundle's to assert. Frame the question; route to NVIDIA security architecture material (Confidential Computing mode pages, BlueField secure-boot guides) and the Developer Forum; do not synthesize an isolation claim.
7. **Externally-productized NVIDIA networking software not in the DOCA monorepo.** This bundle is **strictly 1:1 with `doca/{libs,services,tools}`** at the currently-aligned DOCA release (enforced by [`devops/ci/check-doca-inventory.sh`](../devops/ci/check-doca-inventory.sh)). Products that NVIDIA productizes externally to the monorepo — DOCA Telemetry Service (DTS) as deployed, DOCA HBN Service, DOCA BlueMan Service, DOCA SNAP Services, DOCA Virtio-net Service, DOCA-DPACC-Compiler, DPA-Tools (GDB Server / PS / Statistics), DOCA-DPU-CLI, DOCA-Ngauge, the `doca-hugepages` helper, and similar — are out of scope by design. The right next step for a question on one of these is the public NVIDIA documentation on `docs.nvidia.com/doca/sdk/` for that specific product, plus the public DOCA Developer Forum for help. Do NOT synthesize answers about these products from training knowledge; recognize the class, name the boundary, and route.

The shape of a good agent response to a non-goal class question is *"this bundle does not cover X (here is why); the right next step is Y (here is the route)"* — not silence and not improvisation.
