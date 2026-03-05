"""Infrastructure patches — MySQL auth, Caddy multi-site, Nginx config."""

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

# Add extra LMS host blocks to Caddyfile
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

# MFE proxy: Forward selected MFE API paths to LMS for correct host context
{{ MFE_HOST }}{$default_site_port} {
    import security_headers

    reverse_proxy /profile/api/* lms:8000 {
        # Preserve incoming host for tenant-aware SiteConfiguration resolution
        header_up Host {http.request.host}
    }

    reverse_proxy /api/mfe_config/v1* lms:8000 {
        header_up Host {http.request.host}
    }
}
""",
)

###############################################################################
# Nginx Configuration Patches
###############################################################################

_register_env_patch(
    "nginx-lms-config",
    """
# Additional server names for multi-site support
{% for host in MEREKA_LMS_EXTRA_HOSTS %}
{{ host }}{% if not loop.last %} {% endif %}
{% endfor %}

# Health check endpoint
location = /health {
    default_type text/plain;
    return 200 "ok\\n";
}

# Prometheus metrics endpoint (internal access only)
location = /metrics {
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://lms-backend;
}

# MFE profile API proxy
location ^~ /profile/api/ {
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://lms-backend;
}
""",
)
