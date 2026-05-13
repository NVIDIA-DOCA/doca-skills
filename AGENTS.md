# Agent guidance for doca-skills

This repository ships sample code for the NVIDIA DOCA SDK. Any AI coding agent
working in this repo — Cursor, Codex, Gemini, Claude Code, custom in-house
LLMs — should read this file first.

## Where the actual guidance lives

- [SKILLS.md](SKILLS.md) — the index of installed skills with one-line "when
  to load" triggers. Read this to decide which skills are relevant to the
  user's request.
- [.claude/skills/](.claude/skills/) — the skill source files. Vendor-neutral
  Markdown. `.claude/` is Claude Code's auto-discovery path, but the files
  themselves are plain Markdown that any agent can read directly.

If your runtime supports Anthropic Skills auto-loading, the per-skill
`SKILL.md` frontmatter is the trigger. If it does not, read `SKILLS.md` and
load the matching skill files manually.

## Ground rules every agent must follow

1. **Public sources only.** Never reference internal NVIDIA hostnames,
   Gerrit, NVBugs, Confluence, or Jenkins. Customers do not have those.
2. **Prefer the local install over the web.** When DOCA is installed at
   `/opt/mellanox/doca`, those files *are* the release. Web docs describe a
   release.
3. **Never invent symbols, URLs, paths, or package names.** If you cannot
   verify it from a skill, the local install, or the official docs you
   fetched, say so and ask.
4. **Always check the installed DOCA version** before quoting API names,
   options, or sample filenames. See `doca-public-knowledge-map` for how.

## Conformance

`ci/check-skill.sh` enforces the rules every skill in
`.claude/skills/` must satisfy. Three layers, all gating:

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
