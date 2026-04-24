#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import jsonschema


DEFAULT_JSON_OUTPUT = Path("generated/knowledge/review-decision.json")
DEFAULT_MD_OUTPUT = Path("generated/knowledge/review-decision.md")
SCHEMA_PATH = Path("docs/meta/knowledge/schemas/review-decision.schema.json")

ROOT_RULES: list[tuple[str, set[str], str]] = [
    (".github/workflows/", {"review", "cross-repo-impact"}, ".github/workflows"),
    ("docs/meta/knowledge/", {"documentation-truth", "review"}, "docs/meta/knowledge"),
    ("docs/meta/skills/", {"cross-repo-impact", "review"}, "docs/meta/skills"),
    ("docs/", {"documentation-truth"}, "docs"),
    ("generated/skills/", {"cross-repo-impact", "review"}, "generated/skills"),
    ("generated/catalogs/", {"documentation-truth"}, "generated/catalogs"),
    ("scripts/qa/", {"review"}, "scripts/qa"),
    ("tools/skills/", {"cross-repo-impact", "review"}, "tools/skills"),
    ("specs/", {"documentation-truth"}, "specs"),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Wave 12 review decision outputs.")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="diff_range", default="origin/main...HEAD")
    parser.add_argument("--json-output", default=str(DEFAULT_JSON_OUTPUT))
    parser.add_argument("--md-output", default=str(DEFAULT_MD_OUTPUT))
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def git_stdout(repo_root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def canonicalize_diff_range(repo_root: Path, diff_range: str) -> str:
    current_head = git_stdout(repo_root, "rev-parse", "HEAD")
    if "..." in diff_range:
        left, right = diff_range.split("...", 1)
        merge_base = git_stdout(repo_root, "merge-base", left, right)
        resolved_right = git_stdout(repo_root, "rev-parse", right)
        canonical_right = "HEAD" if resolved_right == current_head else resolved_right
        return f"{merge_base}...{canonical_right}"
    if ".." in diff_range:
        left, right = diff_range.split("..", 1)
        resolved_left = git_stdout(repo_root, "rev-parse", left)
        resolved_right = git_stdout(repo_root, "rev-parse", right)
        canonical_right = "HEAD" if resolved_right == current_head else resolved_right
        return f"{resolved_left}..{canonical_right}"
    return git_stdout(repo_root, "rev-parse", diff_range)


def git_changed_files(repo_root: Path, diff_range: str) -> list[str]:
    result = git_stdout(repo_root, "diff", "--name-only", diff_range)
    return [line.strip() for line in result.splitlines() if line.strip()]


def classify_file(path: str) -> tuple[set[str], str]:
    for prefix, classes, root in ROOT_RULES:
        if path.startswith(prefix):
            return set(classes), root
    return {"documentation-truth"}, path.split("/", 1)[0]


def selected_skills(
    skill_registry: dict[str, Any],
    change_classes: set[str],
    touched_roots: set[str],
) -> list[dict[str, Any]]:
    skills = []
    for skill in skill_registry["skills"]:
        if skill["category"] in change_classes:
            skills.append(skill)
            continue
        if "documentation-truth" in change_classes and any(root.startswith("docs") for root in touched_roots):
            if skill["skill_id"] == "docs-truth-review":
                skills.append(skill)
        if "review" in change_classes and "tools/skills" in touched_roots:
            if skill["skill_id"] == "control-plane-validation":
                skills.append(skill)
    deduped: dict[str, dict[str, Any]] = {skill["skill_id"]: skill for skill in skills}
    if "change-impact-triage" in {skill["skill_id"] for skill in skill_registry["skills"]} and "cross-repo-impact" in change_classes:
        for skill in skill_registry["skills"]:
            if skill["skill_id"] == "change-impact-triage":
                deduped[skill["skill_id"]] = skill
                break
    return [deduped[key] for key in sorted(deduped)]


def choose_read_first_packs(
    selected: list[dict[str, Any]],
    arbitration: dict[str, Any],
) -> list[dict[str, str]]:
    reasons: dict[str, dict[str, str]] = {}
    for skill in selected:
        for pack_id in skill.get("pack_dependencies", []):
            reasons.setdefault(
                pack_id,
                {
                    "pack_id": pack_id,
                    "reason": f"required by {skill['skill_id']}",
                    "source_skill": skill["skill_id"],
                },
            )
    for rule in arbitration["rules"]:
        categories = set(rule["when_categories"])
        if categories.issubset({skill["category"] for skill in selected}):
            pack_id = "mixed-diff-arbitration"
            reasons.setdefault(
                pack_id,
                {
                    "pack_id": pack_id,
                    "reason": f"needed for {rule['rule_id']} arbitration",
                    "source_skill": rule["primary_read_first_skill"],
                },
            )
    order = ["pack-registry", "skill-registry", "runtime-convergence-report", "evidence-sufficiency-map", "mixed-diff-arbitration", "read-first"]
    ranked = sorted(
        reasons.values(),
        key=lambda item: (order.index(item["pack_id"]) if item["pack_id"] in order else len(order), item["pack_id"]),
    )
    return ranked


def compute_severity(change_classes: set[str], touched_repos: set[str]) -> str:
    if {"contracts", "release"}.issubset(change_classes):
        return "release-critical"
    if "cross-repo-impact" in change_classes or len(touched_repos) > 1:
        return "high"
    if "review" in change_classes or "documentation-truth" in change_classes:
        return "medium"
    return "low"


def build_payload(
    repo_root: Path,
    diff_range: str,
    pack_registry: dict[str, Any],
    skill_registry: dict[str, Any],
    evidence_map: dict[str, Any],
    arbitration: dict[str, Any],
    runtime_convergence: dict[str, Any],
) -> dict[str, Any]:
    canonical_range = canonicalize_diff_range(repo_root, diff_range)
    changed_files = git_changed_files(repo_root, diff_range)
    if not changed_files:
        raise SystemExit(f"No changed files found for range: {diff_range}")

    classes: set[str] = set()
    roots: set[str] = set()
    for path in changed_files:
        file_classes, root = classify_file(path)
        classes.update(file_classes)
        roots.add(root)

    selected = selected_skills(skill_registry, classes, roots)
    selected_ids = [skill["skill_id"] for skill in selected]
    reviewers = sorted({reviewer for skill in selected for reviewer in skill["required_reviewers"]})
    evidence_classes = sorted({e for skill in selected for e in skill["required_evidence_classes"]})

    touched_repos = {"mereka-lms"}
    for skill in selected:
        touched_repos.update(skill.get("secondary_repos", []))

    runtime_state = "pass"
    if runtime_convergence["summary"]["fail"] > 0:
        runtime_state = "fail"
    elif runtime_convergence["summary"]["warning"] > 0:
        runtime_state = "warning"

    severity = compute_severity(classes, touched_repos)
    blocking = runtime_state == "fail" or not reviewers or (severity in {"high", "release-critical"} and not evidence_classes)

    rationale_references = [
        "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
        "generated/skills/pack-registry.json",
        "generated/skills/skill-registry.json",
        "generated/skills/runtime-convergence-report.json",
        "generated/skills/evidence-sufficiency-map.json",
        "generated/skills/mixed-diff-arbitration.json",
    ]

    evidence_sources = {
        item["evidence_class"]: item["required_reviewers"] for item in evidence_map["evidence_classes"]
    }
    evidence_summary = [
        {
            "evidence_class": evidence_class,
            "required_reviewers": evidence_sources.get(evidence_class, []),
        }
        for evidence_class in evidence_classes
    ]

    return {
        "pack_id": "review-decision",
        "generated_by": "tools/knowledge/build_review_decision.py",
        "source_range": canonical_range,
        "canonical_inputs": sorted(
            {
                "generated/skills/pack-registry.json",
                "generated/skills/skill-registry.json",
                "generated/skills/runtime-convergence-report.json",
                "generated/skills/evidence-sufficiency-map.json",
                "generated/skills/mixed-diff-arbitration.json",
                "docs/meta/knowledge/DECISION_RUNTIME_MODEL.md",
            }
        ),
        "schema_version": 1,
        "diff_range": canonical_range,
        "change_classes": sorted(classes),
        "touched_files": changed_files,
        "touched_repos": sorted(touched_repos),
        "touched_roots": sorted(roots),
        "decision": {
            "severity": severity,
            "blocking": blocking,
            "selected_skills": selected_ids,
            "reviewer_state": "required-reviewers-derived-live-approvals-unavailable",
            "runtime_convergence_state": runtime_state,
        },
        "required_reviewers": reviewers,
        "missing_reviewers": [],
        "read_first_packs": choose_read_first_packs(selected, arbitration),
        "rationale_references": rationale_references,
        "explanation": {
            "selected_skill_categories": sorted({skill["category"] for skill in selected}),
            "required_evidence_classes": evidence_classes,
            "evidence_summary": evidence_summary,
            "blocking_reasons": (
                ["runtime convergence reported fail"]
                if runtime_state == "fail"
                else ["required reviewer or evidence class derivation missing"] if blocking else []
            ),
        },
    }


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "<!-- Generated file. Do not hand-edit. -->",
        "# Review Decision",
        "",
        f"- Diff range: `{payload['diff_range']}`",
        f"- Severity: `{payload['decision']['severity']}`",
        f"- Blocking: `{str(payload['decision']['blocking']).lower()}`",
        f"- Runtime convergence: `{payload['decision']['runtime_convergence_state']}`",
        "",
        "## Required Reviewers",
    ]
    for reviewer in payload["required_reviewers"]:
        lines.append(f"- `{reviewer}`")
    lines.extend(["", "## Read-First Packs"])
    for item in payload["read_first_packs"]:
        lines.append(f"- `{item['pack_id']}`: {item['reason']}")
    lines.extend(["", "## Change Classes"])
    for item in payload["change_classes"]:
        lines.append(f"- `{item}`")
    lines.extend(["", "## Canonical Inputs"])
    for item in payload["canonical_inputs"]:
        lines.append(f"- `{item}`")
    lines.extend(["", "## Rationale References"])
    for item in payload["rationale_references"]:
        lines.append(f"- `{item}`")
    return "\n".join(lines) + "\n"


def write_or_check(path: Path, content: str, check: bool, label: str) -> None:
    if check:
        if not path.exists():
            raise FileNotFoundError(f"Missing output: {path}")
        if path.read_text() != content:
            raise SystemExit(f"{label} drift detected: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    json_output = repo_root / args.json_output
    md_output = repo_root / args.md_output

    pack_registry = load_json(repo_root / "generated/skills/pack-registry.json")
    skill_registry = load_json(repo_root / "generated/skills/skill-registry.json")
    evidence_map = load_json(repo_root / "generated/skills/evidence-sufficiency-map.json")
    arbitration = load_json(repo_root / "generated/skills/mixed-diff-arbitration.json")
    runtime_convergence = load_json(repo_root / "generated/skills/runtime-convergence-report.json")
    schema = load_json(repo_root / SCHEMA_PATH)

    payload = build_payload(
        repo_root,
        args.diff_range,
        pack_registry,
        skill_registry,
        evidence_map,
        arbitration,
        runtime_convergence,
    )
    jsonschema.validate(instance=payload, schema=schema)

    serialized = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    markdown = render_markdown(payload)
    write_or_check(json_output, serialized, args.check, "REVIEW_DECISION_JSON")
    write_or_check(md_output, markdown, args.check, "REVIEW_DECISION_MD")
    mode = "check" if args.check else "write"
    print(
        "REVIEW_DECISION_OK "
        f"mode={mode} severity={payload['decision']['severity']} "
        f"blocking={str(payload['decision']['blocking']).lower()} "
        f"reviewers={','.join(payload['required_reviewers'])}"
    )


if __name__ == "__main__":
    main()
