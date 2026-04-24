#!/usr/bin/env bash
# Fixture tests for scripts/ci/resolve_release_bundle_digests.py.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/ci/resolve_release_bundle_digests.py"

TMPDIR="$(mktemp -d -t resolve-release-bundle-digests.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

digest_a="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
digest_b="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

GITHUB_OUTPUT="$TMPDIR/direct.out" \
OPENEDX_DIGEST="$digest_a" \
MFE_DIGEST="$digest_b" \
BUILD_OPENEDX_RESULT="success" \
BUILD_MFE_RESULT="success" \
python3 "$SCRIPT" >"$TMPDIR/direct.log"

grep -qx "openedx_digest=$digest_a" "$TMPDIR/direct.out"
grep -qx "mfe_digest=$digest_b" "$TMPDIR/direct.out"
grep -q "no fallback required" "$TMPDIR/direct.log"

python3 - "$ROOT_DIR" "$TMPDIR" <<'PY'
from __future__ import annotations

import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
import zipfile
from pathlib import Path
from socketserver import ThreadingMixIn


root = Path(sys.argv[1])
tmpdir = Path(sys.argv[2])
script = root / "scripts/ci/resolve_release_bundle_digests.py"

openedx_digest = "sha256:" + "a" * 64
mfe_digest = "sha256:" + "b" * 64
release_bundle = {
    "images": {
        "openedx": {"digest": openedx_digest},
        "mfe": {"digest": mfe_digest},
    }
}
zip_path = tmpdir / "release-bundle.zip"
with zipfile.ZipFile(zip_path, "w") as zf:
    zf.writestr("release-bundle.json", json.dumps(release_bundle))


class ThreadedHTTPServer(ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class ArtifactHandler(http.server.BaseHTTPRequestHandler):
    saw_authorization = False

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def do_GET(self) -> None:
        if self.headers.get("Authorization"):
            type(self).saw_authorization = True
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"artifact blob must not receive GitHub Authorization")
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/zip")
        self.end_headers()
        self.wfile.write(zip_path.read_bytes())


artifact_server = ThreadedHTTPServer(("127.0.0.1", 0), ArtifactHandler)
artifact_port = artifact_server.server_address[1]
artifact_thread = threading.Thread(target=artifact_server.serve_forever)
artifact_thread.start()


class ApiHandler(http.server.BaseHTTPRequestHandler):
    saw_authorization = False

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _json(self, payload: dict[str, object]) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())

    def do_GET(self) -> None:
        if self.headers.get("Authorization") == "Bearer test-token":
            type(self).saw_authorization = True

        if self.path.startswith("/repos/o/r/actions/workflows/build-tutor-images.yml/runs"):
            self._json({"workflow_runs": [{"id": 123}]})
            return

        if self.path == "/repos/o/r/actions/runs/123/artifacts":
            self._json(
                {
                    "artifacts": [
                        {
                            "id": 456,
                            "name": "release-bundle",
                            "archive_download_url": (
                                f"http://127.0.0.1:{api_port}/artifact/456"
                            ),
                        }
                    ]
                }
            )
            return

        if self.path == "/artifact/456":
            self.send_response(302)
            self.send_header("Location", f"http://127.0.0.1:{artifact_port}/archive.zip")
            self.end_headers()
            return

        self.send_response(404)
        self.end_headers()


api_server = ThreadedHTTPServer(("127.0.0.1", 0), ApiHandler)
api_port = api_server.server_address[1]
api_thread = threading.Thread(target=api_server.serve_forever)
api_thread.start()

try:
    output_path = tmpdir / "fallback.out"
    env = {
        **os.environ,
        "OPENEDX_DIGEST": openedx_digest,
        "MFE_DIGEST": "",
        "BUILD_OPENEDX_RESULT": "success",
        "BUILD_MFE_RESULT": "skipped",
        "GH_TOKEN": "test-token",
        "REPO": "o/r",
        "CURRENT_RUN_ID": "999",
        "GITHUB_API_BASE_URL": f"http://127.0.0.1:{api_port}",
        "GITHUB_OUTPUT": str(output_path),
    }
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=tempfile.mkdtemp(dir=tmpdir),
        env=env,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)

    output = output_path.read_text(encoding="utf-8")
    assert f"openedx_digest={openedx_digest}\n" in output
    assert f"mfe_digest={mfe_digest}\n" in output
    assert "fallback_run_id=123\n" in output
    assert ApiHandler.saw_authorization, "GitHub API requests must carry Authorization"
    assert not ArtifactHandler.saw_authorization, (
        "redirected artifact blob requests must not carry Authorization"
    )
finally:
    api_server.shutdown()
    artifact_server.shutdown()
    api_thread.join(timeout=5)
    artifact_thread.join(timeout=5)
PY

echo "PASS: resolve-release-bundle-digests fixture tests"
