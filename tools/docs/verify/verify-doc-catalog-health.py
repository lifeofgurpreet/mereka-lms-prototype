#!/usr/bin/env python3
"""Verify generated/catalogs/docs-catalog.json quality and derived mirror contracts."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any, Dict, List


@dataclass
class Counter:
    total: int = 0
    missing_file: int = 0
    missing_owner: int = 0
    missing_verified: int = 0
    stale: int = 0
    high_risk: int = 0
    low_risk: int = 0


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("catalog", nargs="?", default="generated/catalogs/docs-catalog.json")
    p.add_argument(
        "--derived-catalog",
        default="docs/catalog.json",
        help="Derived docs catalog path that must mirror the generated source",
    )
    p.add_argument("--root", default=".", help="Repo root")
    p.add_argument(
        "--max-stale-days",
        type=int,
        default=45,
        help="Fail canonical docs older than this threshold",
    )
    p.add_argument(
        "--strict",
        action="store_true",
        help="Require file exists and is current for all catalog entries (not just canonical)",
    )
    p.add_argument(
        "--summary-file",
        default="",
        help="Optional JSON summary file path to write parser-friendly metrics",
    )
    return p.parse_args()


def parse_date(value: str) -> date:
    return datetime.fromisoformat(value).date()


def main() -> int:
    args = parse_args()

    repo_root = Path(args.root)
    catalog_path = repo_root / args.catalog
    derived_catalog_path = repo_root / args.derived_catalog
    if not catalog_path.exists():
        print(f"DOCS_CATALOG_ERROR: catalog missing: {catalog_path}")
        return 1
    if not derived_catalog_path.exists():
        print(f"DOCS_CATALOG_ERROR: derived catalog missing: {derived_catalog_path}")
        return 1

    generated_catalog_text = catalog_path.read_text(encoding="utf-8")
    derived_catalog_text = derived_catalog_path.read_text(encoding="utf-8")
    raw_payload = json.loads(generated_catalog_text)
    if not isinstance(raw_payload, list):
        print(f"DOCS_CATALOG_ERROR: catalog payload is not a list: {catalog_path}")
        return 1
    raw_derived_payload = json.loads(derived_catalog_text)
    if not isinstance(raw_derived_payload, list):
        print(f"DOCS_CATALOG_ERROR: derived catalog payload is not a list: {derived_catalog_path}")
        return 1
    if raw_derived_payload != raw_payload:
        print(
            "DOCS_CATALOG_ERROR: derived docs/catalog.json drifted from generated/catalogs/docs-catalog.json"
        )
        return 1
    payload: List[Dict[str, Any]] = raw_payload
    canonical = Counter()
    all_entries = Counter()

    today = date.today()
    stale_entries: List[str] = []
    missing_file_entries: List[str] = []
    canonical_missing_file_entries: List[str] = []
    missing_owner_entries: List[str] = []
    missing_verified_entries: List[str] = []

    for entry in payload:
        path_text = entry.get("path")
        status = (entry.get("status") or "").lower()
        owner = str(entry.get("owner") or "").strip()
        freshness_risk = str(entry.get("freshness_risk") or "").strip().lower()
        last_verified = str(entry.get("last_verified_or_updated") or "").strip()
        if not path_text:
            doc_path = None
        else:
            normalized_path = (
                path_text[5:] if path_text.startswith("docs/") else path_text
            )
            doc_path = (repo_root / "docs" / normalized_path)

        is_canonical = status == "canonical"
        if is_canonical:
            canonical.total += 1
        all_entries.total += 1
        if freshness_risk:
            if is_canonical:
                canonical.high_risk += int(freshness_risk in ("high", "critical"))
                canonical.low_risk += int(freshness_risk == "low")
            else:
                all_entries.high_risk += int(freshness_risk in ("high", "critical"))
                all_entries.low_risk += int(freshness_risk == "low")

        if doc_path is None or not path_text:
            if args.strict and is_canonical:
                canonical.missing_file += 1
                missing_file_entries.append(str(path_text))
            continue

        exists = doc_path.exists()
        if not exists:
            if is_canonical or args.strict:
                missing_file_entries.append(path_text)
                if is_canonical:
                    canonical_missing_file_entries.append(path_text)
                if is_canonical:
                    canonical.missing_file += 1
                all_entries.missing_file += 1

        if is_canonical:
            if not owner or owner.lower() in {"null", "none"}:
                canonical.missing_owner += 1
                missing_owner_entries.append(path_text)
            if not last_verified:
                canonical.missing_verified += 1
                missing_verified_entries.append(path_text)
            elif exists and last_verified:
                try:
                    age = (today - parse_date(last_verified)).days
                except ValueError:
                    canonical.stale += 1
                    stale_entries.append(f"{path_text}:invalid-date:{last_verified}")
                else:
                    if age > args.max_stale_days:
                        canonical.stale += 1
                        stale_entries.append(f"{path_text}:{age}d:{last_verified}")

        if args.strict and not exists:
            if is_canonical:
                # Already counted above
                pass

    total_failures = (
        canonical.missing_file
        + canonical.missing_owner
        + canonical.missing_verified
        + canonical.stale
        + canonical.high_risk
    )
    summary_payload = {
        "catalog_path": str(catalog_path),
        "derived_catalog_path": str(derived_catalog_path),
        "canonical_total": canonical.total,
        "canonical_missing_file": canonical.missing_file,
        "canonical_missing_owner": canonical.missing_owner,
        "canonical_missing_verified": canonical.missing_verified,
        "canonical_stale": canonical.stale,
        "canonical_high_risk": canonical.high_risk,
        "canonical_low_risk": canonical.low_risk,
        "all_entries": all_entries.total,
        "all_missing_file": all_entries.missing_file,
        "all_high_risk": all_entries.high_risk,
        "all_low_risk": all_entries.low_risk,
        "max_stale_days": args.max_stale_days,
        "failures": total_failures,
        "failed": total_failures > 0,
        "canonical_missing_file_entries": canonical_missing_file_entries,
        "missing_owner_entries": missing_owner_entries,
        "missing_verified_entries": missing_verified_entries,
        "missing_file_entries": missing_file_entries,
        "stale_entries": stale_entries,
    }
    if args.summary_file:
        Path(args.summary_file).write_text(json.dumps(summary_payload, indent=2) + "\n")

    print(f"Docs catalog scope: total={all_entries.total}, canonical={canonical.total}")
    print(f"Derived catalog mirror: {derived_catalog_path}")
    print(
        "Canonical freshness gate: "
        f"owner={canonical.missing_owner}, verified={canonical.missing_verified}, "
        f"stale>{args.max_stale_days}d={canonical.stale}, missing_file={canonical.missing_file}, "
        f"high_freshness_risk={canonical.high_risk}"
    )

    if total_failures > 0:
        print("DOCS_CATALOG_ERRORS: canonical health checks failed")
        if missing_owner_entries:
            print(f"- Missing owner: {', '.join(missing_owner_entries)}")
        if missing_verified_entries:
            print(f"- Missing last verified date: {', '.join(missing_verified_entries)}")
        if canonical_missing_file_entries:
            print(
                "- Missing canonical docs: "
                + ", ".join(canonical_missing_file_entries[:20])
            )
        if stale_entries:
            print(f"- Stale canonical docs: {', '.join(stale_entries)}")
        if canonical.high_risk:
            print("- Canonical doc entries with high/critical freshness risk exist; review required before release")
        return 1

    print(
        f"DOCS_CATALOG_OK (canonical={canonical.total}, "
        f"missing_file={canonical.missing_file}, stale={canonical.stale}, "
        f"missing_owner={canonical.missing_owner}, missing_verified={canonical.missing_verified})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
