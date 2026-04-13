# Branch Protection Requirements

_Audience: Platform Engineers • Owner: platform-team • Last verified: 2026-04-13 • Status: canonical_

<!-- Last verified: 2026-04-13 -->

This document specifies the required GitHub branch protection settings for the
`main` branch and explains how they contribute to the repository's OpenSSF
Scorecard score.

---

## Required Settings for `main`

| Setting | Required Value | Why |
|---------|---------------|-----|
| Require pull request reviews before merging | Enabled, minimum 0 reviewers | Keeps branch protection active without blocking the owner-merged agent workflow documented in the contract |
| Dismiss stale pull request approvals on new commits | Disabled while required approvals = 0 | No approval state exists to invalidate in the current owner-merged workflow |
| Require status checks to pass before merging | Enabled (see list below) | Gates on CI, IaC scan, and lint |
| Require branches to be up to date before merging | Enabled | Prevents stale-branch merges bypassing checks |
| Apply branch protection to admins | Enabled | Prevents admin bypass from silently weakening CI trust |
| Allow force pushes | Disabled | Preserves audit trail; Scorecard `Branch-Protection` check |
| Allow deletions | Disabled | Protects history |
| Require signed commits | Optional now; escalate per T064 | Scorecard `Signed-Releases` / `Branch-Protection` partial credit |

### Required Status Checks

These check names must match the job names reported by GitHub Actions:

| Check Name | Workflow File | Purpose |
|------------|--------------|---------|
| `Static Validation` | `ci.yml` | Consolidated static gate: conventions, docs generation, spec integrity, token/branding checks, verification inventory, and source-only policy checks |
| `Tutor Configuration Tests` | `ci.yml` | Tutor render/apply-patches/idempotency gate |
| `Security Scans` | `ci.yml` | TruffleHog, hadolint, and pip-audit gate |
| `Python test coverage` | `ci.yml` | Python test execution and coverage gate |
| `Review dependencies` | `dependency-review.yml` | Dependency review gate on PR dependency changes |
| `Trivy — K8s Manifests` | `iac-scan.yml` | K8s security scan |
| `Trivy — Terraform` | `iac-scan.yml` | Terraform security scan |

> `Analyze (python)`, `Analyze (javascript-typescript)`, and `Seer Code Review`
> currently run on PRs but are informational here; they are not part of the
> required merge gate in this policy.

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
| `SAST` | Medium | CodeQL (`codeql.yml`) runs on PRs and push to main; currently informational, not branch-protection required |

### Checks Not Directly Tied to Branch Protection

These Scorecard checks are addressed elsewhere in the repo:

| Check | Where It Is Addressed |
|-------|-----------------------|
| `Token-Permissions` | All workflows use `permissions: {}` at top level and grant least-privilege per-job |
| `Security-Policy` | `SECURITY.md` (disclosure) plus `docs/reference/operations/SECRET_SCANNING.md` (operational controls) |
| `Maintained` | Active commit history |

---

## Configure via GitHub UI

1. Treat [`config/branch-protection-contract.yaml`](../../../config/branch-protection-contract.yaml) as the machine source of truth for this repo's live settings.
2. Go to **Settings → Branches** in the repository.
3. Click **Add branch ruleset** (or edit the existing `main` ruleset).
4. Set **Target branches** to `main`.
5. Enable the settings listed in the table above:
   - **Require a pull request before merging**: checked
     - Set **Required approvals** to `0`
     - Leave **Dismiss stale pull request approvals when new commits are pushed** unchecked
   - **Require status checks to pass**:
     - Check **Require branches to be up to date before merging**
     - Add each check name from the table above
   - **Block force pushes**: checked
   - **Restrict deletions**: checked
   - **Include administrators**: checked
6. Click **Save changes**.

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
      "Static Validation",
      "Tutor Configuration Tests",
      "Security Scans",
      "Python test coverage",
      "Review dependencies",
      "Trivy — K8s Manifests",
      "Trivy — Terraform"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismissal_restrictions": {},
      "dismiss_stale_reviews": false,
      "require_code_owner_reviews": false,
      "required_approving_review_count": 0
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

Use the included scripts to verify branch protection is correctly configured:

```bash
./scripts/qa/verify-branch-protection.sh
./scripts/qa/verify-branch-protection-contract.sh --live
```

The repo-local verifier reads `config/branch-protection-contract.yaml` as the
machine contract and exits `0` if all required settings are compliant, `1`
otherwise. It requires the `gh` CLI authenticated with a token that has at
least **Administration: read** permission on the repository.

The cross-repo `--live` audit is stricter: it checks every repo declared in the
contract, not just `mereka-lms`. If it fails, treat that as governance drift to
record and repair, not as proof that this repo's local branch protection row is
wrong.

---

## Related Documents

- `docs/policies/operations/ALLOWED_ACTIONS_POLICY.md` — SHA-pinning policy
- `docs/reference/operations/CI_CD_SETUP.md` — CI workflow reference
- `.github/workflows/scorecard.yml` — Scorecard workflow
- `scripts/qa/verify-actions-pinned.sh` — Pinning enforcement script
- `scripts/qa/verify-branch-protection.sh` — Branch protection verification
