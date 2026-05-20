#!/usr/bin/env python3
"""ab_runner.py — 3-way agent A/B runner for the doca-skills bundle.

Compares three agent variants on the same prompt set:
    baseline  : no skills loaded
    main      : skills @ origin/main (previous-rev, default "main")
    pr        : skills @ the PR branch HEAD (current-rev, default "HEAD")

The CLI keeps the historical --previous-rev / --current-rev names for
compatibility, and adds --main-rev / --pr-rev aliases for the
"baseline / main / pr" mental model the round-2.5 plan calls for.

Reads prompts (with embedded criteria) from ./prompts/*.yaml (or an
explicit --prompts-files list, as produced by select_prompts.py for
dynamic prompt selection), the scoring schema from
./rubric/scoring_schema.yaml, and emits an HTML + JSON report to
./report/.

Per the round-2 directive, all gate conditions ship as SOFT WARN —
this runner reports, it does not block. Promote conditions to
HARD_FAIL by editing ./rubric/scoring_schema.yaml; do not edit this
file for that purpose.

CONTRACT FOR INTEGRATORS
------------------------
This runner does NOT invoke an agent or an LLM judge directly. Both
are pluggable via the AgentAdapter / JudgeAdapter ABCs at the bottom
of this file. Wire your environment-specific implementations and pass
them via --agent-adapter / --judge-adapter on the CLI (see __main__).

The reference implementations stubbed below are intentionally
inert: they raise NotImplementedError with a message pointing to the
adapter contract. CI must provide working adapters before the runner
can produce real scores. Locally, the ManualPasteAdapter lets a human
paste agent responses for ad-hoc runs without any API.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as _dt
import enum
import importlib
import json
import logging
import pathlib
import shutil
import subprocess
import sys
import time
import typing as _t

import yaml  # type: ignore[import-not-found]


# --------------------------------------------------------------------------- #
# Domain types
# --------------------------------------------------------------------------- #

class Status(str, enum.Enum):
    """One of the three judge outcomes per criterion."""
    PASS = "PASS"
    FAIL = "FAIL"
    INCONCLUSIVE = "INCONCLUSIVE"


@dataclasses.dataclass(frozen=True)
class Criterion:
    """A single binary scoring criterion attached to a prompt."""
    id: str
    label: str
    weight: int
    pass_when: str


@dataclasses.dataclass(frozen=True)
class Prompt:
    """A single prompt + its criteria, loaded from prompts/<id>.yaml."""
    id: str
    name: str
    description: str
    prompt_text: str
    intent: str
    changed_skill_in_pr: _t.Optional[str]
    criteria: _t.Tuple[Criterion, ...]

    @property
    def is_first_app(self) -> bool:
        """True if this prompt triggers the app-example compile sub-protocol."""
        return self.intent == "first_app"


@dataclasses.dataclass(frozen=True)
class Variant:
    """One of the three agent variants the runner compares.

    Variant IDs are kept stable for backward compatibility with rubric
    gate IDs ("current_below_baseline", "current_below_previous_*"):
        "baseline" - no skills loaded
        "previous" - skills @ main  (or whatever --previous-rev points to)
        "current"  - skills @ PR    (or whatever --current-rev points to)
    The 3-way contract from AUTHORING § 11 maps these to
    baseline / main / pr in human-readable reports via Variant.label.
    """
    id: str           # "baseline" | "previous" | "current"
    label: str
    skills_dir: _t.Optional[pathlib.Path]   # None means no skills loaded


@dataclasses.dataclass(frozen=True)
class AgentResponse:
    """An agent's response to a single prompt under one variant."""
    variant_id: str
    prompt_id: str
    text: str
    elapsed_seconds: float
    raw_metadata: _t.Mapping[str, _t.Any] = dataclasses.field(default_factory=dict)


@dataclasses.dataclass(frozen=True)
class JudgeResult:
    """One criterion's judge outcome for one (variant, prompt)."""
    criterion_id: str
    status: Status
    rationale: str


@dataclasses.dataclass(frozen=True)
class AppExampleResult:
    """Result of the full_compile sub-protocol for first_app prompts."""
    ran: bool                 # whether the sub-protocol fired at all
    commands_executed: _t.Tuple[str, ...]
    exit_codes: _t.Tuple[int, ...]
    failing_command: _t.Optional[str]
    failure_excerpt: _t.Optional[str]

    @property
    def passed(self) -> bool:
        return self.ran and all(rc == 0 for rc in self.exit_codes)


@dataclasses.dataclass(frozen=True)
class PerPromptVariantScore:
    """Aggregated score for one (variant, prompt) pair."""
    variant_id: str
    prompt_id: str
    judge_results: _t.Tuple[JudgeResult, ...]
    app_example: _t.Optional[AppExampleResult]
    elapsed_seconds: float
    response_text: str

    @property
    def numeric_score(self) -> float:
        """Weighted sum of PASS criteria (FAIL and INCONCLUSIVE count as 0)."""
        total = 0.0
        for jr in self.judge_results:
            if jr.status is Status.PASS:
                # weight is reconstructed at scoring time; see Runner.score()
                total += 1.0  # raw PASS count; weighted version applied externally
        return total

    @property
    def inconclusive_count(self) -> int:
        return sum(1 for jr in self.judge_results if jr.status is Status.INCONCLUSIVE)


# --------------------------------------------------------------------------- #
# Adapters (PLUGGABLE — not implemented in this file)
# --------------------------------------------------------------------------- #

class AgentAdapter:
    """ABC for invoking an agent variant on a prompt.

    A concrete adapter is responsible for constructing the agent's
    context (loading the skill bundle pointed to by variant.skills_dir,
    if any), passing the prompt text, capturing the response, and
    measuring wall-clock elapsed time.
    """
    def invoke(self, variant: Variant, prompt: Prompt) -> AgentResponse:
        raise NotImplementedError(
            "Provide a concrete AgentAdapter implementation. See the contract "
            "comment at the top of ab_runner.py and the example "
            "ManualPasteAdapter at the bottom of this file."
        )


class JudgeAdapter:
    """ABC for judging a single criterion against a single response."""
    def judge(self, criterion: Criterion, response: AgentResponse) -> JudgeResult:
        raise NotImplementedError(
            "Provide a concrete JudgeAdapter implementation. The reference "
            "shape is: pass criterion.label and criterion.pass_when into the "
            "judge LLM along with response.text; require JSON output "
            "{\"status\": \"PASS|FAIL|INCONCLUSIVE\", \"rationale\": \"...\"}; "
            "return JudgeResult."
        )


class AppExampleRunner:
    """Runs the full_compile sub-protocol for first_app prompts.

    Default implementation: extract bash blocks from the response, filter
    to a safe allowlist (docker pull / docker run / ls / pkg-config /
    meson / ninja / gcc / g++), execute them inside the NGC DOCA
    container per devops/env/ngc_container.sh, capture exit codes.

    This adapter is provided in-file because the protocol is fixed by
    the scoring_schema.yaml app_example block — there is no per-CI
    customization to abstract.
    """
    SAFE_COMMAND_PREFIXES = (
        "docker pull",
        "docker run",
        "ls",
        "pkg-config",
        "meson",
        "ninja",
        "gcc",
        "g++",
        "cat",
        "echo",
    )

    def __init__(self, ngc_helper_script: pathlib.Path, dry_run: bool = False):
        self.helper = ngc_helper_script
        self.dry_run = dry_run

    def run(self, response: AgentResponse) -> AppExampleResult:
        commands = self._extract_safe_commands(response.text)
        if not commands:
            return AppExampleResult(
                ran=False, commands_executed=(), exit_codes=(),
                failing_command=None, failure_excerpt=None,
            )
        if self.dry_run:
            logging.info("AppExampleRunner: dry-run, not executing %d commands",
                         len(commands))
            return AppExampleResult(
                ran=True,
                commands_executed=tuple(commands),
                exit_codes=tuple(0 for _ in commands),
                failing_command=None,
                failure_excerpt=None,
            )
        return self._execute_in_ngc(commands)

    def _extract_safe_commands(self, text: str) -> _t.List[str]:
        """Pull bash command lines out of ```bash / ```shell fenced blocks."""
        import re
        out: _t.List[str] = []
        for fence in re.finditer(
            r"```(?:bash|shell|sh)\n(.*?)```", text, re.DOTALL | re.IGNORECASE
        ):
            for raw in fence.group(1).splitlines():
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if any(line.startswith(p) for p in self.SAFE_COMMAND_PREFIXES):
                    out.append(line)
        return out

    def _execute_in_ngc(self, commands: _t.List[str]) -> AppExampleResult:
        if not self.helper.is_file():
            raise FileNotFoundError(
                f"NGC helper script not found at {self.helper} — "
                "see devops/env/ngc_container.sh"
            )
        executed: _t.List[str] = []
        codes: _t.List[int] = []
        for cmd in commands:
            executed.append(cmd)
            r = subprocess.run(
                ["bash", str(self.helper), "exec", cmd],
                capture_output=True, text=True, timeout=600,
            )
            codes.append(r.returncode)
            if r.returncode != 0:
                return AppExampleResult(
                    ran=True,
                    commands_executed=tuple(executed),
                    exit_codes=tuple(codes),
                    failing_command=cmd,
                    failure_excerpt=(r.stdout + "\n" + r.stderr)[-2000:],
                )
        return AppExampleResult(
            ran=True,
            commands_executed=tuple(executed),
            exit_codes=tuple(codes),
            failing_command=None,
            failure_excerpt=None,
        )


# --------------------------------------------------------------------------- #
# Loaders
# --------------------------------------------------------------------------- #

def _parse_prompt_file(path: pathlib.Path) -> Prompt:
    d = yaml.safe_load(path.read_text())
    criteria = tuple(
        Criterion(
            id=c["id"],
            label=c["label"],
            weight=int(c.get("weight", 1)),
            pass_when=c["pass_when"].strip(),
        )
        for c in d["criteria"]
    )
    return Prompt(
        id=d["id"],
        name=d["name"],
        description=d.get("description", "").strip(),
        prompt_text=d["prompt"].strip(),
        intent=d.get("context", {}).get("intent", "unknown"),
        changed_skill_in_pr=d.get("context", {}).get("changed_skill_in_pr"),
        criteria=criteria,
    )


def load_prompts(prompts_dir: pathlib.Path) -> _t.List[Prompt]:
    return [_parse_prompt_file(p) for p in sorted(prompts_dir.glob("*.yaml"))]


def load_prompts_from_files(paths: _t.Sequence[pathlib.Path]) -> _t.List[Prompt]:
    """Load a curated list of prompt YAMLs (e.g. from select_prompts.py)."""
    out: _t.List[Prompt] = []
    for path in paths:
        if not path.exists():
            logging.warning("prompt file not found, skipping: %s", path)
            continue
        out.append(_parse_prompt_file(path))
    return out


def load_schema(schema_path: pathlib.Path) -> _t.Mapping[str, _t.Any]:
    return yaml.safe_load(schema_path.read_text())


# --------------------------------------------------------------------------- #
# Variant resolution
# --------------------------------------------------------------------------- #

def resolve_variants(
    skills_repo: pathlib.Path,
    *,
    current_rev: str = "HEAD",
    previous_rev: str = "main",
    workdir: pathlib.Path,
) -> _t.List[Variant]:
    """Materialize the three agent variants by checking out skills at two revs.

    `baseline` carries skills_dir=None so the AgentAdapter loads no
    skill context at all.
    `previous` and `current` git-worktree-checkout the skills repo at
    the two revs into separate sibling directories under `workdir`.

    Label convention (round 2.5): show the variant's role rather than
    the literal rev. Reports read "baseline / main / pr" which matches
    the AUTHORING § 11 contract; the actual rev still appears in
    parentheses for traceability.
    """
    workdir.mkdir(parents=True, exist_ok=True)
    prev_dir = workdir / "skills_previous"
    curr_dir = workdir / "skills_current"

    for d, rev in [(prev_dir, previous_rev), (curr_dir, current_rev)]:
        if d.exists():
            shutil.rmtree(d)
        archive = subprocess.run(
            ["git", "-C", str(skills_repo), "archive", rev],
            capture_output=True, check=True,
        )
        d.mkdir()
        subprocess.run(
            ["tar", "-xf", "-", "-C", str(d)],
            input=archive.stdout, check=True,
        )

    return [
        Variant(id="baseline", label="baseline (no skills)", skills_dir=None),
        Variant(
            id="previous",
            label=f"main ({previous_rev})",
            skills_dir=prev_dir / "skills",
        ),
        Variant(
            id="current",
            label=f"pr ({current_rev})",
            skills_dir=curr_dir / "skills",
        ),
    ]


# --------------------------------------------------------------------------- #
# Runner orchestrator
# --------------------------------------------------------------------------- #

class Runner:
    def __init__(
        self,
        prompts: _t.Sequence[Prompt],
        variants: _t.Sequence[Variant],
        agent: AgentAdapter,
        judge: JudgeAdapter,
        app_example: _t.Optional[AppExampleRunner] = None,
    ):
        self.prompts = list(prompts)
        self.variants = list(variants)
        self.agent = agent
        self.judge = judge
        self.app_example = app_example
        self._results: _t.List[PerPromptVariantScore] = []

    def run(self) -> _t.List[PerPromptVariantScore]:
        for prompt in self.prompts:
            for variant in self.variants:
                logging.info("Running variant=%s prompt=%s",
                             variant.id, prompt.id)
                response = self.agent.invoke(variant, prompt)

                judge_results = tuple(
                    self.judge.judge(c, response) for c in prompt.criteria
                )

                app_result: _t.Optional[AppExampleResult] = None
                if prompt.is_first_app and self.app_example is not None:
                    app_result = self.app_example.run(response)

                self._results.append(PerPromptVariantScore(
                    variant_id=variant.id,
                    prompt_id=prompt.id,
                    judge_results=judge_results,
                    app_example=app_result,
                    elapsed_seconds=response.elapsed_seconds,
                    response_text=response.text,
                ))
        return list(self._results)

    def score(self) -> "ScoreSheet":
        return ScoreSheet.from_results(self._results, self.prompts, self.variants)


# --------------------------------------------------------------------------- #
# Scoring + gate evaluation
# --------------------------------------------------------------------------- #

@dataclasses.dataclass
class ScoreSheet:
    """Aggregate scores per (prompt, variant) and per variant."""
    per_prompt_variant: _t.Dict[_t.Tuple[str, str], float]   # (prompt_id, variant_id) -> score
    per_variant_aggregate: _t.Dict[str, float]
    per_prompt_max: _t.Dict[str, float]
    inconclusive_rate: float
    raw_results: _t.Sequence[PerPromptVariantScore]

    @classmethod
    def from_results(
        cls,
        results: _t.Sequence[PerPromptVariantScore],
        prompts: _t.Sequence[Prompt],
        variants: _t.Sequence[Variant],
    ) -> "ScoreSheet":
        per_prompt_variant: _t.Dict[_t.Tuple[str, str], float] = {}
        per_variant_aggregate: _t.Dict[str, float] = {v.id: 0.0 for v in variants}
        per_prompt_max: _t.Dict[str, float] = {
            p.id: float(sum(c.weight for c in p.criteria)) for p in prompts
        }
        prompt_by_id = {p.id: p for p in prompts}

        total_criteria = 0
        inconclusive = 0
        for r in results:
            score = 0.0
            criteria_by_id = {c.id: c for c in prompt_by_id[r.prompt_id].criteria}
            for jr in r.judge_results:
                total_criteria += 1
                if jr.status is Status.INCONCLUSIVE:
                    inconclusive += 1
                if jr.status is Status.PASS:
                    score += float(criteria_by_id[jr.criterion_id].weight)
            per_prompt_variant[(r.prompt_id, r.variant_id)] = score
            per_variant_aggregate[r.variant_id] += score

        rate = (inconclusive / total_criteria) if total_criteria else 0.0
        return cls(
            per_prompt_variant=per_prompt_variant,
            per_variant_aggregate=per_variant_aggregate,
            per_prompt_max=per_prompt_max,
            inconclusive_rate=rate,
            raw_results=results,
        )

    def evaluate_gates(
        self, schema: _t.Mapping[str, _t.Any]
    ) -> _t.List[_t.Mapping[str, _t.Any]]:
        """Apply the gate_conditions from scoring_schema.yaml.

        Returns a list of {id, severity, triggered, message} dicts.
        Per round-2 directive, severities ship as SOFT_WARN/SOFT_INFO; this
        function does not raise even on triggered gates — the caller decides
        what to do with the report.
        """
        ag = self.per_variant_aggregate
        baseline = ag.get("baseline", 0.0)
        previous = ag.get("previous", 0.0)
        current = ag.get("current", 0.0)

        gates: _t.List[_t.Mapping[str, _t.Any]] = []

        for cond in schema.get("gate_conditions", []):
            gid = cond["id"]
            triggered = False
            message = ""

            if gid == "current_below_baseline":
                triggered = current < baseline
                message = f"current={current} < baseline={baseline}"

            elif gid == "current_below_previous_aggregate":
                triggered = current < previous
                message = f"current={current} < previous={previous}"

            elif gid == "current_below_previous_per_prompt":
                regressions = []
                for (pid, vid), s in self.per_prompt_variant.items():
                    if vid == "current":
                        prev = self.per_prompt_variant.get((pid, "previous"), 0.0)
                        if s < prev:
                            regressions.append((pid, prev, s))
                triggered = bool(regressions)
                if regressions:
                    parts = [f"{pid}: previous={p} → current={c}"
                             for pid, p, c in regressions]
                    message = " | ".join(parts)

            elif gid == "current_equals_previous_aggregate":
                triggered = current == previous
                message = f"current={current} == previous={previous}"

            elif gid == "judge_inconclusive_rate_high":
                triggered = self.inconclusive_rate > 0.25
                message = f"inconclusive_rate={self.inconclusive_rate:.1%}"

            elif gid == "app_example_compile_failure":
                offenders = [
                    r for r in self.raw_results
                    if r.variant_id == "current"
                    and r.app_example is not None
                    and r.app_example.ran
                    and not r.app_example.passed
                ]
                triggered = bool(offenders)
                if offenders:
                    parts = []
                    for o in offenders:
                        assert o.app_example is not None
                        parts.append(
                            f"{o.prompt_id}: failed at `{o.app_example.failing_command}`"
                        )
                    message = " | ".join(parts)

            else:
                # Unknown gate id — surface as a soft info; never fail-close.
                message = "unknown gate id; see scoring_schema.yaml"

            gates.append({
                "id": gid,
                "label": cond.get("label", gid),
                "severity": cond.get("severity", "SOFT_INFO"),
                "triggered": triggered,
                "message": message,
            })

        return gates


# --------------------------------------------------------------------------- #
# Report writers
# --------------------------------------------------------------------------- #

class ReportWriter:
    """Emits HTML (similar shape to DEMO-POC.html) and JSON reports."""
    def __init__(self, out_dir: pathlib.Path):
        self.out_dir = out_dir
        self.out_dir.mkdir(parents=True, exist_ok=True)

    def write(
        self,
        sheet: ScoreSheet,
        gates: _t.Sequence[_t.Mapping[str, _t.Any]],
        prompts: _t.Sequence[Prompt],
        variants: _t.Sequence[Variant],
        meta: _t.Mapping[str, _t.Any],
    ) -> _t.Tuple[pathlib.Path, pathlib.Path]:
        html_path = self.out_dir / "report.html"
        json_path = self.out_dir / "report.json"

        # JSON first — simpler.
        payload = {
            "meta": dict(meta),
            "variants": [dataclasses.asdict(v) | {
                "skills_dir": str(v.skills_dir) if v.skills_dir else None
            } for v in variants],
            "prompts": [{"id": p.id, "name": p.name, "intent": p.intent}
                        for p in prompts],
            "per_prompt_variant_score": {
                f"{pid}::{vid}": s
                for (pid, vid), s in sheet.per_prompt_variant.items()
            },
            "per_variant_aggregate": dict(sheet.per_variant_aggregate),
            "per_prompt_max": dict(sheet.per_prompt_max),
            "inconclusive_rate": sheet.inconclusive_rate,
            "gates": list(gates),
            "raw_results": [
                {
                    "prompt_id": r.prompt_id,
                    "variant_id": r.variant_id,
                    "elapsed_seconds": r.elapsed_seconds,
                    "judge_results": [dataclasses.asdict(jr) for jr in r.judge_results],
                    "app_example": dataclasses.asdict(r.app_example)
                                    if r.app_example else None,
                    # truncate response text in JSON to keep file small;
                    # full response is in raw_response/<variant>/<prompt>.txt
                    "response_excerpt": r.response_text[:1000],
                }
                for r in sheet.raw_results
            ],
        }
        json_path.write_text(json.dumps(payload, indent=2, default=str))

        # HTML — keep close to DEMO-POC.html so reviewers see the same shape.
        html_path.write_text(self._render_html(sheet, gates, prompts, variants, meta))

        # Per-(variant, prompt) raw response text dumps for forensics.
        raw_dir = self.out_dir / "raw_responses"
        raw_dir.mkdir(exist_ok=True)
        for r in sheet.raw_results:
            (raw_dir / f"{r.variant_id}__{r.prompt_id}.txt").write_text(r.response_text)

        return html_path, json_path

    def _render_html(
        self,
        sheet: ScoreSheet,
        gates: _t.Sequence[_t.Mapping[str, _t.Any]],
        prompts: _t.Sequence[Prompt],
        variants: _t.Sequence[Variant],
        meta: _t.Mapping[str, _t.Any],
    ) -> str:
        ts = meta.get("timestamp", _dt.datetime.utcnow().isoformat())
        rows = []
        for p in prompts:
            mx = sheet.per_prompt_max[p.id]
            cells = [f"<td class='metric'>{p.name}</td>"]
            for v in variants:
                s = sheet.per_prompt_variant.get((p.id, v.id), 0.0)
                klass = "win" if s > 0 and s == mx else (
                    "fail" if s == 0 else "")
                cells.append(
                    f"<td class='center {klass}'>{int(s)} / {int(mx)}</td>"
                )
            rows.append("<tr>" + "".join(cells) + "</tr>")
        agg_cells = ["<td class='metric'><strong>TOTAL</strong></td>"]
        total_max = sum(sheet.per_prompt_max.values())
        for v in variants:
            agg = sheet.per_variant_aggregate[v.id]
            agg_cells.append(
                f"<td class='center'><strong>{int(agg)} / {int(total_max)}</strong></td>"
            )
        rows.append("<tr>" + "".join(agg_cells) + "</tr>")
        scoreboard = (
            "<table><thead><tr><th>Prompt</th>"
            + "".join(f"<th>{v.label}</th>" for v in variants)
            + "</tr></thead><tbody>"
            + "".join(rows)
            + "</tbody></table>"
        )

        gate_rows = "".join(
            f"<tr><td>{g['id']}</td><td>{g['severity']}</td>"
            f"<td>{'TRIGGERED' if g['triggered'] else 'ok'}</td>"
            f"<td>{g['message']}</td></tr>"
            for g in gates
        )

        coverage_section = self._render_coverage_section(meta.get("coverage", {}))

        return f"""<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>doca-skills CI report</title>
<style>
 body {{ font-family: -apple-system, Helvetica, Arial, sans-serif;
         max-width: 1100px; margin: 24px auto; }}
 h1 {{ font-size: 24px; }} h2 {{ border-bottom: 2px solid #76b900; }}
 table {{ border-collapse: collapse; width: 100%; margin: 12px 0; }}
 th, td {{ border: 1px solid #ccc; padding: 8px; }}
 th {{ background: #2a2a2a; color: white; }}
 td.metric {{ background: #f5f5f5; font-weight: 600; }}
 td.center {{ text-align: center; }}
 td.win {{ background: #f4faf0; }}
 td.fail {{ background: #fdeeee; }}
 td.warn {{ background: #fff5e0; }}
 .meta {{ font-size: 12px; color: #666; }}
 .coverage-pct {{ font-size: 28px; font-weight: 700; }}
 .coverage-pct.full {{ color: #4a8a1e; }}
 .coverage-pct.partial {{ color: #b06a00; }}
 .coverage-pct.low {{ color: #b22222; }}
</style></head><body>
<h1>doca-skills CI report</h1>
<div class='meta'>Run at {ts} &middot; inconclusive rate {sheet.inconclusive_rate:.1%}</div>
<h2>Scoreboard</h2>
{scoreboard}
<h2>Catalog coverage (every public DOCA lib / svc / tool in the routing tables?)</h2>
{coverage_section}
<h2>Gate conditions (initial: SOFT WARN — non-blocking)</h2>
<table><thead><tr><th>Gate</th><th>Severity</th><th>Status</th><th>Detail</th></tr>
</thead><tbody>{gate_rows}</tbody></table>
<p class='meta'>Per-(variant, prompt) raw responses are at
<code>./raw_responses/&lt;variant&gt;__&lt;prompt&gt;.txt</code>.
Full machine-readable result at <code>./report.json</code>.</p>
</body></html>"""

    def _render_coverage_section(self, coverage: _t.Mapping[str, _t.Any]) -> str:
        if not coverage:
            return ("<p class='meta'>No coverage report supplied "
                    "(<code>--coverage-json</code> not provided).</p>")
        if "_parse_error" in coverage:
            return (f"<p class='meta'>Coverage report could not be parsed: "
                    f"<code>{coverage['_parse_error']}</code>.</p>")
        pct = coverage.get("covered_pct", 0)
        klass = ("full" if pct == 100 else
                 "partial" if pct >= 80 else "low")
        missing_libs = coverage.get("missing_libraries", []) or []
        missing_svcs = coverage.get("missing_services", []) or []
        missing_tools = coverage.get("missing_tools", []) or []
        missing_skills = coverage.get("missing_skill_rows", []) or []
        rows = (
            f"<tr><td class='metric'>Total expected</td>"
            f"<td class='center'>{coverage.get('expected_total', '?')}</td></tr>"
            f"<tr><td class='metric'>Covered</td>"
            f"<td class='center'>{coverage.get('covered_count', '?')}</td></tr>"
            f"<tr><td class='metric'>Missing</td>"
            f"<td class='center'>{coverage.get('missing_count', '?')}</td></tr>"
            f"<tr><td class='metric'>Per-skill dirs</td>"
            f"<td class='center'>{coverage.get('skill_dirs_total', '?')}</td></tr>"
            f"<tr><td class='metric'>Skill dirs uncatalogued</td>"
            f"<td class='center'>{coverage.get('skill_dirs_uncatalogued', '?')}</td></tr>"
        )
        miss_html = ""
        if missing_libs or missing_svcs or missing_tools or missing_skills:
            miss_html = "<h3>Missing entries (SOFT WARN — promote to HARD FAIL after 3-5 signal runs)</h3><ul>"
            for s in missing_libs:
                miss_html += f"<li>library: <code>{s}</code></li>"
            for s in missing_svcs:
                miss_html += f"<li>service: <code>{s}</code></li>"
            for s in missing_tools:
                miss_html += f"<li>tool: <code>{s}</code></li>"
            for s in missing_skills:
                miss_html += f"<li>skill dir without catalog row: <code>{s}</code></li>"
            miss_html += "</ul>"
        return (f"<div class='coverage-pct {klass}'>{pct}% covered</div>"
                f"<table><tbody>{rows}</tbody></table>"
                f"{miss_html}")


# --------------------------------------------------------------------------- #
# Reference adapters
# --------------------------------------------------------------------------- #

class ManualPasteAdapter(AgentAdapter):
    """Local-debug adapter — prompts the operator to paste a response.

    Useful for ad-hoc runs where the operator wants to compare their own
    answer (or a chat session's answer) against a different variant
    without wiring up an API. Not suitable for CI.
    """
    def invoke(self, variant: Variant, prompt: Prompt) -> AgentResponse:
        print()
        print("=" * 72)
        print(f"PASTE RESPONSE FOR variant={variant.id} prompt={prompt.id}")
        print(f"  variant.skills_dir = {variant.skills_dir}")
        print(f"  prompt: {prompt.prompt_text}")
        print("Type END on its own line to finish.")
        print("=" * 72)
        lines: _t.List[str] = []
        t0 = time.time()
        for raw in sys.stdin:
            if raw.strip() == "END":
                break
            lines.append(raw)
        return AgentResponse(
            variant_id=variant.id,
            prompt_id=prompt.id,
            text="".join(lines).rstrip(),
            elapsed_seconds=time.time() - t0,
            raw_metadata={"source": "manual_paste"},
        )


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _import_callable(spec: str) -> _t.Any:
    """Import 'pkg.mod:Cls' and return Cls."""
    mod, _, attr = spec.partition(":")
    if not attr:
        raise ValueError(f"adapter spec '{spec}' must be 'module.path:ClassName'")
    return getattr(importlib.import_module(mod), attr)


def main(argv: _t.Optional[_t.Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description="3-way A/B agent runner for doca-skills.")
    p.add_argument("--skills-repo", required=True, type=pathlib.Path,
                   help="Path to the doca-skills git repo root.")
    p.add_argument("--prompts-dir", default="prompts", type=pathlib.Path,
                   help="Directory of *.yaml prompts to run (default: ./prompts).")
    p.add_argument("--prompts-files", nargs="*", default=None,
                   type=pathlib.Path,
                   help="Explicit list of prompt YAML files. Overrides "
                        "--prompts-dir. Use this with select_prompts.py "
                        "output for dynamic, diff-driven prompt selection.")
    p.add_argument("--rubric", default="rubric/scoring_schema.yaml",
                   type=pathlib.Path)
    p.add_argument("--out", default="report", type=pathlib.Path)
    p.add_argument("--workdir", default="/tmp/ab_runner", type=pathlib.Path)
    # Both name pairs are accepted. --main-rev / --pr-rev match the
    # 3-agent contract from AUTHORING § 11 (baseline / main / pr);
    # --previous-rev / --current-rev are kept for backward-compat with
    # CI snippets predating round 2.5.
    p.add_argument("--current-rev", "--pr-rev", default="HEAD",
                   dest="current_rev",
                   help="Git rev for the 'pr' variant (default: HEAD).")
    p.add_argument("--previous-rev", "--main-rev", default="main",
                   dest="previous_rev",
                   help="Git rev for the 'main' variant (default: main).")
    p.add_argument("--agent-adapter", required=True,
                   help="Python import path 'module.path:ClassName' for AgentAdapter.")
    p.add_argument("--judge-adapter", required=True,
                   help="Python import path 'module.path:ClassName' for JudgeAdapter.")
    p.add_argument("--ngc-helper",
                   default="../env/ngc_container.sh",
                   type=pathlib.Path)
    p.add_argument("--app-example-dry-run", action="store_true",
                   help="Skip docker; pretend all extracted commands exited 0.")
    p.add_argument("--coverage-json", type=pathlib.Path, default=None,
                   help="Path to the JSON output of ci/check-coverage.sh. "
                        "If provided, coverage rows are merged into the "
                        "report meta block so reviewers see the catalog "
                        "delta alongside the agent scores.")
    p.add_argument("--log-level", default="INFO")
    args = p.parse_args(argv)

    logging.basicConfig(level=args.log_level,
                        format="%(asctime)s %(levelname)s %(message)s")

    # --prompts-files takes precedence over --prompts-dir. Used by the
    # dynamic prompt-selection flow: select_prompts.py --since main
    # produces a list of YAML paths; the runner consumes that list
    # verbatim. When neither is set explicitly, fall back to the dir.
    if args.prompts_files:
        prompts = load_prompts_from_files(args.prompts_files)
    else:
        prompts = load_prompts(args.prompts_dir)
    schema = load_schema(args.rubric)
    variants = resolve_variants(
        args.skills_repo,
        current_rev=args.current_rev,
        previous_rev=args.previous_rev,
        workdir=args.workdir,
    )
    agent = _import_callable(args.agent_adapter)()
    judge = _import_callable(args.judge_adapter)()
    app_runner = AppExampleRunner(args.ngc_helper.resolve(),
                                  dry_run=args.app_example_dry_run)

    runner = Runner(prompts, variants, agent, judge, app_runner)
    runner.run()
    sheet = runner.score()
    gates = sheet.evaluate_gates(schema)

    coverage_meta: _t.Dict[str, _t.Any] = {}
    if args.coverage_json is not None and args.coverage_json.exists():
        try:
            coverage_meta = json.loads(args.coverage_json.read_text())
        except Exception as exc:
            logging.warning("Could not parse coverage JSON %s: %s",
                            args.coverage_json, exc)
            coverage_meta = {"_parse_error": str(exc)}

    writer = ReportWriter(args.out)
    html_path, json_path = writer.write(
        sheet, gates, prompts, variants,
        meta={
            "timestamp": _dt.datetime.utcnow().isoformat(),
            "current_rev": args.current_rev,
            "previous_rev": args.previous_rev,
            "skills_repo": str(args.skills_repo),
            "coverage": coverage_meta,
        },
    )

    logging.info("HTML report: %s", html_path)
    logging.info("JSON report: %s", json_path)

    # Per round-2 directive: report only, never block. Always exit 0
    # unless the runner itself crashed.
    return 0


if __name__ == "__main__":
    sys.exit(main())
