#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import jsonschema
import yaml


FORBIDDEN_PREFIXES = (
    "docs/archive/",
    "docs/operations/",
    "docs/architecture/",
    "reports/",
    "evidence/",
    "specs/archive/",
)

PACKS = {
    "generated/skills/skill-registry.json": "docs/meta/skills/schemas/skill-registry.schema.json",
    "generated/skills/command-registry.json": "docs/meta/skills/schemas/command-registry.schema.json",
    "generated/skills/scenario-packs.json": "docs/meta/skills/schemas/scenario-packs.schema.json",
    "generated/skills/skill-dependency-graph.json": "docs/meta/skills/schemas/skill-dependency-graph.schema.json",
    "generated/skills/read-first.json": "docs/meta/skills/schemas/read-first.schema.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Wave 11 pack payloads against their schemas.")
    parser.add_argument("--repo-root", default=".")
    return parser.parse_args()


def load_json(path: Path):
    return json.loads(path.read_text())


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()

    abi = yaml.safe_load((repo_root / "docs/meta/skills/AGENT_PACK_ABI.yaml").read_text())
    ensure(abi["schema_version"] == 1, "Unexpected AGENT_PACK_ABI schema_version")

    for pack_path_str, schema_path_str in PACKS.items():
        pack_path = repo_root / pack_path_str
        schema_path = repo_root / schema_path_str
        ensure(pack_path.exists(), f"Missing pack payload: {pack_path_str}")
        ensure(schema_path.exists(), f"Missing schema: {schema_path_str}")

        payload = load_json(pack_path)
        schema = load_json(schema_path)
        jsonschema.validate(instance=payload, schema=schema)

        ensure(payload["schema_version"] == 1, f"Unexpected schema_version in {pack_path_str}")
        ensure(payload["generated_by"], f"Missing generated_by in {pack_path_str}")
        for canonical_input in payload["canonical_inputs"]:
            ensure("/home/gurpreet" not in canonical_input, f"Absolute path leaked in canonical_inputs: {pack_path_str}")
            ensure(not canonical_input.startswith(FORBIDDEN_PREFIXES), f"Forbidden canonical input in {pack_path_str}: {canonical_input}")

    read_first = load_json(repo_root / "generated/skills/read-first.json")
    for entry in read_first["entries"]:
        ensure(not entry["path"].startswith(FORBIDDEN_PREFIXES), f"Forbidden read-first path: {entry['path']}")
        ensure("/home/gurpreet" not in entry["path"], f"Absolute path leaked in read-first entry: {entry['path']}")

    print(f"AGENT_PACK_SCHEMAS_OK packs={len(PACKS)}")


if __name__ == "__main__":
    main()
