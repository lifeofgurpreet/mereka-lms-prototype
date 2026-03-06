# Binary Pinning in CI Workflows

_Audience: Platform Engineers • Owner: platform-engineering • Last verified: 2026-03-06 • Status: canonical_

> **Owner**: platform-engineering
> **Task**: T057 (infrastructure), T058 (platform-control-plane) — DR2:I-015, DR2:I-016
> **Status**: TODO — cross-repo changes required

## Why This Matters

CI workflows that download external binaries (`yq`, `kubectl`, `helm`, `kustomize`, `cosign`, etc.) using floating references such as `latest`, `stable`, or an unverified release URL are vulnerable to supply-chain attacks:

- The binary at a URL can be silently replaced with a malicious version.
- A version tag (e.g. `v4.44.3`) is mutable — a tag can be force-pushed to a different commit.
- Without a SHA256 checksum, there is no way to detect tampering after download.

A compromised CI binary can exfiltrate secrets, backdoor build artifacts, or modify Kubernetes manifests before they are applied.

## Scope

This document covers binary downloads in:

| Repository | Task | Status |
|------------|------|--------|
| `infrastructure` | T057 | TODO |
| `platform-control-plane` | T058 | TODO |

GitHub Actions `uses:` pinning (action SHA pinning) is a separate concern covered by `docs/ops/security/ALLOWED_ACTIONS_POLICY.md`.

## Binaries to Pin

The following tools are commonly installed via `curl`/`wget` in CI and must be pinned:

| Binary | Where to find the digest | Notes |
|--------|--------------------------|-------|
| `yq` | [github.com/mikefarah/yq/releases](https://github.com/mikefarah/yq/releases) — `.tar.gz.sha256` asset | YAML processor; widely used in GitOps workflows |
| `kubectl` | `https://dl.k8s.io/release/<VERSION>/bin/linux/amd64/kubectl.sha256` | Kubernetes CLI |
| `helm` | [github.com/helm/helm/releases](https://github.com/helm/helm/releases) — `helm-<VERSION>-linux-amd64.tar.gz.sha256` | Package manager for Kubernetes |
| `kustomize` | [github.com/kubernetes-sigs/kustomize/releases](https://github.com/kubernetes-sigs/kustomize/releases) — `.tar.gz_SHA` file | Kustomize CLI |
| `argocd` CLI | [github.com/argoproj/argo-cd/releases](https://github.com/argoproj/argo-cd/releases) — `.sha256` asset | ArgoCD CLI |
| `cosign` | [github.com/sigstore/cosign/releases](https://github.com/sigstore/cosign/releases) — `.sha256` asset | Container signing |

## Pinning Patterns

### Pattern A: Exact version + checksum file (preferred)

```yaml
- name: Install yq
  env:
    YQ_VERSION: "v4.44.3"
    YQ_SHA256: "a2c097180dd884a8d16e330389b7b000dfa1b5bc28b36009eb4b86e7a3c36483"
  run: |
    curl -sSfL \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
      -o /usr/local/bin/yq
    echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum --check
    chmod +x /usr/local/bin/yq
```

### Pattern B: Download the upstream checksum file

```yaml
- name: Install kubectl
  env:
    KUBECTL_VERSION: "v1.30.4"
  run: |
    curl -sSfLO \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    curl -sSfLO \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl
```

### Pattern C: Use a pinned GitHub Actions installer (for tools with official actions)

Many tools have official GitHub Actions installers that handle pinning internally. Prefer these over raw `curl` downloads, and pin the action itself to a full SHA:

```yaml
- uses: azure/setup-kubectl@3e0aec4d80787158d308d7b364cb1381784a5834  # v4.0.1
  with:
    version: "v1.30.4"

- uses: azure/setup-helm@b9e51a9587bef69d85d3d09befc63cfe81e7f40e  # v4.2.0
  with:
    version: "v3.16.4"
```

## How to Find the Correct SHA256

```bash
# yq (after release is published on GitHub)
curl -sSfL https://github.com/mikefarah/yq/releases/download/v4.44.3/checksums | grep yq_linux_amd64

# kubectl
curl -sSf https://dl.k8s.io/release/v1.30.4/bin/linux/amd64/kubectl.sha256

# helm
curl -sSfL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz.sha256

# kustomize
curl -sSfL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.3/checksums.txt
```

## Anti-Patterns to Avoid

```yaml
# BAD: fetches whatever "latest" resolves to at run time
- run: curl -sSfL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq

# BAD: version is pinned but no checksum check
- run: |
    curl -sSfL https://github.com/.../yq_linux_amd64 -o yq
    chmod +x yq

# BAD: uses stable.txt which resolves dynamically
- run: |
    KUBECTL_VERSION=$(curl -sSf https://dl.k8s.io/release/stable.txt)
    curl -sSfLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    # no checksum!
```

## Cross-Repo Change Plan

Changes must be made in the following repositories. This repo (`mereka-lms`) contains only the verification script and this documentation.

### infrastructure (T057)

1. Audit all `.github/workflows/*.yml` for binary download patterns.
2. For each download:
   - Pin to an exact version variable (e.g. `YQ_VERSION: "v4.44.3"`).
   - Add SHA256 checksum verification immediately after download.
   - Record the pinned version + SHA256 in a comment next to the variable for easy future updates.
3. Test the change in a branch before merging to main.
4. After merge, update the `YQ_VERSION` / `KUBECTL_VERSION` etc. variables via Dependabot or manual PR when new versions are released.

### platform-control-plane (T058)

Same steps as above. See `T058` in TRACKER.md.

## Verification

Run the verification script after cross-repo changes are in place:

```bash
# From the mereka-lms repo root, with infrastructure checked out locally:
BBI_INFRA=/path/to/infrastructure ./scripts/qa/verify-binary-pinning-bbi-infra.sh
```

The script will SKIP all cross-repo checks if `infrastructure` is not found locally, so it is safe to run in CI for this repo.

## Related Documents

- `docs/ops/security/ALLOWED_ACTIONS_POLICY.md` — GitHub Actions `uses:` SHA pinning
- `docs/operations/SLSA_PROVENANCE.md` — Build provenance and image signing
- `docs/ops/security/SECURITY_INCIDENT_SUPPLY_CHAIN.md` — Supply-chain incident response
- `scripts/qa/verify-actions-pinned.sh` — Verifies `uses:` SHA pinning in this repo
- `scripts/qa/verify-slsa-provenance.sh` — Verifies SLSA provenance workflow
