# MongoDB Atlas Migration Guide
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-02-04_

This guide explains how to move `cs_comments_service` (forum) data from an in-cluster MongoDB to MongoDB Atlas and point the forum service at the managed cluster.

Important:
- This document is **forum-focused**.
- LMS/CMS modulestore cutover to Atlas is a separate migration and must be planned/verified independently.

## 1. Provision Atlas resources

1. Sign in to https://cloud.mongodb.com/ and create a **Dedicated (M10)** cluster in **AWS `ap-southeast-1`** so latency stays low.
2. Under *Database Access*, create a database user (e.g. `cs_comments_user`) with password of your choosing and grant **Read and write to any database** (or a scoped role for `cs_comments_service`).
3. Under *Network Access*, allow outbound IPs from the GKE cluster and the VPS kind cluster. We intentionally use public IP allowlists (no private connectivity).
   - **GKE (production)**: grab the current egress IP(s) by running:
   ```bash
   kubectl run egress-check --rm -i --image=curlimages/curl --restart=Never -- \
     curl -s https://ifconfig.me
   ```
   - **VPS kind (dev)**: check from the VPS shell: `curl -s https://ifconfig.me`

   **As of 2026-02-04**, the VPS egress IP is `194.233.84.55`. Add it to the Atlas allowlist and update whenever the VPS IP changes.

## 2. Migrate existing data (Forum only)

Use the helper script to stream the StatefulSet data directly into Atlas. Set `ATLAS_URI` to the connection string Atlas provides (include `retryWrites=true&w=majority`).

```bash
ATLAS_URI="mongodb+srv://cs_comments_user:<password>@cluster0.abcde.mongodb.net/cs_comments_service?retryWrites=true&w=majority"
./scripts/infra/mongodb-to-atlas.sh
```

The script runs `mongodump` inside `mongodb-0` and pipes it to `mongorestore` (via the official `mongo` Docker image) so the Atlas cluster receives a fresh copy of `cs_comments_service`.

### One-command cutover (data + Tutor config)

To automate the entire migration—including dumping data, updating Tutor overrides, restarting deployments, and storing the URI in Secret Manager—run:

```bash
ATLAS_URI="mongodb+srv://cs_comments_user:<password>@cluster0.abcde.mongodb.net/cs_comments_service?retryWrites=true&w=majority" \
  ./scripts/infra/mongodb-atlas-cutover.sh
```

Environment flags:

| Variable | Default | Purpose |
|----------|---------|---------|
| `RUN_MIGRATION` | `true` | Set to `false` if you already ran `mongodb-to-atlas.sh` and just want to flip Tutor. |
| `UPDATE_SECRET` | `true` | Controls whether the script writes the URI into the `mongodb-atlas-uri` Secret Manager secret. |
| `CLEANUP_STATEFULSET` | `false` | When `true`, deletes the `mongodb` StatefulSet + PVC after Tutor connects to Atlas. |
| `NAMESPACE` / `STATEFULSET` / `PVC_NAME` | `mereka-lms` / `mongodb` / `data-mongodb-0` | Override if your dev namespace differs. |
| `TUTOR_CMD` | `tutor` | Change if you prefer `tutor --config=...` wrappers. |

The script sources `infrastructure/tutor/tutor-env.sh`, runs `tutor config save --set RUN_MONGODB=false --set MONGODB_URI="…"`, restarts the Kubernetes workloads (`tutor k8s start`), waits for the `forum` deployment rollout, and optionally deletes the legacy StatefulSet.

## 3. Point Tutor at Atlas

1. Update the Tutor config to use the connection string and disable the in-cluster MongoDB:
   ```bash
   source infrastructure/tutor/tutor-env.sh
   tutor config save --set RUN_MONGODB=false \
     --set MONGODB_URI="$ATLAS_URI" \
     --set MONGODB_AUTH="" \
     --set MONGODB_HOST="" --set MONGODB_PORT=""
   tutor k8s start
   ```
   The patched forum entrypoint now honors `MONGODB_URI`, so the cs_comments pods will connect directly to Atlas (TLS and replica-set parameters are preserved from the URI).
2. Once the Atlas connection is verified (`kubectl logs deployment/forum -n mereka-lms`), scale the legacy StatefulSet down to zero or delete it:
   ```bash
   kubectl delete statefulset -n mereka-lms mongodb
   kubectl delete pvc -n mereka-lms data-mongodb-0
   ```
   (Keep a copy of the PVC backup before deleting if you may need to roll back.)

Do not remove the in-cluster MongoDB if LMS/CMS modulestore is still using it.
Verify `MONGODB_HOST` in LMS/CMS and confirm course content reads correctly from Atlas before cleanup.

## 4. Store and rotate credentials

Load the Atlas URI into Google Secret Manager so CI/CD pipelines and operators can read it without touching this repo:

```bash
printf '%s' "$ATLAS_URI" | gcloud secrets create mongodb-atlas-uri --data-file=-
```

For updates/rotation run `gcloud secrets versions add mongodb-atlas-uri --data-file=-` instead of creating a new secret.  Tutor can then be configured with:

```bash
ATLAS_URI=$(gcloud secrets versions access latest --secret=mongodb-atlas-uri)
tutor config save --set RUN_MONGODB=false --set MONGODB_URI="$ATLAS_URI"
```

Document the secret ID in `docs/SECRETS_SNAPSHOT.md` and rotate the Atlas database user password regularly.

> **Infisical note:** Atlas API keys now live under `/k8s/mereka-lms/atlas` and are pulled via
> `scripts/infra/atlas-config-from-infisical.sh`.

## 5. Ongoing maintenance

- Rotate the Atlas database user password periodically and update `MONGODB_URI` (run `tutor config save` + `tutor k8s start`).
- Keep the Atlas cluster metrics in Cloud Monitoring by adding the Atlas Prometheus integration (optional).
- We intentionally keep Atlas on public allowlists. Monitor drift with:
  - `kubectl run egress-check --rm -i --image=curlimages/curl --restart=Never -- curl -s https://ifconfig.me`
  - `atlas accesslists list --projectId <projectId>` (confirm allowlist matches egress)
  - `./scripts/infra/check-atlas-allowlist.sh` (automated check; supports `ATLAS_PROFILE` + Infisical profile refresh)

### VPS Automation (dev)

The VPS (kind) environment runs a cron-based allowlist monitor so drift is detected quickly:

```bash
/home/gurpreet/projects/k8s/mereka-lms/scripts/infra/monitor-atlas-allowlist-vps.sh
```

Cron entry (installed on VPS):

```bash
*/30 * * * * gurpreet /home/gurpreet/projects/k8s/mereka-lms/scripts/infra/monitor-atlas-allowlist-vps.sh >> /home/gurpreet/projects/k8s/mereka-lms/var/atlas-allowlist.log 2>&1
```

Optional webhook alerting (recommended):

```bash
ATLAS_ALLOWLIST_WEBHOOK_URL=<your-webhook-url> ./scripts/infra/monitor-atlas-allowlist-vps.sh
```
