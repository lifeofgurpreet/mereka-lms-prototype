# Tenant Drift Investigation Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

> **Alert source**: `tenant-safety-audit` GitHub Actions workflow (daily @ 02:00 UTC)
>
> **Last updated**: 2026-03-05

## Quick Triage (< 5 minutes)

```bash
# 1. Download the failed workflow artifact
#    GitHub UI: Actions → Tenant Safety Drift Audit → <run> → Artifacts

# 2. Parse the JSON report locally
python3 -c "
import json, sys
d = json.load(open('tenant-safety-audit-prod.json'))
print(f\"Failures: {d['failures_count']}\")
for f in d['failures']:
    print(f\"  [{f['category']}] {f['message']}\")
"

# 3. Run the audit locally to reproduce
OUTPUT_FORMAT=json STRICT=1 \
  ./scripts/qa/audit-tenant-config-safety.sh \
  --file infrastructure/tutor/multisite-sites.yml \
  | python3 -m json.tool
```

## Failure Categories

### `host_collision`

**What it means**: Two or more tenant definitions claim the same LMS, CMS, or MFE hostname.

**Common causes**:
- A new tenant was added by copying an existing entry without updating all URL fields.
- A bootstrap operation updated `multisite-sites.yml` but missed the CMS or MFE URL.
- A shared-host allowlist entry expired and the underlying config was never fixed.

**Investigation steps**:
```bash
# Show all host→domain mappings
OUTPUT_FORMAT=json STRICT=0 ./scripts/qa/audit-tenant-config-safety.sh \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d['failures']:
    if f['category'] == 'host_collision':
        print(f['message'])
"

# Check the raw YAML for duplicate entries
grep -n "LMS_ROOT_URL\|CMS_ROOT_URL\|MFE_BASE_URL" \
  infrastructure/tutor/multisite-sites.yml | sort -t: -k3
```

**Fix**:
1. Edit `infrastructure/tutor/multisite-sites.yml` and assign unique hosts to the colliding tenants.
2. If the collision is intentional for preview/dev environments, add the host to `infrastructure/tutor/multisite-shared-host-allowlist.txt` with `owner=<team>` and `expires=<YYYY-MM-DD>`.
3. Re-run the audit to confirm zero failures.
4. Open a PR and merge. The audit runs again on push to main.

---

### `allowlist_policy`

**What it means**: An entry in `multisite-shared-host-allowlist.txt` violates governance rules.

Sub-cases:
- **Expired entry**: `expires=` date is in the past.
- **Missing expiry**: Entry has no `expires=` field.
- **Missing owner**: Entry has no `owner=` field.
- **Non-preview host**: Allowlisted host is an enterprise (production) domain — this is never permitted.

**Common causes**:
- Allowlist entry was created for a time-limited test environment and never cleaned up.
- Entry was added manually without the required metadata.

**Investigation steps**:
```bash
cat infrastructure/tutor/multisite-shared-host-allowlist.txt
```

**Fix** (expired or missing metadata):
1. Either remove the stale entry or extend `expires=` to a future date.
2. If extending: confirm the shared-host situation still applies and set `owner=` to the responsible team.
3. Every entry MUST have both `owner=` and `expires=`.

**Fix** (non-preview host flagged):
1. Remove the allowlist entry — production/enterprise domains are NEVER permitted to share CMS or MFE hosts across tenants.
2. Fix the underlying config collision (see `host_collision` above).

---

### `schema_violation`

**What it means**: A site definition in the YAML file is structurally invalid.

Sub-cases:
- Missing `domain` field.
- Invalid domain format (fails RFC 1123 regex).
- Missing required `site_values` keys (`LMS_ROOT_URL`, `CMS_ROOT_URL`, `MFE_BASE_URL`).
- Top-level `sites` key is not a list.

**Common causes**:
- Incomplete copy-paste when adding a new tenant.
- YAML indentation error (key landed at wrong nesting level).
- Tenant provisioned via `scripts/tenants/provision-tenant.sh` but YAML was edited by hand afterward.

**Investigation steps**:
```bash
# Lint the YAML file directly
python3 -c "import yaml; yaml.safe_load(open('infrastructure/tutor/multisite-sites.yml'))" \
  && echo "YAML parses OK" || echo "YAML parse error"

# Run audit in text mode for human-readable output
./scripts/qa/audit-tenant-config-safety.sh \
  --file infrastructure/tutor/multisite-sites.yml
```

**Fix**:
1. Open the YAML file and correct the malformed entry.
2. Use `scripts/tenants/provision-tenant.sh --dry-run` to validate before committing.
3. Re-run the audit.

---

### `host_ownership`

**What it means**: A tenant's `LMS_ROOT_URL` host does not match its own `domain` field.

Each tenant's LMS host MUST be identical to its canonical domain. Mismatches break Caddy routing and Open edX `Site` configuration lookup.

**Common causes**:
- `LMS_ROOT_URL` was set to a CDN or vanity domain that differs from the canonical routing domain.
- Copy-paste from a different tenant entry, domain was updated but `LMS_ROOT_URL` was not.

**Fix**:
1. Set `LMS_ROOT_URL: "https://<domain>"` where `<domain>` matches the `domain:` field exactly.
2. Run `./scripts/qa/audit-tenant-config-safety.sh` to confirm.

---

## Rollback Actions

### Revert a bad YAML change

```bash
# Show what changed
git log --oneline -5 infrastructure/tutor/multisite-sites.yml

# Revert a specific commit (replace <sha> with the bad commit)
git revert <sha> --no-edit

# Or reset to last known-good state
git show <last-good-sha>:infrastructure/tutor/multisite-sites.yml \
  > infrastructure/tutor/multisite-sites.yml
git add infrastructure/tutor/multisite-sites.yml
git commit -m "revert: restore multisite-sites.yml to last known-good state"
git push
```

After reverting, the daily audit and any open PR checks will re-run automatically.

### Roll back a live tenant change (K8s)

If a bad tenant config was already applied to the cluster via `provision-tenant.sh`:

```bash
# Check which Sites exist in the LMS DB (requires cluster access)
kubectl exec -n mereka-lms \
  $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name | head -1) \
  -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
for s in Site.objects.all(): print(s.id, s.domain, s.name)
"

# Remove a bad Site entry (replace 99 with the actual site ID)
kubectl exec -n mereka-lms \
  $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name | head -1) \
  -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
Site.objects.filter(id=99).delete()
print('Deleted')
"
```

After fixing the DB, also fix the YAML file and raise a PR so git reflects reality.

## Escalation Path

| Condition | Action |
|-----------|--------|
| `host_collision` on a production domain (`*.mereka.io`) | P0 — tenant data isolation at risk. Page on-call. |
| `allowlist_policy` expired entry in use in prod | P1 — fix within 24 hours before next audit cycle. |
| `schema_violation` blocking bootstrap | P1 — prevents new tenant onboarding. Fix and merge. |
| Repeated failures across 3+ consecutive daily runs | Review `docs/ops/runbooks/TENANT_ONBOARDING_PLAYBOOK.md` and open a bead. |

## References

- Audit script: `scripts/qa/audit-tenant-config-safety.sh`
- Branding fallback: `scripts/qa/verify-tenant-branding-fallback.sh`
- Host collision check: `scripts/shared/multisite_bootstrap_django.py --check`
- Allowlist file: `infrastructure/tutor/multisite-shared-host-allowlist.txt`
- Tenant onboarding: `docs/ops/runbooks/TENANT_ONBOARDING_PLAYBOOK.md`
- Multi-tenancy architecture: `docs/reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`
- Provisioning script: `scripts/tenants/provision-tenant.sh`
