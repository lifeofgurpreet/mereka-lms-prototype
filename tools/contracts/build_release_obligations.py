#!/usr/bin/env python3
"""Build the Wave 6 human-facing release obligations packet for a diff range."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.contracts.build_cross_repo_manifest import build_manifest
from tools.contracts.build_deployment_impact_report import build_report
from tools.contracts.contract_runtime import load_service_contracts, load_yaml


def classify_obligation_class(rel_path: str, contract: dict) -> str:
    if rel_path in contract.get("secret_surfaces", []):
        return "secret_surface_change"
    if rel_path in (contract.get("image_source") or {}).get("source_surfaces", []):
        return "image_or_artifact_change"
    if rel_path in contract.get("runbook_surfaces", []):
        return "deployment_affecting_change"
    lowered = rel_path.lower()
    if "ingress" in lowered or "domain" in lowered or "host" in lowered or "dns" in lowered:
        return "ingress_dns_edge_change"
    if rel_path.startswith(".github/workflows/") or rel_path.startswith("scripts/infra/"):
        return "image_or_artifact_change"
    if rel_path.startswith("generated/"):
        return "generated_refresh_only"
    return "deployment_affecting_change"


def build_markdown(repo_root: Path, range_spec: str) -> str:
    manifest = build_manifest(repo_root, range_spec)
    impact_report = build_report(repo_root, range_spec)
    contracts = load_service_contracts(repo_root)
    obligations_schema = load_yaml(repo_root / "docs" / "meta" / "contracts" / "RELEASE_OBLIGATIONS.yaml")

    service_paths = {
        service["service"]: service["touched_paths"]
        for service in manifest["services"]
    }

    lines: list[str] = []
    lines.append("# Wave 6 Release Obligations")
    lines.append("")
    lines.append(f"- Range: `{range_spec}`")
    lines.append(f"- Overall cross-repo verdict: `{impact_report['overall_verdict']}`")
    lines.append(f"- Required counterpart repos: {', '.join(impact_report['required_repositories']) or 'none'}")
    lines.append(f"- Required reviewers: {', '.join(impact_report['required_reviewers']) or 'none'}")
    lines.append("")
    lines.append("## Service obligations")
    lines.append("")

    aggregate_evidence: set[str] = set()
    aggregate_runbooks: set[str] = set()
    aggregate_release_notes: list[str] = []

    for service_impact in impact_report["deployment_impacts"]:
        service = service_impact["service"]
        contract = contracts[service]
        touched_paths = service_paths.get(service, [])
        active_classes = sorted({classify_obligation_class(path, contract) for path in touched_paths})
        lines.append(f"### {service}")
        lines.append(f"- Verdict: `{service_impact['cross_repo_verdict']}`")
        lines.append(f"- Deployment repo: `{service_impact['deployment_repo']}`")
        if service_impact["overlay_roots"]:
            overlay_text = ", ".join(f"{env} -> `{path}`" for env, path in sorted(service_impact["overlay_roots"].items()))
            lines.append(f"- Overlay roots: {overlay_text}")
        if service_impact["argocd_surfaces"]:
            lines.append(f"- Argo/GitOps surfaces: {', '.join(f'`{item}`' for item in service_impact['argocd_surfaces'])}")
        lines.append(f"- Touched paths: {', '.join(f'`{path}`' for path in touched_paths) if touched_paths else 'none'}")
        lines.append(f"- Active obligation classes: {', '.join(f'`{item}`' for item in active_classes) if active_classes else '`app_only_change`'}")

        evidence_needed: set[str] = set()
        release_needs: set[str] = set()
        for obligation_class in active_classes:
            evidence_needed.update(obligations_schema.get("required_evidence", {}).get(obligation_class, []))
            requires = obligations_schema["obligation_classes"][obligation_class]["requires"]
            for key, value in requires.items():
                if value is True:
                    release_needs.add(key)
        aggregate_evidence.update(evidence_needed)
        aggregate_runbooks.update(contract.get("runbook_surfaces", []))
        if "release_note" in release_needs:
            aggregate_release_notes.append(service)

        lines.append(f"- Required evidence: {', '.join(f'`{item}`' for item in sorted(evidence_needed)) if evidence_needed else 'none'}")
        lines.append(
            f"- Runbooks to review: {', '.join(f'`{item}`' for item in contract.get('runbook_surfaces', [])) if contract.get('runbook_surfaces') else 'none'}"
        )
        if service_impact["unknowns"]:
            lines.append(f"- Unknowns: {', '.join(service_impact['unknowns'])}")
        if service_impact["notes"]:
            lines.append(f"- Notes: {', '.join(str(item) for item in service_impact['notes'])}")
        lines.append("")

    lines.append("## Required infra follow-up")
    lines.append("")
    for service_impact in impact_report["deployment_impacts"]:
        if service_impact["cross_repo_verdict"] == "infra_counterpart_not_required":
            continue
        lines.append(
            f"- `{service_impact['service']}` -> `{service_impact['cross_repo_verdict']}` in `{service_impact['deployment_repo']}`"
        )
    lines.append("")

    lines.append("## Required evidence and runbook updates")
    lines.append("")
    lines.append(f"- Evidence artifacts: {', '.join(f'`{item}`' for item in sorted(aggregate_evidence)) if aggregate_evidence else 'none'}")
    lines.append(f"- Runbook surfaces: {', '.join(f'`{item}`' for item in sorted(aggregate_runbooks)) if aggregate_runbooks else 'none'}")
    lines.append("")

    lines.append("## Required release and promotion notes")
    lines.append("")
    lines.append(
        f"- Services requiring release-note treatment: {', '.join(f'`{item}`' for item in sorted(set(aggregate_release_notes))) if aggregate_release_notes else 'none'}"
    )
    lines.append("")

    lines.append("## Reviewer checklist")
    lines.append("")
    lines.append("- Confirm whether a counterpart `bbi-infrastructure` PR exists for every `infra_counterpart_required` service.")
    lines.append("- Check all `manual_review_required` services for missing exact GitOps file paths before merge.")
    lines.append("- Verify runbook and evidence surfaces moved with each deployment-affecting change.")
    lines.append("- Treat secret-surface changes as blocked until security and platform review are present.")
    lines.append("")

    ignored = [
        entry["path"]
        for entry in manifest["entries"]
        if entry["path_class"] in {"generated_surface_refresh", "repo_support_change"}
        and not entry["touched_services"]
    ]
    lines.append("## Ignored surfaces")
    lines.append("")
    lines.append(f"- {', '.join(f'`{item}`' for item in ignored) if ignored else 'none'}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--range", dest="range_spec", default="origin/main...HEAD")
    parser.add_argument("--output", default="generated/contracts/release-obligations.md")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_path = repo_root / args.output
    rendered = build_markdown(repo_root, args.range_spec)
    if not rendered.endswith("\n"):
        rendered += "\n"

    if args.check:
        if not output_path.exists():
            raise SystemExit(f"Missing generated file: {output_path}")
        if output_path.read_text() != rendered:
            raise SystemExit("RELEASE_OBLIGATIONS_DRIFT")
        print("RELEASE_OBLIGATIONS_OK mode=check")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print("RELEASE_OBLIGATIONS_OK mode=write")


if __name__ == "__main__":
    main()
