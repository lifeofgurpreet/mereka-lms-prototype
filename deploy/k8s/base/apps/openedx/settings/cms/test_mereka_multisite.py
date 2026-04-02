"""
Unit tests for CMS multisite redirect helpers.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
if MODULE_DIR not in sys.path:
    sys.path.insert(0, MODULE_DIR)

sys.modules.setdefault("django", MagicMock())
sys.modules.setdefault("django.contrib", MagicMock())
sys.modules.setdefault("django.contrib.sites", MagicMock())
sys.modules.setdefault("django.contrib.sites.models", MagicMock())

import mereka_multisite as ms


class TestStudioSigninRedirectMiddleware(unittest.TestCase):
    def _make_request(self, host, path):
        req = MagicMock()
        req.get_host.return_value = host
        req.path = path
        return req

    def _make_redirect_response(self, location, status=302):
        resp = MagicMock()
        resp.status_code = status
        resp.get.return_value = location
        resp.__setitem__ = MagicMock()
        return resp

    @patch.object(ms, "patch_sites_framework")
    @patch.object(ms, "_lms_root_url_for_host")
    def test_signin_redirect_uses_tenant_lms_host(self, mock_lms_root, mock_patch):
        mock_lms_root.return_value = "https://biji-biji.academyv2.mereka.dev"

        def get_response(request):
            return self._make_redirect_response("https://academyv2.mereka.dev/login?next=%2Fhome%2F")

        mw = ms.MerekaStudioSigninRedirectMiddleware(get_response)
        req = self._make_request("studio.biji-biji.academyv2.mereka.dev", "/signin")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://biji-biji.academyv2.mereka.dev/login?next=%2Fhome%2F",
        )

    @patch.object(ms, "patch_sites_framework")
    @patch.object(ms, "_lms_root_url_for_host")
    def test_edx_oauth2_redirect_uses_tenant_lms_host(self, mock_lms_root, mock_patch):
        mock_lms_root.return_value = "https://biji-biji.academyv2.mereka.dev"

        def get_response(request):
            return self._make_redirect_response(
                "https://academyv2.mereka.dev/oauth2/authorize?client_id=cms-sso&scope=user_id+profile+email"
            )

        mw = ms.MerekaStudioSigninRedirectMiddleware(get_response)
        req = self._make_request("studio.biji-biji.academyv2.mereka.dev", "/login/edx-oauth2/")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://biji-biji.academyv2.mereka.dev/oauth2/authorize?client_id=cms-sso&scope=user_id+profile+email",
        )

    @patch.object(ms, "patch_sites_framework")
    @patch.object(ms, "_lms_root_url_for_host")
    def test_non_matching_redirect_is_unchanged(self, mock_lms_root, mock_patch):
        mock_lms_root.return_value = "https://biji-biji.academyv2.mereka.dev"

        def get_response(request):
            return self._make_redirect_response("https://example.com/home/")

        mw = ms.MerekaStudioSigninRedirectMiddleware(get_response)
        req = self._make_request("studio.biji-biji.academyv2.mereka.dev", "/login/edx-oauth2/")
        resp = mw(req)

        resp.__setitem__.assert_not_called()
