# Security Incident Runbook: Supply-Chain Attacks

> **Owner**: platform-engineering
> **Last Updated**: 2026-02-24
> **Audience**: Small team (2-3 engineers). Practical, not bureaucratic.

This runbook covers detection, containment, and recovery for supply-chain security incidents — compromised dependencies, malicious packages, and tampered build artifacts.

---

## 1. Detection Signals

Any of these should trigger an investigation. Don't wait for confirmation before starting triage.

### Automated Alerts (highest priority — act immediately)
- **Dependabot / Dependency Review** flags a CRITICAL or HIGH severity CVE in a direct or transitive dependency
- **Trivy scan** (CI) outputs a known-malicious package name (e.g., typosquatted `colourama` vs `colorama`)
- **GitHub Advisory Database** notification for a package we pin by exact version
- **SBOM diff** (via `syft` or `trivy sbom`) shows an unexpected new dependency after a merge — especially a new transitive dep that wasn't in the prior SBOM

### Behavioral Signals (requires human judgment)
- CI job makes unexpected outbound network calls (visible in job logs or network egress alerts)
- Built artifacts (`*.whl`, Docker image layers) differ from what the source tree would produce
- Dependency hash mismatch: `pip install --require-hashes` or `npm ci` rejects a lockfile entry
- **OpenSSF Scorecard** for a dependency we rely on drops below 4.0 (check weekly via `scorecard` CLI or GitHub action results)

### Manual Discovery
- Security researcher disclosure (DM, email, CVE publication)
- Open edX community forum or Slack reports a compromised plugin we use

---

## 2. Severity Classification

| Level | Criteria | Examples |
|-------|----------|---------|
| **P1 — Critical** | Known exploited in the wild AND affects production data or auth | `xz-utils` backdoor scenario; malicious pip package with known C2 callback; CVE with public exploit AND we're running the vulnerable version in prod |
| **P2 — High** | Exploitable CVSS ≥ 8.0, no public exploit yet, or exploit requires network access we restrict | RCE in a library we use, but no active exploitation reported |
| **P3 — Medium** | Requires specific attacker-controlled conditions (e.g., authenticated user with staff role) | SSRF in an admin-only tool; CVSS 4–7.9 |
| **P4 — Low** | Theoretical / defense-in-depth; no realistic attack path in our deployment | Outdated crypto primitive in a library used only for non-sensitive hashing |

**Escalation rule**: When in doubt, classify one level higher. You can de-escalate once you have more facts.

---

## 3. Isolation and Response Steps

### P1 — Critical: Contain First, Investigate Second

**Target: containment within 30 minutes of detection.**

```bash
# Step 1: Roll back the affected image to last-known-good SHA
# Find the last clean image SHA before the dependency was introduced
gcloud artifacts docker images list \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx \
  --include-tags --sort-by ~UPDATE_TIME | head -10

# Roll back LMS/CMS deployment via GitOps (preferred)
# ⚠️  Direct kubectl mutations are blocked by Kyverno policy protect-gitops-managed-resources.
# Update the image tag in git and force ArgoCD sync:
cd deploy/k8s/overlays/production
kustomize edit set image openedx=ghcr.io/biji-biji-initiative/mereka-lms/openedx:<LAST_GOOD_SHA>
git add . && git commit -m "fix(security): roll back to <LAST_GOOD_SHA> — INC-NNN"
git push
argocd app sync mereka-lms --force

# Emergency bypass ONLY (if git push is impossible):
kubectl --as=system:serviceaccount:argocd:argocd-application-controller \
  set image deployment/lms \
  lms=ghcr.io/biji-biji-initiative/mereka-lms/openedx:<LAST_GOOD_SHA> \
  -n mereka-lms
# ⚠️  Follow up with a git commit within 5 minutes to prevent ArgoCD drift loop.

# Verify rollback completed
kubectl rollout status deployment/lms -n mereka-lms
```

```bash
# Step 2: Block the affected dependency from being installed in CI
# This repo uses Tutor (Docker-based). Dependencies are managed via Tutor patches.
# Add a pip constraint to block the vulnerable package:
#   Option A: Add to OPENEDX_EXTRA_PIP_REQUIREMENTS in tutor config
#   Option B: Add a constraint in infrastructure/tutor/apply-patches.sh
#
# Example — add version exclusion to Tutor config:
#   tutor config save --set 'OPENEDX_EXTRA_PIP_REQUIREMENTS=["<package>!=<bad_version>"]'
#   ./infrastructure/tutor/apply-patches.sh
#
# For purchase-gateway (pip-based): add exclusion to requirements.lock
#   echo "<package>!=<bad_version>" >> services/purchase-gateway/constraints.txt
#
# Track the block in the security exceptions register:
echo "| $(date -I) | <package>==<version> | CVE-XXXX-XXXXX | INC-NNN | $(date -d '+90 days' -I) |" \
  >> docs/policies/operations/SECURITY_EXCEPTIONS.md
```

```bash
# Step 3: Rotate secrets that may have been exfiltrated
# Check what secrets the affected service had access to:
kubectl get secret -n mereka-lms -o name | xargs -I{} \
  kubectl get {} -n mereka-lms -o jsonpath='{.metadata.name}: {.metadata.annotations}'

# Rotate via Infisical — run from reka-slackbot dir:
cd /home/gurpreet/projects/k8s/reka-slackbot
infisical secrets set MEREKA_LMS_<SECRET_NAME>="<NEW_VALUE>" \
  --domain https://secrets.mereka.io/api --env prod --path /
```

**Notify team immediately** (see Communications Templates below). Do not wait until fully diagnosed.

---

### P2 — High: Pin and Track

**Target: fix deployed within 4 hours.**

```bash
# Pin the affected package to last-known-good version
# For Python (requirements/*.txt):
# Change: some-package>=1.2.0
# To:     some-package==1.1.9  # pinned: CVE-XXXX-XXXXX, fix pending

# For Node (package.json overrides):
# Add to package.json:
# "overrides": { "vulnerable-package": "1.1.9" }

# Commit the pin:
git add requirements/ package.json
git commit -m "fix(security): pin <package> to <version> pending CVE-XXXX remediation"
git push
```

Open a tracking issue immediately:

```
Title: [SECURITY] CVE-XXXX-XXXXX in <package> — remediation tracking
Body:
- CVE: <link>
- Affected version: <version>
- Pinned to: <version> (temporary)
- Fix available in: <version> (if known)
- Owner: @<name>
- Target fix date: <date within 7 days>
```

---

### P3/P4 — Medium/Low: Register and Schedule

Add to the security exceptions register (create at `docs/policies/operations/SECURITY_EXCEPTIONS.md` if absent):

```markdown
| ID | Package | CVE | CVSS | Rationale | Pinned Version | Review Date | Owner |
|----|---------|-----|------|-----------|----------------|-------------|-------|
| SE-001 | <package> | CVE-XXXX | 5.4 | Requires admin access; admin login restricted to VPN | <version> | <date+90d> | @name |
```

Review the register every 90 days or after any related P1/P2 incident.

---

## 4. Communications Templates

### Internal Slack — Initial Alert

Post to `#engineering` (or equivalent):

```
:rotating_light: [SECURITY] Supply-chain alert — <P1|P2|P3>

Package: <name> <version>
CVE: <link>
Impact: <one line — what's at risk>
Status: Investigating / Contained / Remediated

What we know:
- <brief summary>

Current action:
- <what is being done right now>

Next update: <time, e.g. "in 30 minutes" or "once containment confirmed">

IC: @<name>
```

For P3/P4, a single message with no follow-up cadence is fine.

---

### Internal Slack — Resolution

```
:white_check_mark: [SECURITY RESOLVED] <CVE / incident name>

Duration: <X hours>
Root cause: <one line>
Fix: <what was done>
User impact: <none | describe>

Postmortem: <link or "not required for P3/P4">
```

---

### External Disclosure (only if user data was accessed or exfiltrated)

Send from `security@mereka.io` (or `admin@mereka.io`) within 72 hours of confirmed data access:

```
Subject: Security Notice — Mereka Academy

We are writing to inform you of a security incident that may have affected your account.

What happened:
On [DATE], we identified that [BRIEF NON-TECHNICAL DESCRIPTION].

What information was involved:
[LIST ONLY WHAT IS CONFIRMED — e.g., "email addresses and course enrollment history"]

What we have done:
- [Action 1]
- [Action 2]

What you should do:
- Change your Mereka Academy password at https://academyv2.mereka.io/password_reset
- If you use the same password elsewhere, change it there too

Questions:
Contact us at security@mereka.io

— The Mereka Academy Team
```

**Do not send external disclosure for P3/P4 unless legal counsel advises otherwise.**

---

### Response Timeline Expectations

| Severity | Acknowledge (Slack) | Containment | External Disclosure |
|----------|--------------------|---------|--------------------|
| P1 | Within **1 hour** | Within **30 minutes** of ack | Within **72 hours** if data accessed |
| P2 | Within **4 hours** | Within **4 hours** | Not required unless data accessed |
| P3 | Within **24 hours** | Scheduled (within 7 days) | Not required |
| P4 | Within **24 hours** | Scheduled (within 90 days) | Not required |

---

## 5. Post-Incident Review Checklist

Run this after every P1 or P2. For P3/P4 it's optional but recommended if the same pattern recurs.

### Required (P1/P2)

- [ ] **Root cause identified**: Which package, which version, how it entered the dependency graph (direct vs transitive, which upgrade introduced it)
- [ ] **Timeline documented**: Detection → containment → remediation, with actual timestamps
- [ ] **Affected secrets rotated**: All credentials accessible to the compromised service are rotated, even if not confirmed exfiltrated
- [ ] **Detection gap closed**: Would this have been caught sooner with a tighter scan policy, pinned hashes, or earlier alert routing? Implement the fix.
- [ ] **Dependency audit**: Run `pip-audit` / `npm audit` / `trivy fs .` against the full tree to find similar patterns in adjacent packages
- [ ] **SBOM updated**: Regenerate `sbom.json` (via `syft`) and commit it so the next diff is clean
- [ ] **Security exceptions register updated**: If we accepted residual risk temporarily, add the entry

### Learning Capture (always)

- [ ] **CLAUDE.md / runbook updated**: If this incident revealed a gap in our detection setup or response steps, update this file now
- [ ] **Postmortem filed** (P1/P2 only): `docs/operations/postmortems/YYYY-MM-DD-supply-chain-<slug>.md` — use the template in `INCIDENT_TEMPLATES.md`

---

## 6. Quick Reference Commands

```bash
# Scan running images for CVEs
trivy image ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest

# Scan local filesystem dependencies
trivy fs . --severity HIGH,CRITICAL

# Audit Python deps
pip install pip-audit && pip-audit -r requirements/production.txt

# Audit Node deps
npm audit --audit-level=high

# Generate SBOM (requires syft)
syft ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest \
  -o cyclonedx-json > sbom.json

# Diff SBOM against previous (requires cyclonedx-cli)
cyclonedx diff sbom-prev.json sbom.json --component-versions

# Check OpenSSF Scorecard for a dependency
scorecard --repo github.com/<org>/<repo>
```

---

## Related Documents

- `docs/runbooks/operations/INCIDENT_TEMPLATES.md` — postmortem template
- `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` — secret rotation procedure
- `docs/reference/operations/SECRETS_SNAPSHOT.md` — current secret inventory
- `specs/secrets-management.md` — secrets architecture
