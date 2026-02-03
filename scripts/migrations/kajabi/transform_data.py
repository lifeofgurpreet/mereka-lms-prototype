#!/usr/bin/env python3
"""
Transform Kajabi export files (NDJSON) into Open edX-friendly CSV/JSON outputs.

Usage:
  python scripts/migrations/kajabi/scripts/transform_data.py \
      --exports-dir exports/kajabi \
      --structure-dir exports/kajabi/structure \
      --output-dir scripts/migrations/kajabi/output
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional


def read_ndjson(path: Path) -> Iterator[dict]:
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def write_csv(rows: Iterable[dict], fieldnames: List[str], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def safe_get(data: dict, *keys, default=None):
    cur = data
    for key in keys:
        if cur is None:
            return default
        cur = cur.get(key)
    return cur if cur is not None else default


def normalize_username(email: Optional[str], fallback: str) -> str:
    if email:
        base = email.split("@")[0][:30]
        return base or fallback
    return fallback


def build_user_rows(contacts: Path, customers: Path) -> List[dict]:
    contact_records: Dict[str, dict] = {}
    customer_records: Dict[str, dict] = {}
    customer_to_contact: Dict[str, str] = {}

    for rec in read_ndjson(customers):
        customer_records[rec["id"]] = rec
        contact_rel = safe_get(rec, "relationships", "contact", "data", default={})
        if contact_rel:
            customer_to_contact[rec["id"]] = contact_rel.get("id")

    users: List[dict] = []
    seen_contacts: set = set()

    for rec in read_ndjson(contacts):
        contact_id = rec["id"]
        seen_contacts.add(contact_id)
        attrs = rec.get("attributes", {})
        contact_records[contact_id] = rec
        customer_rel = safe_get(rec, "relationships", "customer", "data", default={})
        customer_id = customer_rel.get("id") if customer_rel else None
        if customer_id:
            customer_to_contact.setdefault(customer_id, contact_id)
        customer_attrs = customer_records.get(customer_id, {}).get("attributes", {})
        email = attrs.get("email") or customer_attrs.get("email")
        row = {
            "username": normalize_username(email, f"contact_{contact_id}"),
            "email": email or "",
            "full_name": attrs.get("name") or customer_attrs.get("name") or "",
            "phone": attrs.get("phone_number") or "",
            "country": attrs.get("custom_19") or "",
            "subscribed": attrs.get("subscribed", False),
            "kajabi_contact_id": contact_id,
            "kajabi_customer_id": customer_id or "",
            "sign_in_count": customer_attrs.get("sign_in_count") or 0,
            "last_login_at": customer_attrs.get("last_request_at") or "",
            "contact_created_at": attrs.get("created_at") or "",
            "customer_created_at": customer_attrs.get("created_at") or "",
        }
        users.append(row)

    # Customers without a matching contact
    for customer_id, rec in customer_records.items():
        contact_id = customer_to_contact.get(customer_id)
        if contact_id and contact_id in seen_contacts:
            continue
        attrs = rec.get("attributes", {})
        email = attrs.get("email")
        row = {
            "username": normalize_username(email, f"customer_{customer_id}"),
            "email": email or "",
            "full_name": attrs.get("name") or "",
            "phone": "",
            "country": "",
            "subscribed": "",
            "kajabi_contact_id": contact_id or "",
            "kajabi_customer_id": customer_id,
            "sign_in_count": attrs.get("sign_in_count") or 0,
            "last_login_at": attrs.get("last_request_at") or "",
            "contact_created_at": "",
            "customer_created_at": attrs.get("created_at") or "",
        }
        users.append(row)

    return users


def build_offer_product_map(offers_file: Path) -> Dict[str, List[str]]:
    mapping: Dict[str, List[str]] = defaultdict(list)
    for rec in read_ndjson(offers_file):
        offer_id = rec["id"]
        products = safe_get(rec, "relationships", "products", "data", default=[])
        if products:
            mapping[offer_id].extend(p["id"] for p in products)
    return mapping


def build_customer_contact_map(customers_file: Path) -> Dict[str, str]:
    mapping: Dict[str, str] = {}
    for rec in read_ndjson(customers_file):
        customer_id = rec["id"]
        contact_rel = safe_get(rec, "relationships", "contact", "data", default={})
        if contact_rel:
            mapping[customer_id] = contact_rel.get("id")
    return mapping


def load_courses(courses_file: Path) -> Dict[str, dict]:
    return {rec["id"]: rec for rec in read_ndjson(courses_file)}


def load_products(products_file: Path) -> Dict[str, dict]:
    return {rec["id"]: rec for rec in read_ndjson(products_file)}


def build_enrollment_rows(
    purchases_file: Path,
    offers_file: Path,
    customers_file: Path,
    courses_file: Path,
    products_file: Path,
) -> List[dict]:
    offers_map = {rec["id"]: rec for rec in read_ndjson(offers_file)}
    offer_to_products = build_offer_product_map(offers_file)
    customer_to_contact = build_customer_contact_map(customers_file)
    courses = load_courses(courses_file)
    products = load_products(products_file)

    rows: List[dict] = []

    for rec in read_ndjson(purchases_file):
        attrs = rec.get("attributes", {})
        rel = rec.get("relationships", {})
        customer_id = safe_get(rel, "customer", "data", "id", default="")
        contact_id = customer_to_contact.get(customer_id, "")
        offer_id = safe_get(rel, "offer", "data", "id", default="")
        offer_attr = offers_map.get(offer_id, {}).get("attributes", {})
        product_ids = [p["id"] for p in safe_get(rel, "products", "data", default=[])]
        if not product_ids and offer_id in offer_to_products:
            product_ids = offer_to_products[offer_id]
        if not product_ids:
            product_ids = [""]
        for product_id in product_ids:
            course_id = product_id if product_id in courses else ""
            course_title = (
                safe_get(courses.get(course_id, {}), "attributes", "title", default="")
            )
            row = {
                "kajabi_purchase_id": rec["id"],
                "customer_id": customer_id,
                "contact_id": contact_id,
                "offer_id": offer_id,
                "offer_title": offer_attr.get("title", ""),
                "product_id": product_id,
                "course_id": course_id,
                "course_title": course_title,
                "enrolled_at": attrs.get("created_at") or "",
                "currency": attrs.get("currency") or "",
                "amount_in_cents": attrs.get("amount_in_cents") or 0,
                "is_active": attrs.get("deactivated_at") is None,
                "deactivated_at": attrs.get("deactivated_at") or "",
                "deactivation_reason": attrs.get("deactivation_reason") or "",
            }
            rows.append(row)
    return rows


def build_course_summary(
    courses_file: Path,
    modules_file: Path,
    lessons_file: Path,
    lesson_media_file: Path,
    lesson_details_file: Path | None = None,
) -> (List[dict], List[dict]):
    courses = load_courses(courses_file)
    course_modules: Dict[str, List[dict]] = defaultdict(list)
    module_lessons: Dict[str, List[dict]] = defaultdict(list)
    lesson_media_rel: Dict[str, str] = {}
    media_detail: Dict[str, dict] = {}
    lesson_details: Dict[str, dict] = {}

    for rec in read_ndjson(modules_file):
        module = rec.get("module", {})
        course_id = rec.get("course_id")
        if course_id:
            course_modules[course_id].append(module)

    for rec in read_ndjson(lessons_file):
        lesson = rec.get("lesson", {})
        course_id = rec.get("course_id")
        module_id = safe_get(lesson, "relationships", "module", "data", "id", default="")
        media_rel = safe_get(lesson, "relationships", "media", "data", default={})
        if media_rel:
            lesson_media_rel[lesson.get("id")] = media_rel.get("id")
        module_lessons[module_id].append({"course_id": course_id, "lesson": lesson})

    if lesson_media_file.exists():
        for rec in read_ndjson(lesson_media_file):
            media = rec.get("media", {})
            media_detail[media.get("id")] = media

    # Load lesson details if available
    if lesson_details_file and lesson_details_file.exists():
        for rec in read_ndjson(lesson_details_file):
            lesson_id = rec.get("lesson_id")
            detail = rec.get("detail", {})
            if lesson_id and detail:
                # Store both the lesson data and included resources
                lesson_details[lesson_id] = {
                    "attributes": detail.get("attributes", {}),
                    "included": rec.get("included", []),
                }

    course_structures: List[dict] = []
    summary_rows: List[dict] = []

    for course_id, course_rec in courses.items():
        modules = []
        module_list = sorted(
            course_modules.get(course_id, []),
            key=lambda m: safe_get(m, "attributes", "position", default=0),
        )
        lesson_count = 0
        lesson_with_media = 0
        for module in module_list:
            module_id = module.get("id")
            lessons = []
            lesson_list = sorted(
                module_lessons.get(module_id, []),
                key=lambda item: safe_get(item["lesson"], "attributes", "position", default=0),
            )
            for item in lesson_list:
                lesson = item["lesson"]
                lesson_id = lesson.get("id")
                lesson_entry = {
                    "id": lesson_id,
                    "title": safe_get(lesson, "attributes", "title", default=""),
                    "position": safe_get(lesson, "attributes", "position", default=0),
                    "status": safe_get(lesson, "attributes", "status", default=""),
                    "publishing_option": safe_get(
                        lesson, "attributes", "publishing_option", default=""
                    ),
                }
                
                # Merge in lesson details if available
                if lesson_id in lesson_details:
                    detail_attrs = lesson_details[lesson_id].get("attributes", {})
                    # Add content fields from detail fetch
                    if detail_attrs.get("body"):
                        lesson_entry["body"] = detail_attrs["body"]
                    if detail_attrs.get("content_html"):
                        lesson_entry["content_html"] = detail_attrs["content_html"]
                    if detail_attrs.get("video_url"):
                        lesson_entry["video_url"] = detail_attrs["video_url"]
                    if detail_attrs.get("download_url"):
                        lesson_entry["download_url"] = detail_attrs["download_url"]
                    # Store included resources (media, downloads, etc.)
                    included = lesson_details[lesson_id].get("included", [])
                    if included:
                        lesson_entry["included_resources"] = included
                
                media_id = lesson_media_rel.get(lesson_id)
                if media_id:
                    lesson_entry["media_id"] = media_id
                    if media_id in media_detail:
                        lesson_entry["media"] = media_detail[media_id].get("attributes", {})
                    lesson_with_media += 1
                lessons.append(lesson_entry)
                lesson_count += 1
            module_entry = {
                "id": module_id,
                "title": safe_get(module, "attributes", "title", default=""),
                "position": safe_get(module, "attributes", "position", default=0),
                "lessons": lessons,
            }
            modules.append(module_entry)
        course_structures.append(
            {
                "course_id": course_id,
                "title": safe_get(course_rec, "attributes", "title", default=""),
                "modules": modules,
            }
        )
        summary_rows.append(
            {
                "course_id": course_id,
                "course_title": safe_get(course_rec, "attributes", "title", default=""),
                "module_count": len(modules),
                "lesson_count": lesson_count,
                "lessons_with_media": lesson_with_media,
            }
        )
    return course_structures, summary_rows


def main():
    parser = argparse.ArgumentParser(description="Kajabi → Open edX transformer")
    parser.add_argument("--exports-dir", required=True, help="Path to Kajabi export directory")
    parser.add_argument(
        "--structure-dir",
        default=None,
        help="Path to structure files (modules/lessons/lesson_media)",
    )
    parser.add_argument("--output-dir", required=True, help="Where transformed files will be written")
    parser.add_argument(
        "--lesson-details-file",
        default=None,
        help="Optional path to lesson_details.ndjson (from scrape_lessons.py)",
    )
    args = parser.parse_args()

    exports_dir = Path(args.exports_dir)
    structure_dir = Path(args.structure_dir or exports_dir / "structure")
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Loading users…")
    users = build_user_rows(
        exports_dir / "contacts.ndjson",
        exports_dir / "customers.ndjson",
    )
    write_csv(
        users,
        [
            "username",
            "email",
            "full_name",
            "phone",
            "country",
            "subscribed",
            "kajabi_contact_id",
            "kajabi_customer_id",
            "sign_in_count",
            "last_login_at",
            "contact_created_at",
            "customer_created_at",
        ],
        output_dir / "users.csv",
    )

    print("Building enrollments…")
    enrollments = build_enrollment_rows(
        exports_dir / "purchases.ndjson",
        exports_dir / "offers.ndjson",
        exports_dir / "customers.ndjson",
        exports_dir / "courses_index.ndjson",
        exports_dir / "products.ndjson",
    )
    write_csv(
        enrollments,
        [
            "kajabi_purchase_id",
            "customer_id",
            "contact_id",
            "offer_id",
            "offer_title",
            "product_id",
            "course_id",
            "course_title",
            "enrolled_at",
            "currency",
            "amount_in_cents",
            "is_active",
            "deactivated_at",
            "deactivation_reason",
        ],
        output_dir / "enrollments.csv",
    )

    print("Summarizing courses…")
    courses = load_courses(exports_dir / "courses_index.ndjson")
    course_rows = []
    for course_id, rec in courses.items():
        attrs = rec.get("attributes", {})
        course_rows.append(
            {
                "course_id": course_id,
                "title": attrs.get("title", ""),
                "description": attrs.get("description", ""),
                "status": attrs.get("status", ""),
                "created_at": attrs.get("created_at", ""),
            }
        )
    write_csv(
        course_rows,
        ["course_id", "title", "description", "status", "created_at"],
        output_dir / "courses.csv",
    )

    if structure_dir.exists():
        print("Aggregating course structures…")
        if args.lesson_details_file:
            lesson_details_path = Path(args.lesson_details_file)
        else:
            lesson_details_path = structure_dir / "lesson_details.ndjson"
        course_structures, summary_rows = build_course_summary(
            exports_dir / "courses_index.ndjson",
            structure_dir / "modules.ndjson",
            structure_dir / "lessons.ndjson",
            structure_dir / "lesson_media.ndjson",
            lesson_details_path if lesson_details_path.exists() else None,
        )
        (output_dir / "course_structure.json").write_text(
            json.dumps(course_structures, indent=2),
            encoding="utf-8",
        )
        write_csv(
            summary_rows,
            ["course_id", "course_title", "module_count", "lesson_count", "lessons_with_media"],
            output_dir / "course_summary.csv",
        )
    else:
        print("Structure directory not found; skipping course structure export.")

    print(f"Done. Files written to {output_dir}")


if __name__ == "__main__":
    main()
