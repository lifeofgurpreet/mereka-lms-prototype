# ESCALATION: Staging Environment Down
**Date:** 2025-11-24  
**Severity:** CRITICAL  
**Status:** Needs Senior Developer Action  
**Reporter:** ChatGPT (AI pair-programmer)  
**Impact:** PM cannot review staging; all user-facing URLs timing out or redirecting to dead HTTPS

---

## Executive Summary
- Staging (GKE namespace `mereka-lms`) went offline because core services (caddy, lms, cms) lost all endpoints when their service selectors drifted from current pod labels. This blocked all HTTP/HTTPS traffic.  
- The public caddy Service was also missing port 443, so the load balancer only exposed HTTP. Even after selectors were fixed, HTTPS continued to fail until the port was added and GCP LB propagated.  
- We need a senior developer with cluster access to re-verify selectors and LB ports, then add guardrails so selector drift cannot silently take the site down again.

---

## What Happened (Evidence)
- `docs/PRODUCTION_STATUS.md` (updated 2025-11-24) records that `caddy`, `cms`, and `lms` Services had **no endpoints**, rendering the site unreachable. Running `./scripts/infra/fix-service-selectors.sh` repointed selectors to the current pod instance IDs.  
- The caddy Service originally exposed only port 80; port 443 was added via `kubectl patch svc caddy ...` (see same doc). HTTPS remained pending while the GCP LoadBalancer propagated.  
- Current kube state is unknown—selectors could drift again after any pod restart or `tutor k8s` operation if the script is not re-run.

---

## Root Cause Analysis
1) **Service selector drift after pod restarts**  
   - Services (caddy, lms, cms) were still selecting old `pod-template-hash` labels after new ReplicaSet rollouts. Result: `<none>` endpoints → 100% outage.  
   - No automation re-syncs selectors when pods roll; drift can recur on any restart or redeploy.

2) **Incomplete LB exposure (missing HTTPS port)**  
   - Caddy Service lacked port 443, so LB never opened TLS. Users hitting `https://academyv2.mereka.io` saw timeouts even once selectors were corrected.  
   - Propagation delay on GCP LB masked the fix; requires verification after each change.

---

## Immediate Action Plan (Senior Dev)
0. **Run quick repair (selectors + HTTPS)**
   ```bash
   ./scripts/infra/repair-staging-routing.sh mereka-lms
   ```
   - Fixes selector drift and ensures caddy exposes 443 in one pass.

1. **If requests hang but pods/selectors look healthy: fix Redis host drift**
   ```bash
   kubectl get cm openedx-config-5t8bdcb64h -n mereka-lms -o yaml \
     | sed 's/10\\.[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+:6379/redis:6379/g' \
     | kubectl apply -f -
   kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
   ```
   - Symptom: `curl http://lms:8000` hangs; Redis in configmap points to a stale IP instead of `redis:6379`.

1. **If login fails (CSRF 403/500): ensure Auth MFE + cookies**
   ```bash
   # In openedx-config-*.json set:
   #   LOGIN_MICROFRONTEND_URL = LOGISTRATION_MICROFRONTEND_URL = https://apps.academyv2.mereka.io/authn
   #   CSRF_TRUSTED_ORIGINS includes staging/studio/apps/academy.biji-biji.com/skillourfuture.*
   #   CSRF_COOKIE_DOMAIN=academyv2.mereka.io
   #   SESSION_COOKIE_DOMAIN=.academyv2.mereka.io
   kubectl rollout restart deploy/lms deploy/cms -n mereka-lms
   ```

1. **Re-verify endpoint health (must confirm now)**
   ```bash
   kubectl get endpoints -n mereka-lms caddy cms lms
   kubectl describe svc caddy -n mereka-lms | grep -E \"Ports|Selector\"
   ```
   - Expect non-empty endpoints and ports `80/TCP` + `443/TCP`.

2. **Reapply selector fix if any `<none>` found**
   ```bash
   ./scripts/infra/fix-service-selectors.sh mereka-lms
   kubectl get endpoints -n mereka-lms caddy cms lms
   ```

3. **Confirm HTTPS is live**
   ```bash
   curl -Ik https://academyv2.mereka.io
   curl -Ik https://34.126.186.80      # LB IP in PRODUCTION_STATUS.md
   ```
   - Should return `HTTP/2 200` (or 308 to HTTPS) with `server: Caddy`.

4. **Check GCP LB health checks**
   ```bash
   gcloud compute backend-services list
   gcloud compute health-checks list
   ```
   - Ensure backend for `caddy` shows healthy on ports 80 and 443.

5. **Lock in guardrails (prevents recurrence)**
   - Add a post-deploy hook or CronJob to run `fix-service-selectors.sh` after any rollout.
   - Add a small canary/uptime probe (HTTPS) hitting `academyv2.mereka.io` and alert on 5xx/timeouts.
   - Document “run selector fix + verify endpoints” in the deploy runbook checklist.

---

## Decision Matrix (if problems persist)
- **Option A (preferred):** Keep current setup, automate selector sync + LB HTTPS verification. Minimal risk, fastest restore.  
- **Option B:** Recreate caddy Service to a fresh ClusterIP + LB if selectors keep drifting (rare). More disruptive, requires DNS/LB validation.  
- **Option C:** Roll back to prior ReplicaSet versions that still match existing selectors (stop-gap only).

---

## Verification Checklist (complete when fixed)
- `kubectl get endpoints -n mereka-lms caddy cms lms` → all show pod IPs  
- `kubectl get svc caddy -n mereka-lms -o jsonpath='{.spec.ports[*].port}'` → `80 443`  
- `curl -Ik https://academyv2.mereka.io` → `HTTP/2 200` (or 308 redirect to HTTPS)  
- PM confirms LMS/Studio/MFE load on domain over HTTPS

---

## Notes & Risks
- Selector drift is the historically documented top cause of outages in this repo (`docs/ops/runbooks/TROUBLESHOOTING.md`). Without automation, it will recur after pod churn.  
- GKE Autopilot may recreate pods during maintenance; schedule a daily endpoint check until guardrails are in place.  
- If HTTPS still fails after ports/health checks are confirmed, inspect Caddy logs (`kubectl logs -n mereka-lms deploy/caddy --tail=200`) for TLS issuance/renewal issues.
