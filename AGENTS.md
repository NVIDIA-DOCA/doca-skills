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

`ci/check-skill.sh` enforces the structural rules every skill in
`.claude/skills/` must satisfy. Run it locally before opening a PR that
touches any skill file.
