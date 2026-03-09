#!/usr/bin/env python3
from pathlib import Path

import yaml

MANIFEST = Path("docs/adr/manifest.yaml")
CLASSIFICATION_MAP = Path("docs/adr/classification-map.yaml")
STATUS_MAP = Path("docs/adr/status-map.yaml")


def load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def main():
    manifest = load_yaml(MANIFEST)
    classification_map = load_yaml(CLASSIFICATION_MAP)
    status_map = load_yaml(STATUS_MAP)

    errors = []
    adrs = manifest.get("adrs", [])
    expected_ids = [adr["id"] for adr in adrs]
    expected_by_id = {adr["id"]: adr for adr in adrs}

    for map_name, map_doc in (
        ("classification-map.yaml", classification_map),
        ("status-map.yaml", status_map),
    ):
        if map_doc.get("version") != 1:
            errors.append(f"{map_name}: version must equal 1")
        if map_doc.get("generated_from") != "docs/adr/manifest.yaml":
            errors.append(f"{map_name}: generated_from must equal docs/adr/manifest.yaml")
        entries = map_doc.get("entries") or {}
        if sorted(entries.keys()) != sorted(expected_ids):
            errors.append(f"{map_name}: entry ids must match manifest ids exactly")

    classification_entries = classification_map.get("entries") or {}
    status_entries = status_map.get("entries") or {}

    for adr_id in expected_ids:
        manifest_entry = expected_by_id[adr_id]
        class_entry = classification_entries.get(adr_id) or {}
        status_entry = status_entries.get(adr_id) or {}
        expected_path = manifest_entry.get("path")

        if class_entry.get("path") != expected_path:
            errors.append(f"{adr_id}: classification path mismatch")
        if status_entry.get("path") != expected_path:
            errors.append(f"{adr_id}: status path mismatch")

        if class_entry.get("decision_type") != manifest_entry.get("decision_type"):
            errors.append(f"{adr_id}: classification decision_type mismatch")
        if status_entry.get("decision_status") != manifest_entry.get("decision_status"):
            errors.append(f"{adr_id}: status decision_status mismatch")
        if status_entry.get("rollout_state") != manifest_entry.get("rollout_state"):
            errors.append(f"{adr_id}: status rollout_state mismatch")

    if errors:
        print("ADR_AUX_MAPS_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "ADR_AUX_MAPS_OK "
        f"classification_entries={len(classification_entries)} "
        f"status_entries={len(status_entries)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
