"""
Baseline tests for credentials_vc_issuer.

Covers:
- Import smoke tests for every module
- AppConfig (name, verbose_name)
- DID document view logic (configured, unconfigured, missing key)
- Ed25519 public key derivation from 64-byte and 32-byte private keys
- Verification methods builder (_get_verification_methods)
- URL patterns
- Cache-control headers on DID document

Runs without external services or real signing keys.
"""

import base64
import importlib
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Stub Open edX platform dependencies BEFORE Django setup
# ---------------------------------------------------------------------------

# No opaque_keys needed for this app

# ---------------------------------------------------------------------------
# Django bootstrap
# ---------------------------------------------------------------------------

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'credentials_vc_issuer._test_settings')

_settings = types.ModuleType('credentials_vc_issuer._test_settings')
_settings.SECRET_KEY = 'test-secret-key-vc-issuer'
_settings.INSTALLED_APPS = [
    'django.contrib.contenttypes',
    'django.contrib.auth',
    'credentials_vc_issuer',
]
_settings.DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}
_settings.DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
_settings.USE_TZ = True
_settings.TIME_ZONE = 'UTC'
_settings.AUTH_USER_MODEL = 'auth.User'
_settings.VERIFIABLE_CREDENTIALS = {
    'ISSUER_DID': 'did:web:academyv2.mereka.io',
    'SIGNING_KEY_ID': 'did:web:academyv2.mereka.io#key-1',
}
_settings.ROOT_URLCONF = 'credentials_vc_issuer.urls'
_settings.REST_FRAMEWORK = {}

sys.modules['credentials_vc_issuer._test_settings'] = _settings

import django
django.setup()

from django.test import TestCase, RequestFactory


# ===========================================================================
# 1. Import smoke tests
# ===========================================================================

class TestModuleImports(unittest.TestCase):

    def _assert_importable(self, name):
        try:
            return importlib.import_module(name)
        except ImportError as exc:
            self.fail(f'Failed to import {name}: {exc}')

    def test_import_init(self):
        self._assert_importable('credentials_vc_issuer')

    def test_import_apps(self):
        self._assert_importable('credentials_vc_issuer.apps')

    def test_import_views(self):
        self._assert_importable('credentials_vc_issuer.views')

    def test_import_urls(self):
        self._assert_importable('credentials_vc_issuer.urls')


# ===========================================================================
# 2. AppConfig
# ===========================================================================

class TestAppConfig(unittest.TestCase):

    def test_app_name(self):
        from credentials_vc_issuer.apps import CredentialsVcIssuerConfig
        self.assertEqual(CredentialsVcIssuerConfig.name, 'credentials_vc_issuer')

    def test_verbose_name(self):
        from credentials_vc_issuer.apps import CredentialsVcIssuerConfig
        self.assertEqual(CredentialsVcIssuerConfig.verbose_name,
                         'Verifiable Credentials Issuer Identity')

    def test_default_auto_field(self):
        from credentials_vc_issuer.apps import CredentialsVcIssuerConfig
        self.assertEqual(CredentialsVcIssuerConfig.default_auto_field,
                         'django.db.models.BigAutoField')


# ===========================================================================
# 3. Public key derivation
# ===========================================================================

class TestGetPublicKeyFromPrivate(unittest.TestCase):
    """Test _get_public_key_from_private with real Ed25519 keys."""

    def test_64_byte_key_extracts_public(self):
        """Standard Ed25519 private key (64 bytes) = seed(32) + public(32)."""
        from credentials_vc_issuer.views import _get_public_key_from_private
        # Create a known 64-byte key where the last 32 bytes are the public key
        seed = os.urandom(32)
        public = os.urandom(32)
        private_64 = seed + public
        private_b64 = base64.b64encode(private_64).decode()

        result = _get_public_key_from_private(private_b64)

        expected = base64.b64encode(public).decode()
        self.assertEqual(result, expected)

    def test_32_byte_seed_derives_public(self):
        """32-byte seed should derive public key via cryptography lib."""
        from credentials_vc_issuer.views import _get_public_key_from_private
        try:
            from cryptography.hazmat.primitives.asymmetric import ed25519
        except ImportError:
            self.skipTest('cryptography library not available')

        # Generate a real Ed25519 key pair
        private_key = ed25519.Ed25519PrivateKey.generate()
        seed = private_key.private_bytes(
            encoding=__import__('cryptography.hazmat.primitives.serialization',
                               fromlist=['Encoding']).Encoding.Raw,
            format=__import__('cryptography.hazmat.primitives.serialization',
                             fromlist=['PrivateFormat']).PrivateFormat.Raw,
            encryption_algorithm=__import__('cryptography.hazmat.primitives.serialization',
                                           fromlist=['NoEncryption']).NoEncryption(),
        )
        # seed is 32 bytes
        self.assertEqual(len(seed), 32)

        seed_b64 = base64.b64encode(seed).decode()
        result_b64 = _get_public_key_from_private(seed_b64)

        # The result should be a valid base64 string
        public_bytes = base64.b64decode(result_b64)
        self.assertEqual(len(public_bytes), 32)

    def test_invalid_length_raises(self):
        """Key of unexpected length should raise ValueError."""
        from credentials_vc_issuer.views import _get_public_key_from_private
        bad_key = base64.b64encode(b'too-short').decode()
        with self.assertRaises(ValueError) as ctx:
            _get_public_key_from_private(bad_key)
        self.assertIn('Invalid private key length', str(ctx.exception))


# ===========================================================================
# 4. Verification methods builder
# ===========================================================================

class TestGetVerificationMethods(unittest.TestCase):

    @patch.dict(os.environ, {'VC_SIGNING_PRIVATE_KEY': ''})
    def test_empty_key_returns_empty(self):
        from credentials_vc_issuer.views import _get_verification_methods
        result = _get_verification_methods()
        self.assertEqual(result, [])

    @patch.dict(os.environ, {}, clear=False)
    def test_missing_env_var_returns_empty(self):
        from credentials_vc_issuer.views import _get_verification_methods
        os.environ.pop('VC_SIGNING_PRIVATE_KEY', None)
        result = _get_verification_methods()
        self.assertEqual(result, [])

    def test_valid_key_returns_method(self):
        """With a valid 64-byte key, should return one verification method."""
        from credentials_vc_issuer.views import _get_verification_methods
        seed = os.urandom(32)
        public = os.urandom(32)
        private_b64 = base64.b64encode(seed + public).decode()

        with patch.dict(os.environ, {'VC_SIGNING_PRIVATE_KEY': private_b64}):
            result = _get_verification_methods()

        self.assertEqual(len(result), 1)
        vm = result[0]
        self.assertEqual(vm['type'], 'Ed25519VerificationKey2020')
        self.assertIn('publicKeyBase64', vm)
        self.assertEqual(vm['controller'], 'did:web:academyv2.mereka.io')
        self.assertEqual(vm['id'], 'did:web:academyv2.mereka.io#key-1')


# ===========================================================================
# 5. DID document view
# ===========================================================================

class TestDidDocumentView(TestCase):

    def test_returns_did_document_with_valid_config(self):
        from credentials_vc_issuer.views import did_document_view
        seed = os.urandom(32)
        public = os.urandom(32)
        private_b64 = base64.b64encode(seed + public).decode()

        factory = RequestFactory()
        request = factory.get('/.well-known/did.json')

        with patch.dict(os.environ, {'VC_SIGNING_PRIVATE_KEY': private_b64}):
            response = did_document_view(request)

        self.assertEqual(response.status_code, 200)
        import json
        data = json.loads(response.content)
        self.assertIn('@context', data)
        self.assertEqual(data['id'], 'did:web:academyv2.mereka.io')
        self.assertIn('verificationMethod', data)
        self.assertIn('assertionMethod', data)
        self.assertEqual(len(data['verificationMethod']), 1)
        # assertionMethod should reference the key ID
        self.assertEqual(data['assertionMethod'],
                         [data['verificationMethod'][0]['id']])

    def test_returns_500_when_did_not_configured(self):
        from credentials_vc_issuer.views import did_document_view
        factory = RequestFactory()
        request = factory.get('/.well-known/did.json')

        with patch('credentials_vc_issuer.views.settings') as mock_settings:
            mock_settings.VERIFIABLE_CREDENTIALS = {}
            response = did_document_view(request)

        self.assertEqual(response.status_code, 500)
        import json
        data = json.loads(response.content)
        self.assertIn('error', data)

    def test_returns_500_when_no_signing_key(self):
        from credentials_vc_issuer.views import did_document_view
        factory = RequestFactory()
        request = factory.get('/.well-known/did.json')

        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop('VC_SIGNING_PRIVATE_KEY', None)
            response = did_document_view(request)

        self.assertEqual(response.status_code, 500)

    def test_cache_control_header(self):
        """DID document should have public cache-control header."""
        from credentials_vc_issuer.views import did_document_view
        seed = os.urandom(32)
        public = os.urandom(32)
        private_b64 = base64.b64encode(seed + public).decode()

        factory = RequestFactory()
        request = factory.get('/.well-known/did.json')

        with patch.dict(os.environ, {'VC_SIGNING_PRIVATE_KEY': private_b64}):
            response = did_document_view(request)

        cc = response.get('Cache-Control', '')
        self.assertIn('public', cc)
        self.assertIn('max-age=3600', cc)

    def test_only_get_allowed(self):
        """POST to DID document should be rejected."""
        from credentials_vc_issuer.views import did_document_view
        factory = RequestFactory()
        request = factory.post('/.well-known/did.json')
        response = did_document_view(request)
        self.assertEqual(response.status_code, 405)

    def test_did_context_includes_ed25519_suite(self):
        from credentials_vc_issuer.views import did_document_view
        seed = os.urandom(32)
        public = os.urandom(32)
        private_b64 = base64.b64encode(seed + public).decode()

        factory = RequestFactory()
        request = factory.get('/.well-known/did.json')

        with patch.dict(os.environ, {'VC_SIGNING_PRIVATE_KEY': private_b64}):
            response = did_document_view(request)

        import json
        data = json.loads(response.content)
        contexts = data['@context']
        self.assertIn('https://www.w3.org/ns/did/v1', contexts)
        self.assertIn('https://w3id.org/security/suites/ed25519-2020/v1', contexts)


# ===========================================================================
# 6. URL patterns
# ===========================================================================

class TestURLPatterns(unittest.TestCase):

    def test_did_document_url(self):
        from credentials_vc_issuer.urls import urlpatterns
        names = [p.name for p in urlpatterns]
        self.assertIn('did-document', names)

    def test_app_name(self):
        from credentials_vc_issuer import urls
        self.assertEqual(urls.app_name, 'credentials_vc_issuer')

    def test_did_document_path(self):
        from credentials_vc_issuer.urls import urlpatterns
        paths = [p.pattern._route for p in urlpatterns]
        self.assertIn('.well-known/did.json', paths)


# ===========================================================================
# 7. Version
# ===========================================================================

class TestVersion(unittest.TestCase):

    def test_version_string(self):
        import credentials_vc_issuer
        self.assertEqual(credentials_vc_issuer.__version__, '1.0.0')


if __name__ == '__main__':
    unittest.main()
