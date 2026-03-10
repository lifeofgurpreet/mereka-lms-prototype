#!/usr/bin/env python3
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class RepoRoots:
    mereka_lms: Path
    bbi_infrastructure: Path
    platform_control_plane: Path

    def get(self, key: str) -> Path:
        return getattr(self, key.replace("-", "_"))


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text())


def _candidate_paths(repo_root: Path, override: str | None, env_var: str, candidates: list[str]) -> list[Path]:
    values: list[Path] = []
    if override:
        values.append(Path(override))
    env_value = os.environ.get(env_var)
    if env_value:
        values.append(Path(env_value))
    for candidate in candidates:
        values.append((repo_root / candidate).resolve())
    return values


def discover_repo_root(
    repo_root: Path,
    override: str | None,
    env_var: str,
    candidates: list[str],
    label: str,
    required_markers: list[str],
) -> Path:
    checked: list[str] = []
    for candidate in _candidate_paths(repo_root, override, env_var, candidates):
        resolved = candidate.resolve()
        checked.append(str(resolved))
        if not resolved.exists():
            continue
        if all((resolved / marker).exists() for marker in required_markers):
            return resolved

    raise FileNotFoundError(
        f"Unable to resolve {label} repo root. Checked: {', '.join(checked)}. "
        f"Set {env_var} or pass an explicit override."
    )


def load_repo_discovery_model(repo_root: Path) -> dict[str, Any]:
    return load_yaml(repo_root / "docs/meta/skills/REPO_DISCOVERY_MODEL.yaml")


def resolve_repo_roots(
    repo_root: Path,
    bbi_root_override: str | None = None,
    platform_root_override: str | None = None,
) -> RepoRoots:
    model = load_repo_discovery_model(repo_root)
    repos = model["repos"]
    return RepoRoots(
        mereka_lms=discover_repo_root(
            repo_root,
            str(repo_root),
            repos["mereka-lms"]["env_var"],
            repos["mereka-lms"]["default_relative_candidates"],
            "mereka-lms",
            repos["mereka-lms"]["required_markers"],
        ),
        bbi_infrastructure=discover_repo_root(
            repo_root,
            bbi_root_override,
            repos["bbi-infrastructure"]["env_var"],
            repos["bbi-infrastructure"]["default_relative_candidates"],
            "bbi-infrastructure",
            repos["bbi-infrastructure"]["required_markers"],
        ),
        platform_control_plane=discover_repo_root(
            repo_root,
            platform_root_override,
            repos["platform-control-plane"]["env_var"],
            repos["platform-control-plane"]["default_relative_candidates"],
            "platform-control-plane",
            repos["platform-control-plane"]["required_markers"],
        ),
    )
