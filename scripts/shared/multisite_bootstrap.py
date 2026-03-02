#!/usr/bin/env python3
"""Bootstrap django.contrib.sites + SiteConfiguration entries for multi-tenant LMS domains."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import textwrap
from dataclasses import dataclass
from urllib.parse import urlparse

import pymysql

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_ENV_PATH = REPO_ROOT / "tutor_env" / "env" / "apps" / "openedx" / "config" / "lms.env.yml"
DEFAULT_DEFINITIONS_PATH = REPO_ROOT / "infrastructure" / "tutor" / "multisite-sites.yml"


@dataclass(frozen=True)
class SiteDefinition:
    domain: str
    name: str
    orgs: list[str]
    site_values: dict[str, object]


def _load_yaml(path: pathlib.Path) -> dict[str, object]:
    import yaml  # type: ignore
    payload = yaml.safe_load(path.read_text()) or {}
    assert isinstance(payload, dict)
    return payload

def hero_html(*, eyebrow: str, heading: str, body: str, primary_label: str, primary_href: str, secondary_label: str, secondary_href: str, accent: str, background: str) -> str:
    return textwrap.dedent(
        f"""
        <section class=\"site-hero\" style=\"background:{background};color:{accent};padding:3rem;border-radius:1.5rem;text-align:center;box-shadow:0 30px 80px rgba(15,23,42,.25);\">
          <p style=\"letter-spacing:.3em;text-transform:uppercase;font-weight:600;margin-bottom:1rem;color:{accent};\">{eyebrow}</p>
          <h1 style=\"margin-bottom:1rem;font-size:2.5rem;color:#fff;\">{heading}</h1>
          <p style=\"max-width:640px;margin:0 auto 2rem;color:#f4f4f5;\">{body}</p>
          <div style=\"display:flex;gap:1rem;justify-content:center;flex-wrap:wrap;\">
            <a href=\"{primary_href}\" style=\"background:{accent};color:#0f172a;padding:.85rem 1.75rem;border-radius:999px;font-weight:600;\">{primary_label}</a>
            <a href=\"{secondary_href}\" style=\"border:2px solid {accent};color:{accent};padding:.75rem 1.5rem;border-radius:999px;font-weight:600;\">{secondary_label}</a>
          </div>
        </section>
        """
    ).strip()


def load_definitions() -> tuple[list[dict[str, object]], list[SiteDefinition]]:
    path = pathlib.Path(os.environ.get("MULTISITE_DEFINITIONS_PATH") or DEFAULT_DEFINITIONS_PATH)
    payload = _load_yaml(path)
    orgs = payload.get("organizations") or []
    sites = payload.get("sites") or []
    definitions: list[SiteDefinition] = []
    for s in sites:
        if not isinstance(s, dict):
            continue
        domain = str(s.get("domain") or "").strip()
        if not domain:
            continue
        name = str(s.get("name") or domain).strip()
        org_list = s.get("orgs") or []
        if not isinstance(org_list, list):
            org_list = []
        site_values = s.get("site_values") or {}
        if not isinstance(site_values, dict):
            site_values = {}
        definitions.append(
            SiteDefinition(
                domain=domain,
                name=name,
                orgs=[str(o) for o in org_list],
                site_values=site_values,
            )
        )
    return list(orgs), definitions


ORGANIZATIONS, SITE_DEFINITIONS = load_definitions()


def load_db_settings(path: pathlib.Path) -> dict[str, object]:
    raw = path.read_text()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        import yaml  # type: ignore

        payload = yaml.safe_load(raw)
    db = payload["DATABASES"]["default"]
    return {
        "host": db["HOST"],
        "port": int(db.get("PORT") or 3306),
        "user": db["USER"],
        "password": db["PASSWORD"],
        "database": db["NAME"],
    }


def upsert_sites(connection, definitions: list[SiteDefinition], dry_run: bool) -> None:
    with connection.cursor() as cursor:
        for definition in definitions:
            if dry_run:
                print(f"[dry-run] Ensure django_site[{definition.domain}] => {definition.name}")
            else:
                cursor.execute(
                    """
                    INSERT INTO django_site (domain, name)
                    VALUES (%s, %s)
                    ON DUPLICATE KEY UPDATE name = VALUES(name)
                    """,
                    (definition.domain, definition.name),
                )
            if dry_run:
                continue
            cursor.execute(
                "SELECT id FROM django_site WHERE domain = %s",
                (definition.domain,),
            )
            site_id = cursor.fetchone()[0]
            rendered_values = dict(definition.site_values)
            rendered_values["course_org_filter"] = definition.orgs

            # Ensure MFEs don't drift back to the primary LMS domain by providing
            # per-site MFE_CONFIG overrides (merged by the MFE config API).
            lms_root = str(rendered_values.get("LMS_ROOT_URL") or "").rstrip("/")
            cms_root = str(rendered_values.get("CMS_ROOT_URL") or "").rstrip("/")
            mfe_base = str(rendered_values.get("MFE_BASE_URL") or "").rstrip("/")
            if lms_root:
                mfe_host = ""
                if mfe_base:
                    try:
                        parsed = urlparse(mfe_base)
                        mfe_host = parsed.netloc or ""
                    except Exception:
                        mfe_host = ""
                overrides: dict[str, object] = {
                    "LMS_BASE_URL": lms_root,
                    "LOGIN_URL": f"{lms_root}/login",
                    "LOGOUT_URL": f"{lms_root}/logout",
                    "MARKETING_SITE_BASE_URL": lms_root,
                    "REFRESH_ACCESS_TOKEN_ENDPOINT": f"{lms_root}/login_refresh",
                    "FAVICON_URL": f"{lms_root}/theming/asset/mereka/images/favicon.ico",
                    "LOGO_URL": f"{lms_root}/theming/asset/mereka/images/logo-horizontal.png",
                    "LOGO_WHITE_URL": f"{lms_root}/theming/asset/mereka/images/logo-horizontal-white.png",
                    "LOGO_TRADEMARK_URL": f"{lms_root}/theming/asset/mereka/images/logo.png",
                }
                if cms_root:
                    overrides["STUDIO_BASE_URL"] = cms_root
                if mfe_host:
                    overrides["BASE_URL"] = mfe_host
                    overrides["AUTHN_MICROFRONTEND_URL"] = f"https://{mfe_host}/authn"
                rendered_values["MFE_CONFIG"] = overrides

            site_values = json.dumps(rendered_values, sort_keys=True)
            cursor.execute(
                """
                INSERT INTO site_configuration_siteconfiguration (site_id, enabled, site_values)
                VALUES (%s, true, %s)
                ON DUPLICATE KEY UPDATE
                    enabled = VALUES(enabled),
                    site_values = VALUES(site_values)
                """,
                (site_id, site_values),
            )


def upsert_organizations(connection, dry_run: bool) -> None:
    with connection.cursor() as cursor:
        for record in ORGANIZATIONS:
            if dry_run:
                print(f"[dry-run] Ensure organization[{record['short_name']}]")
                continue
            cursor.execute(
                """
                INSERT INTO organizations_organization (short_name, name, description, active, created, modified)
                VALUES (%s, %s, %s, true, NOW(), NOW())
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    description = VALUES(description),
                    active = VALUES(active),
                    modified = VALUES(modified)
                """,
                (record["short_name"], record["name"], record["description"]),
            )


def connect_database(
    settings: dict[str, object],
    use_connector: bool,
    instance_connection_name: str | None,
    ip_type: str,
) -> tuple[object, object | None]:
    """
    Return a DB connection plus optional connector handle (when using Cloud SQL).
    """
    if use_connector:
        if not instance_connection_name:
            raise SystemExit("--instance is required when --use-connector is set.")
        from google.cloud.sql.connector import Connector, IPTypes  # type: ignore

        connector = Connector()
        ip_pref = IPTypes.PRIVATE if ip_type.upper() == "PRIVATE" else IPTypes.PUBLIC
        conn = connector.connect(
            instance_connection_name,
            "pymysql",
            user=settings["user"],
            password=settings["password"],
            db=settings["database"],
            ip_type=ip_pref,
        )
        return conn, connector

    conn = pymysql.connect(
        host=settings["host"],
        port=settings["port"],
        user=settings["user"],
        password=settings["password"],
        database=settings["database"],
        charset="utf8mb4",
        autocommit=False,
    )
    return conn, None


def close_connection(conn, connector=None) -> None:
    try:
        conn.close()
    finally:
        if connector is not None:
            connector.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--env",
        type=pathlib.Path,
        default=DEFAULT_ENV_PATH,
        help="Path to lms.env.yml (defaults to tutor_env/.../lms.env.yml).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Execute SQL updates. Without this flag the script only logs planned changes.",
    )
    parser.add_argument("--host", help="Override DB host when not using the Cloud SQL connector.")
    parser.add_argument("--port", type=int, help="Override DB port when not using the Cloud SQL connector.")
    parser.add_argument("--user", help="Override DB user.")
    parser.add_argument("--password", help="Override DB password.")
    parser.add_argument("--database", help="Override DB name.")
    parser.add_argument(
        "--use-connector",
        action="store_true",
        help="Use the Cloud SQL Python connector instead of direct TCP access.",
    )
    parser.add_argument(
        "--instance",
        help="Cloud SQL instance connection name (project:region:instance). Required with --use-connector.",
    )
    parser.add_argument(
        "--ip-type",
        choices=["PRIVATE", "PUBLIC"],
        default="PRIVATE",
        help="Which Cloud SQL IP type to request when using the connector.",
    )
    args = parser.parse_args()

    settings = load_db_settings(args.env)
    if args.host:
        settings["host"] = args.host
    if args.port:
        settings["port"] = args.port
    if args.user:
        settings["user"] = args.user
    if args.password:
        settings["password"] = args.password
    if args.database:
        settings["database"] = args.database

    if not args.apply:
        print("Planned DB target:", settings["host"], settings["database"])
        for org in ORGANIZATIONS:
            print(f"[dry-run] Would ensure organization {org['short_name']}")
        for site in SITE_DEFINITIONS:
            print(f"[dry-run] Would ensure site {site.domain} -> {site.name}")
            print(f"           course_org_filter={site.orgs}")
        return

    connection, connector = connect_database(settings, args.use_connector, args.instance, args.ip_type)
    try:
        upsert_organizations(connection, dry_run=False)
        upsert_sites(connection, SITE_DEFINITIONS, dry_run=False)
        connection.commit()
        print("Site + organization records updated.")
    finally:
        close_connection(connection, connector)


if __name__ == "__main__":
    main()
