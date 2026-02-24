#!/usr/bin/env bash
# Patch: Extra domain names for multi-site support.
# Adds academy.biji-biji.com and skillourfuture hosts to ALLOWED_HOSTS,
# nginx server_name, and Caddy LMS proxy blocks.

apply_domain_names_patch() {
  local targets=(
    "$LMS_SETTINGS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
    "$NGINX_LMS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/nginx/lms.conf"
    "$CADDY_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import re
import sys

targets = sys.argv[1:]

extra_lms_hosts = [
    "academy.biji-biji.com",
    "skillourfuture.academy.mereka.io",
]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    def ensure_allowed_hosts(text):
        marker = "ALLOWED_HOSTS = ["
        if marker not in text:
            return text
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            if line.strip().startswith(marker):
                end_idx = idx
                while end_idx < len(lines):
                    if lines[end_idx].strip().endswith("]"):
                        break
                    end_idx += 1
                indent = line[: len(line) - len(line.lstrip())] + "    "
                existing = set()
                for entry_line in lines[idx + 1 : end_idx]:
                    stripped = entry_line.strip().rstrip(",")
                    if stripped.startswith(("'", '"')):
                        existing.add(stripped.strip('"\''))
                inserts = []
                for host in extra_lms_hosts:
                    if host not in existing:
                        inserts.append(f'{indent}"{host}",')
                if inserts:
                    lines = lines[:end_idx] + inserts + lines[end_idx:]
                return "\n".join(lines)
        return text

    if path.name == "production.py":
        updated = ensure_allowed_hosts(updated)

    if path.name == "lms.conf":
        anchor = "  server_name academyv2.mereka.io preview.academyv2.mereka.io;"
        if anchor in updated and "academy.biji-biji.com" not in updated:
            updated = updated.replace(
                anchor,
                anchor.rstrip(";")
                + " academy.biji-biji.com skillourfuture.academy.mereka.io;",
            )

    if path.name == "Caddyfile":
        lms_caddy_block_template = """__DOMAIN__{$default_site_port} {
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

"""
        for host in extra_lms_hosts:
            if host not in updated:
                updated = updated.rstrip() + "\n\n" + lms_caddy_block_template.replace("__DOMAIN__", host)

    if updated != original:
        path.write_text(updated)
PY
}
