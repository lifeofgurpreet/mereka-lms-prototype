#!/usr/bin/env python3
from pathlib import Path

import yaml

MANIFEST = Path("docs/adr/manifest.yaml")
CLASSIFICATION_MAP = Path("docs/adr/classification-map.yaml")
STATUS_MAP = Path("docs/adr/status-map.yaml")
GENERATED_BANNER = (
    "# Generated from docs/adr/manifest.yaml. Do not hand-edit.\n"
)


def _write_generated_yaml(path: Path, payload: dict) -> None:
    rendered = yaml.safe_dump(payload, sort_keys=False, allow_unicode=True)
    path.write_text(f"{GENERATED_BANNER}{rendered}", encoding="utf-8")


def main() -> int:
    data = yaml.safe_load(MANIFEST.read_text(encoding="utf-8"))
    adrs = sorted(data.get("entries", data.get("adrs", [])), key=lambda adr: adr.get("id", ""))
    generated_on = data.get("generated_on")

    classification = {
        "version": 1,
        "generated_on": generated_on,
        "generated_from": str(MANIFEST),
        "entries": {},
    }
    status = {
        "version": 1,
        "generated_on": generated_on,
        "generated_from": str(MANIFEST),
        "entries": {},
    }

    for adr in adrs:
        adr_id = adr["id"]
        path = adr["path"]
        classification["entries"][adr_id] = {
            "path": path,
            "decision_type": adr.get("decision_type"),
        }
        status["entries"][adr_id] = {
            "path": path,
            "decision_status": adr.get("decision_status"),
            "rollout_state": adr.get("rollout_state"),
        }

    _write_generated_yaml(CLASSIFICATION_MAP, classification)
    _write_generated_yaml(STATUS_MAP, status)
    print(
        f"ADR_AUX_MAPS_GENERATED classification_entries={len(classification['entries'])} "
        f"status_entries={len(status['entries'])}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
