from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).parent.parent
HELPER_PATH = REPO_ROOT / "infrastructure" / "tutor" / "patches" / "mfe_slot_ownership.py"

spec = importlib.util.spec_from_file_location("mfe_slot_ownership_patch", HELPER_PATH)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
sys.modules["mfe_slot_ownership_patch"] = module
spec.loader.exec_module(module)  # type: ignore[union-attr]

strip_app_block = module.strip_app_block
strip_slot_ownership = module.strip_slot_ownership


ACCOUNT_BLOCK = """
if (process.env.APP_ID == 'account') {
  addPlugins(config, 'org.openedx.frontend.layout.footer.v1', [
    {
      op: PLUGIN_OPERATIONS.Hide,
      widgetId: 'default_contents',
    },
    {
      op: PLUGIN_OPERATIONS.Insert,
      widget: {
        id: 'custom_footer',
        type: DIRECT_PLUGIN,
        priority: 1,
        RenderWidget: IndigoFooter,
      },
    },
    {
      op: PLUGIN_OPERATIONS.Insert,
      widget: {
        id: 'read_theme_cookie',
        type: DIRECT_PLUGIN,
        priority: 2,
        RenderWidget: AddDarkTheme,
      },
    },
  ]);
  addPlugins(config, 'desktop_secondary_menu_slot', [
    {
      op: PLUGIN_OPERATIONS.Insert,
      widget: {
        id: 'theme_switch_button',
        type: DIRECT_PLUGIN,
        RenderWidget: ToggleThemeButton,
      },
    },
  ]);
  addPlugins(config, 'mobile_header_slot', [
    {
      op: PLUGIN_OPERATIONS.Hide,
      widgetId: 'default_contents',
    }
  ]);
  addPlugins(config, 'mobile_header_slot', [
    {
      op: PLUGIN_OPERATIONS.Insert,
      widget: {
        id: 'theme_switch_button',
        type: DIRECT_PLUGIN,
        RenderWidget: MobileViewHeader,
      },
    },
  ]);
}
""".lstrip()


def test_strip_app_block_removes_entire_foreign_block():
    source = (
        "if (process.env.APP_ID == 'authn') {\n}\n"
        + ACCOUNT_BLOCK
        + "if (process.env.APP_ID == 'communications') {\n}\n"
    )

    updated, changed = strip_app_block(source, "account")

    assert changed is True
    assert "if (process.env.APP_ID == 'account')" not in updated
    assert "desktop_secondary_menu_slot" not in updated
    assert "mobile_header_slot" not in updated
    assert "custom_footer" not in updated
    assert "if (process.env.APP_ID == 'communications')" in updated


def test_strip_app_block_is_noop_without_foreign_markers():
    source = """
if (process.env.APP_ID == 'account') {
  addPlugins(config, 'org.openedx.frontend.layout.footer.v1', [
    {
      op: PLUGIN_OPERATIONS.Insert,
      widget: {
        id: 'mereka_footer',
        type: DIRECT_PLUGIN,
        priority: 1,
        RenderWidget: MerekaFooter,
      },
    },
  ]);
}
""".lstrip()

    updated, changed = strip_app_block(source, "account")

    assert changed is False
    assert updated == source


def test_strip_slot_ownership_reports_all_removed_apps():
    source = ACCOUNT_BLOCK + ACCOUNT_BLOCK.replace("'account'", "'profile'")

    updated, stripped_apps = strip_slot_ownership(source, apps=("account", "profile"))

    assert updated.strip() == ""
    assert stripped_apps == ["account", "profile"]
