#!/usr/bin/env python3
"""D-08: Domain Runtime Audit Generator.

Reads deploy/k8s/tenancy/tenant-registry.yaml and probes each active domain
for DNS resolution and HTTPS reachability.

Produces:
  - generated/domain/domain-runtime-audit.json   (machine-readable)
  - docs/reference/generated/domain-runtime-audit.md (human-readable)

Usage:
  python scripts/domains/generate_domain_runtime_audit.py               # Full audit
  python scripts/domains/generate_domain_runtime_audit.py --env dev     # One env only
  python scripts/domains/generate_domain_runtime_audit.py --timeout 5   # Custom timeout
"""
from __future__ import annotations

import argparse
import json
import socket
import ssl
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required.  pip install pyyaml")

# ---------------------------------------------------------------------------
# Paths (relative to repo root)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
JSON_OUT = REPO_ROOT / "generated" / "domain" / "domain-runtime-audit.json"
MD_OUT = REPO_ROOT / "docs" / "reference" / "generated" / "domain-runtime-audit.md"


# ---------------------------------------------------------------------------
# Registry loader
# ---------------------------------------------------------------------------

def load_registry(path: Path) -> dict:
    """Load and return the tenant registry YAML."""
    with open(path) as fh:
        return yaml.safe_load(fh)


def collect_active_domains(
    registry: dict,
    env_filter: str | None = None,
) -> list[dict]:
    """Return domain entries with status=active, optionally filtered by env."""
    result = []
    for d in registry.get("domains", []):
        if d.get("status") != "active":
            continue
        if env_filter and d.get("environment") != env_filter:
            continue
        result.append(d)
    return result


# ---------------------------------------------------------------------------
# Probes
# ---------------------------------------------------------------------------

def probe_dns(hostname: str) -> tuple[bool, list[str]]:
    """Resolve hostname via DNS. Returns (ok, list_of_addresses)."""
    try:
        results = socket.getaddrinfo(hostname, 443, socket.AF_UNSPEC, socket.SOCK_STREAM)
        addresses = sorted({r[4][0] for r in results})
        return (True, addresses) if addresses else (False, [])
    except socket.gaierror:
        return False, []
    except Exception:
        return False, []


def probe_https(hostname: str, timeout: int) -> tuple[int | None, str | None]:
    """HTTPS GET to the hostname. Returns (status_code_or_None, error_or_None).

    We accept any HTTP status as "reachable"; only connection/TLS failures
    count as errors.
    """
    url = f"https://{hostname}/"
    # Create a permissive SSL context (we care about reachability, not cert validity)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    req = urllib.request.Request(
        url,
        method="HEAD",
        headers={"User-Agent": "mereka-domain-audit/1.0"},
    )

    try:
        resp = urllib.request.urlopen(req, timeout=timeout, context=ctx)
        return resp.status, None
    except urllib.error.HTTPError as exc:
        # HTTPError has a status code (e.g. 403, 502) — still reachable
        return exc.code, None
    except urllib.error.URLError as exc:
        return None, str(exc.reason)
    except TimeoutError:
        return None, "timeout"
    except Exception as exc:
        return None, str(exc)


# ---------------------------------------------------------------------------
# Output generators
# ---------------------------------------------------------------------------

def run_audit(
    domains: list[dict],
    timeout: int,
) -> tuple[list[dict], dict]:
    """Run DNS + HTTPS probes for each domain.

    Returns (probes_list, summary_dict).
    """
    probes: list[dict] = []
    dns_ok = dns_fail = https_ok = https_fail = 0

    total = len(domains)
    for i, d in enumerate(domains, 1):
        hostname = d["domain"]
        tenant = d.get("tenant", "")
        environment = d.get("environment", "")
        role = d.get("role", "")

        print(f"  [{i}/{total}] {hostname} ...", end=" ", flush=True)

        dns_resolves, dns_addresses = probe_dns(hostname)
        if dns_resolves:
            dns_ok += 1
        else:
            dns_fail += 1

        # Only probe HTTPS if DNS resolves
        if dns_resolves:
            status_code, https_error = probe_https(hostname, timeout)
        else:
            status_code, https_error = None, "dns_failed"

        if status_code is not None:
            https_ok += 1
        else:
            https_fail += 1

        operational = dns_resolves and status_code is not None

        status_label = (
            f"DNS={'OK' if dns_resolves else 'FAIL'} "
            f"HTTPS={status_code or 'FAIL'}"
        )
        print(status_label)

        probes.append({
            "hostname": hostname,
            "tenant": tenant,
            "environment": environment,
            "role": role,
            "status_declared": d.get("status", ""),
            "dns_resolves": dns_resolves,
            "dns_addresses": dns_addresses,
            "https_status": status_code,
            "https_error": https_error,
            "operational": operational,
        })

    summary = {
        "total_probed": total,
        "dns_ok": dns_ok,
        "dns_fail": dns_fail,
        "https_ok": https_ok,
        "https_fail": https_fail,
    }
    return probes, summary


def generate_json(
    probes: list[dict],
    summary: dict,
    now: str,
) -> str:
    """Return the JSON string for the runtime audit."""
    payload = {
        "generated_at": now,
        "source": "deploy/k8s/tenancy/tenant-registry.yaml",
        "probes": probes,
        "summary": summary,
    }
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def generate_markdown(
    probes: list[dict],
    summary: dict,
    now_date: str,
) -> str:
    """Return the Markdown string for the runtime audit."""
    lines: list[str] = []
    lines.append("# Domain Runtime Audit")
    lines.append("")
    lines.append(
        f"_Generated from `deploy/k8s/tenancy/tenant-registry.yaml`"
        f" on {now_date}._"
    )
    lines.append(
        "_Do not hand-edit. Regenerate with:"
        " `python scripts/domains/generate_domain_runtime_audit.py`_"
    )
    lines.append("")

    # Summary
    lines.append("## Summary")
    lines.append("")
    lines.append("| Metric | Count |")
    lines.append("|--------|-------|")
    lines.append(f"| Total probed | {summary['total_probed']} |")
    lines.append(f"| DNS OK | {summary['dns_ok']} |")
    lines.append(f"| DNS FAIL | {summary['dns_fail']} |")
    lines.append(f"| HTTPS OK | {summary['https_ok']} |")
    lines.append(f"| HTTPS FAIL | {summary['https_fail']} |")
    lines.append("")

    # Results table
    lines.append("## Probe Results")
    lines.append("")
    lines.append(
        "| Hostname | Tenant | Env | Role | DNS | HTTPS | Operational |"
    )
    lines.append(
        "|----------|--------|-----|------|-----|-------|-------------|"
    )

    for p in probes:
        dns_icon = "pass" if p["dns_resolves"] else "FAIL"
        https_icon = str(p["https_status"]) if p["https_status"] is not None else "FAIL"
        op_icon = "pass" if p["operational"] else "FAIL"
        lines.append(
            f"| `{p['hostname']}` "
            f"| {p['tenant']} "
            f"| {p['environment']} "
            f"| {p['role']} "
            f"| {dns_icon} "
            f"| {https_icon} "
            f"| {op_icon} |"
        )
    lines.append("")

    # Failures detail
    failures = [p for p in probes if not p["operational"]]
    if failures:
        lines.append("## Failures")
        lines.append("")
        for p in failures:
            error_detail = p.get("https_error") or "dns_failed"
            lines.append(f"- **{p['hostname']}** ({p['tenant']}/{p['environment']})")
            lines.append(f"  - DNS: {'OK' if p['dns_resolves'] else 'FAIL'}")
            if p["dns_addresses"]:
                lines.append(f"  - Addresses: {', '.join(p['dns_addresses'])}")
            lines.append(f"  - HTTPS: {p['https_status'] or 'FAIL'} ({error_detail})")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Probe active domains from the tenant registry for DNS + HTTPS."
    )
    parser.add_argument(
        "--env",
        type=str,
        default=None,
        help="Filter to a single environment (e.g. dev, production, staging).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=10,
        help="HTTPS probe timeout in seconds (default: 10).",
    )
    args = parser.parse_args()

    if not REGISTRY_PATH.exists():
        sys.exit(f"ERROR: Registry not found at {REGISTRY_PATH}")

    registry = load_registry(REGISTRY_PATH)
    domains = collect_active_domains(registry, env_filter=args.env)

    if not domains:
        env_msg = f" for --env={args.env}" if args.env else ""
        sys.exit(f"ERROR: No active domains found{env_msg}")

    print(f"Auditing {len(domains)} active domains ...")
    probes, summary = run_audit(domains, timeout=args.timeout)

    now = datetime.now(timezone.utc).isoformat()
    now_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    json_text = generate_json(probes, summary, now)
    md_text = generate_markdown(probes, summary, now_date)

    # Ensure output dirs exist
    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    MD_OUT.parent.mkdir(parents=True, exist_ok=True)

    JSON_OUT.write_text(json_text)
    MD_OUT.write_text(md_text)

    print(f"\nGenerated {JSON_OUT.relative_to(REPO_ROOT)} ({len(probes)} probes)")
    print(f"Generated {MD_OUT.relative_to(REPO_ROOT)}")
    print(
        f"\nSummary: {summary['dns_ok']} DNS OK, {summary['dns_fail']} DNS FAIL, "
        f"{summary['https_ok']} HTTPS OK, {summary['https_fail']} HTTPS FAIL"
    )

    # Non-zero exit if any failures
    if summary["dns_fail"] > 0 or summary["https_fail"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
