# doca-skills — Quickstart

Five minutes to your first agent-answered DOCA question.

## 1. Install

```bash
git clone https://github.com/NVIDIA-DOCA/doca-skills.git
cd doca-skills
./install.sh --agent <cursor|claude-code|codex|gemini-cli|kiro-cli>
```

Pick the agent you use. The installer writes (or symlinks) the 61 skill
folders into the right discovery path for that agent. Repeat with another
`--agent` flag if you use more than one — they don't collide.

> **Don't have one of those agents?** Use
> `./install.sh --agent custom --dest /path/to/your/agent/skills`. Any
> [AgentSkills.io](https://agentskills.io/specification)-aware agent can
> load this bundle from any directory you point it at.

## 2. Start a fresh session

The agent only discovers new skills at session start. Open a new chat /
new agent session / new IDE window. An already-open session won't pick
up the new skills.

## 3. Ask a real DOCA question

Examples that reliably activate the right skill(s):

| Ask this | Skills that activate |
|---|---|
| *"I just got a BlueField. How do I check it's set up correctly and run a tiny DOCA sample?"* | `doca-setup` → `doca-version` → `doca-programming-guide` |
| *"Build me a DOCA Flow pipeline that steers UDP/5000 to RX queue 0 on my BlueField-3."* | `doca-flow` (+ `doca-version`, `doca-debug`) |
| *"How do I deploy DOCA Firefly for PTP sync? My BlueField is on `192.168.100.2`."* | `doca-firefly` (+ `doca-container-deployment`, `doca-version`) |
| *"My `doca_eth_rxq` sample compiles but I get `DOCA_ERROR_NOT_SUPPORTED` at start. What's wrong?"* | `doca-debug` → `doca-eth` → `doca-version` |
| *"What is DOCA SHA and does it support SHA-256 on my hardware?"* | `doca-sha` (+ `doca-version`) |

The agent will quote the bundle's skill files inline (you'll see
`skills/libs/doca-flow/TASKS.md ## build` style citations) so you can
trace every claim back to a source file in this repo.

## 4. Verify the install (optional)

```bash
ls ~/.cursor/skills/doca-flow/SKILL.md   # if you installed --agent cursor
```

If that path exists, the install landed correctly. The same check applies
for `~/.claude/skills/`, `~/.agents/skills/` (Codex / cross-platform), or
`~/.gemini/skills/`, depending on which agent you installed for.

## What's in the bundle

- **28 library skills** (one per DOCA library — Flow, RDMA, GPUNetIO,
  AES-GCM, Telemetry, …)
- **6 service skills** (Firefly, DMS, OS Inspector, Argus, Flow Inspector,
  URO M Svc)
- **17 tool skills** (bench, caps, flow-perf, flow-tune, apsh-config,
  pcc-counters, …)
- **10 cross-cutting skills** that overlay on top of any per-component
  answer: `doca-setup`, `doca-version`, `doca-debug`,
  `doca-programming-guide`, `doca-public-knowledge-map`,
  `doca-container-deployment`, `doca-bare-metal-deployment`,
  `doca-hardware-safety`, `doca-structured-tools-contract`.

## Next steps

- For the *why* and *how* in depth, read [`README.md`](README.md).
- For agent-side ground rules and persona routing, read
  [`AGENTS.md`](AGENTS.md).
- For the per-skill catalog (which skill activates when), read
  [`SKILLS.md`](SKILLS.md).
- To file a content correction (wrong symbol, wrong path, wrong URL),
  read [`CONTRIBUTING.md`](CONTRIBUTING.md).

## You don't need a BlueField to try it

The bundle's `doca-programming-guide`, `doca-public-knowledge-map`,
`doca-setup`, and many of the library skills will give useful answers
even on a laptop without DOCA installed — they explain what to install,
what to expect, and what to verify *before* you have hardware. Once you
have hardware, the same skills activate the *device + capability
discovery* + *modify-from-sample* + *run-and-verify* legs of the
workflow.

## Where this bundle fits — what it covers, what it doesn't

`doca-skills` is the **external-developer skill set for the NVIDIA DOCA
SDK** — meant for anyone building an application against the public DOCA
libraries, services, or tools from outside the NVIDIA DOCA SDK team.

**Covers (in scope).** Every public DOCA **library** under `doca/libs/`,
every public DOCA **service** under `doca/services/`, every public DOCA
**tool** under `doca/tools/`, plus the cross-cutting setup / version /
debug / deployment / programming-guide overlays.

**Does not cover (out of scope on purpose; routed to the right owner).**

- **DOCA Platform Framework (DPF)** — separately-productized; DPF
  skills are being prepared as part of the DPF PoR. Ask DPF-specific
  questions against the DPF docs / DPF skills, not this bundle.
- **DOCA Microservices** (HBN, BlueMan, SNAP, Virtio-net, Telemetry
  Service as-deployed) — productized externally to `doca/services/` and
  not modelled here.
- **NVIDIA Network Operator** — has its own AI skills at
  <https://mellanox.github.io/network-operator-docs/ai-skills.html>;
  use those.
- **BlueField BSP / BFB / RShim / TMFIFO / BMC** lifecycle — out of
  bundle; the agent will route to public BlueField BSP docs.

If you're *inside* the NVIDIA DOCA SDK team and need Gerrit-upload /
NVAuto / BFB-build / release-gate workflows, the internal `doca_ai_conf`
repo is the better fit; the two bundles are complementary, not
competing. When you ask this bundle an out-of-scope question, the agent
should name the boundary explicitly and route you to the right docs URL
+ Developer Forum search — never invent an answer.
