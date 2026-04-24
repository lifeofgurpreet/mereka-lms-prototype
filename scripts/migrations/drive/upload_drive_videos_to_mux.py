#!/usr/bin/env python3
"""Upload Google Drive videos to Mux.

Reads exports/drive/videos_for_mux.json — a list of records describing videos
stored in Google Drive — and submits each one to the Mux Video API so that Mux
fetches the file directly from Drive.

Requirements
------------
    pip install requests

Environment Variables
---------------------
    MUX_TOKEN_ID      Mux API access token ID (required)
    MUX_TOKEN_SECRET  Mux API secret key (required)

Usage
-----
    # Full run
    python scripts/migrations/drive/upload_drive_videos_to_mux.py

    # Dry-run (print what would be submitted, no API calls)
    python scripts/migrations/drive/upload_drive_videos_to_mux.py --dry-run

    # Only upload videos for a specific course
    python scripts/migrations/drive/upload_drive_videos_to_mux.py --course PB-ENG

    # Resume: skip videos that already have a mux_playback_id in the results file
    python scripts/migrations/drive/upload_drive_videos_to_mux.py --skip-existing

Input
-----
    exports/drive/videos_for_mux.json

    Each record must have at least:
        airtable_id    (str, may be empty)
        course_number  (str, e.g. "PB-ENG")
        new_course_key (str, e.g. "course-v1:MEREKA+PB-EN+course")
        title          (str)
        drive_url      (str, e.g. "https://drive.google.com/file/d/{ID}/view")

Output
------
    exports/drive/mux_upload_results.json

    Structure::

        {
          "started_at": "<ISO datetime>",
          "completed_at": "<ISO datetime>",
          "successful": [
            {
              "airtable_id": "...",
              "course_number": "...",
              "new_course_key": "...",
              "title": "...",
              "drive_url": "...",
              "mux_asset_id": "...",
              "mux_playback_id": "...",
              "mux_status": "preparing"
            },
            ...
          ],
          "failed": [
            { ..., "error": "<message>" }
          ],
          "skipped": <int>
        }

Notes
-----
- Drive direct-download URL format: ``https://drive.google.com/uc?id={FILE_ID}&export=download``
- The file must be publicly shared ("Anyone with the link can view") or the
  service account running this script must have Drive read access.
- Mux fetches the video asynchronously; ``mux_status`` will be ``"preparing"``
  immediately after submission.  Poll the Mux API or use webhooks to confirm
  the asset reaches ``"ready"`` state.
- Rate-limited to 2 seconds between requests to avoid hitting Mux's API limits.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:
    print("Error: 'requests' library not installed. Run: pip install requests", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent.parent
EXPORTS_DRIVE = REPO_ROOT / "exports" / "drive"
VIDEOS_INPUT = EXPORTS_DRIVE / "videos_for_mux.json"
RESULTS_OUTPUT = EXPORTS_DRIVE / "mux_upload_results.json"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MUX_API_BASE = "https://api.mux.com/video/v1"
RATE_LIMIT_SECONDS = 2.0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _extract_drive_file_id(drive_url: str) -> str | None:
    """Extract the Google Drive file ID from various Drive URL formats.

    Supported formats:
        https://drive.google.com/file/d/{ID}/view?...
        https://drive.google.com/open?id={ID}
        https://drive.google.com/uc?id={ID}
    """
    # Pattern: /file/d/{ID}/
    m = re.search(r"/file/d/([a-zA-Z0-9_-]+)", drive_url)
    if m:
        return m.group(1)
    # Pattern: id={ID}
    m = re.search(r"[?&]id=([a-zA-Z0-9_-]+)", drive_url)
    if m:
        return m.group(1)
    return None


def _build_direct_download_url(file_id: str) -> str:
    """Build a Google Drive direct-download URL for a given file ID."""
    return f"https://drive.google.com/uc?id={file_id}&export=download"


def _load_existing_results(path: Path) -> dict[str, Any]:
    """Load existing results file, returning a default structure if absent."""
    if path.exists():
        with path.open(encoding="utf-8") as fh:
            try:
                return json.load(fh)
            except json.JSONDecodeError:
                pass
    return {"started_at": _now_iso(), "successful": [], "failed": [], "skipped": 0}


def _save_results(path: Path, results: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=2, ensure_ascii=False)


def _get_mux_creds() -> tuple[str, str]:
    token_id = os.environ.get("MUX_TOKEN_ID", "").strip()
    token_secret = os.environ.get("MUX_TOKEN_SECRET", "").strip()
    if not token_id or not token_secret:
        print(
            "Error: MUX_TOKEN_ID and MUX_TOKEN_SECRET environment variables are required.\n"
            "  export MUX_TOKEN_ID=<your-token-id>\n"
            "  export MUX_TOKEN_SECRET=<your-token-secret>",
            file=sys.stderr,
        )
        sys.exit(1)
    return token_id, token_secret


def _submit_to_mux(
    session: requests.Session,
    video: dict,
    download_url: str,
    dry_run: bool = False,
) -> dict:
    """Submit one video to Mux and return the result record.

    The ``passthrough`` field encodes a JSON string with identifiers so that
    we can correlate Mux webhook events back to the source video.
    """
    passthrough = json.dumps({
        "airtable_id": video.get("airtable_id", ""),
        "course_number": video.get("course_number", ""),
        "new_course_key": video.get("new_course_key", ""),
        "title": video.get("title", ""),
    })

    payload = {
        "input": [{"url": download_url}],
        "playback_policy": ["public"],
        "passthrough": passthrough,
    }

    result = {
        "airtable_id": video.get("airtable_id", ""),
        "course_number": video.get("course_number", ""),
        "new_course_key": video.get("new_course_key", ""),
        "title": video.get("title", ""),
        "drive_url": video.get("drive_url", ""),
        "download_url": download_url,
    }

    if dry_run:
        result["mux_asset_id"] = "DRY_RUN"
        result["mux_playback_id"] = "DRY_RUN"
        result["mux_status"] = "dry_run"
        return result

    resp = session.post(
        f"{MUX_API_BASE}/assets",
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json().get("data", {})

    result["mux_asset_id"] = data.get("id", "")
    # Mux may return multiple playback IDs; take the first public one
    playback_ids = data.get("playback_ids", [])
    result["mux_playback_id"] = playback_ids[0]["id"] if playback_ids else ""
    result["mux_status"] = data.get("status", "preparing")
    return result


# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def run(
    course_filter: str | None = None,
    skip_existing: bool = False,
    dry_run: bool = False,
) -> None:
    """Upload Google Drive videos to Mux."""

    # Load input
    if not VIDEOS_INPUT.exists():
        print(f"Error: input file not found: {VIDEOS_INPUT}", file=sys.stderr)
        sys.exit(1)

    with VIDEOS_INPUT.open(encoding="utf-8") as fh:
        videos: list[dict] = json.load(fh)

    print(f"Loaded {len(videos)} videos from {VIDEOS_INPUT}")

    # Filter by course if requested
    if course_filter:
        videos = [v for v in videos if course_filter in (v.get("course_number", ""), v.get("new_course_key", ""))]
        print(f"Filtered to {len(videos)} videos for course '{course_filter}'")

    # Load existing results for resume support
    results = _load_existing_results(RESULTS_OUTPUT)
    if not results.get("started_at"):
        results["started_at"] = _now_iso()

    already_uploaded: set[str] = set()
    if skip_existing:
        for s in results.get("successful", []):
            key = s.get("airtable_id") or s.get("drive_url", "")
            if key:
                already_uploaded.add(key)
        print(f"Skip-existing mode: {len(already_uploaded)} already uploaded")

    # Mux session
    token_id, token_secret = _get_mux_creds()
    session = requests.Session()
    session.auth = (token_id, token_secret)
    session.headers.update({"Content-Type": "application/json"})

    successful = results.setdefault("successful", [])
    failed = results.setdefault("failed", [])
    skipped_count: int = results.get("skipped", 0) if isinstance(results.get("skipped"), int) else 0

    for idx, video in enumerate(videos, 1):
        drive_url = video.get("drive_url", "").strip()
        title = video.get("title", "(untitled)")
        course_number = video.get("course_number", "")
        airtable_id = video.get("airtable_id", "")

        print(f"[{idx}/{len(videos)}] {course_number} — {title}")

        if not drive_url:
            print("  SKIP: missing drive_url")
            skipped_count += 1
            continue

        # Resume: skip if already processed
        resume_key = airtable_id or drive_url
        if skip_existing and resume_key in already_uploaded:
            print("  SKIP: already uploaded")
            skipped_count += 1
            continue

        # Extract file ID
        file_id = _extract_drive_file_id(drive_url)
        if not file_id:
            msg = f"Cannot extract Drive file ID from URL: {drive_url}"
            print(f"  FAIL: {msg}")
            failed.append({**video, "error": msg})
            continue

        download_url = _build_direct_download_url(file_id)
        print(f"  Download URL: {download_url}")

        if dry_run:
            print("  [DRY RUN] Would submit to Mux")
            result = _submit_to_mux(session, video, download_url, dry_run=True)
            successful.append(result)
            continue

        try:
            result = _submit_to_mux(session, video, download_url, dry_run=False)
            successful.append(result)
            print(f"  OK: asset={result['mux_asset_id']} playback={result['mux_playback_id']}")
        except requests.HTTPError as exc:
            msg = f"Mux API error {exc.response.status_code}: {exc.response.text[:200]}"
            print(f"  FAIL: {msg}")
            failed.append({**video, "error": msg})
        except Exception as exc:
            msg = str(exc)
            print(f"  FAIL: {msg}")
            failed.append({**video, "error": msg})

        # Save after every video so progress survives interruptions
        results["skipped"] = skipped_count
        _save_results(RESULTS_OUTPUT, results)

        # Rate limit
        time.sleep(RATE_LIMIT_SECONDS)

    results["completed_at"] = _now_iso()
    results["skipped"] = skipped_count
    _save_results(RESULTS_OUTPUT, results)

    print(
        f"\nDone. successful={len(successful)}  failed={len(failed)}  skipped={skipped_count}"
    )
    print(f"Results written to {RESULTS_OUTPUT}")

    if failed:
        print(f"\nFailed ({len(failed)}):")
        for f in failed:
            print(f"  {f.get('course_number')} — {f.get('title')}: {f.get('error')}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Upload Google Drive videos to Mux via the Mux Video API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--course",
        metavar="COURSE_NUMBER",
        help="Only upload videos for this course number (e.g. PB-ENG)",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip videos already recorded in mux_upload_results.json",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be submitted without making API calls",
    )
    args = parser.parse_args()

    run(
        course_filter=args.course,
        skip_existing=args.skip_existing,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
