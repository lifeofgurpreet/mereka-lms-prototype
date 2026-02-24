# Commit Signing Guide

<!-- Last verified: 2026-02-24 -->

This document covers commit signing for the Mereka LMS repository — why it matters,
the two approaches available, and how to set up and verify signatures.

---

## Why Commit Signing Matters

Unsigned commits create a supply-chain risk: any contributor (or a compromised account)
can push code claiming to be authored by anyone else. Signed commits provide
cryptographic proof that:

- The commit was created by the holder of a specific key or OIDC identity.
- The commit has not been tampered with after signing.
- Maintainers can verify authorship without trusting GitHub's account system alone.

This is especially important for a deployment repo — a malicious commit to `main`
can affect infrastructure, secrets wiring, or K8s manifests.

---

## Two Approaches

### Option A — GitHub Vigilant Mode (GPG or SSH keys)

GitHub's **vigilant mode** marks every commit that lacks a verified signature with
a "Unverified" badge. When enabled on a personal account, commits signed with an
uploaded GPG or SSH key get a green "Verified" badge.

**Pros**: Zero tooling beyond `git`. Works with GitHub's existing UI.
**Cons**: Key management is per-person. Keys must be rotated manually. Does not
integrate with CI/CD identity federation.

### Option B — Sigstore Gitsign (keyless, OIDC-backed)

[Gitsign](https://github.com/sigstore/gitsign) uses your OIDC identity (GitHub
Actions OIDC, Google, GitHub personal OAuth) to sign commits without a long-lived
key. Signatures are recorded in the Sigstore transparency log (Rekor), making them
auditable and verifiable without exchanging keys.

**Pros**: No key management. Signatures are tied to OIDC identity (email + provider).
Works natively in GitHub Actions via the `id-token: write` permission. Rekor provides
a tamper-evident audit log.
**Cons**: Requires `gitsign` binary on developer machines. Slightly longer sign/verify
cycle. Keyless signatures expire (Fulcio short-lived certs, 10-minute TTL) — but
Rekor inclusion proves the identity at signing time.

**Recommendation**: Use **Gitsign for CI** (GitHub Actions OIDC, no secrets required)
and **GPG/SSH for developer machines** (simpler to set up without Gitsign binary).
Both approaches are compatible — the CI soft gate accepts any valid signature.

---

## Setup: GPG Signing (Option A)

### 1. Generate a GPG key (if you don't have one)

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, no expiry (or set an expiry)
# Use your GitHub-verified email address
```

### 2. Export and upload to GitHub

```bash
# List keys
gpg --list-secret-keys --keyid-format LONG

# Export public key (replace KEY_ID with your key ID)
gpg --armor --export KEY_ID

# Copy the output and paste into:
# GitHub → Settings → SSH and GPG keys → New GPG key
```

### 3. Configure git to sign commits

```bash
# Set the signing key
git config --global user.signingkey KEY_ID

# Sign all commits by default
git config --global commit.gpgsign true

# Sign all tags by default
git config --global tag.gpgsign true
```

### 4. Enable GitHub Vigilant Mode

Go to **GitHub → Settings → SSH and GPG keys → Vigilant mode** and enable
"Flag unsigned commits as unverified".

---

## Setup: SSH Signing (Option A, simpler)

GitHub supports commit signing with SSH keys (available since 2022).

```bash
# Configure git to use your SSH key for signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Upload the same public key to GitHub under:
# Settings → SSH and GPG keys → New signing key (not authentication key)
```

---

## Setup: Gitsign (Option B, keyless)

### 1. Install gitsign

```bash
# macOS
brew install sigstore/tap/gitsign

# Linux (download binary)
curl -fsSL https://github.com/sigstore/gitsign/releases/latest/download/gitsign_linux_amd64 \
  -o /usr/local/bin/gitsign
chmod +x /usr/local/bin/gitsign
```

### 2. Configure git to use gitsign

```bash
git config --global gpg.x509.program gitsign
git config --global gpg.format x509
git config --global commit.gpgsign true
```

### 3. Sign a commit

On first use, gitsign opens a browser to authenticate via OIDC (GitHub, Google,
or Microsoft). The identity is bound to a short-lived Fulcio certificate, and
the signature is recorded in Rekor.

```bash
git commit -m "feat: my change"
# Browser opens → authenticate → certificate issued → commit signed
```

---

## Verifying Signatures

### Quick check (single commit)

```bash
git verify-commit HEAD
```

### Log view with signature status

```bash
git log --show-signature -1

# Example output for a GPG-signed commit:
# gpg: Signature made ...
# gpg: Good signature from "Alice <alice@example.com>"
# commit abc123...
# Author: Alice <alice@example.com>
```

### Bulk status check

```bash
# %G? codes: G=good, U=unknown key, X=expired, Y=expired key, N=unsigned, E=error, B=bad
git log --format='%H %G? %GS' -n 20
```

### Verify a Gitsign signature against Rekor

```bash
gitsign verify HEAD \
  --certificate-identity=<email> \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com
```

---

## CI Soft Gate

The workflow `.github/workflows/verify-commit-signing.yml` runs on every push to
`main` and every pull request targeting `main`.

It calls `scripts/qa/verify-commit-signing.sh`, which:

1. Examines the last N commits on the branch (default: 20).
2. Counts commits by signature status (`G`, `U`, `X`, `Y` = signed; `N` = unsigned;
   `E`, `B` = error).
3. Calculates the percentage of signed commits.
4. Warns if the signed percentage falls below the configured threshold (default: 50%).

**The gate is currently soft**: `continue-on-error: true` in the workflow means the
CI check is informational only and will not block merges. This is intentional during
the adoption ramp-up period.

---

## Migration Plan: Soft Gate → Hard Gate

| Phase | Condition | Action |
|-------|-----------|--------|
| **Phase 1 (now)** | Adoption ramp-up | Soft gate (warn only). `continue-on-error: true`. Threshold: 50%. |
| **Phase 2** | ≥80% of recent commits signed across 2 weeks | Raise threshold to 80%. Still soft gate. |
| **Phase 3** | 100% of commits signed for 2 consecutive weeks | Remove `continue-on-error`. Threshold: 100%. Hard gate blocks merge. |
| **Phase 4** | Hard gate stable for 1 sprint | Optionally enable GitHub branch protection rule requiring signed commits. |

To move to Phase 2, update `THRESHOLD` in `scripts/qa/verify-commit-signing.sh`
and remove `continue-on-error: true` from the workflow when ready for Phase 3.

To enable GitHub's native signed-commit requirement:
**Settings → Branches → Branch protection rules → main → Require signed commits**.

---

## References

- [Sigstore Gitsign](https://github.com/sigstore/gitsign)
- [GitHub: About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)
- [GitHub: Displaying verification statuses for all of your commits (Vigilant Mode)](https://docs.github.com/en/authentication/managing-commit-signature-verification/displaying-verification-statuses-for-all-of-your-commits)
- [Rekor transparency log](https://rekor.sigstore.dev)
- [SLSA framework](https://slsa.dev) — commit signing satisfies SLSA Source Level 1 provenance
