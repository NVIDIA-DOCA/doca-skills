#!/usr/bin/env python3
"""e2e_generate.py — generate the 52-artifact deep E2E prompt+grader suite.

This is the vendored, reproducible form of the May-2026 ad-hoc deep-E2E
pipeline (the run that produced 50/52 → 52/52 PASS after the 4 bundle
fixes). Pre-vendoring it lived under `/tmp/e2e/` as a one-shot side script;
post-vendoring it lives here so:

  * any reviewer can regenerate the full suite from a fresh checkout,
  * CI (`ci/run-e2e-suite.sh`, then `ci/Jenkinsfile.skills.ci ## Deep E2E
    suite`) can re-run it on every PR,
  * the suite covers EVERY artifact that ships in `skills/{libs,services,
    tools}/`, not a hand-curated subset (so a newly-added skill never
    silently skips deep-E2E coverage).

What it produces under `--out-dir`:

  prompts/<art>.prompt.txt    Full E2E prompt, tailored to the artifact's
                              kind (library vs service vs tool) and its
                              primary purpose (extracted from SKILL.md
                              frontmatter). Pre-fills the bundle path so
                              the dispatched agent can `open` the right
                              skill files.

  graders/<art>.grader.txt    The strict, conservative DOCA grader prompt
                              for that artifact. References the SAME
                              bundle paths so the grader and the agent
                              see the same source of truth. 5 grading
                              dimensions (invented_tokens, sequence,
                              validation, debug, consumer).

  index.json                  Machine-readable artifact catalog
                              {art, kind, kind_dir, purpose}, used by
                              e2e_aggregate.py to enumerate the suite
                              without re-walking `skills/`.

Use:
  python3 runner/e2e_generate.py \
      --bundle-root .                  \
      --out-dir     /tmp/e2e

Then dispatch each `prompts/<art>.prompt.txt` to your agent, write the
response to `responses/<art>.md`, dispatch each `graders/<art>.grader.txt`,
write the verdict to `grades/<art>.json`, and run `e2e_aggregate.py`.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from textwrap import dedent

KIND_FROM_DIR = {"libs": "library", "services": "service", "tools": "tool"}

# Header on every prompt — keeps the agent's framing consistent across
# the 52 artifacts so the grader's "did the response follow the bundle's
# 5-step workflow contract?" question is well-defined.
PROMPT_HEADER = dedent("""\
    You are an AI coding agent with access to a DOCA-skills bundle at
    {bundle_skills_root}.
    You will answer one end-to-end question. The bundle is your authoritative
    source; open AGENTS.md first, then SKILLS.md, then the per-artifact skill
    at skills/{kind_dir}/{art}/.

    USER QUESTION:
    """)

# 5-step workflow contract — same shape for every artifact, only the verb
# in step (3) changes based on kind (library/service/tool).
WORKFLOW_LIB = dedent("""\
    Walk me through the COMPLETE end-to-end workflow:

    (1) Confirm DOCA and {art} are installed on my host at compatible versions
        (host package + runtime device cap query both agreeing).

    (2) Discover which devices on this host can be used for {art} and which
        per-device capabilities are supported — name the actual capability-query
        symbol(s) I should call before committing.

    (3) Start from a real shipped DOCA sample under
        /opt/mellanox/doca/samples/{art_uscore}/ (or wherever the bundle says
        the canonical sample lives) as my modify-target. Name the sample, the
        files I'll be touching, and the minimum-change set.

    (4) Build (using `pkg-config --cflags --libs {art}`, not hand-crafted -l
        flags), run once on the smallest legal scope, and verify the application
        actually did the right thing — name a concrete observable that proves it
        worked.

    (5) If it fails, the first three layers I should check (in order), with the
        specific symptom that distinguishes each layer.""")

WORKFLOW_SVC = dedent("""\
    Walk me through the COMPLETE end-to-end workflow:

    (1) Confirm the {art} service is installed on my host at a compatible
        DOCA version, and confirm the version+runtime alignment chain.

    (2) Discover how the service is packaged on this host (container vs
        systemd unit vs script) and which start/stop/status surface the
        bundle says I should drive it through.

    (3) Run the service's smallest legal start — name the exact unit, image,
        or invocation the bundle points at — and verify it's actually serving
        (not just "no error / process is alive"). Name the concrete observable
        (port, health endpoint, log line, sysfs node) that proves it.

    (4) Validate that the service's expected control / data plane is reaching
        the BlueField correctly — what's the bundle's named end-to-end check?

    (5) If it fails, the first three layers I should check (in order), with the
        specific symptom that distinguishes each layer.""")

WORKFLOW_TOOL = dedent("""\
    Walk me through the COMPLETE end-to-end workflow:

    (1) Confirm DOCA and the {art} tool are installed on my host at compatible
        versions; name the exact path and the version surface I should query.

    (2) Discover the tool's option surface — name the canonical introspection
        flag/subcommand the bundle says I should use (NOT a guess) before
        committing to a real invocation.

    (3) Run the smallest legal invocation that exercises the tool's core
        purpose. Name the exact arguments and the input shape (file, device,
        socket, ...) the tool expects.

    (4) Verify the tool actually did the right thing — name a concrete
        observable (output file, stdout line, sysfs change, counter delta,
        return code WITH an additional out-of-band check). 'Exited 0' is NOT
        a green signal on its own.

    (5) If it fails, the first three layers I should check (in order), with the
        specific symptom that distinguishes each layer.""")

WORKFLOW_BY_KIND = {
    "library": WORKFLOW_LIB,
    "service": WORKFLOW_SVC,
    "tool":    WORKFLOW_TOOL,
}

PROMPT_FOOTER = dedent("""

    Constraints (these are HARD — the grader will fail your response on any of
    these):

      * Do NOT invent symbols, flags, subcommand names, paths, or
        pkg-config module names. Quote them verbatim from the bundle skill,
        AGENTS.md, or a public NVIDIA doc.
      * Do NOT hardcode install-layout values; defer to pkg-config / ldconfig /
        find per AGENTS.md ground rule #6.
      * Step (3) must name a CONCRETE real shipped sample / config / unit; if
        the bundle deliberately defers to `ls`, mirror that pattern explicitly.
      * Step (4) must name a CONCRETE observable that proves the right thing
        happened. 'No error / exited 0' alone is NOT a green signal.
      * Step (5) must name three DISTINCT layers each with a distinguishing
        symptom that lets me self-classify which layer I'm in.

    Output: structured Markdown with numbered headings (1)–(5).
    """)

GRADER_TEMPLATE = dedent("""\
    You are a strict, conservative DOCA operational-fidelity grader.

    You are grading ONE end-to-end response that an AI agent produced for the
    artifact `{art}` (kind: {kind}). You will compare the response against the
    authoritative bundle skill files for that artifact and against general public
    DOCA reality.

    INPUTS:
      * Original user-facing E2E question + constraints:
          {prompt_path}
      * Agent response under test:
          {response_path}
      * Authoritative bundle skill for this artifact:
          {bundle_root}/skills/{kind_dir}/{art}/SKILL.md
          {bundle_root}/skills/{kind_dir}/{art}/CAPABILITIES.md
          {bundle_root}/skills/{kind_dir}/{art}/TASKS.md
      * Universal rules:
          {bundle_root}/AGENTS.md

    Open every one of those files yourself before grading.

    Grade on EXACTLY these 5 dimensions. For each, output PASS or FAIL plus a
    1-3 sentence concrete justification quoting the response text under test.

    D1. invented_tokens — Did the response invent any symbol, flag, subcommand,
        path, or pkg-config module name that is not present in the bundle skill,
        AGENTS.md, or a real NVIDIA public doc? Every name the agent uses MUST be
        traceable. Inventing a flag or symbol is an automatic FAIL on D1.

    D2. sequence_correctness — Are the steps in a workable order? Step N's
        preconditions must be established by steps 1..N-1. The 5-step contract
        (env confirm → discover → modify-from-sample → build/run/validate →
        debug-layer) must be visibly walked.

    D3. validation_concreteness — Does step (4) (validate) name a CONCRETE
        observable that proves the right thing happened? 'Exited 0' or 'no
        error in stderr' alone is FAIL on D3. The observable must be tied to
        the artifact's actual semantics.

    D4. debug_concreteness — Does step (5) (first-failure ladder) name 3
        DISTINCT layers each with a distinguishing symptom that lets the user
        self-classify which layer they're in?

    D5. consumer_concreteness — Does step (3) point to a REAL shipped sample,
        config, systemd unit, or container image that the user can put their
        hands on right now? If the bundle deliberately defers to `ls` for sample
        choice, the response must mirror that explicitly (and naming an exact
        sample anyway is FINE provided it's a real one).

    Output ONE JSON object on a single line with EXACTLY these keys (no extra
    keys, no Markdown wrapping):

      {{
        "artifact": "{art}",
        "kind": "{kind}",
        "D1_invented_tokens":         {{"verdict":"PASS|FAIL","why":"..."}},
        "D2_sequence_correctness":    {{"verdict":"PASS|FAIL","why":"..."}},
        "D3_validation_concreteness": {{"verdict":"PASS|FAIL","why":"..."}},
        "D4_debug_concreteness":      {{"verdict":"PASS|FAIL","why":"..."}},
        "D5_consumer_concreteness":   {{"verdict":"PASS|FAIL","why":"..."}},
        "verdict_overall": "PASS|FAIL",
        "blocker_findings": [...],
        "med_findings":     [...],
        "low_findings":     [...]
      }}

    Severity classes:
      * blocker_findings: any D1 FAIL (invented token) OR a D2/D3/D4/D5 FAIL
        that would cause a real user to take a wrong action on real hardware.
      * med_findings:     non-blocking factual gap, stylistic mismatch with
        the bundle's preferred phrasing, or anchor reference slightly off.
      * low_findings:     minor / nitpick (e.g. could-be-more-concrete).

    The overall verdict is PASS iff blocker_findings is empty.
    """)


def parse_frontmatter(skill_md: Path) -> dict:
    """Read the YAML frontmatter from a SKILL.md without pulling in pyyaml.
    The frontmatter is small and conformant (the `claude-skill-check` gate
    enforces shape) so a small key:value parser is sufficient."""
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    fm: dict = {}
    for line in m.group(1).splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


def extract_purpose(skill_md: Path) -> str:
    """Pull a short purpose blurb. Preference order:
       1. frontmatter `description:` (the canonical short)
       2. first prose paragraph after the frontmatter
       3. first H2 section body
    """
    fm = parse_frontmatter(skill_md)
    if fm.get("description"):
        return fm["description"]
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    body = re.sub(r"^---\s*\n.*?\n---\s*\n", "", text, count=1, flags=re.DOTALL)
    # First non-empty, non-heading paragraph
    para_lines: list[str] = []
    for line in body.splitlines():
        if line.startswith("#"):
            if para_lines:
                break
            continue
        if not line.strip():
            if para_lines:
                break
            continue
        para_lines.append(line.strip())
    return " ".join(para_lines)[:600] or "(no purpose extracted)"


def enumerate_artifacts(bundle_root: Path) -> list[dict]:
    """Return a sorted catalog of every artifact under
    `skills/{libs,services,tools}/*/SKILL.md`. The catalog rows are
    {art, kind, kind_dir, skill_path, purpose}."""
    catalog: list[dict] = []
    skills_root = bundle_root / "skills"
    if not skills_root.is_dir():
        raise SystemExit(f"bundle skills/ not found at {skills_root}")
    for kind_dir, kind in KIND_FROM_DIR.items():
        root = skills_root / kind_dir
        if not root.is_dir():
            continue
        for art_dir in sorted(root.iterdir()):
            skill = art_dir / "SKILL.md"
            if not skill.exists():
                continue
            catalog.append({
                "art": art_dir.name,
                "kind": kind,
                "kind_dir": kind_dir,
                "skill_path": str(skill),
                "purpose": extract_purpose(skill),
            })
    return catalog


def render_prompt(entry: dict, bundle_skills_root: Path) -> str:
    art = entry["art"]
    workflow = WORKFLOW_BY_KIND[entry["kind"]].format(
        art=art, art_uscore=art.replace("-", "_"),
    )
    header = PROMPT_HEADER.format(
        bundle_skills_root=str(bundle_skills_root) + "/",
        kind_dir=entry["kind_dir"],
        art=art,
    )
    purpose_quote = entry["purpose"]
    if len(purpose_quote) > 320:
        purpose_quote = purpose_quote[:320].rstrip() + "…"
    body = dedent(f"""\
        "I'm new to DOCA and I have a BlueField with DOCA installed. I want
        to exercise the {art} {entry['kind']} end-to-end. Specifically:

        {purpose_quote}

        {workflow}
        """)
    return header + body + PROMPT_FOOTER


def render_grader(entry: dict, bundle_root: Path,
                  prompt_path: Path, response_path: Path) -> str:
    return GRADER_TEMPLATE.format(
        art=entry["art"],
        kind=entry["kind"],
        kind_dir=entry["kind_dir"],
        bundle_root=str(bundle_root),
        prompt_path=str(prompt_path),
        response_path=str(response_path),
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--bundle-root", required=True, type=Path,
                   help="Path to the doca-skills bundle root (the dir containing AGENTS.md + skills/).")
    p.add_argument("--out-dir", required=True, type=Path,
                   help="Output directory; prompts/ and graders/ and index.json are written under it.")
    p.add_argument("--bundle-skills-root", type=Path, default=None,
                   help="Absolute path to the skills/ directory the dispatched agent will see "
                        "(may differ from --bundle-root/skills when the agent runs in a different "
                        "filesystem layout, e.g. inside a Jenkins container). Defaults to "
                        "<bundle-root>/skills.")
    args = p.parse_args()

    bundle_root = args.bundle_root.resolve()
    out_dir = args.out_dir.resolve()
    bundle_skills_root = (args.bundle_skills_root or (bundle_root / "skills")).resolve()
    if not (bundle_root / "AGENTS.md").exists():
        print(f"ERROR: {bundle_root} does not look like a doca-skills bundle (no AGENTS.md).",
              file=sys.stderr)
        return 2

    (out_dir / "prompts").mkdir(parents=True, exist_ok=True)
    (out_dir / "graders").mkdir(parents=True, exist_ok=True)
    (out_dir / "responses").mkdir(parents=True, exist_ok=True)
    (out_dir / "grades").mkdir(parents=True, exist_ok=True)

    catalog = enumerate_artifacts(bundle_root)

    for entry in catalog:
        art = entry["art"]
        prompt_path  = out_dir / "prompts"  / f"{art}.prompt.txt"
        grader_path  = out_dir / "graders"  / f"{art}.grader.txt"
        response_path = out_dir / "responses" / f"{art}.md"
        prompt_path.write_text(render_prompt(entry, bundle_skills_root) + "\n",
                               encoding="utf-8")
        grader_path.write_text(render_grader(entry, bundle_root, prompt_path,
                                              response_path) + "\n",
                                encoding="utf-8")

    # Drop the catalog as index.json for downstream tooling.
    catalog_short = [{k: v for k, v in row.items() if k != "skill_path"} for row in catalog]
    (out_dir / "index.json").write_text(json.dumps(catalog_short, indent=2) + "\n",
                                         encoding="utf-8")

    print(f"e2e_generate: wrote {len(catalog)} prompts + {len(catalog)} graders to {out_dir}")
    print(f"  prompts/  -> {out_dir / 'prompts'}")
    print(f"  graders/  -> {out_dir / 'graders'}")
    print(f"  responses/ (empty, dispatch your agent into this dir) -> {out_dir / 'responses'}")
    print(f"  grades/    (empty, dispatch your grader into this dir) -> {out_dir / 'grades'}")
    print(f"  index.json -> {out_dir / 'index.json'}")

    # Sanity: by-kind counts so the operator can confirm shape.
    from collections import Counter
    cnt = Counter(e["kind"] for e in catalog)
    print(f"  by-kind: " + ", ".join(f"{k}={v}" for k, v in sorted(cnt.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
