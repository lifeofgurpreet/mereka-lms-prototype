"""CMS production/development settings + Credentials Dockerfile patches."""

from _mereka_lms import _register_env_patch

_CMS_PROMETHEUS_METRICS_SNIPPET = """
# Safe module loading helper for CMS
def _safe_add_app(app_name):
    if app_name not in INSTALLED_APPS:
        try:
            __import__(app_name.split('.')[0])
            INSTALLED_APPS.append(app_name)
        except ImportError:
            pass

# Prometheus metrics + URL exposure for CMS
try:
    __import__('django_prometheus')
    if "django_prometheus" not in INSTALLED_APPS:
        INSTALLED_APPS.insert(0, "django_prometheus")
except ImportError:
    pass

_safe_add_app("openedx_prometheus")

if "django_prometheus" in INSTALLED_APPS:
    if "django_prometheus.middleware.PrometheusBeforeMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.insert(0, "django_prometheus.middleware.PrometheusBeforeMiddleware")
    if "django_prometheus.middleware.PrometheusAfterMiddleware" not in MIDDLEWARE:
        MIDDLEWARE.append("django_prometheus.middleware.PrometheusAfterMiddleware")

# Ensure /metrics URL wiring even when PluginURLs auto-discovery is unavailable.
ROOT_URLCONF_OVERRIDES = globals().get("ROOT_URLCONF_OVERRIDES", [])
if "openedx_prometheus.urls" not in ROOT_URLCONF_OVERRIDES:
    ROOT_URLCONF_OVERRIDES.insert(0, "openedx_prometheus.urls")
""".strip()

###############################################################################
# Credentials Service Patches (Verifiable Credentials)
###############################################################################

# Install credentials_vc_issuer custom app
_register_env_patch(
    "credentials-dockerfile-post-python-requirements",
    """
# Copy and install credentials_vc_issuer custom app
COPY --chown=app:app ./infrastructure/tutor/custom-apps/credentials_vc_issuer /openedx/credentials_vc_issuer
RUN pip install -e /openedx/credentials_vc_issuer

# Install cryptography for Ed25519 key operations
RUN pip install cryptography>=41.0.0

# Ensure ZoneInfo("UTC") works even when OS tzdata files are absent
RUN pip install tzdata>=2024.1
""",
)

# NOTE: credentials-urlpatterns is NOT a standard Tutor patch. The VC issuer
# URLs must be wired via the credentials_vc_issuer AppConfig or by providing
# a custom urls.py template via ENV_TEMPLATE_TARGETS when the credentials
# service is deployed.  See: credentials_vc_issuer/apps.py

# CMS production settings patch (metrics + URL exposure + modern features in Studio)
_register_env_patch(
    "openedx-cms-production-settings",
    f"""
{_CMS_PROMETHEUS_METRICS_SNIPPET}
# Explicit ROOT_URLCONF_OVERRIDES keeps /metrics stable across plugin API variations.

# Content Libraries v2 (Learning Core) — required for Studio library authoring
FEATURES['ENABLE_CONTENT_LIBRARIES'] = True
FEATURES['ENABLE_LIBRARY_AUTHORING_MICROFRONTEND'] = True

# Extracted XBlocks — use the new modular blocks from xblocks-contrib (0.6.0)
FEATURES['USE_EXTRACTED_VIDEO_BLOCK'] = True
FEATURES['USE_EXTRACTED_HTML_BLOCK'] = True
FEATURES['USE_EXTRACTED_PROBLEM_BLOCK'] = True
FEATURES['USE_EXTRACTED_DISCUSSION_BLOCK'] = True
FEATURES['USE_EXTRACTED_LTI_BLOCK'] = True
FEATURES['USE_EXTRACTED_WORD_CLOUD_BLOCK'] = True
FEATURES['USE_EXTRACTED_POLL_QUESTION_BLOCK'] = True
FEATURES['USE_EXTRACTED_ANNOTATABLE_BLOCK'] = True

# Aspects event routing — enable batching for performance
EVENT_ROUTING_BACKEND_BATCHING_ENABLED = True

# Safe app installer for CMS
def _safe_add_app_cms(app_name):
    if app_name not in INSTALLED_APPS:
        try:
            __import__(app_name.split('.')[0])
            INSTALLED_APPS.append(app_name)
        except ImportError:
            pass

_safe_add_app_cms("openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig")
""",
)

# CMS development settings patch (metrics parity with production).
# Keep this in sync with production CMS metrics wiring so nonprod/dev also has /metrics.
_register_env_patch(
    "openedx-cms-development-settings",
    _CMS_PROMETHEUS_METRICS_SNIPPET,
)
