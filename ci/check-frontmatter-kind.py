#!/usr/bin/env python3
"""Gate: every artifact under skills/{libs,services,tools}/<name>/SKILL.md
must declare the correct `kind` value in its YAML frontmatter:
  libs/*    -> kind: library
  services/* -> kind: service
  tools/*   -> kind: tool

Per the AgentSkills.io spec (https://agentskills.io/specification), the
bundle's `kind` routing contract lives under the spec-allowed `metadata:`
extension point (the spec rejects unknown top-level frontmatter fields).
This gate accepts both placements during the transition:
  1) New (spec-compliant):  metadata.kind: library|service|tool
  2) Legacy (top-level):    kind: library|service|tool

After the full migration, the legacy top-level form will be removed.

Catches the systematic copy-paste error where service / tool skills were
spawned from a library skeleton and inherited `kind: library`.

Exits 0 if all artifacts match; exits 1 listing every mismatch otherwise.
"""

import pathlib
import re
import sys


EXPECTED = {"libs": "library", "services": "service", "tools": "tool"}


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent / "skills"
    if not root.is_dir():
        print(f"FAIL: skills/ not found at {root}")
        return 2

    bad = []
    total = 0
    for kind_dir, expected_kind in EXPECTED.items():
        base = root / kind_dir
        if not base.is_dir():
            continue
        for art in sorted(p for p in base.iterdir() if p.is_dir()):
            skill = art / "SKILL.md"
            if not skill.exists():
                bad.append((art, "no SKILL.md", expected_kind, "missing"))
                continue
            total += 1
            text = skill.read_text()
            m = re.match(r"---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
            if not m:
                bad.append((art, "no YAML frontmatter", expected_kind, "missing"))
                continue
            fm = m.group(1)
            # Spec-compliant placement first: metadata.kind (under metadata: block).
            # Match `metadata:` then look for `  kind: <value>` on a subsequent
            # line indented by 2+ spaces (still inside the mapping).
            km = re.search(
                r"^metadata:\s*\n(?:[ \t]+[a-z_-]+:.*\n)*?[ \t]+kind:\s*(\S+)",
                fm,
                re.MULTILINE,
            )
            placement = "metadata.kind"
            if not km:
                # Legacy top-level placement (deprecated, still accepted).
                km = re.search(r"^kind:\s*(\S+)", fm, re.MULTILINE)
                placement = "top-level"
            if not km:
                bad.append((art, "no kind field in frontmatter (looked for both metadata.kind and top-level kind)", expected_kind, "missing"))
                continue
            actual = km.group(1).strip()
            if actual != expected_kind:
                bad.append((art, f"wrong kind value (placement={placement})", expected_kind, actual))

    if bad:
        print(f"FAIL: {len(bad)} of {total} artifact SKILL.md files have wrong/missing kind frontmatter:")
        for art, reason, expected, actual in bad:
            print(f"  {art.relative_to(root.parent)}  expected kind={expected}  actual={actual}  ({reason})")
        print("\nFix: edit each listed SKILL.md so that its YAML frontmatter contains the expected kind value.")
        return 1

    print(f"OK: all {total} artifact SKILL.md files declare the correct kind frontmatter")
    return 0


if __name__ == "__main__":
    sys.exit(main())
