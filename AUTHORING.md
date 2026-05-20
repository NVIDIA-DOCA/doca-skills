# Authoring guide for `doca-skills`

This file is for **contributors** adding or modifying a skill in this
repository. It captures the rules we have already arrived at, in one
place, so new skills do not have to rediscover them. The
`ci/check-skill.sh` lint and `ci/check-coverage.sh`
coverage check enforce the parts of this guide that can be mechanically
checked; **§ 11 below names two further gates a contributor MUST run
before opening a PR** (the upstream Anthropic frontmatter validator and
the two-agent A/B comparison test). The rest is on you when you write
the skill.

If you are an *agent consumer* (Cursor, Claude Code, …), read
[`AGENTS.md`](AGENTS.md) and [`SKILLS.md`](SKILLS.md) instead — those
describe how to *use* the skills. This file describes how to *write*
them.

---

## 1. Audience

**Every skill in this repo serves external developers consuming DOCA**
— i.e., people calling `doca_*` from their own networking application
to offload work onto a BlueField DPU or ConnectX NIC. Concretely:

- They installed DOCA from the public packages (or are using the
  public NGC DOCA container per `doca-setup ## no-install`).
- They do **not** have access to the DOCA source repository, internal
  NVIDIA Gerrit / NVBugs / Confluence, or any internal mirror.
- They are using a fresh AI agent on a clean dev environment; the
  agent has no prior project context beyond what these skills provide.

If a skill would only make sense to a **DOCA contributor** (someone
modifying DOCA itself), it does not belong in this repo. Move it to
the contributor-internal repo or do not write it.

When in doubt: write for someone who has a freshly-installed DOCA, no
git access to NVIDIA-internal repos, and an off-the-shelf AI coding
agent.

---

## 1a. Classes-over-instances (load-bearing invariant)

**Every artifact in this bundle teaches the agent to handle a CLASS of
problems. Specific instances appear only as worked examples inside
class-shaped artifacts.** This is the central design constraint: we
cannot enumerate every DOCA use case (L4 load balancer, NAT, firewall,
hairpin, sampling, mirroring, switch-representor, ad infinitum), and any
attempt to do so makes the bundle look complete when it is actually a
curated demo.

Concretely:

- **References / md depth content** are taxonomies, maps, and playbooks
  — never deep walkthroughs of one named use case. `pattern-library`
  (taxonomy) is in scope; `flow-load-balancer` (instance) is out of
  scope.
- **Example prompts** demonstrate the *shape* of an effective question.
  The headline names the class (*"derive any app from any sample"*); a
  specific feature appears only as the worked example inside the prompt
  body.
- **Prompts in `runner/prompts/`** target an artifact CLASS
  (any service, any tool, any library). `baseline_artifact:` names the
  artifact the prompt is loaded against; the prompt body teaches the
  class so any variant of the same question still passes.
- **Scripts** (when the maintainer roadmap is
  implemented) parameterize over library/artifact. `list_doca_samples.sh
  [library]` is in scope; `list_flow_samples.sh` is out of scope.
- **New skills** cover a cross-cutting concern (the pattern of
  `doca-debug`, the planned `doca-eval`). Library-specific overlays
  stay in the matching `libs/<lib>/`, `services/<svc>/`,
  `tools/<tool>/` skill.

A PR that ships an instance-shaped artifact (e.g. a markdown filename
like `flow-load-balancer.md`, a future template like `flow-firewall.yaml`,
a future script like `list_rdma_qps.sh`) **fails review by construction,
regardless of whether the rest of the gates pass.** The
mechanical enforcer is the class-shape filename regex in
`ci/check-skill.sh` (rejects `*-load-balancer.md`,
`*-firewall.md`, `*-nat.md`, `*-l3-router.md`, `*-hairpin.md`,
`*-sampling.md`, `*-mirroring.md`, and a small set of common feature
names). The two-agent A/B from § 11 plus the
`generalizes_beyond_worked_example` criterion in every prompt is the
behavioral enforcer: skills-loaded must succeed on a *variant* of the
shipped worked example, not just the exact one.

**Why this rule exists.** Without it, every customer feature request
becomes a candidate artifact. The bundle grows linearly in customer
requests but its agent-value per artifact decreases: an agent loaded
with 200 use-case templates is no better at the 201st request than an
agent loaded with one schema and the patience to compose. The class-
shape rule keeps the bundle's growth aligned with the *shape of agent
work*, not the *cardinality of customer asks*.

---

## 2. Public sources only

**No internal NVIDIA references, anywhere, ever.** The lint enforces
this with a non-public-references check (always on). The blocked
vocabulary in URL or path context includes `gerrit`, `nvbugs`,
`*.internal.*`, `gitlab-master`, `labhome`, `internal-mirror`,
`/labhome/`, `/opt/internal/`, and `confluence.nvidia.com` (an
upstream `docs.nvidia.com` page may leak a Confluence URL — do not
re-cite it).

`*.nvidia.com` URLs are restricted to a small public allowlist:

- `docs.nvidia.com`
- `developer.nvidia.com`
- `catalog.ngc.nvidia.com`
- `ngc.nvidia.com`
- `forums.developer.nvidia.com`
- `nvcr.io`

If you need to cite an NVIDIA URL on a different host, it is almost
certainly internal — find the public equivalent or do not cite.

For non-NVIDIA public sources (DPDK, Linux kernel docs, OpenConfig,
gRPC, …), no allowlist applies; the URL HEAD validity check
(opt-in, `--check-urls`) will simply confirm the URL responds.

---

## 3. Validate the data you add

**Never invent symbols, URLs, paths, package names, language
bindings, cloud SKUs, or service names.** If you cannot verify it
from a public DOCA doc page, the public NGC catalog, the on-disk
layout of a real DOCA install, or the live install's `--help` output,
do not write it.

Concrete checks before adding content:

- **URLs.** Fetch the page. The URL HEAD lint catches 404s; you
  catch *wrong page that happens to render*.
- **Service / library / tool existence.** Open
  `https://docs.nvidia.com/doca/sdk/` and confirm the artifact is
  listed.
- **API symbols.** If you mention `doca_<library>_<symbol>`, the
  symbol must exist in the headers shipped on a real install at
  `/opt/mellanox/doca/include/<library>/`. If you can't check, write
  prose that points the user at where to find the symbol, not the
  symbol itself.
- **Versioned claims.** If you say "introduced in DOCA X.Y", that
  fact has to be in the public release notes. If it's not, omit the
  version pin.
- **Tool flags.** If you quote a tool's flag, it must be in the
  public guide for that tool. Do not infer flags from generic CLI
  patterns.
- **Provenance / patchset claims.** Do not infer downstream provenance
  ("this is DPDK 22.11 LTS with NVIDIA patches") from version strings
  alone. Either find a public statement or omit the claim. (TODO:
  this guideline will move into
  `doca-programming-guide CAPABILITIES.md ## Version compatibility`
  in a follow-up; it is captured here meanwhile.)

When in doubt: route the agent to read the live source rather than
shipping the answer in the skill. The skills are a *map*, not a
*cache*.

---

## 4. Keep it simple

A skill that tries to cover everything covers nothing well. Keep
each skill focused:

- **One artifact per skill.** A library skill is about that one
  library; a service skill is about that one service; a tool skill
  is about that one tool. Cross-cutting concerns (env setup,
  programming patterns, doc routing) live in the three top-level
  skills, not duplicated in every per-artifact skill.
- **Cross-link instead of duplicating.** If a topic is covered in
  another skill, link to it (`[<skill-name> ## <anchor>]`) rather
  than re-writing it. The cross-anchor lint will catch you if the
  target moves or renames.
- **Procedural, not encyclopedic.** A skill's job is to tell an
  agent *what to do next*. Background prose is justified only when
  it changes the next step the agent should take.
- **Refuse to ship code.** No pre-written DOCA application source
  code in any language (C, C++, Rust, Go, Python, …). No standalone
  build manifests. No `samples/`, `bindings/`, or `reference/`
  subtree. The shipped DOCA samples on disk *are* the verified
  source of truth; the skill prescribes a minimum-diff modification
  on them via the universal modify-a-sample workflow.

---

## 5. Layered tree

> **Strict-to-doca invariant (load-bearing, added in PR3).** The
> per-artifact skills under `skills/{libs,services,tools}/` are
> **strictly 1:1 with `doca/{libs,services,tools}`** at the DOCA
> release the bundle is aligned to (read from `doca/VERSION` — the
> currently-aligned release at the time of writing is `3.5.0019`).
> The CI HARD gate
> [`ci/check-doca-inventory.sh`](ci/check-doca-inventory.sh)
> clones `@doca` at the `DOCA_BRANCH` parameter, reads `doca/VERSION`,
> and fails the build on:
>
> - **MISSING**: an artifact exists in `doca/{libs,services,tools}/`
>   but the bundle has no skill for it → AUTHOR the skill.
> - **EXTRA**: a skill exists in `skills/{libs,services,tools}/` but
>   `doca/` has no matching artifact → DELETE the skill (it's drift
>   from a previous DOCA release, or it represents an external
>   NVIDIA product not in the monorepo — see
>   [`AGENTS.md ## Non-goals`](../doca-skills/AGENTS.md#non-goals)).
>
> **Naming alignment is also strict.** Skill directory names match
> the `doca/` artifact name modulo the convention `doca_X →
> doca-X` (underscore → dash). When `doca/` renames an artifact
> (e.g. `doca_device_emulation → doca_devemu`, `doca_rivermax →
> doca_rmax`, `doca_pcc_counter → doca_pcc_counters`), the bundle
> renames in lockstep on the next bundle alignment. Out-of-date
> names fail the inventory gate as EXTRA + MISSING in the same run.
>
> **What this is not.** This invariant applies only to
> per-artifact skills. The top-level cross-cutting skills
> (`doca-setup`, `doca-programming-guide`, `doca-debug`,
> `doca-version`, `doca-structured-tools-contract`,
> `doca-hardware-safety`, `doca-container-deployment`,
> `doca-public-knowledge-map`) are NOT per-artifact and are
> exempt — they cover concerns that apply across `doca/`'s
> per-artifact decomposition.

Skills live under top-level `skills/`, in one of four slots. The
path is intentionally **not** under `.claude/`, `.cursor/`, or any
other agent-runtime-specific directory — the bundle is vendor-
neutral and reads naturally to any agent driven by `AGENTS.md`.

```
skills/
├── doca-public-knowledge-map/   # cross-cutting routing skill
├── doca-setup/                   # cross-cutting env skill
├── doca-programming-guide/       # cross-cutting programming skill
├── libs/<library>/               # one skill per DOCA library
├── services/<service>/           # one skill per DOCA service
└── tools/<tool>/                 # one skill per DOCA tool
```

**Top-level slots are reserved for cross-cutting skills.** The three
that exist (`doca-public-knowledge-map`, `doca-setup`,
`doca-programming-guide`) cover concerns that apply across libraries,
services, and tools. New top-level skills are unusual — most
contributions belong under `libs/`, `services/`, or `tools/`.

Slot selection:

- **`libs/<library>/`** — the artifact is a DOCA library the user
  links into their own application (e.g. `doca-flow`, `doca-rdma`,
  `doca-comch`, `doca-gpunetio`). User writes code that calls
  `doca_<library>_*` symbols.
- **`services/<service>/`** — the artifact is a long-running daemon
  / container documented separately on `docs.nvidia.com/doca/sdk/`
  (e.g. `doca-dms`, `doca-dts`, `doca-firefly`). User runs it; user
  does not link `lib<service>.so`.
- **`tools/<tool>/`** — the artifact is a CLI shipped under
  `/opt/mellanox/doca/tools/` and documented on its own public page
  (e.g. `doca-caps`, `doca-bench`, `doca-socket-relay`). User runs
  it; output is its primary surface.

If you can't tell which slot something belongs in, it probably
straddles two and you are looking at a skill-design mistake. Split it.

The physical tree is a convention; agents discover skills by their
declared `name:` and resolve cross-links by name regardless of
location. Reorganizing later does not break agent discovery — it
only requires updating relative paths in cross-links.

---

## 6. Kind selection (`knowledge` vs `library`)

Every `SKILL.md` declares `kind:` in its frontmatter:

- **`kind: knowledge`** — single-file skill. No companion files.
  No required H2 anchors beyond `## When to load this skill`. Use
  only for:
    - Cross-cutting routing / knowledge maps that are pure pointer
      tables, not workflows the agent walks an operator through
      (`doca-public-knowledge-map`).
- **`kind: library`** — three-file skill (`SKILL.md` +
  `CAPABILITIES.md` + `TASKS.md`). Required H2 anchors are
  enforced by `ci/check-skill.sh`. **This is the default; prefer
  it.** Use for:
    - DOCA libraries (`doca-flow`).
    - DOCA services (`doca-dms`) — even though they're not C
      libraries, the operational surface is rich enough to justify
      the same six task verbs.
    - DOCA tools (`doca-caps`) — even read-only CLIs the user
      *invokes* belong here, because the agent's task-verb contract
      (`run / test / debug` in particular) carries real workflow
      content for them. For verbs that genuinely don't apply to a
      shipped read-only binary (`configure / build / modify`), use a
      one-paragraph routing stub under the H2 instead of skipping
      the H2.
    - Cross-cutting skills with rich workflows (`doca-setup`,
      `doca-programming-guide`).

When choosing: **default to `kind: library`** for any artifact the
agent is meant to operate against — library, service, or tool — so
the task-verb contract is uniform across the bundle and no skill
becomes a structural exception that a reviewer has to ask about.
Only fall back to `kind: knowledge` when the skill is a pure
routing / pointer table with no `run / test / debug` content of its
own.

---

## 7. Required structure (enforced by lint)

### Every skill (`SKILL.md`)

- YAML frontmatter with:
    - `name:` matching `^[a-z0-9-]{1,64}$`
    - `description:` non-empty, ≤ 1024 characters
    - `kind: knowledge | library`
- An H2 `## When to load this skill`.

### `kind: library` skills

In addition to the above:

- `CAPABILITIES.md` exists with these H2 anchors, in this order:
  `## Capabilities and modes`, `## Version compatibility`,
  `## Error taxonomy`, `## Observability`, `## Safety policy`.
- `TASKS.md` exists with these H2 anchors, in this order:
  `## configure`, `## build`, `## modify`, `## run`, `## test`,
  `## debug`, `## Deferred task verbs`.
- Cross-link labels of the form `[<skill-name> ## <anchor>](...)`
  inside `TASKS.md` must resolve: the named skill must exist
  somewhere under `skills/`, and the anchor must exist in
  one of its files.

If a verb is genuinely n/a for your skill (e.g. "modify" for a
side-effect-free tool, or "build" for a service), keep the H2 and
write a short *routing stub* — explain why the verb is n/a here and
where the user's question really belongs. Do not delete the H2; the
lint requires it.

### Layered cross-references

When you link from a `libs/<lib>/` skill to a top-level skill, the
relative path is `../../<top-level-skill>/...`. When you link from a
top-level skill to a `libs/<lib>/` skill, the relative path is
`../libs/<lib>/...`. Same pattern for `services/` and `tools/`.

The lint only checks that the target skill *and the target anchor*
exist; it does not validate the relative URL itself, but the URL has
to be correct for human navigation and for agent runtimes that follow
links literally. When in doubt, build the skill, run the lint, and
click the link.

---

## 8. Lint expectations

Run these locally before opening a PR:

```bash
ci/check-skill.sh --all                # structural + non-public, no network
ci/check-skill.sh --all --check-urls   # also URL HEAD validity (needs network)
ci/check-skill.sh --self-test          # confirm every gating check still trips
ci/check-coverage.sh                   # bundle covers every public DOCA lib/svc/tool
```

What each check enforces:

| Check | Default | Network | Catches |
| --- | --- | --- | --- |
| Frontmatter validity, required H2 anchors, cross-anchor resolution, no symlinks. | always on | no | structural drift, broken cross-links, accidental symlinks (which the symlink-objection rule forbids). |
| Non-public references: NVIDIA-host allowlist + internal-vocabulary blocklist. | always on | no | leaks of internal hostnames, paths, or tool names. |
| URL HEAD validity. | opt-in `--check-urls` | yes | renamed / deleted public pages (the *Samples Overview 404* failure mode). |

**Soft warnings about `/opt/mellanox/doca` and `docs.nvidia.com`
density** are non-gating: they exist to nudge you to consider whether
something belongs in `doca-public-knowledge-map` instead of
duplicated everywhere. For env-class and programming-guide-class
skills, the density is intrinsic to the topic and the warnings are
expected.

CI runs `--all --check-urls` whenever outbound network is available.

**Coverage check (`check-coverage.sh`) is also non-gating today** (SOFT
WARN per round-2 directive). It diffs the bundle's three routing
tables in `doca-public-knowledge-map/SKILL.md` against the live SDK
catalog enumerated in the script's `EXPECTED_LIBRARIES` /
`EXPECTED_SERVICES` / `EXPECTED_TOOLS` arrays, and against the
per-skill directory tree under `skills/libs/`, `skills/services/`,
`skills/tools/`. **A new skill that lands without a row in
`doca-public-knowledge-map` will trip the coverage check** — fix it by
adding the routing-table row, not by suppressing the warning. The
gate promotes to HARD FAIL via `--hard-fail-below=<pct>` after 3-5
runs of signal.

---

## 9. Discovery and routing

The four-layer routing pattern every skill participates in:

1. **`doca-public-knowledge-map`** — *where do I look up this thing?*
   The routing table for public docs, on-disk install layout, public
   repos, NGC catalog, the developer forum, the public services
   index, and the public tools index.
2. **`doca-setup`** — *is my env actually ready?* Install
   verification, build environment, env-class debugging, and the
   *I have no install yet* path with the public NGC DOCA container.
3. **`doca-programming-guide`** — *how do I program against DOCA in
   general?* The canonical build pattern, the universal
   modify-a-sample workflow, the universal lifecycle, the
   cross-library `DOCA_ERROR_*` taxonomy, the program-side debug
   order. Library-agnostic.
4. **`libs/<library>` / `services/<service>` / `tools/<tool>`** —
   *the per-artifact specifics*. Layered on top of the three above;
   never duplicating them.

A new skill always starts by stating which of the three foundations
it builds on, and in its `## Related skills` section names the
others it expects to run alongside. The lint catches broken
cross-anchors but does not enforce that you *use* the layering — that
is on you when designing the skill.

---

## 10. Style: rules vs guidelines

Frame procedural content as **guidelines / best practices**, not
mandatory rules, where possible. The agent has to make judgment
calls; framing everything as a hard rule wastes its judgment budget
on mechanical compliance.

Mandatory ground rules (the four in `AGENTS.md` § *Ground rules
every agent must follow*) are the exception — they exist because
violating them produces visible-to-the-customer failures.

### 10a. Affirmative phrasing for project-specific rules

When you write any rule (mandatory or guideline), **say what to do,
not what not to do.** This is the convention in published agent-rule
docs (see the `agents.md` reference spec — every example block in it
is affirmative; no `"never reference X, Y, Z"` patterns naming
specific infrastructure).

| Avoid | Prefer |
|---|---|
| "Never reference internal NVIDIA hostnames, Gerrit, NVBugs, Confluence, Jenkins." | "Reference NVIDIA documentation only on these public hosts: `docs.nvidia.com`, `developer.nvidia.com`, `catalog.ngc.nvidia.com`, `ngc.nvidia.com`, `forums.developer.nvidia.com`, `nvcr.io`." |
| "Don't ship hand-written DOCA application source code." | "Prescribe a minimum-diff modification on the upstream shipped sample (the verified source of truth on the user's install)." |
| "Don't invent symbols / URLs / paths." | "Cite only what you've verified against a real public source — the live page, the live install's `--help`, the on-disk header." |

Two reasons this is materially better, not just polish:

1. **Sharper agent signal.** A closed allow-set is more actionable
   for an agent than an open deny-set: the agent can answer "is this
   in the allow-set?" yes/no; "is this in the deny-set?" requires
   the agent to enumerate everything the deny-set might cover.
2. **Doesn't surface internal-tooling vocabulary in user-facing
   prose.** Customers reading the bundle should not need to read a
   list of NVIDIA-internal tools to learn what's in scope. The
   *enforcement* layer (`ci/check-skill.sh` regex) needs the names
   to match against — that's where they belong, not in user-facing
   skill files.

**Exception: the lint script and the Conformance section.** The lint
regex (`ci/check-skill.sh`) has to name the blocklist patterns to
match against; that's by necessity. The `## Conformance` sections in
`AGENTS.md` and `README.md` document *what the lint matches* and
also reasonably name the patterns; that's contributor-facing context
about how the gate works, not a rule the agent or user is being
asked to internalize. Keep affirmative phrasing in the rule
sections; keep descriptive phrasing in the gate-documentation
sections.

### 10b. Defense-in-depth between rule and gate

When a rule has a mechanical enforcer (the lint), the rule should
*name the enforcer* and stay affirmative about the in-scope set.
Example pattern:

> **Public sources only.** Reference NVIDIA documentation only on
> the public hosts listed above. Anything else is rejected by
> `ci/check-skill.sh`.

This pattern (affirmative rule + pointer to the enforcer) makes the
rule self-documenting about its own enforcement, lets a reader
check the gate's exact behavior in `ci/check-skill.sh` if they
want to, and doesn't duplicate the gate's blocklist in user-facing
prose.

---

## 11. Required merge gates (HARD)

In addition to the lint and coverage checks, **two further gates MUST
pass before a skill change merges**. The Jenkins pipeline enforces gate
A automatically; gate B is a contributor responsibility because it
depends on running fresh agents that the CI's adapter contract does not
yet wire up by default.

### Gate A — Upstream Anthropic frontmatter validator

Run the upstream community validator on every `SKILL.md` you added or
modified. The Jenkins pipeline runs this in the
`Validate frontmatter (claude-skill-check) — HARD GATE` stage; the
pipeline blocks merge on any real ERROR. Run it locally first so you
do not waste a CI cycle.

The package the contract calls *"`skills-ref validate ./my-skill`"*
does not exist on PyPI under that name. The actual installable
upstream community validator is **`claude-skill-check`**
(<https://pypi.org/project/claude-skill-check/>). Treat the two names
as synonyms; the contract is the same.

```bash
pip install --user claude-skill-check
for f in $(find doca-skills/skills -name SKILL.md); do
    claude-skill-check "$f"
done
```

**Pass criterion: 0 errors per file.** Warnings of the form
`W900 unknown field 'kind'` are expected on every skill in this
bundle and do not block merge — `kind:` is the bundle's own routing
contract documented in `AGENTS.md` § *Ground rules every agent must
follow* (values: `library` or `knowledge`); it is not part of the
upstream Anthropic spec. Any other warning or any error fails the
gate; fix the frontmatter and re-run.

### Gate B — Three-agent A/B comparison test (baseline / main / pr)

For any change that adds or substantively modifies a skill,
**run three fresh agents on the same prompt set and confirm the
pr-branch variant beats both baseline and main**. This is the gate
that catches *"the skill compiles, lints, and validates, but doesn't
actually help an agent answer the user's question"* — a failure mode
the mechanical checks structurally cannot catch — AND the gate that
catches the new regression mode introduced as the bundle grows:
*"a perfectly good answer at main got worse on this PR"*.

The three-agent contract:

- **Variant 1: baseline.** A fresh agent with **no access** to
  `doca-skills/` or any demo file. May fetch public
  docs (`docs.nvidia.com`, `developer.nvidia.com`,
  `catalog.ngc.nvidia.com`, `forums.developer.nvidia.com`,
  `nvcr.io`) and use general training knowledge.
- **Variant 2: main.** A fresh agent with **access** to
  `doca-skills/` at `origin/main`. Reads `AGENTS.md` and
  `SKILLS.md` first and loads whichever per-skill `SKILL.md` files
  it judges relevant.
- **Variant 3: pr.** Same setup as main, but `doca-skills/` is
  checked out at this PR's HEAD.

All three variants answer the **same prompt set** (chosen
dynamically per § 15) and self-audit against the **same criteria**
the prompt YAML in `runner/prompts/` encodes. The change is
mergeable when **all** of the following hold:

- pr strictly beats baseline on at least one criterion the change
  targets, and ties-or-beats baseline on every other criterion. No
  criterion regresses against baseline.
- pr ties-or-beats main on every criterion of every selected prompt.
  Any per-criterion regression against main is a hard fail —
  investigate before merging, even if the aggregate pr score is
  higher.
- For every class-shaped prompt, pr passes the
  `generalizes_beyond_worked_example` criterion. If the agent only
  answers the worked example and is silent on the broader class,
  the skill content has drifted into instance-shaped territory and
  needs to be rewritten before merge (see § 1a).

Picking the prompts: see § 15 — selection is automatic via
`runner/select_prompts.py`. You do not pick prompts by
hand for the merge gate.

How to run, locally (until the Jenkins job is wired):

1. From the workspace root, list the prompts this PR should
   exercise:
   ```bash
   python3 runner/select_prompts.py \
     --prompts-dir runner/prompts \
     --skills-repo doca-skills \
     --since main \
     --print-decision > selected_prompts.txt
   ```
   Read the stderr decision log; confirm the right prompts were
   selected for the skills you changed.
2. Open THREE parallel chat sessions (or three subagent invocations
   if your runtime supports it). Fresh state matters; reusing a
   session that has already seen the bundle is not a baseline.
3. Apply the per-variant access rules above. For the main variant,
   point the agent at a worktree of `doca-skills` checked out at
   `origin/main`; for the pr variant, point it at your branch's HEAD.
4. For EACH prompt listed by `select_prompts.py`, paste it into all
   three sessions and score the responses against the prompt YAML's
   `criteria:` block. The criteria are graded yes/no with supporting
   lines; that is intentionally cheap to run by hand.
5. Apply the three pass criteria above. If any fails, fix the skill
   and re-run.

The pattern is the same one the round-2 quality gate used; the
captured baseline-vs-skills runs from that gate live as named
subagent transcripts and serve as worked examples. The writeup
shape (two columns at round-2, three once the main variant lands)
is documented in the maintainer-only round-2 backlog.

The CI runs an *automated* version of this same A/B
(`runner/ab_runner.py`) once a working `AgentAdapter` and
`JudgeAdapter` are wired up; that automated path complements but
does not replace the manual three-agent test, because the manual
test catches a class of failure (loaded the wrong skills,
loaded but did not use them) that an automated rubric cannot
reliably score.

---

## 12. Anchor-density gate (HARD)

Lint (§ 7) verifies that every required H2 anchor in `SKILL.md`,
`CAPABILITIES.md`, and `TASKS.md` is *present*. The anchor-density
gate (`ci/check-anchor-density.sh`) additionally verifies that
each required anchor carries **real content** — not a one-line
placeholder, not "TBD", not a single bullet that punts to another
file.

The floor is **5 non-blank lines under each required H2 anchor**,
with two anchors allowed to be shorter because they legitimately
*are* short:

| Anchor                  | Min non-blank lines |
|-------------------------|---------------------|
| `## Deferred task verbs`| 3                   |
| `## Safety policy`      | 3                   |
| (everything else)       | 5                   |

The script ignores anchors that are *missing* (lint catches those as
hard fails), so the density gate only fires on under-filled present
anchors. Run it locally before opening a PR:

```bash
SKILLS_ROOT=doca-skills/skills bash ci/check-anchor-density.sh --all
```

If you legitimately cannot say more than two sentences about an
anchor for a particular skill (e.g. a tool's `## modify` section
when the tool genuinely has no modify-time concerns), state that
*and the reason* under the anchor, in prose. "Not applicable: this
tool produces no source artifacts" counts; "TBD" does not.

---

## 13. Class-shape filename gate (HARD)

The class-shape gate (`ci/check-skill.sh ## 8`, also
`--check-class-shape <dir>`) rejects filenames that name a specific
use case rather than a class of problems. The blocked suffixes are
the canonical "shape of every customer feature request":

```
load-balancer, firewall, nat, l3-router, hairpin, sampling,
mirroring, switch-representor, tunnel-encap, tunnel-decap,
vxlan, gre, gtpu, mpls
```

Filenames that match any of those suffixes after the last separator
(`-` or `_`) fail the gate regardless of where in the tree they sit.
The rule applies to every `.md` file under `doca-skills/skills/` and
every `.md` / `.yaml` / `.yml` under `runner/prompts/`.

The fix is always the same: fold the use case into a class-shaped
artifact (e.g. `references/pattern-library.md` with a "load
balancer" section) and reference the worked example from the prompt
body, not the filename. See § 1a for the full rationale.

A self-test exercises this gate. Run it locally:

```bash
SKILLS_ROOT=doca-skills/skills bash ci/check-skill.sh --self-test
```

Self-test 7 specifically asserts that `flow-load-balancer.md` fails
the gate.

---

## 14. Markdown-quality gates (SOFT WARN by default; HARD when promoted)

Three additional gates focus on baseline markdown craftsmanship.
They start as SOFT WARN; the Jenkinsfile flips each to HARD FAIL
once it has 3-5 clean runs of signal, per the gate-promotion
policy in § 10.

| Tool                         | What it checks                                             | Promotion threshold |
|------------------------------|------------------------------------------------------------|---------------------|
| `markdownlint`               | List markers, heading depth, line length, ATX style        | 3 clean runs        |
| `lychee`                     | URL validity (advanced replacement for `--check-urls`)     | 5 clean runs        |
| `check-anchor-density.sh`    | Stub-anchor detection (see § 12)                           | HARD day one        |

The `markdownlint` config lives at `ci/.markdownlint.json`.
Edit the config to relax a rule, never to whitelist a specific file
— a per-file exception almost always points at content that should
move into a different anchor.

Install locally (one-time):

```bash
npm install -g markdownlint-cli
cargo install lychee   # or: brew install lychee
```

Run locally:

```bash
markdownlint --config ci/.markdownlint.json doca-skills devops
lychee --config ci/lychee.toml doca-skills devops
SKILLS_ROOT=doca-skills/skills bash ci/check-anchor-density.sh --all
```

(A `lychee.toml` will land alongside the first time the Jenkins job
needs a non-default config; until then, lychee runs with defaults.)

---

## 15. Dynamic prompt selection and per-artifact coverage gates

The A/B test in § 11 Gate B does **not** run every prompt in
`runner/prompts/` against every PR. That would be both slow
and uninformative — most prompts have no signal for most PRs.
Instead, `runner/select_prompts.py` picks the prompt subset
per PR based on what the PR touches.

### Selection rules

For any PR, `select_prompts.py --since main` returns:

1. **General prompts** (no `baseline_artifact:` in their YAML
   frontmatter, or `baseline_artifact: general`). These probe
   bundle-wide concerns (orientation, latest tag, link-error debug)
   and always run regardless of which skill changed.
2. **Targeted prompts** whose `baseline_artifact:`,
   `changed_skill_in_pr:`, or any `expected_skill_co_load:` entry
   names a skill that the PR touched. "Touched" means a path under
   `skills/<...>/` shows up in `git diff --name-only main...HEAD`.

Result: a PR that only edits `skills/services/doca-dms/` runs the
general prompts plus `05_deploy_doca_service.yaml`. A PR that adds
a brand-new `skills/libs/doca-rdma/` must therefore land a prompt
that targets `doca-rdma` in the same PR — there is no other way to
make the A/B exercise the new skill.

### Per-artifact PROMPT coverage gate (HARD)

`ci/check-coverage.sh --prompt-coverage-hard-fail` enforces
**every `libs/`, `services/`, `tools/` skill has at least one prompt
that names it**. This is the gate that pairs with selection rule 2:
without it, you could add a new skill, ship it without a prompt, and
the A/B would silently skip it because the dynamic selector found
nothing targeted to run.

The gate fails the build on two conditions:

- Any `libs/services/tools` skill dir has no prompt whose
  `baseline_artifact:` / `expected_skill_co_load:` names it. Fix
  the gap by adding a class-shaped prompt under
  `runner/prompts/` (see prompts 05 and 06 as the template).
- Any prompt's `baseline_artifact:` names a skill that does not
  exist under `skills/`. This catches typos and stale references
  to deleted skills. Fix by correcting the YAML or deleting the
  obsolete prompt.

### Per-artifact SKILL coverage gate (HARD @ 100% as of PR1 close)

`ci/check-coverage.sh` ALSO reports, per category, whether
every public DOCA library / service / tool from the live SDK index
has a corresponding 3-file skill directory (`SKILL.md` +
`CAPABILITIES.md` + `TASKS.md`) under `skills/<libs|services|tools>/`.
PR1 brings the bundle to **100 % per-artifact SKILL coverage** (51 / 51
non-umbrella artifacts: 28 libraries, 11 services, 12 tools) and the
Jenkins job runs the HARD gate at that threshold:
`check-coverage.sh --skill-coverage-hard-fail-below=100`.

What this means in practice:

- Adding a new DOCA library / service / tool to the live SDK requires
  the same PR that adds the slug to `EXPECTED_LIBRARIES` /
  `EXPECTED_SERVICES` / `EXPECTED_TOOLS` in `check-coverage.sh` to
  also (a) ship the matching 3-file skill dir under `skills/...`
  and (b) add the canonical short alias to
  `slug_to_skill_candidates` in the same script. Steps (a) without
  (b) — or vice versa — fail the gate by construction.
- The `slug_to_skill_candidates` table encodes every short alias the
  bundle uses (e.g. `doca-eth` for `DOCA-Ethernet`, `doca-apsh` for
  `DOCA-App-Shield`, `doca-argp` for `DOCA-Arg-Parser`, `doca-dts`
  for `DOCA-Telemetry-Service-Guide`, `doca-urom-svc` for
  `DOCA-UROM-Service-Guide`, …). Three slugs are intentionally
  `__umbrella__`-tagged (`DOCA-Core`, `DOCA-Common`,
  `DOCA-Reference-Applications`) because they are covered cross-
  cuttingly by `doca-programming-guide` / `doca-public-knowledge-map`
  rather than by a discrete library skill.
- Routing-table coverage (`check-coverage.sh` without flags) remains
  SOFT WARN: the slug-mention-in-knowledge-map check uses the public
  doc page name, which is different from the bundle's short skill
  name. PR1 leaves this one at SOFT WARN deliberately; it surfaces
  drift between the bundle's catalog and the live SDK page index
  without blocking unrelated PRs.

Run all three gates locally:

```bash
bash ci/check-coverage.sh                                  # SOFT WARN report
bash ci/check-coverage.sh --prompt-coverage-hard-fail      # exits 2 on prompt gap
bash ci/check-coverage.sh --skill-coverage-hard-fail-below=100
                                                                  # exits 2 if <100%
```

---

## 16. Where the artifact catalog comes from

The bundle's per-artifact catalog (libraries / services / tools) is
**not invented in this repo**. It mirrors the live public NVIDIA DOCA
SDK index page-by-page. Two places encode it:

- **`ci/check-coverage.sh`** holds three arrays —
  `EXPECTED_LIBRARIES`, `EXPECTED_SERVICES`, `EXPECTED_TOOLS` — each
  populated from the corresponding section on
  <https://docs.nvidia.com/doca/sdk/>. The entries are the exact
  doc-page slugs (e.g. `DOCA-Ethernet`, `DOCA-Argus-Service-Guide`,
  `DOCA-DPACC-Compiler`). When NVIDIA publishes a new library /
  service / tool page, add the slug to the appropriate array in the
  same PR that ships the matching skill dir.
- **`slug_to_skill_candidates`** in the same script maps each slug to
  the short alias(es) the bundle uses. The first listed alias is
  canonical; additional aliases are fallbacks for renames.

Three slugs are intentionally tagged `__umbrella__` because they are
cross-cutting and covered by top-level skills, not by a per-artifact
skill: `DOCA-Core` and `DOCA-Common` (covered by
`doca-programming-guide`) and `DOCA-Reference-Applications` (covered
by `doca-public-knowledge-map`'s reference-app routing table). Do not
invent skill dirs for these.

If you cannot find an upstream slug for an artifact you think exists,
the artifact is either internal, deprecated, or you are looking at a
non-public page. Do not write a skill for it.

---

## 17. Naming conventions

The skill dir name *is* the agent-visible name (it shows up in
`SKILL.md` frontmatter `name:` and in every cross-link). Two rules
apply:

### Short alias of the SDK page slug

The skill dir uses the short, all-lowercase, hyphenated alias of the
public SDK slug. Examples:

| SDK page slug                       | Skill dir                       |
|-------------------------------------|---------------------------------|
| `DOCA-Ethernet`                     | `libs/doca-eth`                 |
| `DOCA-App-Shield`                   | `libs/doca-apsh`                |
| `DOCA-Arg-Parser`                   | `libs/doca-argp`                |
| `DOCA-Device-Emulation`             | `libs/doca-devemu`              |
| `DOCA-Rivermax`                     | `libs/doca-rmax`                |
| `DOCA-Argus-Service-Guide`          | `services/doca-argus`           |
| `DOCA-OS-Inspector-Service-Guide`   | `services/doca-os-inspector`    |
| `DOCA-Flow-Tune`                    | `tools/doca-flow-tune`          |
| `DOCA-Bench-Extension`              | `tools/doca-bench-extension`    |

The mapping must be registered in
`slug_to_skill_candidates` in `check-coverage.sh` for the coverage
gate to recognise it.

### `-svc` suffix discipline (services only)

A service skill drops the `-Service-Guide` portion of the upstream
slug. The bare short form (e.g. `doca-argus`, `doca-firefly`,
`doca-os-inspector`) is the default. **Use a `-svc` suffix only when
there is an identically-named DOCA library that would otherwise
collide.**

| Service              | Has library counterpart?     | Skill dir                  |
|----------------------|------------------------------|----------------------------|
| `doca-firefly`       | No                           | `services/doca-firefly`    |
| `doca-argus`         | No                           | `services/doca-argus`      |
| `doca-dms`           | No                           | `services/doca-dms`        |
| `doca-flow-inspector`| No (`libs/doca-flow` is the library) | `services/doca-flow-inspector` |
| `doca-os-inspector`  | No (`libs/doca-apsh` is the related library) | `services/doca-os-inspector` |
| `doca-urom`          | **Yes** — `libs/doca-urom`   | `services/doca-urom-svc`   |

The `-svc` suffix exists to disambiguate the library skill from the
service skill when an agent loads them side by side. If there is no
library with the same short name, the suffix adds nothing and
shouldn't be added.

When promoting a service from "documented" to "deployed" — or
rebranding an existing service — and a library of the same short name
exists at the same time, **add the `-svc` suffix to the service skill
dir in the same PR that introduces the collision**. The coverage
script's alias table accepts both forms so the rename is
backward-compatible.

---

## 18. Bulk authoring with sub-agents

When a PR adds many skills at once (e.g. the PR1 batch of 28
libraries / 10 services / 11 tools), authoring them by hand serially
is impractical. The pattern that worked for PR1:

### 18a. Batch in groups of three to four

Dispatch sub-agents in batches of 3–4 in parallel, each one
authoring one library/service/tool skill end-to-end. Larger batches
risk thrashing the model with conflicting context; smaller batches
under-utilise wall time. Each sub-agent gets:

1. The canonical short-form name from § 17.
2. The public SDK page URL (live, not cached).
3. The `doca-rdma` skill as the structural template (it ships every
   required H2 anchor, the cross-link pattern to `doca-version` /
   `doca-structured-tools-contract`, and the `## Command appendix`
   shape).
4. The list of cross-cutting skills it MUST cross-link into:
   `doca-version`, `doca-structured-tools-contract`,
   `doca-programming-guide`, `doca-debug`, `doca-public-knowledge-map`,
   `doca-setup`.
5. The strict instruction: **leave out facts you cannot verify
   from a public source; never invent symbols, flags, paths,
   versions, or filenames.** This is the load-bearing instruction
   that prevented hallucination in PR1.
6. A matching prompt YAML under `runner/prompts/`, written
   by the same sub-agent in the same call so the prompt and the
   skill ship together (per § 15).

### 18b. The `resource_exhausted` finisher pattern

Sub-agents occasionally hit `resource_exhausted` after producing
`SKILL.md` and `CAPABILITIES.md` but before `TASKS.md` + the prompt
YAML. The fix is **not** to re-author from scratch (that wastes
tokens and risks contradicting the already-written files). Instead:

1. `ls -la` the partial skill dir to confirm what landed.
2. Dispatch a **focused finisher sub-agent** with a much narrower
   scope: "Read the existing `SKILL.md` and `CAPABILITIES.md`; produce
   only the missing `TASKS.md` and the prompt YAML; reuse the cross-
   links, version policy, and tone already established."
3. Verify with `check-skill.sh --all`, `check-anchor-density.sh
   --all`, and `claude-skill-check` before declaring the skill done.

This pattern was used successfully for several batches in PR1, PR2,
and PR3 (the PR3 batches added 7 new libs + 1 new service + 13 new
tools to reach 1:1 alignment with `doca/`).

### 18c. After every batch, re-run the gates

The full local gate suite must come back green after each batch
before dispatching the next. The gates catch authoring drift early
(e.g. a sub-agent that invented a flag, or one that forgot the
`## Deferred task verbs` anchor):

```bash
SKILLS_ROOT=doca-skills/skills bash ci/check-skill.sh --all
SKILLS_ROOT=doca-skills/skills bash ci/check-skill.sh --all --check-urls   # network
SKILLS_ROOT=doca-skills/skills bash ci/check-anchor-density.sh --all
bash ci/check-coverage.sh --prompt-coverage-hard-fail --skill-coverage-hard-fail-below=100
for f in $(find doca-skills/skills -name SKILL.md); do
    claude-skill-check "$f"
done
```

Treat every red gate as a stop-the-line event for the *current* batch
before queuing the next.

---

## 19. Schema-first, executables-second

Several PR1 design decisions (the `doca-structured-tools-contract`
knowledge skill, the `doca-version` library skill, the deferred
material captured in the maintainer roadmap) all
follow the same rule: **ship the contract as markdown today; ship the
matching executable behind a separate PR later.**

The motivation is that a markdown contract is verifiable by lint and
review immediately, while the executable that implements it requires
runtime setup, signing, distribution, and a second round of agent
behavior testing. Decoupling them keeps the public bundle small and
the gate surface predictable.

Concretely:

- **`doca-structured-tools-contract`** (`kind: knowledge`) holds the
  JSON-schema definitions that future infra helpers — env probe,
  PCI/SR-IOV inventory, NGC promoter, version checker — will conform
  to. The schemas are usable today by an agent to validate its own
  proposed JSON output; the actual helper binaries land later.
- **`doca-version`** (`kind: library`) holds the version-detection,
  pairing, and rollback rules every other skill cross-links to via
  its `## Version compatibility` anchor. The skill is self-contained;
  the offline version-compatibility database lives in
  the maintainer roadmap for now.
- **`doca-debug`** (`kind: library`) holds the cross-cutting debug
  taxonomy + program-side debug order; the closed-loop auto-debug
  runner is also captured in the future-plan document.

When you find yourself wanting to ship a script, a generator, or a
binary in the same PR as a contract, **split the PR**. The contract
goes in this round; the implementation goes in the next round once
the contract has at least one clean validation cycle on its own.

---

## 20a. Routing discoverability (HARD gate added in PR2)

A new failure mode surfaced during the PR2 audit: **48 of 51
per-artifact skills authored by the batch sub-agents were not
mentioned in `doca-skills/SKILLS.md` OR in
`doca-public-knowledge-map/SKILL.md`**. The skills existed on disk
and passed `--skill-coverage-hard-fail-below=100`, but a fresh agent
walking the bundle (`AGENTS.md → SKILLS.md → load relevant skills`)
would never discover them — they were *phantom* skills. The
SKILL-coverage gate (does the dir exist?) and the
ROUTING-coverage gate (is the SDK page in the kmap routing tables?)
both passed; neither caught the missing skill-dir cross-link.

The mitigation:

1. The **routing-discoverability gate** in `check-coverage.sh`
   (PR2): for every skill dir under `libs/services/tools`, the
   short skill name must appear in BOTH `doca-skills/SKILLS.md`
   AND `doca-public-knowledge-map/SKILL.md`.
2. The gate ships in two modes:
   - **SOFT WARN** (`bash ci/check-coverage.sh`) — prints
     gaps, does not fail.
   - **HARD FAIL** (`bash ci/check-coverage.sh
     --routing-discoverability-hard-fail`) — fails the build on
     any gap. The Jenkins pipeline uses HARD FAIL.
3. Every new per-artifact skill PR MUST update both files in the
   same commit. The Quick checklist below has been amended.
4. A "Per-artifact skills" compact table at the bottom of
   `SKILLS.md` is the canonical entry-point listing; the kmap rows
   carry the per-SDK-page links and the skill cross-link suffix.

This is now the second mechanical defense against the *phantom
skill* failure mode, alongside the per-artifact PROMPT-coverage
gate from § 15.

## 20b. Hardware-safety meta-policy (HARD pattern added in PR2)

A new top-level cross-cutting skill, `doca-hardware-safety`, landed
in PR2 as the seventh top-level skill alongside the existing six
(`doca-public-knowledge-map`, `doca-setup`, `doca-programming-guide`,
`doca-debug`, `doca-version`, `doca-structured-tools-contract`). It
captures the cross-cutting safety discipline that wraps any change
touching DPU / NIC hardware state — `mlxconfig` writes, firmware
burn, BlueField mode flip, BAR window changes, IOMMU mode, hugepage
reservation, BFB reflash.

The pattern:

1. Every per-artifact skill that has a `## Safety policy` anchor
   in `CAPABILITIES.md` (services + tools mostly; some libs)
   carries the *artifact-specific* rules.
2. `doca-hardware-safety ## Safety policy` (also in `CAPABILITIES.md`)
   carries the *meta-policy*: pre-flight inventory, OOB requirement,
   maintenance window discipline, replica-first validation,
   observability-before-workload, rollback discipline, escalation.
3. Per-artifact safety anchors cross-link `doca-hardware-safety`
   for the meta-policy and add only the artifact-specific overlay
   (the same pattern as `doca-version` for compatibility rules).
4. A new prompt at
   `runner/prompts/55_apply_a_hardware_touching_doca_change_safely.yaml`
   exercises the meta-policy class-shape across the bundle. The
   prompt-coverage gate verifies it lands.

When you author or modify a per-artifact skill that touches
hardware state, the `## Safety policy` overlay MUST cross-link
`doca-hardware-safety` and MUST NOT redefine the meta-policy rules.

## 20c. Contributor-experience base infra (added in PR2)

Three files that did not exist before PR2 close, all now living at
the bundle root so consumers see a fully self-contained tree:

| File | Location | Purpose | Borrowed from |
| --- | --- | --- | --- |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | bundle root | The TL;DR every contributor reads first — public-only-info rule, guidance-only rule, class-shape discipline, no-symlinks, the four coverage gates that must be green before a PR opens. | `anthropics/skills` + `google/skills` repo-root convention. |
| [`SECURITY.md`](SECURITY.md) | bundle root | The reporting path for the two security-classes that apply to a doc-only bundle: leaked NVIDIA-internal info, and skill content that would damage hardware if followed. | `anthropics/skills` + `google/skills` repo-root convention. |
| [`README.md`](README.md) `## Install — three deployment shapes` | bundle root | Copy-paste install commands so a new operator can adopt the bundle in 30 seconds. Three shapes: clone-alongside, bring-into-existing-workspace, vet-in-CI. | `google/skills` README-installer-story pattern. |

When you modify these files, the public-only-info rule from § 2
applies as it does to any other file at the bundle root —
`ci/check-skill.sh`'s linter scope is `skills/`, so the maintainer
is the lint for `AUTHORING.md` / `CONTRIBUTING.md` / `SECURITY.md` /
`README.md`. Any private hostname or internal URL in these files is
a release-blocker. The
[`ci/check-reference-hygiene.sh`](ci/check-reference-hygiene.sh)
gate added in this PR enforces the rule mechanically.

The companion the maintainer roadmap is the
broader catalog of public agent-skill repos the maintainer monitors
for further base-infra patterns; that survey is re-walked once per
round, not once per PR.

## 20. PR1 closure snapshot (for continuity)

When this section is older than the latest release, treat it as
historical context for new contributors, not the authoritative state.

- **Bundle size at PR1 close:** 57 skills (6 top-level + 28 libs +
  11 services + 12 tools).
- **Per-artifact SKILL coverage:** 51 / 51 non-umbrella artifacts
  covered (the three umbrella slugs from § 16 stay umbrella).
- **HARD gates green:** structural lint, non-public-references lint,
  URL HEAD validity (`--check-urls`), claude-skill-check (0 errors
  per file, only `W900 unknown field 'kind'` warnings),
  anchor-density, per-artifact PROMPT coverage, per-artifact SKILL
  coverage at 100 %.
- **A/B drift check:** local sampled 2-agent run (baseline vs.
  skills) on three representative prompts produced baseline 29 / 60
  (48 %) vs. skills 58 / 60 (97 %), a +49 pp delta. The full
  3-agent (baseline / main / pr) run is deferred to the Jenkins
  pipeline because the local workspace is non-git.
- **Service naming alignment:** `doca-argus-svc` →
  `doca-argus` and `doca-virtio-net-svc` → `doca-virtio-net` because
  neither has a library counterpart (§ 17). The `-svc` suffix
  remains on `doca-urom-svc` because `libs/doca-urom` exists.

## 21. PR2 closure snapshot (for continuity)

- **Bundle size at PR2 close:** 58 skills (7 top-level + 28 libs +
  11 services + 12 tools). The seventh top-level skill is
  `doca-hardware-safety` (§ 20b).
- **HARD gates green at PR2 close:** structural lint, non-public
  references lint, URL HEAD validity (`--check-urls`),
  claude-skill-check (0 errors per file; `W900 unknown field 'kind'`
  expected), anchor-density, per-artifact PROMPT coverage 100%,
  per-artifact SKILL coverage 100%, knowledge-map ROUTING coverage
  100%, and the new **routing-discoverability** gate (§ 20a) at
  100%.
- **Routing-discoverability gap closed:** pre-PR2 audit found 48 /
  51 per-artifact skills missing from `SKILLS.md` and / or
  `doca-public-knowledge-map`. PR2 added the gate, added the
  per-artifact compact tables to `SKILLS.md`, and added the
  *"Covered by `<skill>` skill"* suffix to every kmap routing row.
  Final audit: 51 / 51 routed in both entry points.
- **Hardware-safety meta-policy** introduced as the seventh
  cross-cutting top-level skill (§ 20b). Every per-artifact `##
  Safety policy` overlay cross-links it.
- **Contributor-experience base infra** (§ 20c): `CONTRIBUTING.md`,
  `SECURITY.md`, and `AUTHORING.md` now live at the bundle root
  alongside `README.md` so the bundle is fully self-contained for
  consumers; the README install section shipped at the bundle root
  in the same round.
- **A/B drift check on the renamed services** (`doca-argus`,
  `doca-virtio-net`): 12 / 12 with skills vs 6 / 12 baseline,
  +50 pp delta. Recorded in
  `runner/reports/final_ab_2026-05-18/VERDICT.md`.
- **A/B drift check on the discoverability fix** (a `doca-blueman`
  prompt that targets the formerly-phantom service skill):
  recorded in `runner/reports/blueman_ab_2026-05-18/VERDICT.md`.
- **Honest gaps recorded** on the maintainer roadmap:
  - `version-offline-database.md` — the populated
    `version-matrix.json` does NOT yet ship; the markdown rules,
    schema, and live-docs fallback DO ship and are sufficient for
    correctness. The DB + verifier CLI ship together in the
    executable round.
  - `cuda-executables-analysis.md` — the full executable-side gap
    analysis (Meson/CMake wrappers, container-build CI smoke,
    auto-verify, declarative specs, version-adaptive loop).
  - `reference-repos-survey.md` — broader public agent-skill repo
    survey beyond `google/skills`.

---

## 22. PR3 closure snapshot (for continuity)

- **Bundle size at PR3 close:** 61 skills (9 top-level + 28 libs +
  6 services + 18 tools), **strictly 1:1 with
  `doca/{libs,services,tools}`** at `doca/VERSION` = `3.5.0019`. The
  eighth top-level skill (added in PR3) is `doca-container-deployment`
  (moved from `services/` because it is cross-cutting deployment
  policy, not a service); the ninth (added late in PR3) is
  `doca-bare-metal-deployment` — the sibling deployment path for a
  DOCA-linked binary launched directly on hardware (host x86 or
  BlueField Arm bare-metal — no container). The two deployment
  skills are routed to from `doca-setup ## recognize` (the new
  deployment-routing front door anchor in `doca-setup/TASKS.md` —
  precedented by the existing `## no-install` 7th anchor).
- **Strict-to-doca invariant** (§ 5, this PR): the per-artifact
  skills are 1:1 with `doca/{libs,services,tools}/`. Enforced by
  the new HARD gate
  [`ci/check-doca-inventory.sh`](ci/check-doca-inventory.sh),
  which clones `@doca` at the build's `DOCA_BRANCH` parameter
  (default `master`), reads `doca/VERSION`, and fails on any
  MISSING or EXTRA artifact. Final audit at PR3 close: libs 28/28,
  services 6/6, tools 18/18, **52 / 52 aligned, 0 MISSING,
  0 EXTRA**.
- **Externals removed** (12): DOCA Telemetry Service (as
  productized), BlueMan, HBN, SNAP, Virtio-net, Switching, DPL,
  DPACC Compiler, DPA-Tools, DPU-CLI, Ngauge, `doca-hugepages`
  helper. All are externally-productized NVIDIA networking
  software NOT in the `doca/` monorepo at `doca_3.5`, so they fall
  out of scope by the strict-to-doca invariant. Documented at
  `AGENTS.md ## Non-goals` row 7 and called out as "Non-goals" in
  the kmap's Services and Tools tables. A user asking about one
  is routed to public NVIDIA docs, never silently extrapolated
  from training knowledge.
- **Sub-features folded** into their parents as H2 anchors
  (5 → 3 parents): `doca-flow-ct → doca-flow ## flow-ct`;
  `doca-dpa-comms → doca-dpa ## comms`;
  `doca-dpa-verbs → doca-dpa ## verbs`;
  `doca-log → doca-common`;
  `doca-rdma-verbs → doca-verbs`.
- **Clean renames** (3) to match `doca/libs/` exactly:
  `doca-device-emulation → doca-devemu`;
  `doca-rivermax → doca-rmax`;
  `doca-pcc-counter → doca-pcc-counters`.
- **Consolidation** (1): `doca-flow-tune-tool` +
  `doca-flow-tune-server` → single `doca-flow-tune` skill matching
  `doca/tools/flow_tune/` (one binary, two internal roles).
- **New per-artifact skills authored** (21): 7 new libs
  (`doca-common`, `doca-verbs`, `doca-rdmi`, `doca-gpi`,
  `doca-mgmt`, `doca-flow-dpa-provider`,
  `doca-pcc-ztr-rttcc-algo`); 1 new service (`doca-os-inspector`);
  13 new tools (`doca-apsh-config`, `doca-bench-extension`,
  `doca-dpa-hl-tracer`, `doca-flow-dpa-perf`,
  `doca-flow-grpc-server`, `doca-flow-perf`,
  `doca-gpi-ib-write-lat`, `doca-gpunetio-ib-write-bw`,
  `doca-gpunetio-ib-write-lat`, `doca-sha-offload-engine`,
  `doca-spcx-cc`, `doca-telemetry-utils`, plus the consolidated
  `doca-flow-tune`). Each ships full
  `SKILL.md / CAPABILITIES.md / TASKS.md` + safety-overlay + kmap
  row + SKILLS.md route + class-shape prompt.
- **Version-aware CI**: new Jenkins parameter `DOCA_BRANCH`
  (default `master`); new stages "Checkout doca/ at DOCA_BRANCH"
  (shallow clone, stamps `doca/VERSION` + SHA into
  `_run/doca_alignment.json`) and "Strict inventory alignment
  (HARD)". For a `doca_3.5` alignment run, override
  `DOCA_BRANCH=doca_3.5`; for the next DOCA release, a single
  `DOCA_BRANCH=doca_3.6` will surface every newly-introduced
  artifact as a MISSING gate failure — a positive forcing
  function.
- **JTBD coverage gate** wired (SOFT WARN day-one):
  `ci/check-jtbd-coverage.sh` consumes the consolidated
  output of the upstream `jtbd-extraction-skills` suite dropped
  into `ci/jtbd-coverage/freshly-extracted/`; buckets each
  extracted JTBD as FULL / PARTIAL / GAP against the bundle's
  claimed coverage (machine-derived from prompt `intent:` fields
  into `ci/jtbd-coverage/bundle-jtbd-coverage.md`).
  Promote to HARD with `--strict` (≥ 60% FULL, ≥ 85%
  FULL+PARTIAL) after 1-3 clean nightly runs.
- **AGENTS.md ## Non-goals row 7** added (this PR) — the
  strict-to-doca scope rule is now a load-bearing ground rule
  the agent must follow, not a hidden CI invariant.
- **HARD gates green at PR3 close**: structural lint,
  non-public references lint, URL HEAD validity
  (`--check-urls`), claude-skill-check (0 errors per file),
  anchor-density, cross-link integrity (0 broken across 7015
  cross-skill links), per-artifact PROMPT coverage 100%,
  per-artifact SKILL coverage 100%, routing-discoverability
  52/52 (100% in both `SKILLS.md` AND kmap), strict-to-doca
  inventory 52/52 (0 MISSING, 0 EXTRA), class-shape filename
  gate. **SOFT WARN day-one** for JTBD coverage (SKIPPED
  with rc=0 until the upstream extraction is run).

## Quick checklist for a new skill

1. **Audience check.** External DOCA consumer. Fresh install. No
   internal access. No prior project context.
2. **Class shape (§ 1a).** Headline of every artifact names a CLASS
   of problem, not a specific instance. No filename ends in
   `*-load-balancer.md`, `*-firewall.md`, … (full list in § 13).
3. **Slot.** Pick `libs/<library>/`, `services/<service>/`, or
   `tools/<tool>/` (or, rarely, top-level for genuinely
   cross-cutting).
4. **Kind.** `knowledge` (single file, lightweight) or `library`
   (three files, full task verbs).
5. **Validate.** Every URL, symbol, path, version, and flag you
   add must be checked against a real public source.
6. **Write.** Procedural, focused, refusing to ship code or
   unverified claims.
7. **Cross-link.** Use `[<skill-name> ## <anchor>]` labels; the
   lint resolves them by name.
8. **Lint.** `SKILLS_ROOT=doca-skills/skills bash
   ci/check-skill.sh --all --check-urls` is clean.
   `--self-test` (all 7) still passes.
9. **Anchor density (§ 12).** `bash
   ci/check-anchor-density.sh --all` reports no
   under-filled anchors. Stub sections fail.
10. **Coverage.** `bash ci/check-coverage.sh` reports 0
    missing and 0 uncatalogued in the routing-table check, and the
    per-artifact SKILL coverage report shows you closed a gap (not
    opened one). Add the new skill's row to
    `doca-public-knowledge-map/SKILL.md` AND a compact entry to
    `doca-skills/SKILLS.md` in the same commit.
11. **Prompt coverage (§ 15).** Every new `libs/services/tools`
    skill comes with a prompt in `runner/prompts/` that names
    it via `baseline_artifact:`. Run `bash
    ci/check-coverage.sh --prompt-coverage-hard-fail` — exit
    0 confirms no gap.
11a. **Routing discoverability (§ 20a).** Run `bash
    ci/check-coverage.sh
    --routing-discoverability-hard-fail` — exit 0 confirms the new
    skill is mentioned in BOTH `doca-skills/SKILLS.md` AND
    `doca-public-knowledge-map/SKILL.md`. Without this, the skill
    is *phantom* — it ships but no fresh agent will load it.
11b. **Hardware-safety overlay (§ 20b).** If the new skill has a
    `## Safety policy` anchor and the artifact touches DPU / NIC
    hardware state, the overlay MUST cross-link
    `doca-hardware-safety` for the meta-policy. Do NOT redefine
    the meta-policy rules in the per-artifact overlay.
12. **Upstream validator (Gate A — § 11).** `claude-skill-check
    <SKILL.md>` reports 0 errors per file (W900 'unknown field kind'
    is expected and ignored). The Jenkins pipeline blocks merge on
    any real error.
13. **Three-agent A/B (Gate B — § 11).** Run baseline (no skills) vs
    main vs pr on the prompts `select_prompts.py --since main`
    returns. pr must strictly beat baseline on at least one targeted
    criterion, tie-or-beat baseline on every other, and tie-or-beat
    main on every criterion of every selected prompt.
14. **Index.** Add a row to `SKILLS.md` and `README.md`.
15. **Open the PR.** Reference this file in the PR description so
    reviewers know the contract you committed to. Paste all three
    variants' answers (or the transcript IDs) for Gate B in the PR
    body alongside the score table.
