# Commit Signing Reference
_Audience: Contributors and Operators • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

This reference records the commit-signing expectation for changes in this repository.

## Current expectation

- Signed commits are preferred on active branches.
- Recent signing posture is checked by `scripts/qa/verify-commit-signing.sh`.
- GitHub workflow verification lives in `.github/workflows/verify-commit-signing.yml`.

## Local setup outline

1. Configure your signing key with Git.
2. Enable signing by default:
   ```bash
   git config --global commit.gpgsign true
   ```
3. Verify locally:
   ```bash
   git log --show-signature -n 5
   ```

## Verification

- `bash scripts/qa/verify-commit-signing.sh`
- `.github/workflows/verify-commit-signing.yml`

## Related docs

- [`CI_CD_SETUP.md`](CI_CD_SETUP.md)
- [`SECRET_SCANNING.md`](SECRET_SCANNING.md)
