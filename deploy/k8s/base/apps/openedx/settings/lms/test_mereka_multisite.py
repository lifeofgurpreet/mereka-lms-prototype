"""
Unit tests for mereka_multisite.py

Tests the core domain resolution, cookie scoping, and login redirect logic
without requiring a running Django instance. Functions are tested in isolation
with mocked Django ORM calls where needed.
"""

import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch, PropertyMock
from dataclasses import dataclass

# The module under test lives at a non-standard path. Add it.
MODULE_DIR = os.path.dirname(os.path.abspath(__file__))
if MODULE_DIR not in sys.path:
    sys.path.insert(0, MODULE_DIR)

# Stub Django settings before importing the module
sys.modules.setdefault("django", MagicMock())
sys.modules.setdefault("django.conf", MagicMock())
sys.modules.setdefault("django.contrib", MagicMock())
sys.modules.setdefault("django.contrib.sites", MagicMock())
sys.modules.setdefault("django.contrib.sites.models", MagicMock())

import mereka_multisite as ms


class TestStripPort(unittest.TestCase):
    def test_no_port(self):
        self.assertEqual(ms._strip_port("example.com"), "example.com")

    def test_with_port(self):
        self.assertEqual(ms._strip_port("example.com:8000"), "example.com")

    def test_empty(self):
        self.assertEqual(ms._strip_port(""), "")


class TestCandidateSiteDomains(unittest.TestCase):
    """Test _candidate_site_domains — the core domain resolution function."""

    def test_lms_host_returns_self(self):
        result = ms._candidate_site_domains("academyv2.mereka.io")
        self.assertEqual(result, ["academyv2.mereka.io"])

    def test_apps_prefix_stripped(self):
        result = ms._candidate_site_domains("apps.staging.academy.biji-biji.com")
        self.assertEqual(result, [
            "apps.staging.academy.biji-biji.com",
            "staging.academy.biji-biji.com",
        ])

    def test_studio_prefix_stripped(self):
        result = ms._candidate_site_domains("studio.staging.academy.biji-biji.com")
        self.assertEqual(result, [
            "studio.staging.academy.biji-biji.com",
            "staging.academy.biji-biji.com",
        ])

    def test_admin_prefix_stripped(self):
        result = ms._candidate_site_domains("admin.academyv2.mereka.io")
        self.assertEqual(result, [
            "admin.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_staging_admin_prefix(self):
        result = ms._candidate_site_domains("staging.admin.academyv2.mereka.io")
        # "staging." env prefix + "admin." service prefix → stripped to staging.X
        self.assertEqual(result, [
            "staging.admin.academyv2.mereka.io",
            "staging.academyv2.mereka.io",
        ])

    def test_preview_prefix_stripped(self):
        result = ms._candidate_site_domains("preview.academyv2.mereka.io")
        self.assertEqual(result, [
            "preview.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_port_stripped(self):
        result = ms._candidate_site_domains("apps.academyv2.mereka.io:443")
        self.assertEqual(result, [
            "apps.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_case_insensitive(self):
        result = ms._candidate_site_domains("APPS.AcademyV2.Mereka.IO")
        self.assertEqual(result, [
            "apps.academyv2.mereka.io",
            "academyv2.mereka.io",
        ])

    def test_staging_mereka_lms(self):
        result = ms._candidate_site_domains("staging.academyv2.mereka.io")
        self.assertEqual(result, ["staging.academyv2.mereka.io"])

    def test_staging_apps_mereka(self):
        result = ms._candidate_site_domains("staging.apps.academyv2.mereka.io")
        # "staging." env prefix + "apps." service prefix → stripped to staging.X
        self.assertEqual(result, [
            "staging.apps.academyv2.mereka.io",
            "staging.academyv2.mereka.io",
        ])

    def test_biji_biji_lms(self):
        result = ms._candidate_site_domains("staging.academy.biji-biji.com")
        self.assertEqual(result, ["staging.academy.biji-biji.com"])

    def test_skillourfuture_lms(self):
        result = ms._candidate_site_domains("staging.skillourfuture.academy.mereka.io")
        self.assertEqual(result, ["staging.skillourfuture.academy.mereka.io"])

    def test_no_duplicates(self):
        """If host doesn't start with a known prefix, result has no dupe."""
        result = ms._candidate_site_domains("academyv2.mereka.io")
        self.assertEqual(len(result), len(set(result)))

    def test_empty_host(self):
        result = ms._candidate_site_domains("")
        self.assertEqual(result, [])


class TestCookiePolicyForHost(unittest.TestCase):
    """Test _cookie_policy_for_host — cookie domain scoping logic."""

    def test_lms_host_gets_broadened_domain(self):
        # Staging LMS: cookie domain broadened to base (strips staging. prefix)
        # so that MFE (staging.apps.X) can read the cookies.
        policy = ms._cookie_policy_for_host("staging.academyv2.mereka.io")
        self.assertEqual(policy.domain, ".academyv2.mereka.io")

    def test_biji_biji_gets_broadened_domain(self):
        """biji-biji staging cookies broadened to base for MFE sharing."""
        policy = ms._cookie_policy_for_host("staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".academy.biji-biji.com")

    def test_skillourfuture_gets_broadened_domain(self):
        policy = ms._cookie_policy_for_host("staging.skillourfuture.academy.mereka.io")
        self.assertEqual(policy.domain, ".skillourfuture.academy.mereka.io")

    def test_apps_prefix_maps_to_broadened_domain(self):
        """MFE host: apps.staging.X → strip apps. → staging.X → broaden → .X"""
        policy = ms._cookie_policy_for_host("apps.staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".academy.biji-biji.com")

    def test_studio_prefix_maps_to_broadened_domain(self):
        """Studio host: studio.staging.X → strip studio. → staging.X → broaden → .X"""
        policy = ms._cookie_policy_for_host("studio.staging.academy.biji-biji.com")
        self.assertEqual(policy.domain, ".academy.biji-biji.com")

    def test_admin_prefix_maps_to_lms_domain(self):
        policy = ms._cookie_policy_for_host("admin.academyv2.mereka.io")
        self.assertEqual(policy.domain, ".academyv2.mereka.io")

    def test_localhost_returns_none(self):
        """localhost should use host-only cookies."""
        policy = ms._cookie_policy_for_host("localhost")
        self.assertIsNone(policy.domain)

    def test_apps_localhost_returns_none(self):
        policy = ms._cookie_policy_for_host("apps.localhost")
        self.assertIsNone(policy.domain)

    def test_empty_host_returns_none(self):
        policy = ms._cookie_policy_for_host("")
        self.assertIsNone(policy.domain)

    def test_no_cross_tenant_contamination(self):
        """Each tenant must get its own cookie domain, never another tenant's."""
        # Staging domains are broadened (strip staging. prefix) for MFE sharing
        tenants = {
            "staging.academyv2.mereka.io": ".academyv2.mereka.io",
            "staging.academy.biji-biji.com": ".academy.biji-biji.com",
            "staging.skillourfuture.academy.mereka.io": ".skillourfuture.academy.mereka.io",
        }
        for host, expected_domain in tenants.items():
            with self.subTest(host=host):
                policy = ms._cookie_policy_for_host(host)
                self.assertEqual(policy.domain, expected_domain)
                # Ensure no other tenant's domain appears
                for other_host, other_domain in tenants.items():
                    if other_host != host:
                        self.assertNotEqual(policy.domain, other_domain,
                            f"{host} got {other_domain} (belongs to {other_host})")

    def test_port_stripped_before_resolution(self):
        policy = ms._cookie_policy_for_host("staging.academyv2.mereka.io:443")
        self.assertEqual(policy.domain, ".academyv2.mereka.io")

    def test_production_host_not_broadened(self):
        """Production hosts should NOT be broadened — no staging. prefix."""
        policy = ms._cookie_policy_for_host("academyv2.mereka.io")
        self.assertEqual(policy.domain, ".academyv2.mereka.io")

    def test_staging_mfe_host_cookie_domain(self):
        """staging.apps.X should get cookie domain that MFE and LMS share."""
        policy = ms._cookie_policy_for_host("staging.apps.academyv2.mereka.io")
        # Candidate stripping: staging.apps.X → staging.X
        # Then staging broadening: staging.X → .X
        self.assertEqual(policy.domain, ".academyv2.mereka.io")


class TestCookieDomainMiddleware(unittest.TestCase):
    """Test MerekaCookieDomainMiddleware behavior."""

    def _make_request(self, host):
        req = MagicMock()
        req.get_host.return_value = host
        return req

    def _make_response_with_cookies(self, cookies_dict):
        """Create a mock response with a real cookies dict."""
        from http.cookies import SimpleCookie
        response = MagicMock()
        response.cookies = SimpleCookie()
        for name, value in cookies_dict.items():
            response.cookies[name] = value
        return response

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_sets_domain_on_csrftoken(self, mock_patch):
        """When cookie policy returns a domain, csrftoken should get it."""
        def get_response(request):
            return self._make_response_with_cookies({"csrftoken": "abc123"})

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academyv2.mereka.io")
        resp = mw(req)
        # Staging domain broadened for MFE cookie sharing
        self.assertEqual(resp.cookies["csrftoken"]["domain"],
                        ".academyv2.mereka.io")

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_sets_domain_on_sessionid(self, mock_patch):
        def get_response(request):
            return self._make_response_with_cookies({"sessionid": "xyz789"})

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)
        # Staging domain broadened for MFE cookie sharing
        self.assertEqual(resp.cookies["sessionid"]["domain"],
                        ".academy.biji-biji.com")

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_no_cross_contamination(self, mock_patch):
        """biji-biji cookies must NOT get mereka's domain."""
        def get_response(request):
            return self._make_response_with_cookies({
                "csrftoken": "token1",
                "sessionid": "session1",
            })

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)
        # Broadened to .academy.biji-biji.com (not .mereka.io)
        self.assertEqual(resp.cookies["csrftoken"]["domain"],
                        ".academy.biji-biji.com")
        self.assertNotIn("mereka", resp.cookies["csrftoken"]["domain"])

    @patch.object(ms, 'patch_sites_framework')
    def test_middleware_localhost_removes_domain(self, mock_patch):
        """localhost should use host-only cookies (no Domain attribute)."""
        def get_response(request):
            resp = self._make_response_with_cookies({"csrftoken": "abc"})
            resp.cookies["csrftoken"]["domain"] = ".some-domain.com"
            return resp

        mw = ms.MerekaCookieDomainMiddleware(get_response)
        req = self._make_request("localhost")
        resp = mw(req)
        # Domain key is deleted — SimpleCookie raises KeyError
        self.assertNotIn("domain", resp.cookies["csrftoken"])


class TestLoginRedirectMiddleware(unittest.TestCase):
    """Test MerekaLoginRedirectMiddleware — per-tenant auth entrypoint redirect."""

    class _FakeJsonResponse:
        def __init__(self, payload, status=200):
            self.status_code = status
            self.content = json.dumps(payload).encode("utf-8")
            self.headers = {}

        def get(self, key, default=None):
            return self.headers.get(key, default)

        def __setitem__(self, key, value):
            self.headers[key] = value

    def _make_request(self, host, path="/login"):
        req = MagicMock()
        req.get_host.return_value = host
        req.path = path
        req.GET = {}
        return req

    def _make_redirect_response(self, location, status=302):
        resp = MagicMock()
        resp.status_code = status
        resp.get.return_value = location
        resp.__getitem__ = MagicMock(return_value=location)
        resp.__setitem__ = MagicMock()
        return resp

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_rewrites_to_tenant_mfe(self, mock_mfe, mock_patch):
        """biji-biji /login should redirect to biji-biji MFE, not mereka MFE."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        original_location = "https://staging.apps.academyv2.mereka.io/authn/login"

        def get_response(request):
            return self._make_redirect_response(original_location)

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)

        # Should have rewritten Location to biji-biji's MFE
        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.academy.biji-biji.com/authn/login"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_rewrites_register_to_tenant_mfe(self, mock_mfe, mock_patch):
        """biji-biji /register should redirect to biji-biji MFE register, not mereka MFE."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        original_location = "https://staging.apps.academyv2.mereka.io/authn/register"

        def get_response(request):
            return self._make_redirect_response(original_location)

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com", path="/register")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.academy.biji-biji.com/authn/register"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_no_rewrite_on_non_login_path(self, mock_mfe, mock_patch):
        """Non-dashboard, non-auth paths should not trigger rewriting."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        def get_response(request):
            return self._make_redirect_response("https://somewhere.com/dashboard")

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com", path="/courses")
        resp = mw(req)

        # Should NOT rewrite — unrelated path
        resp.__setitem__.assert_not_called()

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_no_rewrite_on_non_redirect(self, mock_mfe, mock_patch):
        """200 responses should not be rewritten."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        def get_response(request):
            resp = MagicMock()
            resp.status_code = 200
            return resp

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)

        # Should NOT rewrite — not a redirect
        resp.__setitem__.assert_not_called()

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_no_rewrite_when_no_mfe_base(self, mock_mfe, mock_patch):
        """If SiteConfiguration has no MFE_BASE_URL, don't rewrite."""
        mock_mfe.return_value = None

        def get_response(request):
            return self._make_redirect_response("https://apps.mereka.io/authn/login")

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("unknown-tenant.example.com")
        resp = mw(req)

        # Should NOT rewrite — no MFE base found
        resp.__setitem__.assert_not_called()

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_preserves_query_string(self, mock_mfe, mock_patch):
        """Query parameters in the redirect should be preserved."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        original = "https://staging.apps.academyv2.mereka.io/authn/login?next=%2Fdashboard"

        def get_response(request):
            return self._make_redirect_response(original)

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.academy.biji-biji.com/authn/login?next=%2Fdashboard"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_skillourfuture_redirect(self, mock_mfe, mock_patch):
        """skillourfuture tenant gets its own MFE redirect."""
        mock_mfe.return_value = "https://apps.staging.skillourfuture.academy.mereka.io"

        original = "https://staging.apps.academyv2.mereka.io/authn/login"

        def get_response(request):
            return self._make_redirect_response(original)

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.skillourfuture.academy.mereka.io")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.skillourfuture.academy.mereka.io/authn/login"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_oidc_service_login_url')
    def test_login_bypasses_authn_for_oauth2_authorize(self, mock_oidc_service_login, mock_patch):
        mock_oidc_service_login.return_value = (
            "https://biji-biji.academyv2.mereka.dev/auth/login/oidc/"
            "?next=%2Foauth2%2Fauthorize%3Fclient_id%3Dcms-sso"
        )

        def get_response(request):
            return self._make_redirect_response(
                "https://apps.biji-biji.academyv2.mereka.dev/authn/login?next=%2Foauth2%2Fauthorize%3Fclient_id%3Dcms-sso"
            )

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("biji-biji.academyv2.mereka.dev")
        req.GET = {"next": "/oauth2/authorize?client_id=cms-sso"}
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://biji-biji.academyv2.mereka.dev/auth/login/oidc/?next=%2Foauth2%2Fauthorize%3Fclient_id%3Dcms-sso"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_no_rewrite_when_redirect_not_to_authn(self, mock_mfe, mock_patch):
        """Redirects from /login that don't go to /authn should not be rewritten."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        # e.g. redirect to dashboard after already-logged-in
        def get_response(request):
            return self._make_redirect_response("https://staging.academy.biji-biji.com/dashboard")

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com")
        resp = mw(req)

        resp.__setitem__.assert_not_called()

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_dashboard_auth_redirect_url')
    def test_dashboard_redirects_legacy_login_to_tenant_authn(self, mock_dashboard_auth, mock_patch):
        """LMS /dashboard should stop sending users through the legacy LMS login page."""
        mock_dashboard_auth.return_value = "https://apps.staging.academy.biji-biji.com/authn/login?next=%2Fdashboard"

        def get_response(request):
            return self._make_redirect_response("/login?next=/dashboard")

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com", path="/dashboard")
        resp = mw(req)

        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.academy.biji-biji.com/authn/login?next=%2Fdashboard"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_dashboard_auth_redirect_url')
    def test_dashboard_keeps_unrelated_redirects(self, mock_dashboard_auth, mock_patch):
        mock_dashboard_auth.return_value = "https://apps.staging.academy.biji-biji.com/authn/login?next=%2Fdashboard"

        def get_response(request):
            return self._make_redirect_response("/courses")

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com", path="/dashboard")
        resp = mw(req)

        resp.__setitem__.assert_not_called()

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_dashboard_mfe_url')
    def test_dashboard_html_redirects_to_apps_host(self, mock_dashboard_mfe, mock_patch):
        mock_dashboard_mfe.return_value = "https://apps.staging.academy.biji-biji.com/dashboard"

        def get_response(request):
            resp = MagicMock()
            resp.status_code = 200
            resp.get.side_effect = lambda key, default=None: "text/html; charset=utf-8" if key == "Content-Type" else default
            resp.__setitem__ = MagicMock()
            return resp

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request("staging.academy.biji-biji.com", path="/dashboard")
        resp = mw(req)

        self.assertEqual(resp.status_code, 302)
        resp.__setitem__.assert_called_with(
            "Location",
            "https://apps.staging.academy.biji-biji.com/dashboard"
        )

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_rewrites_login_session_redirect_to_tenant_mfe(self, mock_mfe, mock_patch):
        """login_session success JSON should point MFE routes at the tenant apps host."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        def get_response(request):
            return self._FakeJsonResponse(
                {
                    "success": True,
                    "redirect_url": (
                        "https://staging.academy.biji-biji.com/learning/"
                        "course/course-v1:TEST+COURSE+RUN/home"
                    ),
                }
            )

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request(
            "staging.academy.biji-biji.com",
            path="/api/user/v2/account/login_session/",
        )
        resp = mw(req)

        payload = json.loads(resp.content.decode("utf-8"))
        self.assertEqual(
            payload["redirect_url"],
            "https://apps.staging.academy.biji-biji.com/learning/course/course-v1:TEST+COURSE+RUN/home",
        )
        self.assertEqual(resp.headers["Content-Length"], str(len(resp.content)))

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_login_session_keeps_non_mfe_redirects(self, mock_mfe, mock_patch):
        """login_session should not rewrite LMS-owned post-login destinations."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"

        def get_response(request):
            return self._FakeJsonResponse(
                {
                    "success": True,
                    "redirect_url": "https://staging.academy.biji-biji.com/enterprise/select/active",
                }
            )

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request(
            "staging.academy.biji-biji.com",
            path="/api/user/v2/account/login_session/",
        )
        resp = mw(req)

        payload = json.loads(resp.content.decode("utf-8"))
        self.assertEqual(
            payload["redirect_url"],
            "https://staging.academy.biji-biji.com/enterprise/select/active",
        )
        self.assertEqual(resp.headers, {})

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_apply_tenant_branding_overlay')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_rewrites_mfe_config_urls_to_tenant_mfe(self, mock_mfe, mock_branding, mock_patch):
        """MFE config deep routes should follow the branded tenant apps host."""
        mock_mfe.return_value = "https://apps.staging.academy.biji-biji.com"
        mock_branding.side_effect = lambda request, payload: payload

        def get_response(request):
            return self._FakeJsonResponse(
                {
                    "BASE_URL": "apps.staging.academy.biji-biji.com",
                    "AUTHN_MICROFRONTEND_URL": "https://staging.apps.academyv2.mereka.io/authn",
                    "COURSE_AUTHORING_MICROFRONTEND_URL": "https://staging.apps.academyv2.mereka.io/authoring",
                    "LEARNING_BASE_URL": "https://staging.apps.academyv2.mereka.io/learning",
                    "ACCOUNT_PROFILE_URL": "https://staging.apps.academyv2.mereka.io/u/",
                    "DISCOVERY_API_BASE_URL": "https://staging.discovery.academyv2.mereka.io",
                    "CREDENTIALS_BASE_URL": "",
                }
            )

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request(
            "apps.staging.academy.biji-biji.com",
            path="/api/mfe_config/v1",
        )
        resp = mw(req)

        payload = json.loads(resp.content.decode("utf-8"))
        self.assertEqual(payload["BASE_URL"], "apps.staging.academy.biji-biji.com")
        self.assertEqual(
            payload["AUTHN_MICROFRONTEND_URL"],
            "https://apps.staging.academy.biji-biji.com/authn",
        )
        self.assertEqual(
            payload["COURSE_AUTHORING_MICROFRONTEND_URL"],
            "https://apps.staging.academy.biji-biji.com/authoring",
        )
        self.assertEqual(
            payload["LEARNING_BASE_URL"],
            "https://apps.staging.academy.biji-biji.com/learning",
        )
        self.assertEqual(
            payload["ACCOUNT_PROFILE_URL"],
            "https://apps.staging.academy.biji-biji.com/u/",
        )
        self.assertEqual(
            payload["DISCOVERY_API_BASE_URL"],
            "https://staging.discovery.academyv2.mereka.io",
        )
        self.assertEqual(payload["CREDENTIALS_BASE_URL"], "")
        self.assertEqual(resp.headers["Content-Length"], str(len(resp.content)))

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_apply_tenant_branding_overlay')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_mfe_config_keeps_already_tenant_correct_urls(self, mock_mfe, mock_branding, mock_patch):
        """Tenant-correct MFE config values should not be touched."""
        mock_mfe.return_value = "https://apps.staging.skillourfuture.academy.mereka.io"
        mock_branding.side_effect = lambda request, payload: payload
        original_payload = {
            "AUTHN_MICROFRONTEND_URL": "https://apps.staging.skillourfuture.academy.mereka.io/authn",
            "COURSE_AUTHORING_MICROFRONTEND_URL": "https://apps.staging.skillourfuture.academy.mereka.io/authoring",
            "LEARNING_BASE_URL": "https://apps.staging.skillourfuture.academy.mereka.io/learning",
            "ACCOUNT_PROFILE_URL": "https://apps.staging.skillourfuture.academy.mereka.io/u/",
            "DISCOVERY_API_BASE_URL": "https://staging.discovery.academyv2.mereka.io",
        }

        def get_response(request):
            return self._FakeJsonResponse(original_payload)

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request(
            "apps.staging.skillourfuture.academy.mereka.io",
            path="/api/mfe_config/v1",
        )
        resp = mw(req)

        payload = json.loads(resp.content.decode("utf-8"))
        self.assertEqual(payload, original_payload)
        self.assertEqual(resp.headers, {})

    @patch.object(ms, 'patch_sites_framework')
    @patch.object(ms, '_apply_tenant_branding_overlay')
    @patch.object(ms, '_mfe_base_url_for_host')
    def test_mfe_config_applies_tenant_branding_overlay(self, mock_mfe, mock_branding, mock_patch):
        """Tenant branding values should be overlaid after tenant URL rewriting."""
        mock_mfe.return_value = "https://apps.biji-biji.academyv2.mereka.dev"

        def branding_overlay(request, payload):
            payload = dict(payload)
            payload.update(
                {
                    "SITE_NAME": "Biji-Biji Academy",
                    "PRIMARY_COLOR": "#000000",
                    "SECONDARY_COLOR": "#4b5563",
                    "ACCENT_COLOR": "#374151",
                    "TEXT_ON_PRIMARY": "#ffffff",
                }
            )
            return payload

        mock_branding.side_effect = branding_overlay

        def get_response(request):
            return self._FakeJsonResponse(
                {
                    "BASE_URL": "apps.academyv2.mereka.dev",
                    "AUTHN_MICROFRONTEND_URL": "https://apps.academyv2.mereka.dev/authn",
                }
            )

        mw = ms.MerekaLoginRedirectMiddleware(get_response)
        req = self._make_request(
            "apps.biji-biji.academyv2.mereka.dev",
            path="/api/mfe_config/v1",
        )
        resp = mw(req)

        payload = json.loads(resp.content.decode("utf-8"))
        self.assertEqual(payload["BASE_URL"], "apps.academyv2.mereka.dev")
        self.assertEqual(
            payload["AUTHN_MICROFRONTEND_URL"],
            "https://apps.biji-biji.academyv2.mereka.dev/authn",
        )
        self.assertEqual(payload["SITE_NAME"], "Biji-Biji Academy")
        self.assertEqual(payload["PRIMARY_COLOR"], "#000000")
        self.assertEqual(payload["SECONDARY_COLOR"], "#4b5563")
        self.assertEqual(payload["ACCENT_COLOR"], "#374151")
        self.assertEqual(payload["TEXT_ON_PRIMARY"], "#ffffff")


class TestDomainFromEnvValue(unittest.TestCase):
    def test_plain_domain(self):
        self.assertEqual(ms._domain_from_env_value("academyv2.mereka.io"),
                        "academyv2.mereka.io")

    def test_full_url(self):
        self.assertEqual(ms._domain_from_env_value("https://academyv2.mereka.io"),
                        "academyv2.mereka.io")

    def test_url_with_path(self):
        self.assertEqual(ms._domain_from_env_value("https://academyv2.mereka.io/path"),
                        "academyv2.mereka.io")

    def test_empty(self):
        self.assertEqual(ms._domain_from_env_value(""), "")

    def test_none(self):
        self.assertEqual(ms._domain_from_env_value(None), "")


class TestTenantAuthnMicrofrontendUrlForHost(unittest.TestCase):
    @patch.object(ms, "_mfe_base_url_for_host")
    def test_uses_tenant_apps_host_when_available(self, mock_mfe_base):
        mock_mfe_base.return_value = "https://apps.biji-biji.academyv2.mereka.dev"

        resolved = ms.tenant_authn_microfrontend_url_for_host(
            "biji-biji.academyv2.mereka.dev",
            "https://apps.academyv2.mereka.dev/authn",
        )

        self.assertEqual(
            resolved,
            "https://apps.biji-biji.academyv2.mereka.dev/authn",
        )

    @patch.object(ms, "_mfe_base_url_for_host")
    def test_falls_back_to_default_authn_url(self, mock_mfe_base):
        mock_mfe_base.return_value = None

        resolved = ms.tenant_authn_microfrontend_url_for_host(
            "biji-biji.academyv2.mereka.dev",
            "https://apps.academyv2.mereka.dev/authn/",
        )

        self.assertEqual(
            resolved,
            "https://apps.academyv2.mereka.dev/authn",
        )

    @patch.object(ms, "_tenant_mfe_url")
    def test_falls_back_to_default_authn_url_when_lookup_raises(self, mock_tenant_mfe_url):
        mock_tenant_mfe_url.side_effect = RuntimeError("db unavailable")

        resolved = ms.tenant_authn_microfrontend_url_for_host(
            "biji-biji.academyv2.mereka.dev",
            "https://apps.academyv2.mereka.dev/authn/",
        )

        self.assertEqual(
            resolved,
            "https://apps.academyv2.mereka.dev/authn",
        )


if __name__ == "__main__":
    unittest.main()
