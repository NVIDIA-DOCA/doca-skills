**Subject:** Please review the DOCA skill that covers your library / service / tool

**To:** doca-developers@nvidia.com
**Cc:** <your manager line>

---

Hi DOCA team,

We are about to release the **first version of `doca-skills`** — an open, AgentSkills.io-compliant skill bundle that teaches any AI coding agent (Cursor, Claude Code, Codex CLI, Gemini CLI, Kiro, …) how to use DOCA correctly. Before we send it out we want a review from the developer who owns each library / service / tool — **you know your slice better than anyone**, and we want your name catching the inaccuracies, not the customer's.

## Why this project exists

External developers want to build DOCA applications with an AI agent. Some of them have the DOCA source tree; **most do not** — they only have the public docs, the installed `/opt/mellanox/doca`, and whatever the LLM remembers from training. That last part is the problem: today the agent will confidently hallucinate symbols, paths, build flags, and capability gates, and the user has no way to tell. `doca-skills` makes DOCA **"agent-ready"** by shipping a vendor-neutral, public-sources-only knowledge layer that the agent loads on-demand and uses as ground truth instead of training memory.

The bundle is **1:1 with `doca/{libs,services,tools}/`** at the DOCA 3.3 release — every public library (28), every public service (6), every public tool (18), plus 9 cross-cutting skills (setup, debug, hardware-safety, version-pinning, programming patterns, public-docs routing, non-goal routing for out-of-scope NVIDIA products, …). Total: 61 skills.

## How to install it (one line, any agent)

The bundle is staged on internal GitLab. Pick the agent you already use; the only thing that changes is the `--agent` flag:

```bash
# Cursor
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent cursor

# Claude Code
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent claude-code

# Codex CLI
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent codex

# Gemini CLI
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent gemini-cli

# Kiro
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent kiro-cli

# Any other AgentSkills.io-aware agent
git clone https://gitlab-master.nvidia.com/doca-devops/doca-skills.git \
  && cd doca-skills && ./install.sh --agent custom --dest /path/to/your/agent/skills
```

The installer is a ~310-line bash script with zero runtime dependencies (`bash` / `cp` / `ln` / `mkdir`). It copies (or `--link` symlinks) the skill folders into your agent's discovery directory and prints what it did. Re-runs are idempotent — safe to re-run after every `git pull`.

After install, reload your agent and ask it a real DOCA question. The relevant skill activates automatically.

## What we need from you

Please review **the skill that covers the lib / service / tool you own**:

- `skills/libs/<your-lib>/` — `SKILL.md` + `CAPABILITIES.md` + `TASKS.md`
- `skills/services/<your-service>/` — same three files
- `skills/tools/<your-tool>/` — same three files

Then ask your agent a realistic user question about your component (e.g. *"how do I do X with `doca_<your_lib>`"*) and grade the answer.

## Quick FAQ — what to look for, and what to skip

**Q. What kind of feedback is most useful?**

In priority order:
1. **Fabricated symbols / APIs / flags.** Any function name, enum value, build flag, env var, or config key the skill cites that does not exist in the public header / source. These are the highest-impact bugs — the agent will quote them at the user.
2. **Mischaracterized capabilities.** Modes, sub-libraries, or features the skill claims your component supports when it does not (or omits when it does).
3. **Wrong paths or URLs.** Install paths, sample paths, source-tree paths, `docs.nvidia.com` URLs.
4. **Missing or wrong "Non-goals" routing.** Cases where a user's question should route OUT of your skill (to another bundle skill, to an external NVIDIA product, or to the Developer Forum) but instead gets answered with hallucination.
5. **Anything the agent gets confidently wrong** when you ask it a realistic developer question about your component.

**Q. What should I NOT spend time on?**

- Style / wording / formatting of the skill prose (we have that loop covered).
- Suggestions for additional libraries / services / tools to add (the catalog is locked 1:1 with `doca/{libs,services,tools}/` for this release).
- Cross-vendor comparisons (DPDK vs DOCA, etc.) — these are out-of-scope by design.

**Q. I don't have an agent set up — can I still review?**

Yes. You can just read the three Markdown files in your skill folder directly. They are written to be human-readable.

**Q. What agent should I use if I don't already have one?**

Any of the five above. If you're undecided: **Cursor** is the lowest-friction starting point for most NVIDIA developers (`./install.sh --agent cursor` writes to `~/.cursor/skills/` and Cursor picks it up on the next reload).

**Q. Do I need DOCA installed on my machine?**

No, not for the review. The skills are documentation; they activate without DOCA being present. (For end-to-end behaviour the agent is best on a host with `/opt/mellanox/doca` installed, but you don't need that to spot inaccuracies in the skill content.)

**Q. How do I send feedback?**

Reply to this thread, or open an issue in the GitLab repo, with the specific file and line you're flagging. One-line corrections are perfect — we will land them and re-sync.

## Links

- **Repo (clone here):** https://gitlab-master.nvidia.com/doca-devops/doca-skills
- **README** (one-liner install, full catalog, ground rules): root of the repo
- **AgentSkills.io spec** (the open standard the bundle conforms to): https://agentskills.io/specification

Thanks for the review — your name on the corrections is what makes this bundle trustworthy to the external developers who will rely on it.

— <your name>
DOCA DevOps
