from __future__ import annotations

from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent
KUSTOMIZATION_PATH = REPO_ROOT / "deploy" / "k8s" / "base" / "kustomization.yaml"


def _config_map_generator(name: str) -> dict:
    payload = yaml.safe_load(KUSTOMIZATION_PATH.read_text(encoding="utf-8"))
    for generator in payload.get("configMapGenerator", []):
        if generator.get("name") == name:
            return generator
    raise AssertionError(f"configMapGenerator {name!r} not found")


def test_openedx_settings_lms_includes_runtime_import_helpers() -> None:
    generator = _config_map_generator("openedx-settings-lms")
    files = set(generator.get("files", []))

    assert "apps/openedx/settings/lms/mereka_footer.py" in files
    assert "apps/openedx/settings/lms/mereka_jwt_session.py" in files
