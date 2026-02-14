#!/usr/bin/env python3
"""Bead Quality Linter v3 — Outcome Bead Rubric.

Scores each bead against the world-class outcome bead schema:
  Context, Outcome, Non-goals, Constraints, Plan, AC (Given/When/Then),
  Verification, Rollback, Observability, Security, Docs, Dependencies, Owner.

Usage:
  python3 scripts/qa/bead_linter.py                    # Human-readable report
  python3 scripts/qa/bead_linter.py --json              # Machine-readable JSON
  python3 scripts/qa/bead_linter.py --verbose           # Per-bead breakdown
  python3 scripts/qa/bead_linter.py --open-only         # Only open beads
  python3 scripts/qa/bead_linter.py --min-score 12      # Fail if avg < 12

Exit codes:
  0 = All beads pass minimum score (default 0)
  1 = At least one bead below minimum score
"""

import json
import re
import sys
from pathlib import Path

# ── Section definitions ──────────────────────────────────────────────────────
# Each section: (name, weight, patterns_to_match)
# Weight: 1 = standard, 2 = critical (counts double)
SECTIONS = [
    ("Context", 1, [
        r"(?i)^#+\s*context",
        r"(?i)context:",
        r"(?i)why now",
        r"(?i)what.s broken",
        r"(?i)current state",
        r"(?i)problem:",
    ]),
    ("Outcome", 2, [
        r"(?i)^#+\s*outcome",
        r"(?i)outcome:",
        r"(?i)target state",
        r"(?i)success criteria",
        r"(?i)measurable",
        r"(?i)must be true",
    ]),
    ("Non-goals", 1, [
        r"(?i)^#+\s*non.?goals",
        r"(?i)non.?goals:",
        r"(?i)out of scope",
        r"(?i)explicitly not",
        r"(?i)we will not",
    ]),
    ("Constraints", 1, [
        r"(?i)^#+\s*constraints",
        r"(?i)constraints:",
        r"(?i)budget|timeline|must use|cannot",
        r"(?i)hard requirements?",
    ]),
    ("Plan", 1, [
        r"(?i)^#+\s*plan",
        r"(?i)plan:",
        r"(?i)implementation plan",
        r"(?i)steps?:",
        r"(?i)phase \d",
        r"(?i)^\d+\.\s",  # numbered list
    ]),
    ("AC (Given/When/Then)", 2, [
        r"(?i)given\s+.+\s+when\s+.+\s+then",
        r"(?i)^#+\s*(acceptance criteria|ac\b)",
        r"(?i)acceptance criteria:",
        r"(?i)^-\s*\[[ x]\]",  # checkbox items
    ]),
    ("Verification", 2, [
        r"(?i)^#+\s*verification",
        r"(?i)verification:",
        r"(?i)verify.+\.(sh|py)",
        r"(?i)kubectl\s+(get|describe|exec|logs)",
        r"(?i)curl\s+-",
        r"(?i)scripts?/(qa|infra)/",
    ]),
    ("Rollback", 1, [
        r"(?i)^#+\s*rollback",
        r"(?i)rollback:",
        r"(?i)undo|revert|backout",
        r"(?i)if.*fails?.*(then|restore|delete)",
    ]),
    ("Observability", 1, [
        r"(?i)^#+\s*observability",
        r"(?i)observability:",
        r"(?i)metric|alert|dashboard|grafana|prometheus",
        r"(?i)service.?monitor",
        r"(?i)loki|tempo|log.*(query|aggregat)",
    ]),
    ("Security", 1, [
        r"(?i)^#+\s*security",
        r"(?i)security:",
        r"(?i)secret|credential|auth|rbac|tls|ssl",
        r"(?i)owasp|cve|vulnerability",
        r"(?i)blast radius",
    ]),
    ("Docs", 1, [
        r"(?i)^#+\s*docs",
        r"(?i)docs:",
        r"(?i)documentation",
        r"(?i)docs/(operations|architecture|adr)",
        r"(?i)runbook|playbook",
        r"(?i)update.+\.md",
    ]),
    ("Dependencies", 1, [
        r"(?i)^#+\s*dependenc",
        r"(?i)dependencies?:",
        r"(?i)blocked.?by|blocks",
        r"(?i)depends on",
        r"(?i)prerequisite",
    ]),
    ("Owner", 1, [
        r"(?i)^#+\s*owner",
        r"(?i)owner:",
        r"(?i)assigned to",
        r"(?i)responsible:",
        r"(?i)dri:",
    ]),
]

MAX_SCORE = sum(s[1] for s in SECTIONS)  # 16


def score_bead(bead: dict) -> dict:
    """Score a single bead against the outcome rubric."""
    desc = bead.get("description", "")
    title = bead.get("title", "")
    full_text = f"{title}\n{desc}"

    found = []
    missing = []
    total = 0

    for name, weight, patterns in SECTIONS:
        matched = any(re.search(p, full_text, re.MULTILINE) for p in patterns)
        if matched:
            found.append(name)
            total += weight
        else:
            missing.append(name)

    return {
        "id": bead["id"],
        "title": title,
        "status": bead.get("status", "unknown"),
        "priority": bead.get("priority", ""),
        "issue_type": bead.get("issue_type", ""),
        "score": total,
        "max_score": MAX_SCORE,
        "pct": round(total / MAX_SCORE * 100, 1),
        "found": found,
        "missing": missing,
        "desc_len": len(desc),
    }


def grade(pct: float) -> str:
    """Letter grade from percentage."""
    if pct >= 90:
        return "A"
    if pct >= 75:
        return "B"
    if pct >= 60:
        return "C"
    if pct >= 40:
        return "D"
    return "F"


def load_beads(repo_root: Path) -> list[dict]:
    """Load beads from issues.jsonl."""
    jsonl = repo_root / ".beads" / "issues.jsonl"
    if not jsonl.exists():
        print(f"ERROR: {jsonl} not found", file=sys.stderr)
        sys.exit(1)

    beads = []
    with open(jsonl) as f:
        for line in f:
            line = line.strip()
            if line:
                beads.append(json.loads(line))
    return beads


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Bead Quality Linter v3")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--verbose", "-v", action="store_true", help="Per-bead breakdown")
    parser.add_argument("--open-only", action="store_true", help="Only score open beads")
    parser.add_argument("--min-score", type=int, default=0, help="Minimum average score to pass")
    parser.add_argument("--repo", type=str, default=None, help="Repo root path")
    args = parser.parse_args()

    # Find repo root
    if args.repo:
        repo_root = Path(args.repo)
    else:
        # Walk up from script location
        repo_root = Path(__file__).resolve().parent.parent.parent

    beads = load_beads(repo_root)

    if args.open_only:
        beads = [b for b in beads if b.get("status") != "closed"]

    if not beads:
        print("No beads to scan.", file=sys.stderr)
        sys.exit(0)

    # Score all beads
    results = [score_bead(b) for b in beads]
    results.sort(key=lambda r: r["score"])

    avg_score = sum(r["score"] for r in results) / len(results)
    avg_pct = sum(r["pct"] for r in results) / len(results)

    # Count by grade
    grade_counts = {}
    for r in results:
        g = grade(r["pct"])
        grade_counts[g] = grade_counts.get(g, 0) + 1

    # Most commonly missing sections
    missing_freq = {}
    for r in results:
        for m in r["missing"]:
            missing_freq[m] = missing_freq.get(m, 0) + 1
    top_missing = sorted(missing_freq.items(), key=lambda x: -x[1])

    if args.json:
        output = {
            "summary": {
                "total": len(results),
                "avg_score": round(avg_score, 1),
                "avg_pct": round(avg_pct, 1),
                "max_score": MAX_SCORE,
                "grade": grade(avg_pct),
                "grades": grade_counts,
            },
            "top_missing": [{"section": s, "count": c} for s, c in top_missing],
            "beads": results,
        }
        print(json.dumps(output, indent=2))
    else:
        # Human-readable
        print(f"{'='*60}")
        print(f"  Bead Quality Report (Outcome Rubric v3)")
        print(f"{'='*60}")
        print()
        print(f"  Beads scanned:    {len(results)}")
        print(f"  Average score:    {avg_score:.1f} / {MAX_SCORE} ({avg_pct:.1f}%)")
        print(f"  Overall grade:    {grade(avg_pct)}")
        print()

        # Grade distribution
        print("  Grade Distribution:")
        for g in ["A", "B", "C", "D", "F"]:
            count = grade_counts.get(g, 0)
            bar = "#" * count
            print(f"    {g}: {count:3d}  {bar}")
        print()

        # Top missing sections
        print("  Most Commonly Missing Sections:")
        for section, count in top_missing[:7]:
            pct = count / len(results) * 100
            print(f"    {section:30s}  {count:3d} beads ({pct:.0f}%)")
        print()

        if args.verbose:
            print(f"  {'ID':25s} {'Score':>7s}  {'Grade':>5s}  Title")
            print(f"  {'-'*25} {'-'*7}  {'-'*5}  {'-'*40}")
            for r in results:
                g = grade(r["pct"])
                marker = "!!" if r["score"] < 6 else "  "
                print(f"  {r['id']:25s} {r['score']:2d}/{MAX_SCORE:2d}  ({g:>3s})  {marker}{r['title'][:50]}")
                if r["missing"]:
                    print(f"  {'':25s}   Missing: {', '.join(r['missing'][:5])}")
            print()

        # Bottom 5 (worst)
        print("  Lowest Scoring Beads (upgrade first):")
        for r in results[:5]:
            g = grade(r["pct"])
            print(f"    {r['id']:25s}  {r['score']:2d}/{MAX_SCORE}  ({g})  {r['title'][:50]}")
            print(f"    {'':25s}  Missing: {', '.join(r['missing'][:5])}")
        print()

        # Top 5 (best)
        print("  Highest Scoring Beads (reference examples):")
        for r in results[-5:]:
            g = grade(r["pct"])
            print(f"    {r['id']:25s}  {r['score']:2d}/{MAX_SCORE}  ({g})  {r['title'][:50]}")
        print()

    # Exit code
    if args.min_score > 0 and avg_score < args.min_score:
        if not args.json:
            print(f"  FAIL: Average score {avg_score:.1f} < minimum {args.min_score}")
        sys.exit(1)


if __name__ == "__main__":
    main()
