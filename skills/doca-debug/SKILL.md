---
name: doca-debug
description: NVIDIA DOCA cross-cutting debug skill. Symptom triage, the layered debug ladder (install → version → build → link → runtime → program), public DOCA debug tooling (`gdb`, `valgrind`, `ldd`, `strace`, `dmesg`, `journalctl`, `doca_caps`, `doca-flow-tune`, `doca-flow-inspector`, `doca-bench`), DOCA's logging surface (`DOCA_LOG_LEVEL`, `--sdk-log-level`, the `doca-<lib>-trace` build flavor), how to capture a reproducible state, container-specific debug constraints, and where to ask for help on the public Developer Forum. Cross-cuts every DOCA library; per-library debug overlays (Flow pipe-trace, RDMA QP-state, Comch channel-stats, etc.) live in the matching library skill. Env-class debug stays in `doca-setup`; program-class debug stays in `doca-programming-guide` — this skill is the cross-cutting reference both of those redirect to for the canonical debug surface.
kind: library
---

# DOCA debug

## When to load this skill

Load this skill when the user is debugging anything DOCA-related — a build that won't compile, a link step that can't resolve a `doca_*` symbol, a runtime call that returns `DOCA_ERROR_*`, a packet that does not appear on the wire, a service that won't start, or a tool that returns no useful output. Concretely:

- The user reports a symptom and needs to find the layer that caused it (install / version / build / link / runtime / program).
- The user asks "how do I get more logs?" or "how do I turn up the verbosity?" for any DOCA library or tool.
- The user wants to capture state for a forum question or an internal bug report (the bundle does not own the internal-bug-report channel; it routes to the public DOCA Developer Forum).
- The user is reading a stack trace, a `valgrind` output, or a core dump from a DOCA program and wants to know where to look first.
- The user is debugging *inside* the NGC DOCA container and needs to know what is and is not observable from inside it.

Do **not** load this skill for:

- *"What is `DOCA_ERROR_BAD_STATE`?", "what error codes does DOCA return?"* — that is the cross-library *error taxonomy*, owned by [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../doca-programming-guide/CAPABILITIES.md#error-taxonomy). This skill consumes that taxonomy; it does not redefine it.
- *"My `pkg-config` cannot find `doca-flow`", "hugepages are not mounted", "my representor isn't visible"* — those are env-class symptoms, owned by [`doca-setup ## debug`](../doca-setup/TASKS.md#debug). This skill is the canonical pointer that env-class debug ladder redirects to once the symptom escalates beyond install / version / build prerequisites.
- *Library-specific debugging* (Flow pipe trace, RDMA queue-pair state, Comch channel statistics) — those live in the matching library skill (e.g. [`doca-flow ## debug`](../libs/doca-flow/TASKS.md#debug)). This skill provides the cross-cutting debug ladder; library skills layer their library-specific debug surface on top of it.

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed to pick the right next file. The substantive debug material lives in two companion files:

- [CAPABILITIES.md](CAPABILITIES.md) — what *kinds of debug surface* DOCA exposes: the layered debug model (install / version / build / link / runtime / program), the read-only-first stance, version-availability of debug tools (e.g. `doca_caps` since DOCA 2.6.0), the cross-library error taxonomy (cross-link only — owned by `doca-programming-guide`), the observability primitives DOCA emits (`stderr` logs, `--sdk-log-level`, the `doca-<lib>-trace` build flavor, library counters), and the safety constraints on debug actions (read-only first, don't mutate install tree mid-investigation).
- [TASKS.md](TASKS.md) — the actual debug workflows: `## configure` (set up env for high-verbosity debug), `## test` (capture a reproducible state), `## debug` (the canonical layered ladder, the universal entry point that every library `## debug` redirects to), and the *Where to ask for help* routing (NVIDIA DOCA Developer Forum). Three other anchors (`build`, `modify`, `run`) exist for lint compliance and route to [`doca-programming-guide`](../doca-programming-guide/SKILL.md), which owns those verbs after the env / program split.

## Loading order

1. Read this `SKILL.md` first to confirm the user's symptom is *cross-cutting* debug (not env-class only, not program-class only, not library-internal only).
2. **For the layered debug model, the read-only stance, the version-availability of debug tools, and the observability surface DOCA emits, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the canonical layered debug ladder and the *capture-and-report* workflow, see [TASKS.md](TASKS.md).** The `build`, `modify`, and `run` anchors in `TASKS.md` are stubs that route to [`doca-programming-guide`](../doca-programming-guide/SKILL.md); their substance lives there.
4. If the user's symptom turns out to be env-class (install / build prerequisites), hand off to [`doca-setup ## debug`](../doca-setup/TASKS.md#debug). If program-class, hand off to [`doca-programming-guide ## debug`](../doca-programming-guide/TASKS.md#debug). If library-internal, hand off to the matching library skill's `## debug` (e.g. [`doca-flow ## debug`](../libs/doca-flow/TASKS.md#debug)).

The two companion files cross-link to each other and to [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) whenever the right answer is *"look it up in the public docs or the installed package layout"* rather than *"debug-specific guidance"*.

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md) — public DOCA documentation routing and the on-disk layout of an installed DOCA package. This skill defers all *"where is X documented"*, *"where on disk is Y"*, and *"how do I check the installed version"* questions to the knowledge-map.
- [`doca-setup`](../doca-setup/SKILL.md) — env-class debug (install / build prerequisites): `pkg-config` failures, missing hugepages, representors not visible, header-vs-runtime version mismatches. `doca-setup ## debug` is the env-class layered ladder; this skill is the cross-cutting debug ladder both env and program ladders escalate to.
- [`doca-programming-guide`](../doca-programming-guide/SKILL.md) — program-class debug (lifecycle order, `DOCA_ERROR_*` interpretation, `doca_error_get_descr()` use, the validate-before-commit rule). `doca-programming-guide ## debug` is the program-class layered ladder; this skill picks up where it leaves off when the symptom involves cross-library tooling (`gdb`, `valgrind`, container introspection, core dumps).
- Library skills (e.g. [`doca-flow`](../libs/doca-flow/SKILL.md), [`doca-dms`](../services/doca-dms/SKILL.md), [`doca-caps`](../tools/doca-caps/SKILL.md)) — library-specific debug overlays. Each library's `## debug` builds on the cross-cutting ladder defined here, then adds its own counters, traces, and inspector tools.
