# ARC Runner Capability Contract

> Stabilization document — what ARC runners can and cannot do.
> Date: 2026-03-11

This document is the authoritative reference for CI job authors. Before adding a new CI step,
check whether the target runner pool supports it.

---

## Runner Pools

| Pool label | CPUs | RAM | Docker | Persistent cache | Purpose |
|---|---|---|---|---|---|
| `mereka-k8s-runners` | 2 | 4 GB | No | No | Linting, testing, static analysis |
| `mereka-k8s-heavy-builders` | 4 | 12 GB | Yes (DinD sidecar) | Yes (50Gi + 10Gi) | Image builds, integration tests |

Both pools run in the `arc-runners` namespace on the RKE2 nonprod cluster.
ARC controller lives in `arc-systems` namespace.

---

## Lightweight Runner: What Is NOT Available

The following are absent from `mereka-k8s-runners` pods and must not be assumed present:

| Missing capability | Impact | Workaround |
|---|---|---|
| `xz-utils` | Cannot extract `.tar.xz` (breaks many GH Action self-installers) | Use pip-installable equivalents |
| `lsb_release` | `actions/setup-python@v5` pip cache key fails | Install `lsb_release` stub before setup-python step |
| `sudo` | Cannot install system packages at runtime | Pre-install in runner image or use user-space binaries |
| `apt` / `apt-get` | Cannot add system packages at CI time | Same as above |
| Docker daemon | Cannot run `docker build`, `docker run` | Use `mereka-k8s-heavy-builders` instead |
| Root access | Cannot write to `/usr/local/bin` or similar | Write to `$GITHUB_WORKSPACE/.cache/bin`; add to `$PATH` |

---

## Lightweight Runner: What IS Available

These tools are confirmed present and usable without workarounds:

| Tool | Notes |
|---|---|
| `bash` | Default shell for all steps |
| `git` | Full git, including worktree support |
| `curl` / `wget` | HTTP downloads |
| `python3` | Python 3.10+ |
| `pip` / `pip3` | Package installation to user space |
| `node` | Node.js 18+ |
| `npm` | Package installation |
| `jq` | JSON processing |
| `yq` | YAML processing (v4) |
| `make` | GNU make |
| `shellcheck` | Via `pip install shellcheck-py` |
| `yamllint` | Via `pip install yamllint` |

---

## Heavy Builder Runner: Additional Capabilities

`mereka-k8s-heavy-builders` has everything above plus:

| Capability | Detail |
|---|---|
| Docker-in-Docker | Sidecar container; use `DOCKER_HOST=tcp://localhost:2375` |
| Persistent Docker layer cache | 50Gi PVC mounted at `/var/lib/docker` |
| Persistent dependency cache | 10Gi PVC mounted at `/root/.cache` (pip, npm) |
| Higher memory for webpack | 12 GB RAM supports `NODE_OPTIONS=--max-old-space-size=6144` |
| `tutor images build` | Runs on heavy builders only, with `--cache-from` |

---

## Workarounds In Place

These workarounds have been applied to compensate for lightweight runner gaps.

### 1. shellcheck via pip (xz-utils workaround)

The official `ludeeus/action-shellcheck` downloads a `.tar.xz` and fails. Instead:

```yaml
- name: Install shellcheck
  run: pip install shellcheck-py

- name: Run shellcheck
  run: shellcheck-py --severity=error scripts/**/*.sh
```

### 2. lsb_release stub (setup-python workaround)

Install a stub before `actions/setup-python` runs:

```yaml
- name: Install lsb_release stub
  run: |
    mkdir -p "$GITHUB_WORKSPACE/.cache/bin"
    cat > "$GITHUB_WORKSPACE/.cache/bin/lsb_release" <<'EOF'
    #!/usr/bin/env bash
    case "$1" in
      -i) echo "Ubuntu" ;;
      -r) echo "22.04" ;;
      -c) echo "jammy" ;;
      *)  echo "Ubuntu 22.04.0 LTS" ;;
    esac
    EOF
    chmod +x "$GITHUB_WORKSPACE/.cache/bin/lsb_release"
    echo "$GITHUB_WORKSPACE/.cache/bin" >> "$GITHUB_PATH"

- uses: actions/setup-python@v5
  with:
    python-version: '3.11'
    cache: pip
```

### 3. User-space binary installation path

For any tool that must be installed at CI time without sudo, install to:

```
$GITHUB_WORKSPACE/.cache/bin/
```

And add to `$GITHUB_PATH` before use. This directory is writable without root.

---

## CI Job Routing Rules

| Job type | Correct pool | Reason |
|---|---|---|
| yamllint | `mereka-k8s-runners` | Lightweight; pip-installable |
| shellcheck | `mereka-k8s-runners` | Use shellcheck-py |
| kubeconform | `mereka-k8s-runners` | Single binary, no Docker needed |
| Python unit tests | `mereka-k8s-runners` | No Docker needed |
| tutor config tests | `mereka-k8s-runners` | No Docker needed |
| `tutor images build` | `mereka-k8s-heavy-builders` | Requires Docker + 12 GB RAM |
| Integration tests with containers | `mereka-k8s-heavy-builders` | Requires Docker |
| Security scans (TruffleHog, pip-audit) | `mereka-k8s-runners` | Lightweight |

---

## Verification Script

A verification script confirms the runner contract holds:

```
scripts/qa/verify-arc-runner-contract.sh
```

This script (to be run inside a CI step on each pool) checks:
- Required tools are present and return expected versions.
- Stub workarounds are effective.
- `$GITHUB_WORKSPACE/.cache/bin` is on `$PATH`.

Run it as a canary job on both pools when modifying CI infrastructure.

---

## Adding New CI Steps: Checklist

Before adding any new step to a CI job:

- [ ] Identify which runner pool the job runs on.
- [ ] Check the "NOT Available" table above for every tool the step needs.
- [ ] If the step uses a third-party GH Action, check whether it downloads `.tar.xz` for self-installation.
- [ ] If a tool is missing, apply an approved workaround or route to `mereka-k8s-heavy-builders`.
- [ ] Document any new workaround in this file under "Workarounds In Place".
