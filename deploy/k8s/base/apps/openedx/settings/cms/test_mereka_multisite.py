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

    @patch.object(ms, "patch_sites_framework")
    @patch.object(ms, "_lms_root_url_for_host")
    def test_sof_cross_domain_studio_signin_redirect(self, mock_lms_root, mock_patch):
        """Regression for bead cm9c.

        SOF Studio lives on studio.skillourfuture.academyv2.mereka.io but the
        canonical LMS Site row is under skillourfuture.academy.mereka.io (different
        base domain). The bridge Site row for skillourfuture.academyv2.mereka.io
        makes _lms_root_url_for_host return the canonical LMS root so the middleware
        rewrites the redirect correctly.
        """
        mock_lms_root.return_value = "https://skillourfuture.academy.mereka.io"

        def get_response(request):
            return self._make_redirect_response("https://academyv2.mereka.io/login")

        mw = ms.MerekaStudioSigninRedirectMiddleware(get_response)
        req = self._make_request("studio.skillourfuture.academyv2.mereka.io", "/signin")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://skillourfuture.academy.mereka.io/login",
        )

    def test_candidate_site_domains_sof_studio_cross_domain(self):
        """_candidate_site_domains for the SOF Studio host must include the bridge domain."""
        host = "studio.skillourfuture.academyv2.mereka.io"
        candidates = ms._candidate_site_domains(host)
        # The bridge Site row domain seeded by multisite-sites.yml fix (bead cm9c).
        self.assertIn("skillourfuture.academyv2.mereka.io", candidates)
        # The host itself must also be a candidate.
        self.assertIn("studio.skillourfuture.academyv2.mereka.io", candidates)

    def test_lms_root_url_for_host_reads_canonical_key(self):
        """_lms_root_url_for_host must prefer CANONICAL_LMS_ROOT_URL over LMS_ROOT_URL.

        Bridge rows set LMS_ROOT_URL to the bridge domain (unique host, passes
        validate_site_host_ownership) and CANONICAL_LMS_ROOT_URL to the real tenant
        LMS root. The middleware must follow CANONICAL_LMS_ROOT_URL so the signin
        redirect lands on the correct tenant LMS, not the bridge domain.
        """
        bridge_site_values = {
            "LMS_ROOT_URL": "https://skillourfuture.academyv2.mereka.io",
            "CANONICAL_LMS_ROOT_URL": "https://skillourfuture.academy.mereka.io",
        }
        mock_cfg = MagicMock()
        mock_cfg.site_values = bridge_site_values
        mock_site = MagicMock()
        mock_site.configuration = mock_cfg

        with patch("django.contrib.sites.models.Site") as mock_site_cls:
            mock_site_cls.objects.filter.return_value.first.return_value = mock_site
            result = ms._lms_root_url_for_host("studio.skillourfuture.academyv2.mereka.io")

        self.assertEqual(result, "https://skillourfuture.academy.mereka.io")
