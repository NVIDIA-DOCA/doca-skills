#!/usr/bin/env python3
"""Reference-hygiene gate for the public doca-skills bundle.

Durable safety net for the "agent-consumption review" failure modes
the bundle hit when a reviewer extracted it standalone:

  1. Skill files reference paths that exist in the maintainer monorepo
     but NOT in the extracted public bundle (e.g. `devops/ci/check-skill.sh`,
     `devops/AUTHORING.md`, `future-plan/...`). They look like clickable
     links but break the moment a consumer clones the bundle on its own.
  2. Image references in top-level docs that point at files the bundle
     does not ship (e.g. `doca-software.jpg`).
  3. Misleading anchor links — a label like `[CAPABILITIES.md ## X]` with
     a target like `(#x)` that resolves against the CURRENT file rather
     than the labelled file.
  4. Long maintainer audit-history sections embedded in runtime
     `SKILL.md` files. Maintainer logs belong in `MAINTAINERS-NOTES.md`
     siblings, not in the file agents read.
  5. macOS Finder noise (`.DS_Store`) inside the bundle.
  6. PUBLISHABILITY: a public file (the agent-visible surface that ships
     to skill consumers) must not link to OR mention in prose any
     INTERNAL-only path. Internal-only paths are the contributor + CI
     tooling that ships in the repo for NVIDIA's internal pipeline but
     is excluded from the consumer-visible bundle: `ci/`, `runner/`,
     `fixtures/`, `env/`, `AUTHORING.md`, `CONTRIBUTING.md`,
     `SECURITY.md`. Consumers' agents will go looking for any token a
     public file names — so naming an internal-only path in a public
     file silently leaks "this bundle is incomplete on its own".

Usage:
  ci/check-reference-hygiene.py             # scan; exit 1 on violations
  ci/check-reference-hygiene.py --self-test # perturb-and-trip self-test
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path


INTERNAL_PATH_PATTERNS = [
    re.compile(r"\.\./devops/"),
    re.compile(r"\.\./\.\./devops/"),
    re.compile(r"\.\./\.\./\.\./devops/"),
    re.compile(r"\bdevops/ci/"),
    re.compile(r"\bdevops/runner/"),
    re.compile(r"\bdevops/fixtures/"),
    re.compile(r"\bdevops/AUTHORING\.md"),
    re.compile(r"\bdevops/CONTRIBUTING\.md"),
    re.compile(r"\bdevops/SECURITY\.md"),
    re.compile(r"\bdevops/round2-backlog"),
    re.compile(r"\bdevops/SKILL-PROVENANCE"),
    re.compile(r"\bfuture-plan/"),
]

AUDIT_HISTORY_H2 = re.compile(
    r"^## (Audit history|Maintenance log|Quality gate log|Reviewer log|Wave [0-9])",
    re.MULTILINE,
)
AUDIT_HISTORY_H3 = re.compile(
    r"^### (Audit history|Quality gate|Wave [0-9])",
    re.MULTILINE,
)

# Misleading-anchor pattern: [..CAPABILITIES.md..] or [..SKILL.md..] or
# [..TASKS.md..] paired with a (#anchor) target. The label names a
# sibling file but the target resolves against the CURRENT file.
MISLEADING_ANCHOR = re.compile(
    r"\[[^\]]*?(CAPABILITIES|SKILL|TASKS)\.md[^\]]*?\]\(#"
)

# Local markdown / image link extractor.
LINK_RE = re.compile(r"!?\[[^\]]*?\]\(([^)\s]+)(?:\s[^)]*)?\)")

# Files at the bundle root that ship with every consumer clone.
TOP_LEVEL_RUNTIME_FILES = ["AGENTS.md", "SKILLS.md", "README.md", "CLAUDE.md"]

# Publishability gate: the set of paths inside the repo that are
# INTERNAL-only — they ship in the maintainer / CI tree but are NOT in
# the consumer-visible bundle. A consumer agent that sees one of these
# tokens in a public file will go looking for a file it does not have.
INTERNAL_ONLY_FIRST_PATH_SEGMENTS = {
    "ci", "runner", "fixtures", "env",
}
INTERNAL_ONLY_ROOT_FILES = {
    "AUTHORING.md", "CONTRIBUTING.md", "SECURITY.md", ".gitignore",
}
# Prose tokens that are also internal-only — these may appear with no
# parens link wrapper (e.g. inline `\`ci/check-skill.sh\``), and a
# consumer's agent will still go looking for them.
INTERNAL_ONLY_PROSE_TOKENS = [
    "AUTHORING.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "ci/check-",
    "ci/jtbd-coverage",
    "ci/README.md",
    "ci/Jenkinsfile",
    "Jenkinsfile.skills.ci",
    "runner/run_with_",
    "runner/select_prompts",
    "runner/ab_runner",
    "runner/prompts/",
    "runner/rubric/",
    "fixtures/hardware/",
    "env/ngc_container.sh",
]


def _is_public_file(file: Path, bundle_root: Path) -> bool:
    """A public file is one that ships to skill consumers / agents.
    That is: any *.md / *.yaml / *.json under skills/, plus the
    declared top-level runtime files."""
    try:
        rel = file.resolve().relative_to(bundle_root.resolve())
    except ValueError:
        return False
    parts = rel.parts
    if not parts:
        return False
    if parts[0] == "skills":
        return True
    if len(parts) == 1 and parts[0] in set(TOP_LEVEL_RUNTIME_FILES):
        return True
    return False


def _target_is_internal_only(target_rel_to_bundle: Path) -> bool:
    parts = target_rel_to_bundle.parts
    if not parts:
        return False
    if parts[0] in INTERNAL_ONLY_FIRST_PATH_SEGMENTS:
        return True
    if len(parts) == 1 and parts[0] in INTERNAL_ONLY_ROOT_FILES:
        return True
    return False


def scan_publishability_links(file: Path, text: str, bundle_root: Path):
    """For PUBLIC files, fail any markdown link whose target resolves
    to an INTERNAL-only path inside the bundle."""
    if not _is_public_file(file, bundle_root):
        return []
    violations = []
    file_dir = file.parent
    for m in LINK_RE.finditer(text):
        target = m.group(1).strip()
        if not target or target.startswith(("#", "http://", "https://", "mailto:", "ftp://", "tel:")):
            continue
        if _is_inside_inline_code(text, m.start()) or _line_is_inside_code_fence(text, m.start()):
            continue
        fs_part = target.split("#", 1)[0].split("?", 1)[0]
        if not fs_part:
            continue
        try:
            resolved = (file_dir / fs_part).resolve()
            rel = resolved.relative_to(bundle_root.resolve())
        except Exception:
            continue
        if _target_is_internal_only(rel):
            lineno = text[: m.start()].count("\n") + 1
            violations.append((
                file, lineno,
                f"PUBLIC -> INTERNAL link leak: '{target}' (resolves to '{rel}'). "
                "Consumers' agents will go looking for an internal-only file they will not have."
            ))
    return violations


def scan_publishability_prose(file: Path, text: str, bundle_root: Path):
    """For PUBLIC files, fail any *prose* mention (link or not) of an
    internal-only token."""
    if not _is_public_file(file, bundle_root):
        return []
    violations = []
    for tok in INTERNAL_ONLY_PROSE_TOKENS:
        for m in re.finditer(re.escape(tok), text):
            lineno = text[: m.start()].count("\n") + 1
            line_start = text.rfind("\n", 0, m.start()) + 1
            line_end = text.find("\n", m.end())
            line = text[line_start:(line_end if line_end != -1 else len(text))]
            violations.append((
                file, lineno,
                f"PUBLIC mention of INTERNAL-only token {tok!r}: {line.strip()[:200]}"
            ))
    return violations


def runtime_files(bundle_root: Path):
    """Yield (Path, rel_label) pairs the gate must scan."""
    for name in TOP_LEVEL_RUNTIME_FILES:
        f = bundle_root / name
        if f.is_file():
            yield f
    skills_root = Path(os.environ.get("SKILLS_ROOT", bundle_root / "skills"))
    if skills_root.is_dir():
        for f in sorted(skills_root.rglob("*.md")):
            # MAINTAINERS-NOTES.md is maintainer-only; agents do not load it.
            if f.name == "MAINTAINERS-NOTES.md":
                continue
            yield f


def scan_internal_paths(file: Path, lines: list[str]):
    violations = []
    for i, line in enumerate(lines, 1):
        for pat in INTERNAL_PATH_PATTERNS:
            if pat.search(line):
                violations.append(
                    (file, i, f"internal-only path leak (pattern {pat.pattern!r}): {line.rstrip()[:160]}")
                )
                break
    return violations


def _is_inside_inline_code(text: str, pos: int) -> bool:
    """Return True if `pos` is inside an inline backtick code span on
    the same logical line. We count single backticks before `pos` on
    the line — odd count ⇒ inside a `...` span. (We treat fenced
    triple-backtick blocks separately below in scan_missing_local_links.)"""
    line_start = text.rfind("\n", 0, pos) + 1
    line = text[line_start:pos]
    # Strip backslash-escaped backticks for the count.
    return (line.replace("\\`", "").count("`") % 2) == 1


def _line_is_inside_code_fence(text: str, pos: int) -> bool:
    """Triple-backtick fenced code block detection: True if `pos` is
    between an odd number of ``` fences from the start of file."""
    return text[:pos].count("```") % 2 == 1


def scan_missing_local_links(file: Path, text: str):
    violations = []
    file_dir = file.parent
    for m in LINK_RE.finditer(text):
        target = m.group(1).strip()
        if not target or target.startswith(("#", "http://", "https://", "mailto:", "ftp://", "tel:")):
            continue
        # Skip example syntax inside backticks / fenced code blocks.
        if _is_inside_inline_code(text, m.start()) or _line_is_inside_code_fence(text, m.start()):
            continue
        # Strip query / anchor from the filesystem portion.
        fs_part = target.split("#", 1)[0].split("?", 1)[0]
        if not fs_part:
            continue
        # Skip placeholder targets that obviously aren't real paths
        # (ellipses, single-character chevroned placeholders, etc.).
        if fs_part in ("...", "..."):
            continue
        if fs_part.startswith("<") and fs_part.endswith(">"):
            continue
        candidate = (file_dir / fs_part).resolve() if not fs_part.startswith("/") else Path(fs_part)
        if not candidate.exists():
            violations.append(
                (file, None, f"broken local link: '{target}' (resolves to '{candidate}' — not in bundle)")
            )
    return violations


def scan_misleading_anchor_links(file: Path, lines: list[str]):
    violations = []
    for i, line in enumerate(lines, 1):
        if MISLEADING_ANCHOR.search(line):
            violations.append(
                (file, i, f"misleading anchor link (label names a sibling file but target is local '#anchor'): {line.rstrip()[:200]}")
            )
    return violations


def scan_audit_history_in_runtime_skill(file: Path, text: str):
    """Only meaningful for `SKILL.md` files under skills/."""
    if file.name != "SKILL.md":
        return []
    violations = []
    for m in AUDIT_HISTORY_H2.finditer(text):
        lineno = text[: m.start()].count("\n") + 1
        violations.append((file, lineno, f"audit-history H2 in runtime SKILL.md: '{m.group(0)}' — move the body to a sibling MAINTAINERS-NOTES.md"))
    for m in AUDIT_HISTORY_H3.finditer(text):
        lineno = text[: m.start()].count("\n") + 1
        violations.append((file, lineno, f"audit-history H3 in runtime SKILL.md: '{m.group(0)}' — move the body to a sibling MAINTAINERS-NOTES.md"))
    # Heuristic on the `## URL audit` section: ≥3 dated audit rows
    # inline means the body has not migrated to MAINTAINERS-NOTES yet.
    in_section = False
    dated_rows = 0
    for line in text.splitlines():
        if line.startswith("## URL audit"):
            in_section, dated_rows = True, 0
            continue
        if in_section and line.startswith("## "):
            in_section = False
            continue
        if in_section and re.match(r"\|\s*20[0-9]{2}-[0-9]{2}-[0-9]{2}", line):
            dated_rows += 1
    if dated_rows >= 3:
        violations.append((file, None, f"## URL audit section carries {dated_rows} dated audit rows — move the audit log to a sibling MAINTAINERS-NOTES.md and leave a single summary row + 'How to re-audit' note."))
    return violations


def scan_dsstore(bundle_root: Path):
    violations = []
    for f in bundle_root.rglob(".DS_Store"):
        if f.is_file():
            violations.append((f, None, ".DS_Store must not be committed to the public bundle (covered by .gitignore — but a stray file slipped through)."))
    return violations


def run_scan(bundle_root: Path):
    all_violations = []
    for f in runtime_files(bundle_root):
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError as e:
            all_violations.append((f, None, f"unreadable: {e}"))
            continue
        lines = text.splitlines()
        all_violations.extend(scan_internal_paths(f, lines))
        all_violations.extend(scan_missing_local_links(f, text))
        all_violations.extend(scan_misleading_anchor_links(f, lines))
        all_violations.extend(scan_publishability_links(f, text, bundle_root))
        all_violations.extend(scan_publishability_prose(f, text, bundle_root))
        # Audit-history check applies only to SKILL.md under skills/.
        if "skills" in f.parts and f.name == "SKILL.md":
            all_violations.extend(scan_audit_history_in_runtime_skill(f, text))
    all_violations.extend(scan_dsstore(bundle_root))
    return all_violations


def emit_report(violations):
    if not violations:
        print("OK: reference-hygiene clean (bundle is self-contained for public consumers).")
        return 0
    for file, lineno, msg in violations:
        loc = f"{file}:{lineno}" if lineno is not None else str(file)
        print(f"FAIL[{loc}]: {msg}", file=sys.stderr)
    print("", file=sys.stderr)
    print(f"FAIL: {len(violations)} reference-hygiene violation(s) in the bundle.", file=sys.stderr)
    print("      see ci/check-reference-hygiene.py header for the rationale per class.", file=sys.stderr)
    return 1


# ---------------------------------------------------------------------
# Self-test: perturb a minimal fake bundle and confirm each check trips.
# ---------------------------------------------------------------------
def write(path: Path, body: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")


def fake_bundle(root: Path):
    write(root / "AGENTS.md", "# Agents\nA clean entry. See [SKILLS.md](SKILLS.md).\n")
    write(root / "SKILLS.md", "# Skill index\n- [example-skill](skills/example-skill/SKILL.md)\n")
    write(root / "README.md", "# Readme\nFor agents, read [AGENTS.md](AGENTS.md).\n")
    write(
        root / "skills/example-skill/SKILL.md",
        "---\nname: example-skill\nkind: knowledge\ndescription: example\n---\n# example-skill\nSee [CAPABILITIES.md](CAPABILITIES.md).\n",
    )
    write(
        root / "skills/example-skill/CAPABILITIES.md",
        "# Capabilities\n## Version compatibility\nBody.\n",
    )


def _mk_internal_targets(root: Path):
    """Create the internal-only targets that the publishability
    perturbations will link to, so the link-resolution check actually
    sees a real file behind the internal-only path."""
    (root / "ci").mkdir(parents=True, exist_ok=True)
    (root / "ci" / "check-skill.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    (root / "AUTHORING.md").write_text("# Authoring\n", encoding="utf-8")


def run_self_test():
    perturbs = [
        ("internal devops path", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\nSee [check-skill.sh](../devops/ci/check-skill.sh).\n", encoding="utf-8"
        )),
        ("missing local image", lambda r: (r / "AGENTS.md").write_text(
            (r / "AGENTS.md").read_text() + "\n![logo](missing-image.png)\n", encoding="utf-8"
        )),
        ("misleading anchor link", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\nSee [`CAPABILITIES.md ## Version compatibility`](#version-compatibility).\n", encoding="utf-8"
        )),
        ("audit-history H2 in runtime SKILL.md", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\n## Audit history\nRow 1\n", encoding="utf-8"
        )),
        ("dated audit-rows inline in ## URL audit", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text()
            + "\n## URL audit\n| date | ver | note |\n| --- | --- | --- |\n| 2026-05-01 | v3 | a |\n| 2026-05-02 | v3 | b |\n| 2026-05-03 | v3 | c |\n",
            encoding="utf-8",
        )),
        ("future-plan/ leak", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\nDesign in `future-plan/foo.md`.\n", encoding="utf-8"
        )),
        (".DS_Store file present", lambda r: (r / ".DS_Store").write_text("", encoding="utf-8")),
        ("PUBLIC -> INTERNAL link to ci/", lambda r: (_mk_internal_targets(r), (r / "AGENTS.md").write_text(
            (r / "AGENTS.md").read_text() + "\nRun [the gate](ci/check-skill.sh).\n", encoding="utf-8"
        ))),
        ("PUBLIC -> INTERNAL link to AUTHORING.md", lambda r: (_mk_internal_targets(r), (r / "README.md").write_text(
            "# Readme\nRead [AUTHORING.md](AUTHORING.md).\n", encoding="utf-8"
        ))),
        ("PUBLIC prose mention of ci/check-", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\nThis is enforced by `ci/check-skill.sh`.\n", encoding="utf-8"
        )),
        ("PUBLIC prose mention of AUTHORING.md", lambda r: (r / "skills/example-skill/SKILL.md").write_text(
            (r / "skills/example-skill/SKILL.md").read_text() + "\nSee AUTHORING.md for contributor rules.\n", encoding="utf-8"
        )),
    ]

    print("== reference-hygiene self-test ==")
    caught = 0
    for label, mutator in perturbs:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            fake_bundle(root)
            # confirm baseline clean
            base_v = run_scan(root)
            if base_v:
                print(f"  trip[{label}]: SKIP (baseline not clean: {len(base_v)} pre-existing violations)")
                continue
            mutator(root)
            v = run_scan(root)
            if v:
                print(f"  trip[{label}]: PASS (gate caught it; {len(v)} violation(s))")
                caught += 1
            else:
                print(f"  trip[{label}]: FAIL (gate missed it)")
    print(f"self-test: {caught} / {len(perturbs)} perturbations caught")
    return 0 if caught == len(perturbs) else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--self-test", action="store_true", help="perturb-and-trip self-test (does not modify bundle)")
    p.add_argument("--bundle-root", type=Path, default=Path(__file__).resolve().parent.parent)
    args = p.parse_args()

    if args.self_test:
        rc = run_self_test()
        print("OK: reference-hygiene self-test PASS" if rc == 0 else "FAIL: reference-hygiene self-test FAIL")
        return rc

    violations = run_scan(args.bundle_root)
    return emit_report(violations)


if __name__ == "__main__":
    sys.exit(main())
