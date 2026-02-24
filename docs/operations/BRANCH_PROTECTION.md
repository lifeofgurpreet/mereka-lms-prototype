# Branch Protection Requirements

<!-- Last verified: 2026-02-24 -->

This document specifies the required GitHub branch protection settings for the
`main` branch and explains how they contribute to the repository's OpenSSF
Scorecard score.

---

## Required Settings for `main`

| Setting | Required Value | Why |
|---------|---------------|-----|
| Require pull request reviews before merging | Enabled, minimum 1 reviewer | Prevents unreviewed code reaching production |
| Dismiss stale pull request approvals on new commits | Enabled | Ensures re-review after changes; Scorecard `Code-Review` check |
| Require status checks to pass before merging | Enabled (see list below) | Gates on CI, IaC scan, and lint |
| Require branches to be up to date before merging | Enabled | Prevents stale-branch merges bypassing checks |
| Restrict who can push to matching branches | Enabled (no direct push) | Enforces PR workflow for all contributors |
| Allow force pushes | Disabled | Preserves audit trail; Scorecard `Branch-Protection` check |
| Allow deletions | Disabled | Protects history |
| Require signed commits | Optional now; escalate per T064 | Scorecard `Signed-Releases` / `Branch-Protection` partial credit |

### Required Status Checks

These check names must match the job names reported by GitHub Actions:

| Check Name | Workflow File | Purpose |
|------------|--------------|---------|
| `Spec Integrity Gates` | `ci.yml` | Spec lint, testmap validation, coverage |
| `Generated Docs Are Up To Date` | `ci.yml` | Ensures generated docs are committed |
| `Design Token Validation` | `ci.yml` | Token contract |
| `Branding Preflight (Source)` | `ci.yml` | Branding gate |
| `Monitoring Guardrails` | `ci.yml` | Alert routing lint |
| `Lint` | `ci.yml` | Shell, Python, repo-structure lint |
| `Verify Actions Pinned` | `ci.yml` | SHA-pinning policy (supply chain) |
| `Trivy — K8s Manifests` | `iac-scan.yml` | K8s security scan |
| `Trivy — Terraform` | `iac-scan.yml` | Terraform security scan |

> **Note**: After enabling branch protection, trigger at least one PR so GitHub
> learns each check name. Status check names in the UI are populated from real
> runs, not workflow file names.

---

## OpenSSF Scorecard Alignment

The repository runs [OpenSSF Scorecard](https://github.com/ossf/scorecard) via
`.github/workflows/scorecard.yml` on every push to `main` and weekly on Monday
at 06:00 UTC.

### Target Score: 7 / 10

| Scorecard Check | Impact | How Branch Protection Helps |
|----------------|--------|----------------------------|
| `Branch-Protection` | High | All settings in the table above directly raise this score |
| `Code-Review` | High | Require PR reviews + dismiss stale approvals |
| `CI-Tests` | Medium | Required status checks gate merges on CI |
| `Pinned-Dependencies` | High | Enforced by `verify-actions-pinned.sh` in CI (not branch protection directly, but blocks merges that violate the policy) |
| `Signed-Releases` | Medium | Require signed commits when escalated per T064 |
| `Vulnerabilities` | High | Dependency Review workflow (`dependency-review.yml`) runs on PRs |
| `SAST` | Medium | CodeQL (`codeql.yml`) runs on PRs and push to main |

### Checks Not Directly Tied to Branch Protection

These Scorecard checks are addressed elsewhere in the repo:

| Check | Where It Is Addressed |
|-------|-----------------------|
| `Token-Permissions` | All workflows use `permissions: {}` at top level and grant least-privilege per-job |
| `Security-Policy` | `SECURITY.md` in repo root |
| `Maintained` | Active commit history |

---

## Configure via GitHub UI

1. Go to **Settings → Branches** in the repository.
2. Click **Add branch ruleset** (or edit the existing `main` ruleset).
3. Set **Target branches** to `main`.
4. Enable the settings listed in the table above:
   - **Require a pull request before merging**: checked
     - Set **Required approvals** to `1`
     - Check **Dismiss stale pull request approvals when new commits are pushed**
   - **Require status checks to pass**:
     - Check **Require branches to be up to date before merging**
     - Add each check name from the table above
   - **Block force pushes**: checked
   - **Restrict deletions**: checked
5. Click **Save changes**.

> GitHub's new **Rulesets** interface (not the legacy branch protection page) is
> preferred. Rulesets support bypass actors and are exported via API.

---

## Configure via `gh api`

Use this to automate or audit the settings in CI or a runbook.

### Check Current Settings

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --header "Accept: application/vnd.github+json"
```

### Apply Protection (REST API — legacy branch protection endpoint)

```bash
OWNER="your-org"
REPO="mereka-lms"

gh api \
  --method PUT \
  "repos/${OWNER}/${REPO}/branches/main/protection" \
  --header "Accept: application/vnd.github+json" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Spec Integrity Gates",
      "Generated Docs Are Up To Date",
      "Design Token Validation",
      "Branding Preflight (Source)",
      "Monitoring Guardrails",
      "Lint",
      "Verify Actions Pinned",
      "Trivy — K8s Manifests",
      "Trivy — Terraform"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismissal_restrictions": {},
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": false
}
EOF
```

> The API call above requires the `repo` OAuth scope or a fine-grained token
> with **Administration: read and write** on the repository. The `gh` CLI must
> be authenticated: `gh auth status`.

### Apply via Rulesets API (preferred for new repos)

```bash
# List existing rulesets
gh api "repos/${OWNER}/${REPO}/rulesets"

# Create a ruleset (see GitHub Rulesets docs for full schema)
gh api \
  --method POST \
  "repos/${OWNER}/${REPO}/rulesets" \
  --header "Accept: application/vnd.github+json" \
  --input ruleset.json
```

---

## Verification

Use the included script to verify branch protection is correctly configured:

```bash
./scripts/qa/verify-branch-protection.sh
```

The script exits `0` if all required settings are compliant, `1` otherwise.
It requires the `gh` CLI authenticated with a token that has at least
**Administration: read** permission on the repository.

---

## Related Documents

- `docs/operations/ALLOWED_ACTIONS_POLICY.md` — SHA-pinning policy
- `docs/operations/CI_CD_SETUP.md` — CI workflow reference
- `.github/workflows/scorecard.yml` — Scorecard workflow
- `scripts/qa/verify-actions-pinned.sh` — Pinning enforcement script
- `scripts/qa/verify-branch-protection.sh` — Branch protection verification
