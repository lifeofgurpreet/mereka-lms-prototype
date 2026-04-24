from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LIVE_RUNTIME = (
    REPO_ROOT
    / "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution-runtime.js"
)
COMPAT_RUNTIME = (
    REPO_ROOT / "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution.js"
)
GENERATED_COMPAT = (
    REPO_ROOT / "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime_definitions.js"
)
BUILDTIME_IMPORTS = REPO_ROOT / "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py"


def test_live_palette_bridge_uses_app_ready_without_interval_polling() -> None:
    text = LIVE_RUNTIME.read_text(encoding="utf-8")

    assert "const applyMerekaTenantPaletteBridgeIfReady = () => {" in text
    assert "subscribe(APP_READY, () => {" in text
    assert "setInterval(" not in text
    assert "applyMerekaTenantIdentity();" in text
    assert "applyMerekaTenantPaletteBridge();" in text


def test_compat_palette_bridge_mirror_stays_on_app_ready_bootstrap() -> None:
    compat_text = COMPAT_RUNTIME.read_text(encoding="utf-8")
    generated_text = GENERATED_COMPAT.read_text(encoding="utf-8")

    for text in (compat_text, generated_text):
        assert "const applyMerekaTenantPaletteBridgeIfReady = () => {" in text
        assert "subscribe(APP_READY, () => {" in text
        assert "setInterval(" not in text


def test_palette_bridge_runtime_still_imports_app_ready_support() -> None:
    text = BUILDTIME_IMPORTS.read_text(encoding="utf-8")

    assert "import { subscribe, APP_READY } from '@edx/frontend-platform';" in text
