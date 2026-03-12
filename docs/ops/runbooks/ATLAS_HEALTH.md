# MongoDB Atlas Health Check
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

_Audience: Platform operators · Last updated: 2026-02-24_

## Overview

MongoDB Atlas is the **only** MongoDB option for Mereka LMS — there is no local MongoDB fallback in production. The Atlas health CI job provides a weekly signal that the configuration chain (Infisical → GCP Secret Manager → ExternalSecret → K8s Secret → pods) is intact and that the Atlas SRV dependency is correctly declared.

**Atlas cluster**: `cluster-mereka-lms.2pjex4s.mongodb.net`
**Databases**: `openedx` (modulestore), `cs_comments_service` (forum)

---

## What the CI Job Checks

The workflow (`.github/workflows/atlas-health.yml`) runs every Monday at 06:00 UTC and on manual dispatch. It executes `scripts/qa/verify-atlas-health.sh` in **offline mode** — no credentials required.

| Check | What it verifies |
|-------|-----------------|
| 1. config.sh reference | Atlas or `MONGODB_SRV` setting is acknowledged in shared config |
| 2. ExternalSecret password mapping | `MEREKA_LMS_MONGODB_PASSWORD` is mapped by ExternalSecret |
| 3. ADR-001 hostname | `cluster-mereka-lms.2pjex4s.mongodb.net` is documented |
| 4. Password not hardcoded | Password flows ExternalSecret → K8s Secret (no plaintext in repo) |
| 5. SRV format | `mongodb+srv://` is referenced in the config chain |
| 6. pymongo[srv] dep | `pymongo[srv]` is installed in the Docker image (needed for SRV DNS resolution) |

The job is `continue-on-error: true` — failures are informational and do not block merges. Check the weekly run summary for drift.

---

## Running Live Checks Manually

Live checks require a valid `MONGODB_URI` with read access to `openedx` and `cs_comments_service`.

```bash
# 1. Retrieve the URI from Infisical (run from any repo/workdir configured with `.infisical.json`)
cd <repo-root-with-infisical-context>
MONGO_USER=$(infisical secrets get MEREKA_LMS_MONGODB_USERNAME \
  --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null)
MONGO_PASS=$(infisical secrets get MEREKA_LMS_MONGODB_PASSWORD \
  --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null)

# 2. Run with --live flag
export MONGODB_URI="mongodb+srv://${MONGO_USER}:${MONGO_PASS}@cluster-mereka-lms.2pjex4s.mongodb.net/"
./scripts/qa/verify-atlas-health.sh --live
```

Required Python packages for online checks:

```bash
pip install pymongo[srv] dnspython
```

---

## Troubleshooting Atlas Connectivity

### DNS SRV lookup fails

```bash
# Check SRV records directly
python3 -c "
import dns.resolver
answers = dns.resolver.resolve('_mongodb._tcp.cluster-mereka-lms.2pjex4s.mongodb.net', 'SRV')
for r in answers: print(r)
"
```

Common causes:
- `dnspython` not installed (`pip install dnspython`)
- Corporate firewall blocking UDP/53 or TCP/53
- Atlas cluster paused (free tier auto-pauses after 60 days of inactivity)

### MongoDB ping fails

```bash
python3 -c "
import os
from pymongo import MongoClient
client = MongoClient(os.environ['MONGODB_URI'], serverSelectionTimeoutMS=5000)
print(client.admin.command('ping'))
"
```

Common causes:
- Wrong credentials — verify `MEREKA_LMS_MONGODB_USERNAME` / `MEREKA_LMS_MONGODB_PASSWORD` in Infisical
- GKE node IP not in Atlas network allowlist → Atlas Project → Network Access → Add IP
- `pymongo[srv]` not installed in the Open edX Docker image (check `apply-patches.sh`)

### ExternalSecret not syncing

```bash
# Check ExternalSecret status in cluster
kubectl get externalsecret openedx-secrets -n mereka-lms -o yaml | grep -A10 status

# Force a resync
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite
```

### Atlas cluster is paused

Atlas M0 (free tier) pauses after 60 days without connections. Log in to
[cloud.mongodb.com](https://cloud.mongodb.com) and resume the cluster.

---

## Configuration Chain Reference

```
Infisical (MEREKA_LMS_MONGODB_PASSWORD)
  └─> GCP Secret Manager (bbi-k8 project)
        └─> ExternalSecret (openedx-secrets, mereka-lms namespace)
              └─> K8s Secret (MONGODB_PASSWORD)
                    └─> Pod env var (MONGODB_PASSWORD)
                          └─> Django settings (DOC_STORE_CONFIG / FORUM_MONGODB_CLIENT_PARAMETERS)
                                └─> Atlas cluster-mereka-lms.2pjex4s.mongodb.net
```

See also:
- `docs/adr/historical/001-mongodb-atlas.md` — architectural decision record
- `deploy/k8s/base/secrets/external-secrets.yaml` — ExternalSecret mapping
- `infrastructure/tutor/apply-patches.sh` — `pymongo[srv]` installation
