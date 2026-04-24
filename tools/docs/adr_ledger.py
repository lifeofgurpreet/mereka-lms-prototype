#!/usr/bin/env python3
"""ADR ledger scanner and render helpers."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


ADR_ROOT = Path("docs/adr")
GENERATED_ROOT = ADR_ROOT / "_generated"
REQUIRED_KEYS = [
    "id",
    "title",
    "decision_status",
    "decision_type",
    "rollout_state",
    "owner",
    "created",
    "last_reviewed",
    "review_due",
    "supersedes",
    "amends",
    "depends_on",
    "read_next",
    "governs",
    "does_not_govern",
    "related_oep",
    "related_tutor_docs",
    "related_specs",
    "related_runbooks",
    "related_evidence",
    "fitness_functions",
    "expiry_date",
    "removal_condition",
]
HOT_PATH_IDS = [
    "ADR-021",
    "ADR-028",
    "ADR-029",
    "ADR-030",
    "ADR-031",
    "ADR-032",
    "ADR-033",
    "ADR-006",
    "ADR-018",
    "ADR-013",
    "ADR-022",
    "ADR-024",
]


@dataclass
class LedgerDoc:
    path: Path
    meta: dict[str, Any]
    body: str

    @property
    def relpath(self) -> str:
        return self.path.as_posix()

    @property
    def basename(self) -> str:
        return self.path.name

    @property
    def id(self) -> str:
        return str(self.meta["id"])

    @property
    def title(self) -> str:
        return str(self.meta["title"])

    @property
    def root_bucket(self) -> str:
        rel = self.path.relative_to(ADR_ROOT)
        if rel.parts[0] == "rfc":
            return "rfc"
        if rel.parts[0] == "historical":
            return "historical"
        return "accepted"


def parse_frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError(f"{path}: missing YAML frontmatter")
    _, rest = text.split("---\n", 1)
    if "\n---\n" not in rest:
        raise ValueError(f"{path}: unterminated YAML frontmatter")
    frontmatter, body = rest.split("\n---\n", 1)
    meta = yaml.safe_load(frontmatter) or {}
    if not isinstance(meta, dict):
        raise ValueError(f"{path}: frontmatter must parse as a mapping")
    return meta, body


def iter_adr_docs() -> list[LedgerDoc]:
    docs: list[LedgerDoc] = []
    for path in sorted(ADR_ROOT.rglob("*.md")):
        rel = path.relative_to(ADR_ROOT)
        if rel.parts[0] in {"_generated", "templates"}:
            continue
        if path.name == "README.md":
            continue
        if path.name == "contradictions-register.md":
            continue
        meta, body = parse_frontmatter(path)
        docs.append(LedgerDoc(path=path, meta=meta, body=body))
    return docs


def by_id(docs: list[LedgerDoc]) -> dict[str, LedgerDoc]:
    return {doc.id: doc for doc in docs}


def render_yaml_frontmatter(meta: dict[str, Any]) -> str:
    return "---\n" + yaml.safe_dump(meta, sort_keys=False, allow_unicode=True).strip() + "\n---\n"


def dump_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def display_status(doc: LedgerDoc) -> str:
    if doc.root_bucket == "historical":
        return "historical"
    if doc.root_bucket == "rfc":
        return "proposed"
    return str(doc.meta["decision_status"])


def docs_by_bucket(docs: list[LedgerDoc]) -> dict[str, list[LedgerDoc]]:
    buckets = {"accepted": [], "historical": [], "rfc": []}
    for doc in docs:
        buckets[doc.root_bucket].append(doc)
    for key in buckets:
        buckets[key].sort(key=lambda item: item.id)
    return buckets


def render_readme(docs: list[LedgerDoc]) -> str:
    buckets = docs_by_bucket(docs)
    lines = [
        "# Architecture Decision Ledger",
        "",
        "_Generated from ADR frontmatter. Do not hand-edit._",
        "",
        "## Read First",
        "",
        "- [Hot path](./_generated/hot-path.md)",
        "- [History map](./_generated/history-map.md)",
        "- [RFC queue](./rfc/README.md)",
        "- [ADR templates](./templates/README.md)",
        "",
        "## Current Law",
        "",
        "Only current accepted ADRs remain at this root.",
        "",
        "| ADR | Title | Type | Rollout | Path |",
        "|---|---|---|---|---|",
    ]
    for doc in buckets["accepted"]:
        lines.append(
            f"| {doc.id} | {doc.title} | {doc.meta['decision_type']} | {doc.meta['rollout_state']} | [{doc.basename}]({doc.basename}) |"
        )
    lines.extend(
        [
            "",
            "## Historical Decisions",
            "",
            "Historical ADRs remain discoverable but are not part of the default read path.",
            "",
            "| ADR | Title | Path |",
            "|---|---|---|",
        ]
    )
    for doc in buckets["historical"]:
        link = doc.path.relative_to(ADR_ROOT).as_posix()
        lines.append(f"| {doc.id} | {doc.title} | [{link}]({link}) |")
    lines.extend(
        [
            "",
            "## RFC Queue",
            "",
            "Proposals stay out of the accepted ADR hot path until accepted.",
            "",
            "| RFC | Title | Path |",
            "|---|---|---|",
        ]
    )
    for doc in buckets["rfc"]:
        link = doc.path.relative_to(ADR_ROOT).as_posix()
        lines.append(f"| {doc.id} | {doc.title} | [{link}]({link}) |")
    lines.extend(
        [
            "",
            "## Authority Order",
            "",
            "1. ADR frontmatter in the file itself",
            "2. ADR body content in the file itself",
            "3. Generated projections under `docs/adr/_generated/`",
            "4. Generated compatibility maps (`manifest.yaml`, `classification-map.yaml`, `status-map.yaml`) if still consumed by tooling",
            "",
        ]
    )
    return "\n".join(lines)


def render_rfc_readme(docs: list[LedgerDoc]) -> str:
    rfcs = docs_by_bucket(docs)["rfc"]
    lines = [
        "# RFC Queue",
        "",
        "_Generated from ADR frontmatter. Do not hand-edit._",
        "",
        "This queue contains proposals only. Files here are not current law.",
        "",
        "| RFC | Title | Rollout | Path |",
        "|---|---|---|---|",
    ]
    for doc in rfcs:
        link = doc.path.relative_to(ADR_ROOT / "rfc").as_posix()
        lines.append(f"| {doc.id} | {doc.title} | {doc.meta['rollout_state']} | [{link}]({link}) |")
    return "\n".join(lines)


def build_index(docs: list[LedgerDoc]) -> dict[str, Any]:
    buckets = docs_by_bucket(docs)
    return {
        "authority_order": [
            "adr-frontmatter",
            "adr-body",
            "generated-adr-projections",
            "generated-compatibility-maps",
        ],
        "counts": {key: len(value) for key, value in buckets.items()},
        "entries": [
            {
                "id": doc.id,
                "title": doc.title,
                "path": doc.relpath,
                "bucket": doc.root_bucket,
                "decision_status": doc.meta["decision_status"],
                "decision_type": doc.meta["decision_type"],
                "rollout_state": doc.meta["rollout_state"],
                "owner": doc.meta["owner"],
                "read_next": doc.meta.get("read_next", []),
                "supersedes": doc.meta.get("supersedes", []),
                "amends": doc.meta.get("amends", []),
            }
            for doc in sorted(docs, key=lambda item: item.id)
        ],
    }


def render_hot_path(docs: list[LedgerDoc]) -> str:
    mapping = by_id(docs)
    lines = [
        "# ADR Hot Path",
        "",
        "_Generated from ADR frontmatter. Do not hand-edit._",
        "",
        "This is the read-first path for humans and future agents. It is intentionally smaller than the full accepted corpus.",
        "",
    ]
    for adr_id in HOT_PATH_IDS:
        doc = mapping.get(adr_id)
        if not doc:
            continue
        rel = (Path("..") / doc.path.relative_to(ADR_ROOT)).as_posix()
        lines.append(f"- [{adr_id}: {doc.title}]({rel})")
    return "\n".join(lines) + "\n"


def render_history_map(docs: list[LedgerDoc]) -> str:
    historical = docs_by_bucket(docs)["historical"]
    lines = [
        "# ADR History Map",
        "",
        "_Generated from ADR frontmatter. Do not hand-edit._",
        "",
        "These ADRs carry decision history but are not current law.",
        "",
        "| ADR | Title | Historical reason | Path |",
        "| --- | --- | --- | --- |",
    ]
    for doc in historical:
        reason = doc.meta.get("historical_reason") or doc.meta.get("removal_condition") or "historical"
        rel = (Path("..") / doc.path.relative_to(ADR_ROOT)).as_posix()
        lines.append(f"| {doc.id} | {doc.title} | {reason} | [{rel}]({rel}) |")
    return "\n".join(lines) + "\n"


def build_generated_maps(docs: list[LedgerDoc]) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    manifest = {
        "version": 3,
        "generated_from": "adr-frontmatter",
        "entries": [],
    }
    classification = {
        "version": 2,
        "generated_from": "adr-frontmatter",
        "entries": {},
    }
    status = {
        "version": 2,
        "generated_from": "adr-frontmatter",
        "entries": {},
    }
    for doc in sorted(docs, key=lambda item: item.id):
        manifest["entries"].append(
            {
                "id": doc.id,
                "path": doc.relpath,
                "title": doc.title,
                "bucket": doc.root_bucket,
                "decision_status": doc.meta["decision_status"],
                "decision_type": doc.meta["decision_type"],
                "rollout_state": doc.meta["rollout_state"],
                "owner": doc.meta["owner"],
            }
        )
        classification["entries"][doc.id] = {
            "path": doc.relpath,
            "bucket": doc.root_bucket,
            "decision_type": doc.meta["decision_type"],
        }
        status["entries"][doc.id] = {
            "path": doc.relpath,
            "bucket": doc.root_bucket,
            "decision_status": doc.meta["decision_status"],
            "rollout_state": doc.meta["rollout_state"],
        }
    return manifest, classification, status
