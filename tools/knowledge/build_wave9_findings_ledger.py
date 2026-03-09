#!/usr/bin/env python3
"""Build the Wave 9 findings ledger from current-head repo truth."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any


DATE_RE = re.compile(r"\b(20\d{2}-\d{2}-\d{2})\b")
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")


@dataclass(frozen=True)
class Finding:
    finding_id: str
    source_audit: str
    title: str
    severity: str
    owner: str
    files_affected: list[str]
    proof_command: str
    recommended_action: str
    status: str
    risk: str
    notes: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "finding_id": self.finding_id,
            "source_audit": self.source_audit,
            "title": self.title,
            "severity": self.severity,
            "owner": self.owner,
            "files_affected": self.files_affected,
            "proof_command": self.proof_command,
            "recommended_action": self.recommended_action,
            "current_status": self.status,
            "user_or_agent_risk": self.risk,
            "notes": self.notes,
        }


def extract_dates(path: Path) -> list[date]:
    text = path.read_text(encoding="utf-8")
    values: list[date] = []
    for match in DATE_RE.findall(text):
        try:
            values.append(date.fromisoformat(match))
        except ValueError:
            continue
    return values


def subtitle_verified_date(path: Path) -> date | None:
    head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:8])
    match = re.search(r"Last verified(?: \(UTC\))?: (\d{4}-\d{2}-\d{2})", head)
    if not match:
        return None
    return date.fromisoformat(match.group(1))


def tracker_temporal_finding(repo_root: Path) -> Finding:
    path = repo_root / "docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md"
    verified = subtitle_verified_date(path)
    mentioned_dates = extract_dates(path)
    max_date = max(mentioned_dates) if mentioned_dates else None
    status = "OPEN" if verified and max_date and max_date > verified else "FIXED"
    notes = f"last_verified={verified}, max_mentioned_date={max_date}"
    return Finding(
        finding_id="RTA-01",
        source_audit="repo_truth_audit",
        title="Tracker claims canonical proof while embedding later completion dates",
        severity="blocker",
        owner="platform-team",
        files_affected=["docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md"],
        proof_command=(
            "python3 - <<'PY'\n"
            "from pathlib import Path; import re\n"
            "text=Path('docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md').read_text()\n"
            "print(re.findall(r'20\\\\d{2}-\\\\d{2}-\\\\d{2}', text)[:5], '...', len(re.findall(r'20\\\\d{2}-\\\\d{2}-\\\\d{2}', text)))\n"
            "print(text.splitlines()[1])\nPY"
        ),
        recommended_action="Demote unverifiable future completion claims or update verification semantics mechanically.",
        status=status,
        risk="high",
        notes=notes,
    )


def scorecard_temporal_finding(repo_root: Path) -> Finding:
    path = repo_root / "docs/archive/reports/docs-program-scorecard-20260313.md"
    verified = subtitle_verified_date(path)
    mentioned_dates = extract_dates(path)
    max_date = max(mentioned_dates) if mentioned_dates else None
    status = "OPEN" if verified and max_date and max_date > verified else "FIXED"
    notes = f"last_verified={verified}, max_mentioned_date={max_date}"
    return Finding(
        finding_id="RTA-02",
        source_audit="repo_truth_audit",
        title="Archived scorecard presents future-dated proof with stale verification metadata",
        severity="blocker",
        owner="platform-team",
        files_affected=["docs/archive/reports/docs-program-scorecard-20260313.md"],
        proof_command=(
            "python3 - <<'PY'\n"
            "from pathlib import Path; print('\\n'.join(Path('docs/archive/reports/docs-program-scorecard-20260313.md').read_text().splitlines()[:20]))\nPY"
        ),
        recommended_action="Classify as template/plan or update timestamp semantics so evidence-like docs cannot claim future verification.",
        status=status,
        risk="high",
        notes=notes,
    )


def adr_bundle_navigation_finding(repo_root: Path) -> Finding:
    bundles = sorted((repo_root / "generated/adr-bundles").glob("*.md"))
    broken: list[str] = []
    for bundle in bundles:
        text = bundle.read_text(encoding="utf-8")
        for target in LINK_RE.findall(text):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            resolved = (bundle.parent / target).resolve()
            if not resolved.exists():
                broken.append(f"{bundle.relative_to(repo_root)} -> {target}")
    status = "OPEN" if broken else "FIXED"
    notes = f"broken_links={len(broken)}"
    return Finding(
        finding_id="RTA-03",
        source_audit="repo_truth_audit",
        title="Generated ADR bundles contain broken relative navigation",
        severity="major",
        owner="platform-team",
        files_affected=["generated/adr-bundles/*.md", "scripts/qa/build_decision_graph.py"],
        proof_command=(
            "python3 - <<'PY'\n"
            "from pathlib import Path; import re\n"
            "link_re=re.compile(r'\\[[^\\]]+\\]\\(([^)]+)\\)')\n"
            "for bundle in Path('generated/adr-bundles').glob('*.md'):\n"
            "  for target in link_re.findall(bundle.read_text()):\n"
            "    p=(bundle.parent/target).resolve()\n"
            "    if target and not target.startswith(('http://','https://','#','mailto:')) and not p.exists():\n"
            "      print(f'{bundle}:{target}')\n"
            "PY"
        ),
        recommended_action="Fix the ADR bundle generator so generated links resolve into canonical docs/adr paths.",
        status=status,
        risk="high",
        notes=notes,
    )


def spec_machine_surfaces_finding(repo_root: Path) -> Finding:
    required = [
        "specs/catalog.json",
        "specs/_generated/graph.json",
        "specs/_generated/indexes/spec-read-first.md",
    ]
    missing = [path for path in required if not (repo_root / path).exists()]
    status = "OPEN" if missing else "FIXED"
    notes = "missing=" + (", ".join(missing) if missing else "none")
    return Finding(
        finding_id="RTA-04",
        source_audit="repo_truth_audit",
        title="Spec plane still lacks full machine-readable parity surfaces",
        severity="major",
        owner="platform-team",
        files_affected=required,
        proof_command="test -f specs/catalog.json; test -f specs/_generated/graph.json; test -f specs/_generated/indexes/spec-read-first.md",
        recommended_action="Land deterministic spec catalog, graph, and read-first surfaces with CI checks.",
        status=status,
        risk="high",
        notes=notes,
    )


def dual_catalog_authority_finding(repo_root: Path) -> Finding:
    docs_catalog = repo_root / "docs/catalog.json"
    generated_catalog = repo_root / "generated/catalogs/docs-catalog.json"
    status = "PARTIAL" if docs_catalog.exists() and generated_catalog.exists() else "INVALIDATED"
    notes = "mirror_and_generated_catalogs_present" if status == "PARTIAL" else "one_catalog_missing"
    return Finding(
        finding_id="RTA-05",
        source_audit="repo_truth_audit",
        title="Two docs catalog surfaces still present an authority duplication risk",
        severity="medium",
        owner="platform-team",
        files_affected=["docs/catalog.json", "generated/catalogs/docs-catalog.json"],
        proof_command="test -f docs/catalog.json && test -f generated/catalogs/docs-catalog.json",
        recommended_action="Keep generated catalog primary and verify docs/catalog.json stays a mirror-only projection.",
        status=status,
        risk="medium",
        notes=notes,
    )


def wave_namespace_collision_finding(repo_root: Path) -> Finding:
    candidates = [
        repo_root / "docs/meta/knowledge/WAVE5_EXECUTION_TRACKER.md",
        repo_root / "docs/meta/contracts/WAVE6_EXECUTION_TRACKER.md",
        repo_root / "docs/archive/reports/docs-program-scorecard-20260306.md",
    ]
    present = [str(path.relative_to(repo_root)) for path in candidates if path.exists()]
    status = "PARTIAL" if len(present) >= 2 else "INVALIDATED"
    notes = "overlapping_wave_vocab=" + ", ".join(present) if present else "not_present"
    return Finding(
        finding_id="RTA-06",
        source_audit="repo_truth_audit",
        title="Wave numbering is overloaded across docs program and runtime programs",
        severity="medium",
        owner="platform-team",
        files_affected=present or [str(path.relative_to(repo_root)) for path in candidates],
        proof_command="rg -n \"Wave 2B|Wave 5|Wave 6\" docs/meta docs/archive/reports",
        recommended_action="Introduce explicit program prefixes in read-first and handoff surfaces so wave terms do not collide.",
        status=status,
        risk="medium",
        notes=notes,
    )


def promotion_workflow_finding(repo_root: Path) -> Finding:
    legacy = repo_root / "docs/guides/PROMOTION-WORKFLOW.md"
    actual = repo_root / "docs/reference/operations/RELEASE_PROCESS.md"
    if not legacy.exists() and actual.exists():
        status = "INVALIDATED"
        notes = "audit_target_missing_but_release_process_exists_at_docs/reference/operations/RELEASE_PROCESS.md"
    elif legacy.exists():
        status = "PARTIAL"
        notes = "legacy_promotion_doc_still_present"
    else:
        status = "OPEN"
        notes = "no_promotion_frontdoor_found"
    return Finding(
        finding_id="ICA-01",
        source_audit="infra_alignment_audit",
        title="Promotion workflow drift must be checked against real script and workflow semantics",
        severity="major",
        owner="platform-team",
        files_affected=["docs/guides/PROMOTION-WORKFLOW.md", "docs/reference/operations/RELEASE_PROCESS.md", "scripts/promote.sh", ".github/workflows/promote-image.yml"],
        proof_command="test -f docs/guides/PROMOTION-WORKFLOW.md || test -f docs/reference/operations/RELEASE_PROCESS.md",
        recommended_action="Use the actual release process path and compare it against the real promote script/workflow contract.",
        status=status,
        risk="medium",
        notes=notes,
    )


def claude_summary_finding(repo_root: Path) -> Finding:
    refs = sorted(
        [
        path
        for path in (repo_root / "docs").rglob("*.md")
        if "CLAUDE.md" in path.read_text(encoding="utf-8", errors="ignore")
        ],
        key=lambda path: str(path),
    )
    status = "OPEN" if refs and (repo_root / "CLAUDE.md").exists() else "INVALIDATED"
    notes = f"active_docs_referencing_CLAUDE={len(refs)}"
    return Finding(
        finding_id="ICA-02",
        source_audit="infra_alignment_audit",
        title="CLAUDE.md remains an active front-door summary instead of a compiled or demoted helper",
        severity="major",
        owner="platform-team",
        files_affected=["CLAUDE.md"] + [str(path.relative_to(repo_root)) for path in refs[:8]],
        proof_command="rg -n \"CLAUDE\\.md\" docs docs/ops docs/guides docs/reference",
        recommended_action="Either compile CLAUDE from authoritative contracts or demote it from active read-first surfaces.",
        status=status,
        risk="high",
        notes=notes,
    )


def security_summary_finding(repo_root: Path) -> Finding:
    security = repo_root / "SECURITY.md"
    refs = sorted(
        [
        path
        for path in (repo_root / "docs").rglob("*.md")
        if "SECURITY.md" in path.read_text(encoding="utf-8", errors="ignore")
        ],
        key=lambda path: str(path),
    )
    status = "PARTIAL" if security.exists() and refs else "INVALIDATED"
    notes = f"active_docs_referencing_SECURITY={len(refs)}"
    return Finding(
        finding_id="ICA-03",
        source_audit="infra_alignment_audit",
        title="SECURITY.md is still an active policy front door without contract-derived sync proof",
        severity="medium",
        owner="platform-team",
        files_affected=["SECURITY.md"] + [str(path.relative_to(repo_root)) for path in refs[:8]],
        proof_command="rg -n \"SECURITY\\.md\" docs .github",
        recommended_action="Tie security summary claims to contract-backed sources or demote the summary surface.",
        status=status,
        risk="medium",
        notes=notes,
    )


def contract_source_gap_finding(repo_root: Path) -> Finding:
    required = [
        "config/domain-registry.yaml",
        "config/bootstrap-lane-topology.yaml",
        "contracts/release-contracts.yaml",
        "contracts/service-identity-contract.yaml",
    ]
    present = [path for path in required if (repo_root / path).exists()]
    status = "PARTIAL" if present else "INVALIDATED"
    notes = "present=" + (", ".join(present) if present else "none_in_this_repo")
    return Finding(
        finding_id="ICA-04",
        source_audit="infra_alignment_audit",
        title="Audit-referenced contract source files are not all present in this repo root",
        severity="medium",
        owner="platform-team",
        files_affected=required,
        proof_command="rg --files | rg 'domain-registry|bootstrap-lane-topology|release-contracts|service-identity-contract'",
        recommended_action="Use actual in-repo contract surfaces for alignment work and mark cross-repo-only sources explicitly.",
        status=status,
        risk="medium",
        notes=notes,
    )


def build_findings(repo_root: Path) -> list[Finding]:
    return [
        tracker_temporal_finding(repo_root),
        scorecard_temporal_finding(repo_root),
        adr_bundle_navigation_finding(repo_root),
        spec_machine_surfaces_finding(repo_root),
        dual_catalog_authority_finding(repo_root),
        wave_namespace_collision_finding(repo_root),
        promotion_workflow_finding(repo_root),
        claude_summary_finding(repo_root),
        security_summary_finding(repo_root),
        contract_source_gap_finding(repo_root),
    ]


def render_markdown(findings: list[Finding]) -> str:
    counts = Counter((finding.source_audit, finding.status) for finding in findings)
    status_totals = Counter(finding.status for finding in findings)
    lines = [
        "# Wave 9 Findings Ledger",
        "",
        "> Generated file. Do not hand-edit. Regenerate with `python3 tools/knowledge/build_wave9_findings_ledger.py --repo-root .`.",
        "",
        "## Summary",
        "",
        f"- Generated on: {date.today().isoformat()}",
        f"- Total findings: {len(findings)}",
        f"- Status counts: {json.dumps(dict(status_totals), sort_keys=True)}",
        "",
        "## Audit Breakdown",
        "",
    ]
    for audit in sorted({finding.source_audit for finding in findings}):
        lines.append(f"### {audit}")
        for status in ("OPEN", "PARTIAL", "FIXED", "INVALIDATED"):
            lines.append(f"- {status}: {counts.get((audit, status), 0)}")
        lines.append("")
    lines.extend(
        [
            "## Findings",
            "",
            "| ID | Audit | Status | Severity | Risk | Files | Recommended action |",
            "|---|---|---|---|---|---|---|",
        ]
    )
    for finding in findings:
        files = "<br>".join(finding.files_affected)
        lines.append(
            f"| {finding.finding_id} | {finding.source_audit} | {finding.status} | {finding.severity} | {finding.risk} | {files} | {finding.recommended_action} |"
        )
    lines.append("")
    for finding in findings:
        lines.extend(
            [
                f"### {finding.finding_id} — {finding.title}",
                "",
                f"- Audit: `{finding.source_audit}`",
                f"- Status: `{finding.status}`",
                f"- Severity: `{finding.severity}`",
                f"- Owner: `{finding.owner}`",
                f"- Files: `{', '.join(finding.files_affected)}`",
                f"- Proof command: `{finding.proof_command}`",
                f"- Risk: `{finding.risk}`",
                f"- Notes: {finding.notes}",
                "",
            ]
        )
    return "\n".join(lines) + "\n"


def build_payload(findings: list[Finding]) -> dict[str, Any]:
    audit_totals = Counter(finding.source_audit for finding in findings)
    status_totals = Counter(finding.status for finding in findings)
    return {
        "generated_on": date.today().isoformat(),
        "total_findings": len(findings),
        "audit_totals": dict(sorted(audit_totals.items())),
        "status_totals": dict(sorted(status_totals.items())),
        "findings": [finding.as_dict() for finding in findings],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    findings = build_findings(repo_root)
    payload = build_payload(findings)
    markdown = render_markdown(findings)

    json_path = repo_root / "generated/knowledge/wave9-findings-ledger.json"
    md_path = repo_root / "docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md"
    json_output = json.dumps(payload, indent=2, sort_keys=True) + "\n"

    if args.check:
        current_json = json_path.read_text(encoding="utf-8")
        current_md = md_path.read_text(encoding="utf-8")
        if current_json != json_output or current_md != markdown:
            raise SystemExit("WAVE9_FINDINGS_LEDGER_STALE")
        print(f"WAVE9_FINDINGS_LEDGER_OK mode=check findings={len(findings)}")
        return

    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json_output, encoding="utf-8")
    md_path.write_text(markdown, encoding="utf-8")
    print(f"WAVE9_FINDINGS_LEDGER_OK mode=write findings={len(findings)}")


if __name__ == "__main__":
    main()
