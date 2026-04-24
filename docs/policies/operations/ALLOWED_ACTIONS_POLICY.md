# Allowed GitHub Actions Policy

## Purpose

This document defines the policy for GitHub Actions used in this repository.
External third-party actions must be pinned to a full 40-character commit SHA to
reduce tag-mutation risk. First-party BBI-owned action and reusable-workflow
references must be classified in
[`config/first-party-action-authority.yaml`](../../../config/first-party-action-authority.yaml)
when they rely on a mutable protected branch such as `@main`.

This policy is enforced automatically by `scripts/qa/verify-actions-pinned.sh`,
which is run as part of CI (`ci.yml`).

---

## Pinning Requirement

**Every external third-party `uses:` line in every workflow file MUST reference
a full SHA-1 commit hash (40 hex characters).** Version tags (`@v4`, `@main`,
`@master`) are forbidden as the sole reference. The human-readable version
SHOULD be included as a trailing comment for reviewability:

```yaml
# CORRECT
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4

# WRONG — mutable tag, no SHA
- uses: actions/checkout@v4
```

Policy exemptions:

- Local actions such as `./.github/actions/setup-python-env`.
- First-party `Biji-Biji-Initiative/*` actions and reusable workflows only
  when the exact `uses:` ref is declared in
  `config/first-party-action-authority.yaml` as `pinned`,
  `protected-and-verified`, or `temporary-waiver`.
- `docker://` action references, which are governed by image pinning policy
  instead of GitHub action ref pinning.

## First-Party Mutable Authority

BBI-owned `@main` refs are mutable build authority. They are allowed only when
the consumer repository records:

- the exact `uses:` ref,
- owner and upstream path,
- expected branch protection,
- consumer-side local contract checks, and
- every workflow/action file that consumes the ref.

`scripts/qa/verify-actions-pinned.sh` scans both `.github/workflows/**` and
`.github/actions/**`; any undeclared first-party ref fails CI.

---

## Baseline Approved External Actions

The table below is the historical approved-action baseline from T052 (completed
2026-02-24). The current workflow files and `verify-actions-pinned.sh` output
are the executable source of truth for exact SHAs; update this table during
periodic supply-chain review, not by hand-editing workflow refs alone.

| Action | Pinned SHA | Version | Used In |
|--------|-----------|---------|---------|
| `actions/cache` | `0057852bfaa89a56745cba8c7296529d2fc39830` | v4 | ios-testflight.yml, build-ios-app.yml |
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` | v4 | all workflows |
| `actions/dependency-review-action` | `05fe4576374b728f0c523d6a13d64c25081e0803` | v4.8.3 | dependency-review.yml |
| `actions/download-artifact` | `d3f86a106a0bac45b974a628896c90dbdf5c8093` | v4 | ci.yml |
| `actions/github-script` | `f28e40c7f34bde8b3046d885e986cb6290c5673b` | v7 | tutor-plugin-test.yml, ci.yml |
| `actions/setup-node` | `49933ea5288caeca8642d1e84afbd3f7d6820020` | v4 | ci.yml, smoke-authenticated.yml |
| `actions/setup-python` | `a26af69be951a213d495a4c3e4e4022e16d87065` | v5 | ci.yml, build-tutor-images.yml, and others |
| `actions/upload-artifact` | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4 | ci.yml, build-tutor-images.yml, and others |
| `anchore/sbom-action` | `fbfd9c6c189226748411491745178e0c2017392d` | v0.20.10 | build-tutor-images.yml |
| `aquasecurity/trivy-action` | `e368e328979b113139d6f9068e03accaed98a518` | master | build-tutor-images.yml |
| `docker/setup-buildx-action` | `8d2750c68a42422c14e847fe6c8ac0403b4cbd6f` | v3 | build-tutor-images.yml |
| `github/codeql-action/analyze` | `c4a7bc332abaec03596ff2803dd7f3ca3a238975` | v3 | codeql.yml |
| `github/codeql-action/autobuild` | `c4a7bc332abaec03596ff2803dd7f3ca3a238975` | v3 | codeql.yml |
| `github/codeql-action/init` | `c4a7bc332abaec03596ff2803dd7f3ca3a238975` | v3 | codeql.yml |
| `github/codeql-action/upload-sarif` | `45580472a5bb82c4681c4ac726cfdb60060c2ee1` | v3 | scorecard.yml |
| `google-github-actions/auth` | `c200f3691d83b41bf9bbd8638997a462592937ed` | v2 | cloud-sql-backup.yml, build-tutor-images.yml, and others |
| `google-github-actions/setup-gcloud` | `e427ad8a34f8676edf47cf7d7925499adf3eb74f` | v2 | cloud-sql-backup.yml, observability-audit.yml, and others |
| `ludeeus/action-shellcheck` | `00b27aa7cb85167568cb48a3838b75f4265f2bca` | master | ci.yml, build-tutor-images.yml |
| `ossf/scorecard-action` | `05b42c624433fc40578a4040d5cf5e36ddca8cde` | v2.4.2 | scorecard.yml |
| `trufflesecurity/trufflehog` | `be889fa341b7a3b1c8d5fbd9e5c6ab378f417da8` | main | ci.yml |

---

## Adding a New Action

To add an action not listed above, follow this process:

### 1. Security Review Checklist

Before pinning, answer all of the following:

- [ ] **Org membership**: Is the action published by a GitHub-verified org or a
      widely-trusted open-source maintainer? First-party GitHub (`actions/*`,
      `github/*`) and major vendors (`google-github-actions/*`, `docker/*`,
      `ossf/*`) are pre-approved.
- [ ] **Permissions scope**: Does the action require write permissions to
      `contents`, `id-token`, `packages`, or `security-events`? If yes, add
      justification in the PR.
- [ ] **Source audit**: Has someone reviewed the action's source code at the
      specific commit being pinned? For `actions/*` and `github/*`, GitHub's
      own release process is trusted. For third-party actions, link to the
      commit review in the PR description.
- [ ] **Alternatives considered**: Is there an equivalent action already
      approved above? Prefer extending an existing approved action over adding
      a new dependency.
- [ ] **OpenSSF Scorecard score**: For non-GitHub-owned actions, check the
      action repo's OpenSSF Scorecard rating at
      `https://scorecard.dev/viewer/?uri=github.com/<owner>/<repo>`. Repos
      scoring below 5/10 require a documented risk acceptance.

### 2. Pinning the SHA

```bash
# Find the SHA for a tag
git ls-remote https://github.com/<owner>/<action>.git refs/tags/<version>

# Or look up the SHA directly on GitHub:
# https://github.com/<owner>/<action>/releases/tag/<version>
# Click the commit link and copy the full 40-char SHA.
```

### 3. PR Requirements

- Add the action to the approved table above.
- Add `uses: <action>@<full-sha>  # <version>` in the workflow.
- The PR title must include `[supply-chain]` or `[new-action]`.
- Request review from at least one team member with infra/security context.
- CI must pass including `verify-actions-pinned.sh`.

### 4. Periodic SHA Refresh

SHAs do not auto-update. When a new version of an approved action is available:

1. Verify the new release is legitimate (check the action's changelog and
   release notes).
2. Update the SHA in all affected workflow files.
3. Update the SHA in the table above.
4. CI will confirm the new SHA is valid (40-char hex).

A quarterly review of all pinned SHAs is recommended to pick up security fixes
in upstream actions.

---

## OpenSSF Scorecard Integration

This repository runs the
[OpenSSF Scorecard](https://github.com/ossf/scorecard) via `scorecard.yml` on
every push to `main`. The Scorecard checks include:

- **Token-Permissions**: Verifies workflows do not use `write-all` permissions.
- **Pinned-Dependencies**: Confirms all actions are SHA-pinned (what this
  policy enforces at the code level).
- **Branch-Protection**: Checks branch protection rules are in place.
- **Code-Review**: Checks that PRs require review before merge.

Results are uploaded as SARIF to GitHub Security and are visible under
**Security → Code scanning alerts**.

The `verify-actions-pinned.sh` script is complementary to Scorecard: it gives
instant local and CI feedback before results are uploaded to the Security tab.

---

## Enforcement

| Layer | Mechanism |
|-------|-----------|
| CI gate | `scripts/qa/verify-actions-pinned.sh` runs on every PR (wired into `ci.yml`) |
| Scorecard | `scorecard.yml` checks `Pinned-Dependencies` on every push to `main` |
| PR review | Human reviewer confirms new actions follow the process above |

Violations of this policy (unpinned `uses:` lines) will cause CI to fail with a
non-zero exit code and a clear list of offending files and lines.

---

## References

- [OpenSSF Scorecard](https://github.com/ossf/scorecard)
- [GitHub: Keeping GitHub Actions and workflows secure](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [Securing GitHub Actions supply chain — SHA pinning](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- T052 (SHA-pin all existing actions) — completed 2026-02-24
- T053 (this policy + enforcement script) — completed 2026-02-24
