# Contributing to NVIDIA DOCA Skills

> **Note — this repository is not accepting external contributions.** It is
> maintained by NVIDIA, so pull requests opened here cannot be merged. The
> authoring rules below are the rules NVIDIA maintainers follow; they are
> published here for transparency. To report a problem or request a change, use the issue and
> forum channels in the [README](README.md#getting-help--contributing).

Thank you for your interest in improving the public DOCA agent-skills
bundle. This file is the rules-of-engagement. Read it before you author
a new skill or change an existing one.

## TL;DR

1. **Public sources only.** Every URL in a `SKILL.md`, `CAPABILITIES.md`,
   or `TASKS.md` must resolve under the public allowlist
   (`docs.nvidia.com`, `developer.nvidia.com`, `catalog.ngc.nvidia.com`,
   `ngc.nvidia.com`, `forums.developer.nvidia.com`, `nvcr.io`,
   `github.com/NVIDIA*`). Internal hostnames
   (`gerrit*`, `nvbugs*`, `*.internal.*`, `gitlab-master*`, `labhome*`)
   are rejected at PR time.
2. **Guidance-only, not codegen.** Skills teach the agent the *shape*
   of an answer. They do **not** ship working code, generated
   manifests, or scaffolded apps. The agent uses the skill to derive
   an answer for the user's specific environment.
3. **Class-shape, never instance-shape.** Skill filenames and content
   describe *classes* of work (`apply-a-hardware-touching-change`),
   never a single worked instance (`apply-mlxconfig-on-host-foo`).
4. **No symlinks.** Every file is a real file.
5. **DCO sign-off on every commit.** Use `git commit -s` (or amend with
   `git commit --amend -s`); PRs without `Signed-off-by:` on every
   commit are auto-blocked.

## What "a new skill" means

A skill is a directory under `skills/`. Its shape depends on `kind:`:

- `kind: knowledge` — one file: `SKILL.md` only. Used for routing
  skills and reference compendia (e.g. `doca-public-knowledge-map`,
  `doca-structured-tools-contract`).
- `kind: library` — three files: `SKILL.md` + `CAPABILITIES.md` +
  `TASKS.md`. Used for every per-artifact skill and for the
  cross-cutting library-shaped skills (e.g. `doca-setup`,
  `doca-debug`, `doca-version`, `doca-hardware-safety`).
- `kind: service` / `kind: tool` — same three-file shape as `library`,
  used for the per-service / per-tool skills.

Every shipping skill (libraries, services, tools) additionally ships:

- `evals/evals.json` — a test dataset that grades whether an agent
  loaded with the skill produces a workable end-to-end answer for the
  artifact. Schema is documented at <https://agentskills.io>.
- `SKILLCARD.yaml` — machine-readable metadata for identity,
  provenance, quality baseline, and behavioural boundaries. The
  cryptographic-signature fields (`identity.signature`,
  `provenance.scan_run_id`, `provenance.signed_at`,
  `provenance.signed_by`) are populated by NVIDIA's NVCARPS scanning +
  signing pipeline at publication time.

## How changes are checked

Every release passes automated checks before it is published:

1. **Signing** — each skill is scanned and signed by NVIDIA's skills
   publishing pipeline, which validates each `SKILL.md` against the
   agentskills.io spec, scans for prompt-injection patterns and
   supply-chain risks, and produces the `*.sig` signature files plus the
   filled-in `SKILLCARD.yaml` metadata.
2. **Structural checks** — per-skill conformance, anchor density,
   public-source-URL allowlist, cross-link integrity, AgentSkills.io
   reference validity, and no regression against the previous release.
3. **End-to-end checks** — changed skills are re-graded against a strict
   grader rubric (see [`BENCHMARK.md`](BENCHMARK.md)); a regression
   blocks the release.

## What does NOT belong in this bundle

- Executable wrappers (Meson / CMake / container-build / version-check
  CLIs). The current contract is "markdown-only".
- Anything that requires NVIDIA login or NDA to read. If it's not on
  the public allowlist, it doesn't ship.
- Anything internal-only — internal Confluence pages, internal Jira
  tickets, internal Gerrit reviews.
- Hand-rolled DOCA apps. The skills route the user to the shipped
  samples under `/opt/mellanox/doca/samples/` and teach them how to
  derive a first app from there.

## Reporting issues

For bugs in the skills bundle itself — wrong URL, stale fact, missing
artifact, hallucinated rule, broken cross-link — open an Issue on
this repository with the affected skill name and a minimal
reproduction (the user prompt that triggered the wrong answer).

For security issues, see [`SECURITY.md`](SECURITY.md) at the bundle
root. Hardware-safety bugs in skill content (wrong rollback
procedure, missing safety pre-flight, hot-applied `mlxconfig`-class
change) follow the safety-bug intake described there.
