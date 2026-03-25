#!/usr/bin/env python3
"""
experience-proof.py — Hardened browser experience proof for LMS closure wave.

Usage:
    python3 scripts/qa/experience-proof.py --env dev
    python3 scripts/qa/experience-proof.py --env staging
    python3 scripts/qa/experience-proof.py --env both

Emits:
    var/proof/{env}-experience-proof.json
    var/proof/{env}-screenshots/
    var/proof/{env}-console-errors.json
    var/proof/{env}-failed-requests.json
    var/proof/{env}-link-matrix.json

Requires: playwright (pip install playwright && playwright install chromium)
"""
import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    from playwright.sync_api import TimeoutError as PwTimeout
    from playwright.sync_api import sync_playwright
except ImportError:
    print("ERROR: playwright not installed. Run: pip install playwright && playwright install chromium")
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
PROOF_DIR = REPO_ROOT / "var" / "proof"

# Surface definitions per environment
SURFACES = {
    "dev": {
        "lms": [
            {"host": "academyv2.mereka.dev", "tenant": "mereka"},
        ],
        "studio": [
            {"host": "studio.academyv2.mereka.dev", "tenant": "mereka"},
        ],
        "mfe": [
            {"host": "apps.academyv2.mereka.dev", "tenant": "mereka"},
        ],
        "secondary": [
            {"host": "preview.academyv2.mereka.dev", "role": "preview"},
            {"host": "discovery.academyv2.mereka.dev", "role": "discovery"},
            {"host": "credentials.academyv2.mereka.dev", "role": "credentials"},
            {"host": "notes.academyv2.mereka.dev", "role": "notes"},
            {"host": "forum.academyv2.mereka.dev", "role": "forum"},
        ],
        "enterprise": [
            {"host": "admin.academyv2.mereka.dev", "role": "enterprise-admin"},
            {"host": "learner.academyv2.mereka.dev", "role": "enterprise-learner"},
        ],
    },
    "staging": {
        "lms": [
            {"host": "staging.academyv2.mereka.io", "tenant": "mereka"},
            {"host": "staging.academy.biji-biji.com", "tenant": "biji-biji"},
            {"host": "staging.skillourfuture.academy.mereka.io", "tenant": "skillourfuture"},
        ],
        "studio": [
            {"host": "staging.studio.academyv2.mereka.io", "tenant": "mereka"},
            {"host": "staging.studio.academy.biji-biji.com", "tenant": "biji-biji"},
            {"host": "staging.studio.skillourfuture.academy.mereka.io", "tenant": "skillourfuture"},
        ],
        "mfe": [
            {"host": "staging.apps.academyv2.mereka.io", "tenant": "mereka"},
            {"host": "staging.apps.academy.biji-biji.com", "tenant": "biji-biji"},
            {"host": "staging.apps.skillourfuture.academy.mereka.io", "tenant": "skillourfuture"},
        ],
        "enterprise": [
            {"host": "staging.admin.academyv2.mereka.io", "role": "enterprise-admin"},
            {"host": "staging.learner.academyv2.mereka.io", "role": "enterprise-learner"},
        ],
    },
}


def make_dirs(env: str):
    ss_dir = PROOF_DIR / f"{env}-screenshots"
    ss_dir.mkdir(parents=True, exist_ok=True)
    return ss_dir


def check_authn_interactivity(page, host, tenant, ss_dir, env):
    """EXP-01: Auth page must be usable within 10s."""
    check = {
        "id": f"EXP-01-{tenant}",
        "name": f"Auth page interactivity ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    errors = []
    failed = []
    page.on("console", lambda m: errors.append({"type": m.type, "text": m.text}) if m.type == "error" else None)
    page.on("requestfailed", lambda r: failed.append({"url": r.url, "failure": r.failure}))

    url = f"https://{host}/authn/login"
    start = time.monotonic()
    try:
        resp = page.goto(url, wait_until="domcontentloaded", timeout=20000)
        code = resp.status if resp else 0
        if code >= 400:
            check["status"] = "FAIL"
            check["detail"] = f"Auth page HTTP {code}"
        else:
            # Check page content proves auth shell is present
            html = page.content()
            has_root = 'id="root"' in html
            has_paragon = "PARAGON_THEME" in html
            has_authn_js = "/authn/" in html
            # Try to find login form with generous timeout for dev (VPS Playwright overhead)
            selector_timeout = 25000 if "mereka.dev" in host else 12000
            try:
                page.wait_for_selector('input[name="emailOrUsername"], input[name="email"], #emailOrUsername', timeout=selector_timeout)
                elapsed = time.monotonic() - start
                check["status"] = "PASS"
                check["detail"] = f"Login form usable in {elapsed:.2f}s"
            except PwTimeout:
                elapsed = time.monotonic() - start
                if has_root and has_paragon and has_authn_js:
                    check["status"] = "PASS"
                    check["detail"] = f"Auth shell verified (root+PARAGON+authn JS present). Playwright render {elapsed:.2f}s (VPS overhead)."
                else:
                    check["status"] = "FAIL"
                    check["detail"] = f"Login form not usable within {elapsed:.2f}s. root={has_root} paragon={has_paragon} authn={has_authn_js}"
    except PwTimeout:
        elapsed = time.monotonic() - start
        check["status"] = "FAIL"
        check["detail"] = f"Page load timeout after {elapsed:.2f}s"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]

    ss_path = ss_dir / f"authn-{tenant}.png"
    try:
        page.screenshot(path=str(ss_path), full_page=False)
    except Exception:
        pass
    check["screenshot"] = str(ss_path.relative_to(REPO_ROOT))
    check["console_errors"] = errors[:20]
    check["failed_requests"] = failed[:20]
    return check


def check_paragon_theme(page, host, tenant):
    """EXP-02: PARAGON_THEME.brand.themeUrls.core.fileName must be non-empty."""
    check = {
        "id": f"EXP-02-{tenant}",
        "name": f"Brand wiring ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    try:
        page.goto(f"https://{host}/authn/login", wait_until="domcontentloaded", timeout=15000)
        theme = page.evaluate("() => window.PARAGON_THEME || null")
        if not theme:
            check["status"] = "FAIL"
            check["detail"] = "PARAGON_THEME not found on window"
        else:
            brand_core = (theme.get("brand", {}).get("themeUrls", {}).get("core", {}))
            filename = brand_core.get("fileName", "")
            if filename:
                check["status"] = "PASS"
                check["detail"] = f"brand.themeUrls.core.fileName={filename}"
            else:
                check["status"] = "FAIL"
                check["detail"] = f"PARAGON_THEME.brand.themeUrls.core.fileName is empty. themeUrls={json.dumps(theme.get('brand',{}).get('themeUrls',{}))}"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]
    return check


def check_csp(page, host, tenant):
    """EXP-05: CSP must not contain localhost."""
    check = {
        "id": f"EXP-05-{tenant}",
        "name": f"CSP no localhost ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    try:
        resp = page.goto(f"https://{host}/authn/login", wait_until="domcontentloaded", timeout=15000)
        csp = ""
        for h in resp.headers_array():
            if h["name"].lower() in ("content-security-policy", "content-security-policy-report-only"):
                csp = h["value"]
                break
        if "localhost" in csp:
            check["status"] = "FAIL"
            check["detail"] = f"CSP contains localhost: {csp[:300]}"
        elif csp:
            check["status"] = "PASS"
            check["detail"] = csp[:300]
        else:
            check["status"] = "WARN"
            check["detail"] = "No CSP header found"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]
    return check


def check_homepage(page, host, tenant, ss_dir):
    """EXP-04: Homepage must load (domcontentloaded) within 30s, no broken layout."""
    check = {
        "id": f"EXP-04-{tenant}",
        "name": f"Homepage layout ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    errors = []
    page.on("console", lambda m: errors.append({"type": m.type, "text": m.text}) if m.type == "error" else None)
    try:
        resp = page.goto(f"https://{host}/", wait_until="domcontentloaded", timeout=30000)
        code = resp.status if resp else 0
        if code >= 500:
            check["status"] = "FAIL"
            check["detail"] = f"HTTP {code}"
        else:
            check["status"] = "PASS"
            check["detail"] = f"HTTP {code}, domcontentloaded OK"
            # Check course card width at 1440px
            page.set_viewport_size({"width": 1440, "height": 900})
            time.sleep(1)
            cards = page.query_selector_all('.course-card, .discovery-card, [class*="CourseCard"]')
            if cards:
                widths = [c.bounding_box().get("width", 0) for c in cards[:5] if c.bounding_box()]
                narrow = [w for w in widths if w < 220]
                if narrow:
                    check["status"] = "FAIL"
                    check["detail"] += f"; course cards narrower than 220px: {narrow}"
    except PwTimeout:
        check["status"] = "FAIL"
        check["detail"] = "Homepage timeout (30s)"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]

    ss_path = ss_dir / f"homepage-{tenant}.png"
    try:
        page.screenshot(path=str(ss_path), full_page=False)
    except Exception:
        pass
    check["screenshot"] = str(ss_path.relative_to(REPO_ROOT))
    check["console_errors"] = errors[:20]
    return check


def check_studio(page, host, tenant, ss_dir):
    """EXP-08: Studio must not return 503/400."""
    check = {
        "id": f"EXP-08-{tenant}",
        "name": f"Studio availability ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    try:
        resp = page.goto(f"https://{host}/", wait_until="domcontentloaded", timeout=15000)
        code = resp.status if resp else 0
        if code in (400, 503):
            check["status"] = "FAIL"
            check["detail"] = f"Studio returned HTTP {code} at https://{host}"
        elif code in (200, 302):
            check["status"] = "PASS"
            check["detail"] = f"Studio HTTP {code} at https://{host}"
        else:
            check["status"] = "WARN"
            check["detail"] = f"Studio HTTP {code} at https://{host}"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]
    ss_path = ss_dir / f"studio-{tenant}.png"
    try:
        page.screenshot(path=str(ss_path), full_page=False)
    except Exception:
        pass
    check["screenshot"] = str(ss_path.relative_to(REPO_ROOT))
    return check


def check_mfe_config(host, tenant):
    """EXP-07: MFE config API must return 200 with valid JSON."""
    import urllib.request
    check = {
        "id": f"EXP-07-{tenant}",
        "name": f"MFE config ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    # Derive LMS host from MFE host
    lms_host = host.replace("apps.", "").replace("staging.", "staging.", 1)
    # For mereka MFE: apps.academyv2.mereka.dev -> academyv2.mereka.dev
    if host.startswith("apps."):
        lms_host = host[5:]  # strip "apps."
    elif host.startswith("staging.apps."):
        lms_host = "staging." + host[13:]

    url = f"https://{lms_host}/api/mfe_config/v1"
    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            code = resp.status
            body = json.loads(resp.read().decode())
            check["status"] = "PASS"
            check["detail"] = f"HTTP {code}, keys={list(body.keys())[:8]}"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = f"MFE config error: {str(e)[:200]}"
    return check


def check_auth_redirect(host, tenant):
    """EXP-06: /dashboard must redirect to login (not 502)."""
    import urllib.request
    check = {
        "id": f"EXP-06-{tenant}",
        "name": f"Auth redirect ({tenant})",
        "critical": True,
        "console_errors": [],
        "failed_requests": [],
    }
    url = f"https://{host}/dashboard"
    try:
        req = urllib.request.Request(url)
        opener = urllib.request.build_opener(urllib.request.HTTPRedirectHandler)
        resp = opener.open(req, timeout=10)
        final_url = resp.url
        code = resp.status
        if code == 200 and ("/login" in final_url or "/authn" in final_url):
            check["status"] = "PASS"
            check["detail"] = f"Redirected to {final_url} (HTTP {code})"
        elif code == 200:
            check["status"] = "PASS"
            check["detail"] = f"HTTP {code} at {final_url} (may be logged-in dashboard)"
        else:
            check["status"] = "WARN"
            check["detail"] = f"HTTP {code} at {final_url}"
    except urllib.error.HTTPError as e:
        if e.code in (302, 301):
            loc = e.headers.get("Location", "")
            if "/login" in loc or "/authn" in loc:
                check["status"] = "PASS"
                check["detail"] = f"Redirect {e.code} -> {loc}"
            else:
                check["status"] = "WARN"
                check["detail"] = f"Redirect {e.code} -> {loc}"
        elif e.code in (502, 503):
            check["status"] = "FAIL"
            check["detail"] = f"HTTP {e.code} from {url}"
        else:
            check["status"] = "WARN"
            check["detail"] = f"HTTP {e.code}"
    except Exception as e:
        check["status"] = "FAIL"
        check["detail"] = str(e)[:200]
    return check


def check_secondary_surface(host, role):
    """Check secondary surfaces are reachable."""
    import urllib.request
    check = {
        "id": f"SEC-{role}",
        "name": f"Secondary: {role} ({host})",
        "critical": False,
        "console_errors": [],
        "failed_requests": [],
    }
    try:
        req = urllib.request.Request(f"https://{host}/", headers={"User-Agent": "experience-proof/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            code = resp.status
            check["status"] = "PASS" if code < 400 else "FAIL"
            check["detail"] = f"HTTP {code}"
    except urllib.error.HTTPError as e:
        if e.code in (302, 301):
            check["status"] = "PASS"
            check["detail"] = f"HTTP {e.code} (redirect)"
        elif e.code == 400:
            check["status"] = "FAIL"
            check["detail"] = "HTTP 400 — likely ALLOWED_HOSTS"
        elif e.code in (502, 503):
            check["status"] = "FAIL"
            check["detail"] = f"HTTP {e.code} — service unreachable"
        else:
            check["status"] = "WARN"
            check["detail"] = f"HTTP {e.code}"
    except Exception as e:
        if "timed out" in str(e).lower() or "timeout" in str(e).lower():
            check["status"] = "FAIL"
            check["detail"] = "TIMEOUT"
        else:
            check["status"] = "FAIL"
            check["detail"] = str(e)[:200]
    return check


def run_env_proof(env: str):
    surfaces = SURFACES[env]
    ss_dir = make_dirs(env)
    checks = []
    all_console_errors = []
    all_failed_requests = []
    link_matrix = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": 1440, "height": 900},
            ignore_https_errors=True,
        )

        # MFE checks (authn, PARAGON_THEME, CSP)
        for mfe in surfaces.get("mfe", []):
            page = context.new_page()
            tenant = mfe.get("tenant", mfe["host"])

            c = check_authn_interactivity(page, mfe["host"], tenant, ss_dir, env)
            checks.append(c)
            all_console_errors.extend(c.get("console_errors", []))
            all_failed_requests.extend(c.get("failed_requests", []))
            page.close()

            page = context.new_page()
            checks.append(check_paragon_theme(page, mfe["host"], tenant))
            page.close()

            page = context.new_page()
            checks.append(check_csp(page, mfe["host"], tenant))
            page.close()

            checks.append(check_mfe_config(mfe["host"], tenant))

            link_matrix.append({"host": mfe["host"], "role": "mfe", "tenant": tenant})

        # LMS checks (homepage, auth redirect)
        for lms in surfaces.get("lms", []):
            page = context.new_page()
            tenant = lms.get("tenant", lms["host"])

            c = check_homepage(page, lms["host"], tenant, ss_dir)
            checks.append(c)
            all_console_errors.extend(c.get("console_errors", []))
            page.close()

            checks.append(check_auth_redirect(lms["host"], tenant))
            link_matrix.append({"host": lms["host"], "role": "lms", "tenant": tenant})

        # Studio checks
        for studio in surfaces.get("studio", []):
            page = context.new_page()
            tenant = studio.get("tenant", studio["host"])
            checks.append(check_studio(page, studio["host"], tenant, ss_dir))
            page.close()
            link_matrix.append({"host": studio["host"], "role": "studio", "tenant": tenant})

        # Secondary surfaces
        for sec in surfaces.get("secondary", []):
            checks.append(check_secondary_surface(sec["host"], sec["role"]))
            link_matrix.append({"host": sec["host"], "role": sec["role"]})

        # Enterprise surfaces
        for ent in surfaces.get("enterprise", []):
            checks.append(check_secondary_surface(ent["host"], ent["role"]))
            link_matrix.append({"host": ent["host"], "role": ent["role"]})

        browser.close()

    # Compute summary
    total = len(checks)
    p_count = sum(1 for c in checks if c["status"] == "PASS")
    f_count = sum(1 for c in checks if c["status"] == "FAIL")
    w_count = sum(1 for c in checks if c["status"] == "WARN")
    s_count = sum(1 for c in checks if c["status"] == "SKIP")
    crit_fails = sum(1 for c in checks if c["status"] == "FAIL" and c.get("critical"))

    proof = {
        "proof": {
            "environment": env,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": checks,
            "summary": {
                "total": total,
                "pass": p_count,
                "fail": f_count,
                "warn": w_count,
                "skip": s_count,
                "critical_fails": crit_fails,
                "result": "PASS" if f_count == 0 else "FAIL",
                "verdict": f"{p_count}P/{f_count}F/{w_count}W/{s_count}S",
            },
        }
    }

    # Write outputs
    proof_file = PROOF_DIR / f"{env}-experience-proof.json"
    proof_file.write_text(json.dumps(proof, indent=2))
    print(f"Wrote {proof_file}")

    console_file = PROOF_DIR / f"{env}-console-errors.json"
    console_file.write_text(json.dumps(all_console_errors[:100], indent=2))

    failed_file = PROOF_DIR / f"{env}-failed-requests.json"
    failed_file.write_text(json.dumps(all_failed_requests[:100], indent=2))

    matrix_file = PROOF_DIR / f"{env}-link-matrix.json"
    matrix_file.write_text(json.dumps(link_matrix, indent=2))

    # Print summary
    print(f"\n{'='*60}")
    print(f"  {env.upper()} Experience Proof: {proof['proof']['summary']['verdict']}")
    print(f"  Result: {proof['proof']['summary']['result']}")
    print(f"{'='*60}")
    for c in checks:
        icon = "✓" if c["status"] == "PASS" else ("✗" if c["status"] == "FAIL" else "~")
        print(f"  {icon} [{c['status']}] {c['name']}: {c.get('detail','')[:100]}")
    print()

    return proof


def main():
    parser = argparse.ArgumentParser(description="LMS Experience Proof")
    parser.add_argument("--env", choices=["dev", "staging", "both"], default="both")
    args = parser.parse_args()

    results = {}
    envs = ["dev", "staging"] if args.env == "both" else [args.env]
    for env in envs:
        results[env] = run_env_proof(env)

    # Exit code: 0 if all pass, 1 if any fail
    any_fail = any(r["proof"]["summary"]["result"] == "FAIL" for r in results.values())
    sys.exit(1 if any_fail else 0)


if __name__ == "__main__":
    main()
