#!/usr/bin/env python3
"""
Transform MCT export files (NDJSON) into Open edX-friendly CSV/JSON outputs.

Usage:
  python scripts/migrations/mct/scripts/transform_data.py \
      --exports-dir exports/mct \
      --structure-dir exports/mct/structure \
      --output-dir scripts/migrations/mct/output
"""

from __future__ import annotations

import argparse
import csv
import json
import re
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
        if isinstance(cur, dict):
            cur = cur.get(key)
        else:
            return default
    return cur if cur is not None else default


def normalize_username(email: Optional[str], fallback: str) -> str:
    if email:
        base = email.split("@")[0][:30]
        # Remove special chars, keep alphanumeric and underscore
        base = re.sub(r"[^a-z0-9_]", "_", base.lower())
        return base or fallback
    return fallback


def slugify(value: str, fallback: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:50] or fallback


def build_user_rows(users_file: Path) -> List[dict]:
    users: List[dict] = []
    seen_emails: set = set()
    
    for rec in read_ndjson(users_file):
        email = rec.get("Contact", "").strip().lower()
        if not email or email in seen_emails:
            continue
        seen_emails.add(email)
        
        first_name = rec.get("First Name", "").strip()
        last_name = rec.get("Last Name", "").strip()
        full_name = f"{first_name} {last_name}".strip()
        
        # Extract learning pathways from "My groups"
        groups = rec.get("My groups", "").strip()
        
        row = {
            "username": normalize_username(email, f"user_{len(users)}"),
            "email": email,
            "full_name": full_name,
            "first_name": first_name,
            "last_name": last_name,
            "country": rec.get("Which Country are you from?", "").strip(),
            "gender": rec.get("Gender", "").strip(),
            "dob": rec.get("When were you born?", "").strip(),
            "learning_pathways": groups,
            "mct_user_id": email,  # Use email as ID since no explicit user ID
        }
        users.append(row)
    
    return users


def extract_courses_from_categories(categories_file: Path) -> List[dict]:
    """Extract individual courses from category structure."""
    courses: List[dict] = []
    seen_course_ids: set = set()
    
    for rec in read_ndjson(categories_file):
        category_id = rec.get("CategoryId")
        category_name = (rec.get("CategoryName") or "").strip()
        category_desc = (rec.get("CategoryDescription") or "").strip()
        
        for course in rec.get("Courses", []):
            course_id = course.get("ParentCourseId") or course.get("CourseId")
            if not course_id or course_id in seen_course_ids:
                continue
            seen_course_ids.add(course_id)
            
            course_name = (course.get("CourseName") or "").strip()
            course_desc = (course.get("CourseDescription") or "").strip()
            
            courses.append({
                "course_id": str(course_id),
                "course_name": course_name,
                "course_description": course_desc,
                "category_id": str(category_id) if category_id else "",
                "category_name": category_name,
                "content_language": course.get("ContentLanguage", "en"),
                "course_item_count": course.get("CourseItemCount", 0),
                "completion_percentage": course.get("CompletionPercentage", 0),
            })
    
    return courses


def build_enrollment_rows(users_file: Path, courses: List[dict]) -> List[dict]:
    """Build enrollments from user learning pathways/groups."""
    enrollments: List[dict] = []
    course_by_id = {c["course_id"]: c for c in courses}
    
    # Map learning pathways to course IDs (this is approximate - may need refinement)
    pathway_to_courses: Dict[str, List[str]] = defaultdict(list)
    
    # For now, create enrollments based on user groups
    # This is a simplified approach - may need course-specific enrollment data
    for rec in read_ndjson(users_file):
        email = rec.get("Contact", "").strip().lower()
        if not email:
            continue
        
        groups = rec.get("My groups", "").strip()
        if not groups:
            continue
        
        # Extract pathway names (e.g., "Developer | Id" -> "Developer")
        pathways = [g.split("|")[0].strip() for g in groups.split(";") if g.strip()]
        
        # For each pathway, try to find matching courses
        # This is a heuristic - may need manual mapping
        for pathway in pathways:
            # Try to match courses by name/keywords
            for course_id, course in course_by_id.items():
                course_name_lower = course["course_name"].lower()
                pathway_lower = pathway.lower()
                
                # Simple keyword matching (can be improved)
                if pathway_lower in course_name_lower or any(
                    keyword in course_name_lower
                    for keyword in ["developer", "data", "analyst", "digital", "marketer", "project", "management"]
                    if keyword in pathway_lower
                ):
                    enrollments.append({
                        "email": email,
                        "course_id": course_id,
                        "enrollment_source": "learning_pathway",
                        "pathway": pathway,
                    })
    
    return enrollments


def build_course_structure(
    courses_file: Path,
    content_file: Path,
    metadata_file: Path,
) -> List[dict]:
    """Build nested course structure with modules and lessons."""
    course_content: Dict[int, dict] = {}
    course_metadata: Dict[int, dict] = {}
    
    # Load course content
    for rec in read_ndjson(content_file):
        course_id = rec.get("courseId")
        if course_id:
            course_content[course_id] = rec
    
    # Load course metadata
    for rec in read_ndjson(metadata_file):
        course_id = rec.get("courseId")
        if course_id:
            course_metadata[course_id] = rec
    
    # Extract courses from categories
    courses = extract_courses_from_categories(courses_file)
    
    course_structures: List[dict] = []
    
    for course in courses:
        course_id = int(course["course_id"])
        content = course_content.get(course_id, {})
        metadata = course_metadata.get(course_id, {})
        
        course_items = content.get("CourseItems", [])
        
        # Group items by type (Module vs Lesson)
        modules: List[dict] = []
        current_module: Optional[dict] = None
        
        for item in sorted(course_items, key=lambda x: x.get("DisplayOrder", 0)):
            item_type = item.get("ItemType", "")
            item_data = item.get("Data", {})
            
            if item_type == "Module":
                # Start a new module
                if current_module:
                    modules.append(current_module)
                current_module = {
                    "id": str(item.get("CourseItemId", "")),
                    "title": item_data.get("Title", "Untitled Module"),
                    "description": item_data.get("Description", ""),
                    "position": item.get("DisplayOrder", 0),
                    "lessons": [],
                }
            elif item_type == "Lesson" and current_module:
                # Add lesson to current module
                lesson = {
                    "id": str(item.get("CourseItemId", "")),
                    "title": item_data.get("Title", "Untitled Lesson"),
                    "description": item_data.get("Description", ""),
                    "position": item.get("DisplayOrder", 0),
                    "content": {
                        "file_type": item_data.get("FileType", ""),
                        "download_url": item_data.get("DownloadUrl", ""),
                        "playback_url": item_data.get("PlaybackUrl", ""),
                        "video_text_tracks": item_data.get("VideoTextTracks", ""),
                        "aux_pdf_url": item_data.get("AuxPdfUrl", ""),
                        "aux_word_url": item_data.get("AuxWordUrl", ""),
                        "aux_ppt_url": item_data.get("AuxPptUrl", ""),
                    },
                }
                current_module["lessons"].append(lesson)
        
        # Add final module
        if current_module:
            modules.append(current_module)
        
        # If no modules, create a default one with all lessons
        if not modules and course_items:
            default_module = {
                "id": "default",
                "title": "Course Content",
                "description": "",
                "position": 0,
                "lessons": [],
            }
            for item in sorted(course_items, key=lambda x: x.get("DisplayOrder", 0)):
                if item.get("ItemType") == "Lesson":
                    item_data = item.get("Data", {})
                    default_module["lessons"].append({
                        "id": str(item.get("CourseItemId", "")),
                        "title": item_data.get("Title", "Untitled Lesson"),
                        "description": item_data.get("Description", ""),
                        "position": item.get("DisplayOrder", 0),
                        "content": {
                            "file_type": item_data.get("FileType", ""),
                            "download_url": item_data.get("DownloadUrl", ""),
                            "playback_url": item_data.get("PlaybackUrl", ""),
                            "video_text_tracks": item_data.get("VideoTextTracks", ""),
                            "aux_pdf_url": item_data.get("AuxPdfUrl", ""),
                            "aux_word_url": item_data.get("AuxWordUrl", ""),
                            "aux_ppt_url": item_data.get("AuxPptUrl", ""),
                        },
                    })
            if default_module["lessons"]:
                modules = [default_module]
        
        course_structures.append({
            "course_id": course["course_id"],
            "course_name": course["course_name"],
            "course_description": course["course_description"],
            "category_name": course["category_name"],
            "modules": modules,
        })
    
    return course_structures


def build_category_courses_structure(
    courses_file: Path,
    content_file: Path,
    metadata_file: Path,
) -> List[dict]:
    """
    Build category-level courses where:
    - MCT Category -> Open edX Course
    - MCT Course (ProductId) -> Module (Chapter)
    - CourseItems -> Lessons within each module
    """
    # Load course content (keyed by product/courseId)
    course_content: Dict[int, dict] = {}
    for rec in read_ndjson(content_file):
        course_id = rec.get("courseId")
        if course_id:
            course_content[course_id] = rec

    category_courses: List[dict] = []

    for rec in read_ndjson(courses_file):
        category_id = rec.get("CategoryId")
        category_name = (rec.get("CategoryName") or "").strip()
        category_desc = (rec.get("CategoryDescription") or "") or ""

        modules: List[dict] = []
        for idx, module in enumerate(rec.get("Courses", []) or [], start=1):
            module_course_id = module.get("ParentCourseId") or module.get("CourseId")
            if not module_course_id:
                continue
            module_title = (module.get("CourseName") or f"Module {idx}").strip()
            module_desc = (module.get("CourseDescription") or "") or ""
            content = course_content.get(int(module_course_id), {})
            items = content.get("CourseItems", []) or []

            lessons: List[dict] = []
            for item in sorted(items, key=lambda x: x.get("DisplayOrder", 0)):
                if item.get("ItemType") != "Lesson":
                    continue
                item_data = item.get("Data", {}) or {}
                lessons.append(
                    {
                        "id": str(item.get("CourseItemId", "")),
                        "title": item_data.get("Title", "Untitled Lesson"),
                        "description": item_data.get("Description", "") or "",
                        "position": item.get("DisplayOrder", 0),
                        "content": {
                            "file_type": item_data.get("FileType", ""),
                            "download_url": item_data.get("DownloadUrl", ""),
                            "playback_url": item_data.get("PlaybackUrl", ""),
                            "video_text_tracks": item_data.get("VideoTextTracks", ""),
                            "aux_pdf_url": item_data.get("AuxPdfUrl", ""),
                            "aux_word_url": item_data.get("AuxWordUrl", ""),
                            "aux_ppt_url": item_data.get("AuxPptUrl", ""),
                        },
                    }
                )

            modules.append(
                {
                    "id": str(module_course_id),
                    "title": module_title,
                    "description": module_desc,
                    "position": idx,
                    "lessons": lessons,
                }
            )

        category_courses.append(
            {
                "course_id": str(category_id) if category_id is not None else "",
                "course_name": category_name,
                "course_description": category_desc,
                "category_name": category_name,
                "modules": modules,
            }
        )

    return category_courses


def build_category_enrollments_heuristic(users_file: Path, courses_file: Path) -> List[dict]:
    """
    DEPRECATED: Build enrollments using heuristic keyword matching.
    Use build_real_enrollments() instead for accurate data from enrollments.ndjson.
    """
    # Collect categories
    categories: List[dict] = []
    for rec in read_ndjson(courses_file):
        categories.append(
            {
                "category_id": str(rec.get("CategoryId", "")),
                "category_name": (rec.get("CategoryName") or "").strip(),
            }
        )
    enrollments: List[dict] = []
    keywords = ["developer", "data", "analyst", "digital", "marketer", "project", "management", "ai", "basic", "microsoft", "employability"]

    for rec in read_ndjson(users_file):
        email = (rec.get("Contact") or "").strip().lower()
        if not email:
            continue
        groups = (rec.get("My groups") or "").strip()
        if not groups:
            continue
        pathways = [g.split("|")[0].strip().lower() for g in groups.split(";") if g.strip()]
        matched_ids: set[str] = set()
        for pathway in pathways:
            for cat in categories:
                name_lower = cat["category_name"].lower()
                if not name_lower:
                    continue
                if pathway and pathway in name_lower:
                    matched_ids.add(cat["category_id"])
                    continue
                if any(k in name_lower for k in keywords if k in pathway):
                    matched_ids.add(cat["category_id"])
        for cat_id in matched_ids:
            enrollments.append(
                {
                    "email": email,
                    "category_id": cat_id,
                    "enrollment_source": "learning_pathway",
                    "pathway": ";".join(pathways),
                }
            )
    return enrollments


def build_real_enrollments(enrollments_file: Path, courses_file: Path) -> List[dict]:
    """
    Build enrollments from REAL enrollment data exported from MCT Reports API.

    Each enrollment record from enrollments.ndjson contains:
    - courseId: MCT course ID (module level)
    - Course: Course name
    - Contact: User email
    - Name: User name
    - Lessons Completed: Number of lessons completed
    - Quizzes Completed: Number of quizzes completed
    - Course Completion Percentage: Completion percentage (0-100)
    - Average Score: Average quiz score or "NOT APPLICABLE"

    Returns enrollments aggregated by category (since MCT Category = Open edX Course).
    """
    if not enrollments_file.exists():
        print(f"  ⚠ No enrollments.ndjson found at {enrollments_file}")
        print("  ⚠ Falling back to heuristic enrollment building")
        return []

    # Build course -> category mapping from courses.ndjson
    course_to_category: Dict[int, Dict] = {}
    for rec in read_ndjson(courses_file):
        course_id = rec.get("Id") or rec.get("courseId")
        category_id = rec.get("CategoryId") or rec.get("ParentId")
        category_name = (rec.get("CategoryName") or "").strip()
        if course_id and category_id:
            course_to_category[int(course_id)] = {
                "category_id": str(category_id),
                "category_name": category_name,
            }

    # Read enrollments and aggregate by category
    # Track unique (email, category_id) pairs to avoid duplicates
    seen_enrollments: set = set()
    enrollments: List[dict] = []

    enrollment_count = 0
    for rec in read_ndjson(enrollments_file):
        enrollment_count += 1
        course_id = rec.get("courseId")
        email = (rec.get("Contact") or "").strip().lower()

        if not email or not course_id:
            continue

        category = course_to_category.get(int(course_id))
        if not category:
            continue

        key = (email, category["category_id"])
        if key in seen_enrollments:
            continue
        seen_enrollments.add(key)

        # Extract completion info
        completion = rec.get("Course Completion Percentage", "0")
        try:
            completion_pct = int(float(completion))
        except (ValueError, TypeError):
            completion_pct = 0

        enrollments.append({
            "email": email,
            "category_id": category["category_id"],
            "category_name": category["category_name"],
            "enrollment_source": "mct_export",
            "completion_percentage": completion_pct,
            "lessons_completed": rec.get("Lessons Completed", "0"),
        })

    print(f"  → Processed {enrollment_count:,} enrollment records")
    print(f"  → {len(enrollments):,} unique (user, category) enrollments")

    return enrollments


def build_category_enrollments(users_file: Path, courses_file: Path, enrollments_file: Optional[Path] = None) -> List[dict]:
    """
    Build category-level enrollments. Uses REAL enrollment data if enrollments.ndjson exists,
    otherwise falls back to heuristic matching (deprecated).
    """
    # Check for real enrollment data first
    if enrollments_file and enrollments_file.exists():
        print("  Using REAL enrollment data from enrollments.ndjson")
        return build_real_enrollments(enrollments_file, courses_file)

    # Infer enrollments file path from courses file
    inferred_path = courses_file.parent / "enrollments.ndjson"
    if inferred_path.exists():
        print("  Using REAL enrollment data from enrollments.ndjson")
        return build_real_enrollments(inferred_path, courses_file)

    print("  ⚠ No enrollments.ndjson found, using heuristic matching (DEPRECATED)")
    return build_category_enrollments_heuristic(users_file, courses_file)


def main():
    parser = argparse.ArgumentParser(description="Transform MCT exports to Open edX format")
    parser.add_argument("--exports-dir", required=True, help="Path to MCT export directory")
    parser.add_argument(
        "--structure-dir",
        default=None,
        help="Path to structure files (course_content, course_metadata)",
    )
    parser.add_argument("--output-dir", required=True, help="Where transformed files will be written")
    args = parser.parse_args()

    exports_dir = Path(args.exports_dir)
    structure_dir = Path(args.structure_dir or exports_dir / "structure")
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Loading users…")
    users = build_user_rows(exports_dir / "users.ndjson")
    write_csv(
        users,
        [
            "username",
            "email",
            "full_name",
            "first_name",
            "last_name",
            "country",
            "gender",
            "dob",
            "learning_pathways",
            "mct_user_id",
        ],
        output_dir / "users.csv",
    )
    print(f"  → {len(users)} users")

    print("Extracting courses…")
    courses = extract_courses_from_categories(exports_dir / "courses.ndjson")
    write_csv(
        courses,
        [
            "course_id",
            "course_name",
            "course_description",
            "category_id",
            "category_name",
            "content_language",
            "course_item_count",
            "completion_percentage",
        ],
        output_dir / "courses.csv",
    )
    print(f"  → {len(courses)} courses")

    print("Building enrollments…")
    enrollments = build_enrollment_rows(exports_dir / "users.ndjson", courses)
    write_csv(
        enrollments,
        ["email", "course_id", "enrollment_source", "pathway"],
        output_dir / "enrollments.csv",
    )
    print(f"  → {len(enrollments)} enrollments")

    print("Building course structure…")
    course_structures = build_course_structure(
        exports_dir / "courses.ndjson",
        structure_dir / "course_content.ndjson",
        structure_dir / "course_metadata.ndjson",
    )
    
    # Write course structure as JSON
    with (output_dir / "course_structure.json").open("w", encoding="utf-8") as f:
        json.dump(course_structures, f, indent=2, ensure_ascii=False)
    
    print(f"  → {len(course_structures)} courses with structure")
    
    # Calculate summary stats
    total_modules = sum(len(c.get("modules", [])) for c in course_structures)
    total_lessons = sum(
        sum(len(m.get("lessons", [])) for m in c.get("modules", []))
        for c in course_structures
    )
    print(f"  → {total_modules} modules, {total_lessons} lessons")

    print(f"\n✅ Transformation complete! Outputs written to {output_dir}")

    # Build category-level courses as an additional output (Category -> Course)
    print("\nBuilding category-level courses…")
    category_courses = build_category_courses_structure(
        exports_dir / "courses.ndjson",
        structure_dir / "course_content.ndjson",
        structure_dir / "course_metadata.ndjson",
    )
    with (output_dir / "course_structure_categories.json").open("w", encoding="utf-8") as f:
        json.dump(category_courses, f, indent=2, ensure_ascii=False)
    # Also write a categories courses CSV (one row per category)
    write_csv(
        (
            {
                "course_id": c.get("course_id", ""),
                "course_name": c.get("course_name", ""),
                "course_description": c.get("course_description", ""),
                "category_name": c.get("category_name", ""),
            }
            for c in category_courses
        ),
        ["course_id", "course_name", "course_description", "category_name"],
        output_dir / "courses_categories.csv",
    )
    print(f"  → {len(category_courses)} category courses (Category→Course)")

    # Category-level enrollments - use REAL data from enrollments.ndjson if available
    print("Building category-level enrollments…")
    enrollments_categories = build_category_enrollments(
        exports_dir / "users.ndjson",
        exports_dir / "courses.ndjson",
        exports_dir / "enrollments.ndjson",  # Real enrollment data from MCT Reports API
    )
    write_csv(
        enrollments_categories,
        ["email", "category_id", "category_name", "enrollment_source", "completion_percentage", "lessons_completed"],
        output_dir / "enrollments_categories.csv",
    )
    print(f"  → {len(enrollments_categories)} category enrollments")


if __name__ == "__main__":
    main()

