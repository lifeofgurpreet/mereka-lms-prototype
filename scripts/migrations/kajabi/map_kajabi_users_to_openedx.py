#!/usr/bin/env python3
"""Map Kajabi users, purchases, and completions to Open edX import format.

Merges four Kajabi export files:

1. ``exports/kajabi/contacts.ndjson``
   One record per contact: id, attributes.email, attributes.name,
   attributes.address_country.

2. ``exports/kajabi/customers.ndjson``
   One record per customer: id, attributes.sign_in_count,
   attributes.last_request_at.

3. ``exports/kajabi/purchases.ndjson``
   One record per purchase: relationships.customer.data.id,
   relationships.products.data[].id.

4. ``exports/kajabi/completions.ndjson``
   One record per completion tag: email, course_prefix, tag_name.

Outputs (written to ``exports/kajabi/openedx_import/``):

- ``users_import.csv``       username, email, name, country, gender,
                              year_of_birth, is_active, password, source
- ``user_profiles.json``     extended profile (kajabi_id, sign_in_count, …)
- ``enrollments_import.csv`` email, course_id, mode, is_active
- ``completions_import.csv`` email, course_id, completed, tag_name

MCT usernames are pre-loaded from ``exports/mct/openedx_import/users_import.csv``
(if it exists) to avoid username collisions between the two import sets.

Usage
-----
    python scripts/migrations/kajabi/map_kajabi_users_to_openedx.py

    python scripts/migrations/kajabi/map_kajabi_users_to_openedx.py --dry-run

    # Only (re)generate completions, skip users and enrollments
    python scripts/migrations/kajabi/map_kajabi_users_to_openedx.py --completions-only
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
EXPORTS_KAJABI = REPO_ROOT / "exports" / "kajabi"
EXPORTS_MCT = REPO_ROOT / "exports" / "mct"
OUTPUT_DIR = EXPORTS_KAJABI / "openedx_import"

# ---------------------------------------------------------------------------
# Kajabi course prefix → Open edX course key mapping
# "TIYJ" in completions data maps to "TYJ-EN" (different abbreviation)
# ---------------------------------------------------------------------------
PREFIX_TO_COURSE_KEY: dict[str, str] = {
    "PB":   "course-v1:MEREKA+PB-EN+course",
    "F101": "course-v1:MEREKA+F101-MS+course",
    "PF":   "course-v1:MEREKA+PF-ID+course",
    "PW":   "course-v1:MEREKA+PW-EN+course",
    "TIYJ": "course-v1:MEREKA+TYJ-EN+course",
    "SYFJ": "course-v1:MEREKA+SYFJ-ID+course",
    "SYFC": "course-v1:MEREKA+SYFC-MS+course",
    "MYFC": "course-v1:MEREKA+MYFC-MS+course",
    "SP":   "course-v1:MEREKA+SP-MS+course",
    # AI courses (elevate-ai-* use slug-style prefix in completions)
    "elevate-ai-1":   "course-v1:MEREKA+UPAI1-EN+course",
    "elevate-ai-2":   "course-v1:MEREKA+UPAI2-EN+course",
    "elevate-ai-3":   "course-v1:MEREKA+UPAI3-EN+course",
}

# Kajabi product id → Open edX course key
# Derived from products.ndjson titles; updated manually if new products appear.
PRODUCT_ID_TO_COURSE_KEY: dict[str, str] = {
    "2147807941": "course-v1:MEREKA+PB-EN+course",           # Personal Branding
    "2147807951": "course-v1:MEREKA+MYFC-MS+course",         # Managing Your First Client
    "2147933335": "course-v1:MEREKA+PF-ID+course",           # Personal Finance
    "2147934068": "course-v1:MEREKA+TYJ-EN+course",          # Thriving In Your Job
    "2147940642": "course-v1:MEREKA+SYFJ-ID+course",         # Securing Your First Job
    "2147950554": "course-v1:MEREKA+SP-MS+course",           # Skills Profiling
    "2147950555": "course-v1:MEREKA+F101-MS+course",         # Freelancing 101
    "2147809081": "course-v1:MEREKA+SYFC-MS+course",         # Securing Your First Client
    "2148169302": "course-v1:MEREKA+UPAI2-EN+course",        # Boosting Sales with ChatGPT
    "2148185632": "course-v1:MEREKA+UPAI3-EN+course",        # ChatGPT for Job Search
    "2148348806": "course-v1:MEREKA+UPAI1-EN+course",        # Getting Started with ChatGPT
    # Malay variants mapped to same course keys
    "2148256173": "course-v1:MEREKA+SP-MS+course",           # Profil Keterampilan (ID)
    "2148257968": "course-v1:MEREKA+PB-EN+course",           # Penjenamaan Diri (MY)
    "2148257973": "course-v1:MEREKA+SYFC-MS+course",         # Pikat Hati Klien (MY)
    "2148257982": "course-v1:MEREKA+SYFJ-ID+course",         # Dapatkan Pekerjaan (MY)
    "2148258205": "course-v1:MEREKA+MYFC-MS+course",         # Pengurusan Klien (MY)
    "2148258206": "course-v1:MEREKA+TYJ-EN+course",          # Wibawa dalam Kerjaya (MY)
    "2148258216": "course-v1:MEREKA+PF-ID+course",           # Pengurusan Kewangan (MY)
    "2148258261": "course-v1:MEREKA+F101-MS+course",         # Pekerja Lepas 101 (MY)
    "2148258263": "course-v1:MEREKA+SYFJ-ID+course",         # Dapatkan Pekerjaan Idaman (MY/ID)
    "2148836601": "course-v1:MEREKA+UPAI2-EN+course",        # Meningkatkan Jualan (MY)
}

# ---------------------------------------------------------------------------
# Username helpers (shared with MCT mapper)
# ---------------------------------------------------------------------------

def _sanitise_username(raw: str, max_len: int = 25) -> str:
    normalised = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode("ascii")
    cleaned = re.sub(r"[^a-zA-Z0-9._-]", "_", normalised).strip("_.-")
    return (cleaned or "user")[:max_len]


def _make_unique_username(base: str, taken: set[str]) -> str:
    candidate = base
    counter = 2
    while candidate.lower() in taken:
        suffix = str(counter)
        candidate = base[: max(1, 25 - len(suffix) - 1)] + "_" + suffix
        counter += 1
    return candidate


# ---------------------------------------------------------------------------
# Country normalisation
# ---------------------------------------------------------------------------
_COUNTRY_NAME_MAP: dict[str, str] = {
    "indonesia": "ID", "vietnam": "VN", "viet nam": "VN",
    "thailand": "TH", "cambodia": "KH", "malaysia": "MY",
    "china": "CN", "philippines": "PH", "singapore": "SG",
    "united states": "US", "usa": "US", "united kingdom": "GB",
    "australia": "AU", "india": "IN", "canada": "CA",
    "bangladesh": "BD", "myanmar": "MM", "nigeria": "NG",
}


def _normalise_country(raw: str) -> str:
    if not raw:
        return ""
    lower = raw.strip().lower()
    if lower in _COUNTRY_NAME_MAP:
        return _COUNTRY_NAME_MAP[lower]
    # If already 2-char code, normalise to upper
    if len(raw.strip()) == 2:
        return raw.strip().upper()
    return ""


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------

def _iter_ndjson(path: Path):
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


def _load_contacts() -> dict[str, dict]:
    """Return contact_id -> {email, name, country}."""
    path = EXPORTS_KAJABI / "contacts.ndjson"
    if not path.exists():
        print(f"ERROR: {path} not found", file=sys.stderr)
        sys.exit(1)
    by_id: dict[str, dict] = {}
    for rec in _iter_ndjson(path):
        cid = str(rec.get("id", ""))
        attrs = rec.get("attributes", {})
        email = (attrs.get("email") or "").strip().lower()
        if cid and email:
            by_id[cid] = {
                "email": email,
                "name": (attrs.get("name") or "").strip(),
                "country": _normalise_country((attrs.get("address_country") or "").strip()),
            }
    return by_id


def _load_customers() -> dict[str, dict]:
    """Return customer_id -> {sign_in_count, last_request_at}."""
    path = EXPORTS_KAJABI / "customers.ndjson"
    if not path.exists():
        return {}
    by_id: dict[str, dict] = {}
    for rec in _iter_ndjson(path):
        cid = str(rec.get("id", ""))
        attrs = rec.get("attributes", {})
        by_id[cid] = {
            "sign_in_count": attrs.get("sign_in_count", 0),
            "last_request_at": attrs.get("last_request_at", ""),
        }
    return by_id


def _load_purchases() -> list[dict]:
    """Return list of {customer_id, product_id}."""
    path = EXPORTS_KAJABI / "purchases.ndjson"
    if not path.exists():
        return []
    result = []
    for rec in _iter_ndjson(path):
        rels = rec.get("relationships", {})
        cust_id = (rels.get("customer", {}).get("data") or {}).get("id", "")
        products = rels.get("products", {}).get("data", [])
        for prod in products:
            prod_id = str(prod.get("id", ""))
            if cust_id and prod_id:
                result.append({"customer_id": str(cust_id), "product_id": prod_id})
    return result


def _load_completions() -> list[dict]:
    """Return list of {email, course_key, tag_name}."""
    path = EXPORTS_KAJABI / "completions.ndjson"
    if not path.exists():
        return []
    result = []
    for rec in _iter_ndjson(path):
        email = (rec.get("email") or "").strip().lower()
        prefix = (rec.get("course_prefix") or "").strip()
        tag = (rec.get("tag_name") or "").strip()
        course_key = PREFIX_TO_COURSE_KEY.get(prefix, "")
        if email and course_key:
            result.append({
                "email": email,
                "course_id": course_key,
                "completed": "true",
                "tag_name": tag,
            })
    return result


def _load_mct_usernames() -> set[str]:
    """Load already-taken usernames from MCT import to avoid collisions."""
    path = EXPORTS_MCT / "openedx_import" / "users_import.csv"
    if not path.exists():
        return set()
    taken: set[str] = set()
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            username = row.get("username", "").strip().lower()
            if username:
                taken.add(username)
    return taken


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------

def _write_csv(path: Path, fieldnames: list[str], rows: list[dict], dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would write {len(rows)} rows to {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  Wrote {len(rows)} rows → {path}")


def _write_json(path: Path, data: Any, dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would write {len(data)} records to {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print(f"  Wrote {len(data)} records → {path}")


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def run(completions_only: bool = False, dry_run: bool = False) -> None:
    """Build Open edX import files from Kajabi export data."""

    print("Loading Kajabi completions...")
    completions = _load_completions()
    print(f"  Loaded {len(completions)} completion records")

    if not completions_only:
        print("Loading Kajabi contacts...")
        contacts = _load_contacts()
        print(f"  Loaded {len(contacts)} contacts")

        print("Loading Kajabi customers...")
        customers = _load_customers()
        print(f"  Loaded {len(customers)} customer records")

        print("Loading Kajabi purchases...")
        purchases = _load_purchases()
        print(f"  Loaded {len(purchases)} purchase records")

        # Build customer_id -> email via contacts
        cust_to_email: dict[str, str] = {}
        for cid, info in contacts.items():
            cust_to_email[cid] = info["email"]

        print("Reserving MCT usernames...")
        taken_usernames = _load_mct_usernames()
        print(f"  Reserved {len(taken_usernames)} MCT usernames")

        # Build user records
        print("Building user records...")
        user_rows: list[dict] = []
        profile_records: list[dict] = []

        for cid, contact in contacts.items():
            email = contact["email"]
            name = contact["name"] or email.split("@")[0]
            country = contact["country"]

            cust_info = customers.get(cid, {})
            sign_in_count = cust_info.get("sign_in_count", 0)
            last_active = cust_info.get("last_request_at", "")

            # Username from email prefix
            base = _sanitise_username(email.split("@")[0])
            username = _make_unique_username(base, taken_usernames)
            taken_usernames.add(username.lower())

            user_rows.append({
                "username": username,
                "email": email,
                "name": name,
                "country": country,
                "gender": "",
                "year_of_birth": "",
                "is_active": "true",
                "password": "",
                "source": "kajabi",
            })

            profile_records.append({
                "email": email,
                "username": username,
                "meta": {
                    "kajabi_id": cid,
                    "kajabi_source": True,
                    "kajabi_sign_ins": sign_in_count,
                    "last_active": last_active,
                },
            })

        print(f"  Built {len(user_rows)} user records")

        print("Building enrollment records from purchases...")
        # Build contact email set for quick lookup
        all_emails = {info["email"] for info in contacts.values()}
        cust_enrollments: list[dict] = []
        seen_enrollments: set[tuple[str, str]] = set()

        for purchase in purchases:
            cust_id = purchase["customer_id"]
            product_id = purchase["product_id"]
            email = cust_to_email.get(cust_id, "")
            course_key = PRODUCT_ID_TO_COURSE_KEY.get(product_id, "")

            if not email or not course_key:
                continue
            dedup_key = (email, course_key)
            if dedup_key in seen_enrollments:
                continue
            seen_enrollments.add(dedup_key)
            cust_enrollments.append({
                "email": email,
                "course_id": course_key,
                "mode": "audit",
                "is_active": "true",
            })

        print(f"  Built {len(cust_enrollments)} enrollment records")

        print("Writing user files...")
        _write_csv(
            OUTPUT_DIR / "users_import.csv",
            ["username", "email", "name", "country", "gender", "year_of_birth", "is_active", "password", "source"],
            user_rows,
            dry_run,
        )
        _write_json(OUTPUT_DIR / "user_profiles.json", profile_records, dry_run)
        _write_csv(
            OUTPUT_DIR / "enrollments_import.csv",
            ["email", "course_id", "mode", "is_active"],
            cust_enrollments,
            dry_run,
        )

    print("Writing completions file...")
    _write_csv(
        OUTPUT_DIR / "completions_import.csv",
        ["email", "course_id", "completed", "tag_name"],
        completions,
        dry_run,
    )

    print("\nDone.")
    if not dry_run:
        print(f"Output directory: {OUTPUT_DIR}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Map Kajabi users, purchases, and completions to Open edX import format.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--completions-only",
        action="store_true",
        help="Regenerate only completions_import.csv (skip users and enrollments)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be generated without writing files",
    )
    args = parser.parse_args()

    run(completions_only=args.completions_only, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
