#!/usr/bin/env python3
"""Resolve release-bundle image digests, using a previous bundle for skipped images."""

from __future__ import annotations

import io
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
GITHUB_API_VERSION = "2022-11-28"


class CrossHostArtifactRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Do not forward GitHub API auth headers to signed artifact blob URLs."""

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> urllib.request.Request | None:
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is None:
            return None

        old_host = urllib.parse.urlparse(req.full_url).netloc
        new_host = urllib.parse.urlparse(newurl).netloc
        if old_host and new_host and old_host != new_host:
            for header in ("Authorization", "Accept", "X-GitHub-Api-Version"):
                redirected.remove_header(header)
        return redirected


def is_valid_digest(value: str | None) -> bool:
    return bool(value and DIGEST_RE.fullmatch(value))


def github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": GITHUB_API_VERSION,
    }


def api_get(url: str, token: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers=github_headers(token))
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_artifact_zip(url: str, token: str) -> bytes:
    opener = urllib.request.build_opener(CrossHostArtifactRedirectHandler)
    req = urllib.request.Request(url, headers=github_headers(token))
    with opener.open(req) as resp:
        return resp.read()


def first_release_bundle_from_zip(zip_bytes: bytes) -> dict[str, Any] | None:
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        bundle_name = next(
            (name for name in zf.namelist() if name.endswith("release-bundle.json")),
            None,
        )
        if not bundle_name:
            return None
        return json.loads(zf.read(bundle_name).decode("utf-8"))


def find_fallback_bundle(
    *,
    api_base_url: str,
    repo: str,
    token: str,
    current_run_id: str,
) -> tuple[dict[str, Any] | None, str | None, list[str]]:
    workflow_url = f"{api_base_url}/repos/{repo}/actions/workflows/build-tutor-images.yml/runs"
    runs = api_get(f"{workflow_url}?branch=main&status=success&per_page=30", token).get(
        "workflow_runs", []
    )
    failures: list[str] = []

    for run in runs:
        run_id = str(run.get("id", ""))
        if not run_id or run_id == current_run_id:
            continue

        artifacts_url = f"{api_base_url}/repos/{repo}/actions/runs/{run_id}/artifacts"
        artifacts = api_get(artifacts_url, token)
        for artifact in artifacts.get("artifacts", []):
            if artifact.get("name") != "release-bundle":
                continue

            artifact_id = str(artifact.get("id", "<unknown>"))
            try:
                zip_bytes = download_artifact_zip(artifact["archive_download_url"], token)
                fallback_bundle = first_release_bundle_from_zip(zip_bytes)
            except urllib.error.HTTPError as exc:
                failures.append(
                    f"run {run_id} artifact {artifact_id}: HTTP {exc.code} {exc.reason}"
                )
                continue
            except (KeyError, OSError, ValueError, zipfile.BadZipFile) as exc:
                failures.append(f"run {run_id} artifact {artifact_id}: {type(exc).__name__}: {exc}")
                continue

            if fallback_bundle:
                return fallback_bundle, run_id, failures

    return None, None, failures


def write_github_outputs(outputs: dict[str, str]) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT", "").strip()
    if not output_path:
        print("Missing GITHUB_OUTPUT", file=sys.stderr)
        raise SystemExit(1)
    Path(output_path).write_text(
        "".join(f"{key}={value}\n" for key, value in outputs.items()),
        encoding="utf-8",
    )


def main() -> int:
    openedx_digest = os.environ.get("OPENEDX_DIGEST", "").strip()
    mfe_digest = os.environ.get("MFE_DIGEST", "").strip()
    build_openedx_result = os.environ.get("BUILD_OPENEDX_RESULT", "").strip()
    build_mfe_result = os.environ.get("BUILD_MFE_RESULT", "").strip()

    if is_valid_digest(openedx_digest) and is_valid_digest(mfe_digest):
        write_github_outputs(
            {
                "openedx_digest": openedx_digest,
                "mfe_digest": mfe_digest,
            }
        )
        print("PASS: build digests present; no fallback required")
        return 0

    token = os.environ.get("GH_TOKEN", "").strip()
    repo = os.environ.get("REPO", "").strip()
    current_run_id = os.environ.get("CURRENT_RUN_ID", "").strip()
    api_base_url = os.environ.get("GITHUB_API_BASE_URL", "https://api.github.com").rstrip("/")
    if not token or not repo:
        print("Missing GH_TOKEN or REPO for fallback release bundle lookup", file=sys.stderr)
        return 1

    fallback_bundle, fallback_run_id, failures = find_fallback_bundle(
        api_base_url=api_base_url,
        repo=repo,
        token=token,
        current_run_id=current_run_id,
    )
    if not fallback_bundle:
        print(
            "Unable to locate fallback release-bundle.json from recent successful runs",
            file=sys.stderr,
        )
        for failure in failures:
            print(f"fallback artifact attempt failed: {failure}", file=sys.stderr)
        return 1

    images = fallback_bundle.get("images", {})
    fallback_openedx = (images.get("openedx") or {}).get("digest", "")
    fallback_mfe = (images.get("mfe") or {}).get("digest", "")

    if build_openedx_result == "skipped" and is_valid_digest(fallback_openedx):
        openedx_digest = fallback_openedx
    if build_mfe_result == "skipped" and is_valid_digest(fallback_mfe):
        mfe_digest = fallback_mfe

    if not is_valid_digest(openedx_digest) or not is_valid_digest(mfe_digest):
        print(
            "Fallback release bundle did not provide required digests "
            f"(openedx='{openedx_digest}' mfe='{mfe_digest}')",
            file=sys.stderr,
        )
        return 1

    Path("var/ci").mkdir(parents=True, exist_ok=True)
    Path("var/ci/fallback-release-bundle.json").write_text(
        json.dumps(fallback_bundle, indent=2) + "\n",
        encoding="utf-8",
    )
    write_github_outputs(
        {
            "openedx_digest": openedx_digest,
            "mfe_digest": mfe_digest,
            "fallback_run_id": fallback_run_id or "",
        }
    )
    print(f"PASS: resolved digests using fallback release bundle from run {fallback_run_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
