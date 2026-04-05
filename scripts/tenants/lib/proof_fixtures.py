"""Shared safety library for synthetic runtime proof fixture tooling."""

import os
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Exceptions ────────────────────────────────────────────────────────────────


class ManifestLoadError(Exception):
    """Raised when the manifest cannot be found or parsed."""


class SyntheticSafetyViolation(Exception):
    """Raised when a safety invariant is violated."""


class RealAccountCollisionError(SyntheticSafetyViolation):
    """Raised when an ORM lookup finds a real (non-synthetic) account collision."""


# ── Constants ─────────────────────────────────────────────────────────────────

SYNTHETIC_EMAIL_DOMAIN = "@synthetic.test"
ALLOWED_ENVIRONMENTS = ("dev",)

# ── Dataclasses ───────────────────────────────────────────────────────────────


@dataclass
class ActionRecord:
    timestamp: str
    action: str  # CREATE, NOOP, SKIP, REFUSE, ERROR
    model: str
    identifier: str
    detail: str
    dry_run: bool

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ApplySummary:
    environment: str
    mode: str  # dry_run or apply
    real_account_mutation_forbidden: bool
    actions: list[ActionRecord] = field(default_factory=list)
    created: int = 0
    reused: int = 0
    refused: int = 0
    skipped: int = 0
    errors: int = 0

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["actions"] = [a.to_dict() for a in self.actions]
        return d


# ── Manifest loading ───────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
MANIFEST_DIR = REPO_ROOT / "config" / "runtime-proof"


def _manifest_name_candidates(env: str) -> list[str]:
    normalized = env.strip().lower()
    aliases = {
        "prod": ["prod", "production"],
        "production": ["production", "prod"],
    }
    return aliases.get(normalized, [normalized])


def find_manifest(env: str) -> Path:
    candidates = []
    manifest_dir_override = os.environ.get("RUNTIME_PROOF_MANIFEST_DIR")
    env_names = _manifest_name_candidates(env)
    for env_name in env_names:
        if manifest_dir_override:
            candidates.append(Path(manifest_dir_override) / f"{env_name}.synthetic-proof-fixtures.yaml")
        candidates.extend(
            [
                MANIFEST_DIR / f"{env_name}.synthetic-proof-fixtures.yaml",
                Path(f"/openedx/config/runtime-proof/{env_name}.synthetic-proof-fixtures.yaml"),
            ]
        )
    for p in candidates:
        if p.exists():
            return p
    raise ManifestLoadError(
        f"No manifest for env={env!r}. Tried: {', '.join(str(c) for c in candidates)}"
    )


def load_manifest(env: str) -> tuple[dict[str, Any], str]:
    try:
        import yaml
    except ImportError as exc:
        raise ManifestLoadError("PyYAML required: pip install pyyaml") from exc
    path = find_manifest(env)
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ManifestLoadError(f"Manifest at {path} did not parse as dict")
    return data, str(path)


# ── Guard functions ────────────────────────────────────────────────────────────


def validate_environment(env: str) -> None:
    """Raise SyntheticSafetyViolation if env is not in the allowed list."""
    if env not in ALLOWED_ENVIRONMENTS:
        raise SyntheticSafetyViolation(
            f"Environment {env!r} not in allowed list {ALLOWED_ENVIRONMENTS}. "
            "Synthetic fixtures can only be applied to dev environments."
        )


def validate_safety_flag(manifest: dict[str, Any]) -> None:
    """Raise SyntheticSafetyViolation if real_account_mutation_forbidden is not true."""
    if manifest.get("real_account_mutation_forbidden") is not True:
        raise SyntheticSafetyViolation(
            "real_account_mutation_forbidden must be present and true in manifest"
        )


def validate_synthetic_email(email: str) -> None:
    """Raise SyntheticSafetyViolation if email does not end with @synthetic.test."""
    if not email.endswith(SYNTHETIC_EMAIL_DOMAIN):
        raise SyntheticSafetyViolation(
            f"Email {email!r} does not use {SYNTHETIC_EMAIL_DOMAIN} domain. "
            "Only synthetic emails are allowed."
        )


def validate_all_emails_synthetic(manifest: dict[str, Any]) -> None:
    """Validate every email in the manifest is @synthetic.test."""
    fc = manifest.get("fixture_classes", {})
    # Check synthetic identity emails.
    for user in fc.get("synthetic_identities", {}).get("users", []):
        validate_synthetic_email(user.get("email", ""))
    # Check enterprise customer contact emails.
    for ec in fc.get("lms_enterprise_data", {}).get("enterprise_customers", []):
        contact = ec.get("contact_email", "")
        if contact:
            validate_synthetic_email(contact)


def run_all_guards(manifest: dict[str, Any], env: str) -> None:
    """Run the complete guard chain. Raises SyntheticSafetyViolation on any failure.

    All guards must pass before any ORM write is permitted.
    """
    validate_environment(env)
    validate_safety_flag(manifest)
    validate_all_emails_synthetic(manifest)


# ── Action record helpers ──────────────────────────────────────────────────────


def make_action(
    action: str,
    model: str,
    identifier: str,
    detail: str,
    dry_run: bool,
) -> ActionRecord:
    return ActionRecord(
        timestamp=datetime.now(timezone.utc).isoformat(),
        action=action,
        model=model,
        identifier=identifier,
        detail=detail,
        dry_run=dry_run,
    )
