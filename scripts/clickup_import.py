#!/usr/bin/env python3
"""
ClickUp Task Importer for Mereka LMS

Prerequisites:
1. ClickUp API key: https://app.clickup.com/9008044055/settings/apps
2. ClickUp List ID: Create a list, get ID from URL
3. Python packages: pip install requests

Usage:
    python scripts/clickup_import.py --api-key YOUR_KEY --list-id LIST_ID --csv docs/clickup_import.csv
"""

import argparse
import csv
import time
from datetime import datetime

import requests

# Priority mapping (ClickUp uses 1-4)
PRIORITY_MAP = {
    "Urgent": 1,
    "High": 2,
    "Medium": 3,
    "Low": 4,
}

# Status mapping (must match your ClickUp list statuses)
STATUS_MAP = {
    "Complete": "complete",
    "In Progress": "in progress",
    "Planned": "todo",
    "Blocked": "blocked",
}

# Tag colors (hex)
TAG_COLORS = {
    "Learner-Facing": "#2196F3",
    "Admin-Facing": "#FF9800",
    "Revenue": "#4CAF50",
    "Security": "#F44336",
    "Infrastructure": "#9C27B0",
    "Compliance": "#FFEB3B",
    "Data": "#9E9E9E",
}


def create_task(api_key, list_id, task_data, tag_cache):
    """Create a single task in ClickUp."""
    headers = {
        "Authorization": api_key,
        "Content-Type": "application/json",
    }

    # Build task payload
    payload = {
        "name": task_data["Task Name"],
        "description": task_data["Description"],
        "priority": PRIORITY_MAP.get(task_data["Priority"], 3),
        "tags": [],
    }

    # Add due date if present
    if task_data["Due Date"]:
        try:
            due_date = datetime.strptime(task_data["Due Date"], "%Y-%m-%d")
            payload["due_date"] = int(due_date.timestamp() * 1000)
        except ValueError:
            pass

    # Add status (note: status update may require separate API call)
    # ClickUp API doesn't support status on task creation for custom statuses

    # Add tags
    tag_name = task_data.get("Tags", "")
    if tag_name and tag_name in TAG_COLORS:
        payload["tags"] = [{
            "name": tag_name,
            "tag_bg": TAG_COLORS[tag_name],
        }]

    # Create task
    response = requests.post(
        f"https://api.clickup.com/api/v2/list/{list_id}/task",
        headers=headers,
        json=payload,
    )

    return response


def main():
    parser = argparse.ArgumentParser(description="Import tasks to ClickUp")
    parser.add_argument("--api-key", required=True, help="ClickUp API key")
    parser.add_argument("--list-id", required=True, help="ClickUp list ID")
    parser.add_argument("--csv", required=True, help="Path to CSV file")
    parser.add_argument("--dry-run", action="store_true", help="Preview without creating")
    args = parser.parse_args()

    tag_cache = {}

    with open(args.csv, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        tasks = list(reader)

    print(f"Found {len(tasks)} tasks to import")

    if args.dry_run:
        print("\n=== DRY RUN - Preview ===\n")
        for i, task in enumerate(tasks, 1):
            print(f"{i}. {task['Task Name']}")
            print(f"   Status: {task['Status']}")
            print(f"   Priority: {task['Priority']}")
            print(f"   Due: {task['Due Date']}")
            print(f"   Folder: {task['Folder']}")
            print(f"   Tag: {task['Tags']}")
            print()
        return

    success = 0
    failed = 0

    for i, task in enumerate(tasks, 1):
        print(f"[{i}/{len(tasks)}] Creating: {task['Task Name'][:50]}...")

        response = create_task(args.api_key, args.list_id, task, tag_cache)

        if response.status_code == 200:
            success += 1
            print("   ✅ Created")
        else:
            failed += 1
            print(f"   ❌ Failed: {response.text}")

        # Rate limiting
        time.sleep(0.5)

    print("\n=== Import Complete ===")
    print(f"✅ Success: {success}")
    print(f"❌ Failed: {failed}")


if __name__ == "__main__":
    main()
