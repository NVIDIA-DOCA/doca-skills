# Contributing to NVIDIA DOCA Skills

Thank you for your interest in improving the public DOCA agent-skills
bundle. This file is the rules-of-engagement; the deep contributor
contract lives in [`AUTHORING.md`](AUTHORING.md) at the bundle root —
read it before you author a new skill or change an existing one.

## TL;DR

1. **Public sources only.** Every URL must resolve under the public
   allowlist enforced by `ci/check-skill.sh` (`docs.nvidia.com`,
   `developer.nvidia.com`, `catalog.ngc.nvidia.com`, `ngc.nvidia.com`,
   `forums.developer.nvidia.com`, `nvcr.io`, `github.com/NVIDIA*`).
   Internal hostnames (`gerrit*`, `nvbugs*`, `*.internal.*`,
   `gitlab-master*`, `labhome*`) fail the linter.
2. **Guidance-only, not codegen.** Skills teach the agent the *shape*
   of an answer. They do **not** ship working code, generated
   manifests, or scaffolded apps. The agent uses the skill to derive
   an answer for the user's specific environment.
3. **Class-shape, never instance-shape.** Skill filenames and content
   describe *classes* of work (`apply-a-hardware-touching-change`),
   never a single worked instance (`apply-mlxconfig-on-host-foo`).
   See `AUTHORING.md` § 1a and § 13.
4. **No symlinks.** Every file is a real file. The linter rejects
   symlinks.
5. **All four coverage gates green before opening the PR.** Run from
   the bundle root:
   `bash ci/check-skill.sh --all --check-urls`,
   `bash ci/check-anchor-density.sh --all`,
   `bash ci/check-coverage.sh --routing-discoverability-hard-fail --prompt-coverage-hard-fail --skill-coverage-hard-fail-below=100 --hard-fail-below=100`,
   and the 3-agent A/B sanity probe described in
   [`AUTHORING.md`](AUTHORING.md) § 11.

## What "a new skill" means

A skill is a directory under `skills/`. Its shape depends on `kind:`:

- `kind: knowledge` — one file: `SKILL.md` only. Used for routing
  skills and reference compendia (e.g. `doca-public-knowledge-map`,
  `doca-structured-tools-contract`).
- `kind: library` — three files: `SKILL.md` + `CAPABILITIES.md` +
  `TASKS.md`. Used for every per-artifact skill and for the
  cross-cutting library-shaped skills (e.g. `doca-setup`,
  `doca-debug`, `doca-version`, `doca-hardware-safety`).

Required H2 anchors per file, the YAML frontmatter contract, and the
anchor-density floor are all enforced by `ci/check-skill.sh`
and `ci/check-anchor-density.sh`.

## What gets reviewed in a PR

For every PR that touches `skills/`:

1. CI runs all four coverage gates above as HARD-FAIL.
2. CI runs the 3-agent A/B (no-skills baseline, `main` skills,
   PR-branch skills) on a dynamically-selected prompt set targeting
   the changed skills. The PR scores must not regress from `main`.
3. A human reviewer sanity-checks the class-shape discipline and the
   cross-link contract (every per-artifact skill cross-links
   `doca-version` for the four-way pairing rule and
   `doca-hardware-safety` for any change that touches hardware
   state).

## What does NOT belong in this bundle

- Executable wrappers (Meson/CMake/container-build/version-check
  CLIs). Designs for these live on the maintainer roadmap and ship
  in a later round. The current contract is "markdown-only".
- Anything that requires NVIDIA login or NDA to read. If it's not on
  the public allowlist, it doesn't ship.
- Anything internal-only — internal Confluence pages, internal Jira
  tickets, internal Gerrit reviews. These are stripped by
  `check-skill.sh`.
- Hand-rolled DOCA apps. The skills route the user to the shipped
  samples under `/opt/mellanox/doca/samples/` and teach them how to
  derive a first app from there.

## Reporting issues

For bugs in the skills bundle itself — wrong URL, stale fact, missing
artifact, hallucinated rule, broken cross-link — open an Issue on
this repository with the affected skill name and a minimal
reproduction (the user prompt that triggered the wrong answer).

For security issues, see [`SECURITY.md`](SECURITY.md) at the bundle root.
