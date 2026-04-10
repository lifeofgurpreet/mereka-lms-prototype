"""
Unit tests for mereka_xblock_iframe.py
"""

import os
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch


MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
if MODULE_DIR not in sys.path:
    sys.path.insert(0, MODULE_DIR)


class _FakeResponse(dict):
    pass


class _FakeRequest:
    def __init__(self, host: str, path: str):
        self._host = host
        self.path = path

    def get_host(self):
        return self._host


class _FakeSettings(SimpleNamespace):
    MEREKA_MFE_BASE_URL = "https://apps.academyv2.mereka.dev"


sys.modules.setdefault("django", SimpleNamespace())
sys.modules["django.conf"] = SimpleNamespace(settings=_FakeSettings())

import mereka_xblock_iframe as mxi


class TestOriginHelpers(unittest.TestCase):
    def test_origin_from_url_strips_path(self):
        self.assertEqual(
            mxi._origin_from_url("https://apps.academyv2.mereka.dev/learning"),
            "https://apps.academyv2.mereka.dev",
        )

    def test_origin_from_url_rejects_non_absolute_values(self):
        self.assertEqual(mxi._origin_from_url("/learning"), "")


class TestMerekaXBlockIframeMiddleware(unittest.TestCase):
    def test_non_xblock_paths_are_untouched(self):
        request = _FakeRequest("academyv2.mereka.dev", "/dashboard")
        response = _FakeResponse({"X-Frame-Options": "SAMEORIGIN"})
        middleware = mxi.MerekaXBlockIframeMiddleware(lambda _request: response)

        result = middleware(request)

        self.assertEqual(result["X-Frame-Options"], "SAMEORIGIN")
        self.assertNotIn("Content-Security-Policy", result)

    @patch.object(mxi, "_tenant_mfe_base_url_for_host", return_value="https://apps.academyv2.mereka.dev")
    def test_xblock_paths_replace_frame_headers(self, _mock_mfe):
        request = _FakeRequest("academyv2.mereka.dev", "/xblock/block-v1:test")
        response = _FakeResponse(
            {
                "X-Frame-Options": "SAMEORIGIN",
                "Content-Security-Policy": "default-src 'self'; object-src 'none'",
            }
        )
        middleware = mxi.MerekaXBlockIframeMiddleware(lambda _request: response)

        result = middleware(request)

        self.assertNotIn("X-Frame-Options", result)
        self.assertEqual(
            result["Content-Security-Policy"],
            "default-src 'self'; object-src 'none'; frame-ancestors 'self' https://apps.academyv2.mereka.dev",
        )

    @patch.object(mxi, "_tenant_mfe_base_url_for_host", return_value="https://apps.academyv2.mereka.dev")
    def test_existing_frame_ancestors_is_replaced(self, _mock_mfe):
        request = _FakeRequest("academyv2.mereka.dev", "/xblock/block-v1:test")
        response = _FakeResponse(
            {
                "Content-Security-Policy": "default-src 'self'; frame-ancestors 'self'; object-src 'none'",
            }
        )
        middleware = mxi.MerekaXBlockIframeMiddleware(lambda _request: response)

        result = middleware(request)

        self.assertEqual(
            result["Content-Security-Policy"],
            "default-src 'self'; object-src 'none'; frame-ancestors 'self' https://apps.academyv2.mereka.dev",
        )


if __name__ == "__main__":
    unittest.main()
