#!/usr/bin/env python3
"""
post_import_taxonomy.py
-----------------------
Creates Mereka content taxonomies and tags all 36 imported courses.

Usage (run via kubectl exec into the LMS pod):

    # Step 1: copy the script into the pod
    LMS_POD=$(kubectl get pods -n mereka-lms-dev -o name \
        | grep "^pod/lms-" | grep -v worker | head -1 | sed 's|pod/||')
    kubectl cp scripts/migrations/post_import_taxonomy.py \
        mereka-lms-dev/${LMS_POD}:/tmp/post_import_taxonomy.py -c lms

    # Step 2: execute it
    kubectl exec -n mereka-lms-dev ${LMS_POD} -c lms -- bash -c \
        "cd /openedx/edx-platform && \
         python manage.py lms shell -c \"\$(cat /tmp/post_import_taxonomy.py)\""

Note: Django's `manage.py shell` does not accept a script via stdin redirect;
the kubectl cp + shell -c approach is required.

The script is fully idempotent:
  - Re-running will not create duplicate taxonomies or tags.
  - Tags on courses are replaced with the canonical mapping each run.

Taxonomies created:
  Subject        — Digital Literacy, Office Skills, AI & Technology, Career Development,
                   Entrepreneurship, Sustainability, Soft Skills, Financial Literacy,
                   Digital Marketing, Gaming
  Level          — beginner, intermediate, advanced, assessment
  Credential Type — completion, professional, assessment, none

All 36 courses receive tags from all three taxonomies.
The built-in Languages taxonomy is left to auto-populate from course settings.
"""

# ---------------------------------------------------------------------------
# Taxonomy definitions
# ---------------------------------------------------------------------------

TAXONOMIES = {
    "Subject": {
        "description": "Primary subject area of the course.",
        "allow_multiple": False,
        "tags": [
            "Digital Literacy",
            "Office Skills",
            "AI & Technology",
            "Career Development",
            "Entrepreneurship",
            "Sustainability",
            "Soft Skills",
            "Financial Literacy",
            "Digital Marketing",
            "Gaming",
        ],
    },
    "Level": {
        "description": "Difficulty / proficiency level of the course.",
        "allow_multiple": False,
        "tags": ["beginner", "intermediate", "advanced", "assessment"],
    },
    "Credential Type": {
        "description": "Type of credential earned on course completion.",
        "allow_multiple": False,
        "tags": ["completion", "professional", "assessment", "none"],
    },
}

# ---------------------------------------------------------------------------
# Course → tag mapping
# course_id : (subject, level, credential_type)
# ---------------------------------------------------------------------------

COURSE_TAGS = {
    # MCT courses
    "course-v1:MEREKA+MCT1-EN+course":   ("Soft Skills",          "beginner",     "completion"),
    "course-v1:MEREKA+MCT14-EN+course":  ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+MCT14-VI+course":  ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+MCT15-EN+course":  ("Digital Literacy",     "beginner",     "completion"),
    "course-v1:MEREKA+MCT16-EN+course":  ("Office Skills",        "beginner",     "completion"),
    "course-v1:MEREKA+MCT16-VI+course":  ("Office Skills",        "beginner",     "completion"),
    "course-v1:MEREKA+MCT17-EN+course":  ("Career Development",   "intermediate", "completion"),
    "course-v1:MEREKA+MCT19-EN+course":  ("Career Development",   "intermediate", "completion"),
    "course-v1:MEREKA+MCT20-EN+course":  ("Career Development",   "intermediate", "completion"),
    "course-v1:MEREKA+MCT21-ID+course":  ("Digital Marketing",    "beginner",     "completion"),
    "course-v1:MEREKA+MCT22-EN+course":  ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+MCT22-ID+course":  ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+MCT24-EN+course":  ("AI & Technology",      "beginner",     "completion"),
    "course-v1:MEREKA+MCT24-VI+course":  ("AI & Technology",      "beginner",     "completion"),
    "course-v1:MEREKA+MCT24-ZH+course":  ("AI & Technology",      "beginner",     "completion"),
    "course-v1:MEREKA+MCT27-EN+course":  ("Digital Literacy",     "beginner",     "completion"),
    "course-v1:MEREKA+MCT28-VI+course":  ("Digital Literacy",     "beginner",     "completion"),
    "course-v1:MEREKA+MCT30-EN+course":  ("Sustainability",       "beginner",     "completion"),
    "course-v1:MEREKA+MCT31-EN+course":  ("Sustainability",       "beginner",     "completion"),
    "course-v1:MEREKA+MCT33-ID+course":  ("Soft Skills",          "beginner",     "completion"),
    "course-v1:MEREKA+MCT34-EN+course":  ("Soft Skills",          "beginner",     "completion"),
    "course-v1:MEREKA+MCT4-EN+course":   ("Office Skills",        "beginner",     "completion"),
    "course-v1:MEREKA+MCT4-ID+course":   ("Office Skills",        "beginner",     "completion"),
    "course-v1:MEREKA+MCT44-EN+course":  ("Digital Marketing",    "beginner",     "completion"),
    "course-v1:MEREKA+MCT45-EN+course":  ("Entrepreneurship",     "beginner",     "completion"),
    "course-v1:MEREKA+MCT46-EN+course":  ("Soft Skills",          "beginner",     "completion"),
    "course-v1:MEREKA+MCT47-ID+course":  ("Gaming",               "beginner",     "completion"),
    # FOW courses
    "course-v1:MEREKA+PW-EN+course":     ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+TYJ-EN+course":    ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+PF-ID+course":     ("Financial Literacy",   "beginner",     "completion"),
    "course-v1:MEREKA+SYFJ-ID+course":   ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+F101-MS+course":   ("Entrepreneurship",     "beginner",     "completion"),
    "course-v1:MEREKA+MYFC-MS+course":   ("Entrepreneurship",     "beginner",     "completion"),
    "course-v1:MEREKA+SP-MS+course":     ("Career Development",   "beginner",     "completion"),
    "course-v1:MEREKA+SYFC-MS+course":   ("Entrepreneurship",     "beginner",     "completion"),
    # UPAI
    "course-v1:MEREKA+UPAI2-EN+course":  ("AI & Technology",      "beginner",     "completion"),
}

# Map taxonomy name → index into the (subject, level, credential_type) tuple
TAXONOMY_INDEX = {
    "Subject": 0,
    "Level": 1,
    "Credential Type": 2,
}

# ---------------------------------------------------------------------------
# Implementation
# ---------------------------------------------------------------------------

import sys
import logging

logging.disable(logging.CRITICAL)  # suppress Django noise during interactive use

from openedx.core.djangoapps.content_tagging import api as tagging_api
from openedx_tagging.core.tagging.models import Taxonomy, Tag
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

SEPARATOR = "=" * 70


def _get_or_create_taxonomy(name, definition):
    """Return the existing taxonomy with this name, or create it fresh."""
    existing = Taxonomy.objects.filter(name=name).first()
    if existing:
        print(f"  [exists]  '{name}' (id={existing.id})")
        return existing

    taxonomy = tagging_api.create_taxonomy(
        name=name,
        description=definition["description"],
        enabled=True,
        allow_multiple=definition["allow_multiple"],
        allow_free_text=False,
    )
    # Assign to all orgs so that courses in any org can be tagged.
    tagging_api.set_taxonomy_orgs(taxonomy, all_orgs=True)
    print(f"  [created] '{name}' (id={taxonomy.id})")
    return taxonomy


def _ensure_tags(taxonomy, tag_values):
    """Add any missing tags to the taxonomy. Skip existing ones."""
    existing = {t.value for t in Tag.objects.filter(taxonomy=taxonomy)}
    added = []
    for value in tag_values:
        if value not in existing:
            tagging_api.add_tag_to_taxonomy(taxonomy, value)
            added.append(value)
    if added:
        print(f"    Added tags: {added}")
    else:
        print(f"    All {len(tag_values)} tags already present.")


def _ensure_org_assignment(taxonomy):
    """Ensure taxonomy is assigned to all orgs (idempotent)."""
    from openedx.core.djangoapps.content_tagging.models import TaxonomyOrg
    is_all_org, _ = TaxonomyOrg.get_organizations(taxonomy)
    if not is_all_org:
        tagging_api.set_taxonomy_orgs(taxonomy, all_orgs=True)
        print(f"    Re-assigned '{taxonomy.name}' to all orgs.")


def setup_taxonomies():
    """Step 1: Ensure all three custom taxonomies and their tags exist."""
    print(SEPARATOR)
    print("STEP 1: Setting up taxonomies")
    print(SEPARATOR)
    result = {}
    for name, defn in TAXONOMIES.items():
        tax = _get_or_create_taxonomy(name, defn)
        _ensure_org_assignment(tax)
        _ensure_tags(tax, defn["tags"])
        result[name] = tax
    return result


def tag_all_courses(taxonomies):
    """Step 2: Apply tags to every course in COURSE_TAGS."""
    print()
    print(SEPARATOR)
    print("STEP 2: Tagging courses")
    print(SEPARATOR)

    # Verify all courses exist
    all_course_ids = {str(c.id) for c in CourseOverview.objects.all()}
    missing = [cid for cid in COURSE_TAGS if cid not in all_course_ids]
    if missing:
        print(f"WARNING: {len(missing)} course(s) not found in CourseOverview — skipping:")
        for cid in missing:
            print(f"  {cid}")

    tagged_count = 0
    for course_id, tag_tuple in COURSE_TAGS.items():
        if course_id not in all_course_ids:
            continue
        for tax_name, tax_obj in taxonomies.items():
            tag_value = tag_tuple[TAXONOMY_INDEX[tax_name]]
            tagging_api.tag_object(
                object_id=course_id,
                taxonomy=tax_obj,
                tags=[tag_value],
            )
        tagged_count += 1

    print(f"Tagged {tagged_count}/{len(COURSE_TAGS)} courses across {len(taxonomies)} taxonomies.")


def verify_tagging(taxonomies):
    """Step 3: Spot-check that tags were stored for a sample of courses."""
    print()
    print(SEPARATOR)
    print("STEP 3: Verification")
    print(SEPARATOR)

    sample_ids = [
        "course-v1:MEREKA+MCT1-EN+course",
        "course-v1:MEREKA+MCT24-EN+course",
        "course-v1:MEREKA+F101-MS+course",
        "course-v1:MEREKA+UPAI2-EN+course",
        "course-v1:MEREKA+PF-ID+course",
        "course-v1:MEREKA+MCT47-ID+course",
    ]

    all_ok = True
    for course_id in sample_ids:
        object_tags = list(tagging_api.get_object_tags(course_id))
        tag_map = {ot.taxonomy.name: ot._value for ot in object_tags}
        expected = COURSE_TAGS.get(course_id)
        if not expected:
            continue
        exp_subject, exp_level, exp_cred = expected
        checks = [
            tag_map.get("Subject") == exp_subject,
            tag_map.get("Level") == exp_level,
            tag_map.get("Credential Type") == exp_cred,
        ]
        status = "PASS" if all(checks) else "FAIL"
        if not all(checks):
            all_ok = False
        short_id = course_id.split("+")[1]
        print(f"  [{status}] {short_id:<15} "
              f"Subject={tag_map.get('Subject')!r:20} "
              f"Level={tag_map.get('Level')!r:14} "
              f"Cred={tag_map.get('Credential Type')!r}")

    # Full count
    print()
    from openedx_tagging.core.tagging.models import ObjectTag
    total_ot = ObjectTag.objects.filter(
        taxonomy__in=taxonomies.values()
    ).count()
    expected_total = len([c for c in COURSE_TAGS if c in {
        str(x.id) for x in CourseOverview.objects.all()
    }]) * len(taxonomies)
    count_status = "PASS" if total_ot == expected_total else "WARN"
    print(f"  [{count_status}] ObjectTag count: {total_ot} (expected {expected_total})")
    return all_ok


def print_summary(taxonomies):
    """Print a final summary table."""
    print()
    print(SEPARATOR)
    print("SUMMARY")
    print(SEPARATOR)
    for name, tax in taxonomies.items():
        tag_count = Tag.objects.filter(taxonomy=tax).count()
        from openedx_tagging.core.tagging.models import ObjectTag
        obj_count = ObjectTag.objects.filter(taxonomy=tax).count()
        print(f"  {name:<20} id={tax.id:<4} tags={tag_count:<5} object_tags={obj_count}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

print()
print(SEPARATOR)
print("Mereka LMS — Content Taxonomy Setup")
print(SEPARATOR)

taxonomies = setup_taxonomies()
tag_all_courses(taxonomies)
ok = verify_tagging(taxonomies)
print_summary(taxonomies)

print()
if ok:
    print("SUCCESS: All spot-checks passed.")
else:
    print("WARNING: Some spot-checks failed — review FAIL lines above.")
print()
