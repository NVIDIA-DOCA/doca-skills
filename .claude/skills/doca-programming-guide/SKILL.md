---
name: doca-programming-guide
description: General DOCA programming patterns shared across every DOCA library — the shape of DOCA (host vs DPU vs switch, libraries vs apps vs services vs tools), the universal cfg-create / init / start / use / stop / destroy lifecycle, the canonical `pkg-config doca-<library>` build pattern (C/C++ direct or non-C via FFI / bindings against the public C ABI), the universal modify-a-shipped-sample workflow that any library skill extends with library-specific overrides, the validate-before-commit rule, the `DOCA_ERROR_*` family with `doca_error_get_descr()`, and the program-class debugging order. Library-agnostic; library-specific overrides live in the matching library skill. Assumes `doca-setup` preconditions are satisfied.
kind: library
---

# DOCA programming guide

## Audience

This skill serves **external developers building applications that
*consume* DOCA libraries** — i.e., users whose code calls one or more
`doca_<library>_*` symbols (directly in C/C++, or through FFI /
bindings from another language). It is *programming **with** DOCA*,
not *programming **of** DOCA*: it is *not* for NVIDIA developers
contributing to DOCA itself, and it does *not* assume access to the
DOCA source tree, internal NVIDIA tooling, or any non-public
information. The only inputs it ever points the agent at are the
ones any external user has: the public docs at
[`docs.nvidia.com/doca/sdk/`](https://docs.nvidia.com/doca/sdk/),
the public catalog at
[`catalog.ngc.nvidia.com`](https://catalog.ngc.nvidia.com/), the
public GitHub repos under
[`github.com/NVIDIA`](https://github.com/NVIDIA) /
[`github.com/NVIDIA-DOCA`](https://github.com/NVIDIA-DOCA), the
public developer forum, and the on-disk `/opt/mellanox/doca` tree
that the public DOCA install (or the public NGC DOCA container,
`nvcr.io/nvidia/doca/doca`) puts on the user's host. *Where to find*
and *how to install* questions are routed elsewhere — see *Related
skills* below.

**Language scope.** DOCA itself is a C library family; every shipped
sample in `/opt/mellanox/doca/samples/` and every shipped reference
application in `/opt/mellanox/doca/applications/` is C. C and C++
consumers are the canonical case for every prescriptive workflow in
this skill. Other-language consumers (Rust, Go, Python, …) consume the
same `*.so` libraries through FFI or language-specific bindings against
the public C ABI; the skill keeps the lifecycle, capability, error,
observability, and safety guidance language-neutral, and routes the
language-specific build / FFI work back to the consumer's own toolchain
without authoring wrappers.

## When to load this skill

Load this skill when the user has DOCA installed *and* the env-class
preconditions are already satisfied (i.e.,
[`doca-setup`](../doca-setup/SKILL.md) has produced a clean install
where `pkg-config doca-<library>` resolves, hugepages are mounted, and
devices are visible), and is now asking a question about **how to
actually program against DOCA** in a library-agnostic way:

- Understanding what DOCA's pieces are (libraries, apps, services,
  tools) and which side of the wire they run on.
- The canonical `pkg-config` + meson build pattern any DOCA application
  follows, regardless of which library it consumes.
- The universal *derive a custom first application from a shipped
  sample* workflow that every library skill extends with
  library-specific overrides — moved here from `doca-setup` because it
  is a programming verb, not an env verb.
- The universal DOCA lifecycle (`cfg-create → init → start → use →
  stop → destroy`) and how it manifests across libraries.
- The general `DOCA_ERROR_*` pattern, `doca_error_t`, and
  `doca_error_get_descr()` — the cross-library shape, not Flow- or
  RDMA-specific overlays.
- The validate-before-commit rule and the program-side safety policy
  that every library skill inherits.
- Programming patterns that apply to consumers in *any* language
  (C/C++ directly, FFI / bindings for Rust / Go / Python / …) — the
  skill keeps the patterns language-neutral and points the agent at
  the public C ABI as the authoritative surface.

Do **not** load this skill for:

- *"Is my install healthy? Why does `pkg-config` not find `doca-flow`?
  How do I mount hugepages? I don't have DOCA installed yet — can I
  use a container?"* — env-class questions belong in
  [`doca-setup`](../doca-setup/SKILL.md), which owns install
  verification, env preparation, env-class debugging, and the
  *no-install → NGC container fallback* path for any user on macOS,
  Windows, or Linux without DOCA.
- *"What is DOCA? Where is the Flow programming guide? Which package
  do I install?"* — routing / orientation questions belong in
  [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md).
- *"How do I construct a Flow pipe / set up an RDMA queue / use Comch
  to send a message?"* — library-internal API questions belong in the
  matching library skill (e.g.
  [`doca-flow`](../doca-flow/SKILL.md)).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation needed
to pick the right next file. The substantive material lives in two
companion files:

- `CAPABILITIES.md` — what every DOCA program looks like in the
  abstract: the shape of DOCA (host / DPU / switch, libraries / apps /
  services / tools, build flavor selection rationale), the universal
  program lifecycle, the unified version-compat rule that applies to
  any program linking DOCA, the cross-library `DOCA_ERROR_*` taxonomy,
  the program-side observability surface (DOCA logging, capability
  snapshots), and the program-side safety policy that every library
  skill inherits.
- `TASKS.md` — step-by-step workflows for the six in-scope programming
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`. The
  `## modify` verb owns the universal *derive a custom first app from
  a sample* pattern that every DOCA library skill extends with
  library-specific overrides; the `## build` verb owns the canonical
  `pkg-config doca-<library>` build pattern in two language tracks
  (C/C++ direct, non-C via FFI).

This skill assumes [`doca-setup`](../doca-setup/SKILL.md) has already
produced a clean install. It does **not** cover env preparation; that
is `doca-setup`'s job, including the *no-install → NGC container
(`nvcr.io/nvidia/doca/doca`)* fallback for users on macOS, Windows, or
Linux without DOCA.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates bundle.
It deliberately does not contain — and pull requests should not add:

- **Pre-written DOCA application source code, in any language.** This
  includes C / C++ files, Rust crates, Go packages, Python modules,
  and wrapper code for any other language. The DOCA API surface
  evolves between releases and code written from documentation prose
  cannot be verified without compiling / linking / FFI-loading it
  against the live library on a real install. The verified DOCA
  application source code is the shipped C samples on the user's
  installed system; the agent's job is to route the user to that file
  and prescribe a minimum-diff modification on it
  ([`TASKS.md ## modify`](TASKS.md#modify)) — for C/C++ users — or to
  route non-C users to the public C ABI surface that their bindings
  will call ([`TASKS.md ## build`](TASKS.md#build) Track 2), *not* to
  author the wrapper.
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, `setup.py`, `go.mod`, …) parked inside the skill. The
  agent constructs the build manifest *in the user's project
  directory* against the user's installed DOCA, where `pkg-config
  --modversion doca-<library>` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any kind.
  A mock or incomplete artifact in this skill's tree, even one
  labeled "reference", is misleading: users will read it as
  buildable.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is a
   programming-class question (not env, not routing, not library-API).
2. **For the DOCA shape, the universal lifecycle, the cross-library
   error taxonomy, the program-side observability surface, and the
   safety policy that every library skill inherits, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step programming workflows — `configure`, `build`,
   `modify`, `run`, `test`, `debug` — see [TASKS.md](TASKS.md).**

If the user is asking for a *first app* in a specific library, walk
through [`TASKS.md ## modify`](TASKS.md#modify) for the universal
copy-and-edit pattern, then hand off to the library skill (e.g.
[`doca-flow`](../doca-flow/SKILL.md)) for the library-specific values
to swap.

## Related skills

- [`doca-public-knowledge-map`](../doca-public-knowledge-map/SKILL.md)
  — public DOCA documentation routing and the on-disk layout of an
  installed DOCA package. This skill defers all *"where is X
  documented"*, *"where on disk is Y"*, and *"how do I check the
  installed version"* questions to the knowledge-map.
- [`doca-setup`](../doca-setup/SKILL.md) — env preparation, install
  verification, env-class debugging, and the *I have no install yet*
  procedure with the NGC container (`nvcr.io/nvidia/doca/doca`) as
  the universal Stage-1 fallback for any user on macOS, Windows, or
  Linux without DOCA. This skill assumes `doca-setup`'s preconditions
  are already satisfied.
- [`doca-flow`](../doca-flow/SKILL.md) — DOCA Flow on BlueField.
  Extends this skill's `## modify` (universal first-app derivation)
  with the Flow-specific list of fields to swap.
