# Skill index

Skills installed in this repository. Each row gives the skill ID, where to
find its source file, and a one-line trigger for when an agent should load it.

For the discovery convention and ground rules every agent must follow, see
[AGENTS.md](AGENTS.md).

## Layout

Skills live under `skills/` (top-level, vendor-neutral path — not
under any agent-runtime-specific directory), layered by *kind of
artifact* the skill is about:

```
skills/
├── doca-public-knowledge-map/   # cross-cutting routing skill (knowledge)
├── doca-setup/                   # cross-cutting env skill        (library-shape)
├── doca-programming-guide/       # cross-cutting programming skill (library-shape)
├── libs/<library>/               # one skill per DOCA library
├── services/<service>/           # one skill per DOCA service
└── tools/<tool>/                 # one skill per DOCA tool
```

The three cross-cutting skills (knowledge map, setup, programming guide)
sit at the top level because they apply *across* libraries / services /
tools. Per-artifact skills live under the matching subdirectory.

This is a *physical* convention only — agents discover skills by their
`name:` (declared in each `SKILL.md`'s YAML frontmatter), and cross-link
labels of the form `[<skill-name> ## <anchor>]` resolve by name regardless
of where the skill lives in the tree. Reorganizing the tree later does not
break agent discovery.

## Index

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-public-knowledge-map` | [skills/doca-public-knowledge-map/SKILL.md](skills/doca-public-knowledge-map/SKILL.md) | The user asks anything about DOCA where you need to locate authoritative documentation, installed package paths, downloads, samples, the developer forum, the public DOCA services / tools index, or how to find the installed DOCA version — without access to the DOCA source repository. |
| `doca-setup` | [skills/doca-setup/SKILL.md](skills/doca-setup/SKILL.md) | Env-class only. The user is installing DOCA, verifying the install, preparing the build env (`pkg-config`, headers, hugepages, devlink), debugging an env-class failure, or asking *I'm on macOS / Windows / Linux without DOCA — how do I reach an install?* (the canonical Stage-1 answer is the public NGC DOCA container `nvcr.io/nvidia/doca/doca`, alongside lab-host, cloud-Linux, and hardware paths). Hands off to `doca-programming-guide` once the env is healthy. **Headline contract: never scaffold DOCA code (`main.c` / `Makefile` / `Dockerfile`) for the user before they have an install — this skill's `## no-install` is the canonical pre-install routing.** |
| `doca-programming-guide` | [skills/doca-programming-guide/SKILL.md](skills/doca-programming-guide/SKILL.md) | The user has a healthy DOCA env and is asking a general DOCA programming question — the canonical `pkg-config doca-<library>` build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, or the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. |
| `doca-debug` | [skills/doca-debug/SKILL.md](skills/doca-debug/SKILL.md) | The user is debugging anything DOCA-related across layers — a build that won't compile, a link step that can't resolve a `doca_*` symbol, a runtime call that returns `DOCA_ERROR_*`, a packet not appearing on the wire, a service that won't start, or "how do I get more logs?". Provides the canonical layered debug ladder (install → version → build → link → runtime → program → driver), the cross-cutting tooling reference (`gdb`, `valgrind`, `ldd`, `strace`, `dmesg`, `--sdk-log-level`, the `doca-<lib>-trace` build flavor, container introspection, core dumps), and the *Where to ask for help* escalation to the public Developer Forum. `doca-setup ## debug` (env-class half) and `doca-programming-guide ## debug` (program-class half) both escalate here for cross-cutting tooling and ladder shape; library skills overlay their library-specific debug on top. |
| `doca-flow` | [skills/libs/doca-flow/SKILL.md](skills/libs/doca-flow/SKILL.md) | The user is working with DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, Flow counters and traces, Flow version compatibility, or debugging `DOCA_ERROR_*` failures from the Flow API. Builds on `doca-setup` (env) and `doca-programming-guide` (cross-library patterns) and layers Flow specifics on top. |
| `doca-dms` | [skills/services/doca-dms/SKILL.md](skills/services/doca-dms/SKILL.md) | The user is deploying or operating the DOCA Management Service — choosing a deployment shape (host non-DPU / BlueField Arm / Kubernetes pod), launching `dmsd` (SystemD or manual), choosing an authentication mode (localhost / PAM / credentials / mTLS), wiring `dmsgroup` authorization, issuing gNMI Get/Set against modeled YANG paths, issuing gNOI system operations (reboot, OS install, file transfer, `mlxconfig`, `containerz`), or debugging a DMS request layered through transport / auth / path / backend / library failures. Currently beta per the public guide. |
| `doca-caps` | [skills/tools/doca-caps/SKILL.md](skills/tools/doca-caps/SKILL.md) | The user — or the agent itself — needs a side-effect-free, documented snapshot of *what DOCA sees on this host*: enumerating DOCA devices and representors (`--list-devs`, `--list-rep-devs`, `--pci-addr`), listing the DOCA libraries supported on the running OS, listing per-device per-library capabilities, listing DOCA logger names. Available since DOCA 2.6.0; runs on host or BlueField Arm. The canonical first-step capability snapshot called out from `doca-setup ## test` and `doca-programming-guide ## debug`. |

## Adding a new skill

1. Pick the right slot in the layered tree
   (`libs/<library>` / `services/<service>` / `tools/<tool>`, or
   top-level only if the skill is genuinely cross-cutting).
2. Create `<slot>/<kebab-case-id>/SKILL.md`.
3. Use the frontmatter contract enforced by `ci/check-skill.sh`
   (`name`, `description ≤ 1024 chars`, `kind: knowledge | library`).
4. For `kind: library`, add `CAPABILITIES.md` and `TASKS.md` with the
   required H2 anchors (`ci/check-skill.sh` enforces them).
5. Add a row to the index table above with a single-line "when to
   load" trigger.
6. Run `ci/check-skill.sh --all` locally (and `--check-urls` if any
   URLs were added or changed) and confirm both pass.
