# Secret Scanning

This document covers both layers of secret scanning in this repository: the local pre-commit hook and GitHub Advanced Security (GHAS) secret scanning.

---

## Two Layers of Defence

| Layer | Where it runs | Blocking? | Coverage |
|-------|--------------|-----------|----------|
| Pre-commit hook (`.githooks/pre-commit`) | Developer's machine | Yes — blocks the commit | Staged files only; regex patterns for passwords, API keys, JWTs, DB connection strings, etc. |
| GHAS secret scanning | GitHub (cloud) | Via push protection | Full git history + all future pushes; 200+ partner token patterns |

The two layers are complementary. The pre-commit hook gives instant local feedback. GHAS catches anything that slipped through, scans historical commits, and notifies via the Security tab.

---

## Enabling GHAS (One-Time Setup)

GHAS secret scanning is a GitHub platform feature and must be enabled at the repository (or organisation) level. The config file in `.github/secret-scanning.yml` takes effect once the feature is on.

1. Go to **Settings → Security → Code security and analysis**.
2. Enable **Secret scanning**.
3. Enable **Push protection** to block pushes containing detected secrets.

The `paths-ignore` list in `.github/secret-scanning.yml` excludes documentation and runtime artefacts from scanning to reduce noise.

---

## Handling a Secret Scanning Alert

When GHAS detects a secret, an alert appears in **Security → Secret scanning alerts**.

Follow this order every time:

1. **Rotate or revoke** the exposed credential immediately. Do not wait.
   - Treat the secret as fully compromised from the moment of the earliest commit that contained it.
2. **Audit access logs** for the affected service to check for unauthorised use.
3. **Remove the secret from git history** if required by your organisation's policy:
   ```bash
   git filter-repo --path-glob '<file>' --invert-paths
   # or use BFG Repo Cleaner
   ```
   For most cases on a private repo, rotating the credential is sufficient.
4. **Dismiss the alert** in the GitHub UI once the credential is rotated. Select the correct reason (`Revoked`, `Used in tests`, or `False positive`).
5. **Document** the incident in the relevant bead or incident log.

---

## Push Protection

When push protection is enabled, GitHub intercepts a push that contains a recognised secret pattern and rejects it with an error like:

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - GITHUB PUSH PROTECTION
remote:   —————————————————————————————————————
remote:   Location: commit <sha>, path <file>:<line>
remote:   Match: GitHub Personal Access Token
```

The developer must either:
- **Remove the secret** from the commit and force-push (preferred), or
- **Request a bypass** via the URL shown in the error message (requires reviewer approval).

Bypasses are logged in the Security tab audit trail.

---

## Adding Custom Patterns

To detect project-specific tokens (e.g. a Mereka internal API key format):

1. Go to **Settings → Security → Code security and analysis → Custom patterns**.
2. Click **New pattern**.
3. Provide a regex, test strings, and a display name.
4. Save and optionally enable push protection for the custom pattern.

Custom patterns supplement the 200+ built-in partner patterns; they do not replace them.

---

## Weekly TruffleHog Audit

A scheduled workflow (`.github/workflows/secret-scan-audit.yml`) runs TruffleHog weekly against the full repository history. Results are uploaded as a workflow artifact. The job is non-blocking initially — review the artifact and promote findings to alerts manually.

To review results:
1. Go to **Actions → Secret Scan Audit**.
2. Open the latest run and download the `trufflehog-results` artifact.
3. Review for true positives and follow the alert-handling steps above.

---

## Disclosure Process

For vulnerabilities found in this repository, follow the process in [SECURITY.md](../../../SECURITY.md).
