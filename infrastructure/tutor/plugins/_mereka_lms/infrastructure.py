"""Infrastructure patches — MySQL auth and Caddy edge configuration."""

from tutor import hooks

from _mereka_lms import _register_env_patch

###############################################################################
# MySQL Dockerfile Patches
###############################################################################

_register_env_patch(
    "mysql-docker-compose",
    """
# MySQL 8 authentication plugin fix
environment:
  MYSQL_ROOT_HOST: "%"
command: mysqld --default-authentication-plugin=mysql_native_password
""",
)

###############################################################################
# Caddy Configuration Patches
###############################################################################

# Add security header snippet and extra LMS host blocks to Caddyfile.
_register_env_patch(
    "caddyfile",
    """
(security_headers) {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        X-XSS-Protection "0"
    }
}

# Additional LMS sites
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
{{ host }}{$default_site_port} {
    import security_headers

    @favicon_matcher {
        path_regexp ^/favicon.ico$
    }
    rewrite @favicon_matcher /theming/asset/images/favicon.ico

    # Limit profile image upload size
    handle_path /api/profile_images/*/*/upload {
        request_body {
            max_size 1MB
        }
    }

    import proxy "lms:8000"

    handle_path /* {
        request_body {
            max_size 4MB
        }
    }
}
{% endfor %}
""",
)

# Extend tutor-mfe's canonical MFE host block instead of emitting a second
# {{ MFE_HOST }} site. A duplicate site block makes Caddy refuse to start.
_register_env_patch(
    "caddyfile-mfe-proxy",
    """
import security_headers

@mfe_prefixed_lms_routes path_regexp mfe_prefixed_lms ^/(authn|account|communications|course-authoring|authoring|discussions|gradebook|learner-dashboard|learning|learner-record|ora-grading|profile)(/(api/mfe_config/v1.*|api/.*|login_refresh.*|csrf/.*|oauth2/.*|login))$
handle @mfe_prefixed_lms_routes {
    rewrite * {http.regexp.mfe_prefixed_lms.2}
    reverse_proxy lms:8000 {
        header_up Host {http.request.host}
    }
}

# Strip MFE basename from theme asset requests so /authn/theme/core.min.css
# resolves to /theme/core.min.css instead of hitting the SPA fallback.
@mfe_prefixed_theme path_regexp mfe_theme ^/(authn|account|communications|course-authoring|authoring|discussions|gradebook|learner-dashboard|learning|learner-record|ora-grading|profile)/theme/(.+)$
handle @mfe_prefixed_theme {
    rewrite * /theme/{http.regexp.mfe_theme.2}
    reverse_proxy mfe:8002 {
        header_up Host {http.request.host}
    }
}

reverse_proxy /profile/api/* lms:8000 {
    # Preserve incoming host for tenant-aware SiteConfiguration resolution
    header_up Host {http.request.host}
}

reverse_proxy /api/mfe_config/v1* lms:8000 {
    header_up Host {http.request.host}
}
""",
)

hooks.Filters.CLI_DO_INIT_TASKS.add_item(
    (
        "lms",
        """
# Ensure local/dev site rows converge to the Mereka theme during Tutor init.
./manage.py lms shell -c "
from django.contrib.sites.models import Site

domains = [
    '{{ LMS_HOST }}',
    '{{ LMS_HOST }}:8000',
    '{{ CMS_HOST }}',
    '{{ CMS_HOST }}:8001',
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
    '{{ host }}',
{% endfor %}
]

for domain in dict.fromkeys(domains):
    site, _ = Site.objects.get_or_create(domain=domain)
    theme = site.themes.order_by('id').first()
    if theme is None:
        site.themes.create(theme_dir_name='mereka')
    elif theme.theme_dir_name != 'mereka':
        theme.theme_dir_name = 'mereka'
        theme.save(update_fields=['theme_dir_name'])
"
""",
    ),
    priority=hooks.priorities.LOW,
)
