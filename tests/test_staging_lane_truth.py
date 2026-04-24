from __future__ import annotations
import os
from pathlib import Path
import subprocess
import textwrap


REPO_ROOT = Path(__file__).resolve().parents[1]


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")


def run_script(script: str, *args: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", script, *args],
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def make_infra_fixture(tmp_path: Path) -> Path:
    infra = tmp_path / "bbi-infrastructure"

    write_file(
        infra / "apps/mereka-lms/overlays/staging/kustomization.yaml",
        """
        resources:
          - ../../base
          - patches/ingress.yaml
        """,
    )
    write_file(
        infra / "apps/mereka-lms/overlays/prod/kustomization.yaml",
        """
        resources:
          - ../../base
        """,
    )
    write_file(
        infra / "argocd/applicationsets/mereka-lms-dev.yaml",
        """
        apiVersion: argoproj.io/v1alpha1
        kind: ApplicationSet
        spec:
          template:
            spec:
              source:
                repoURL: https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
                path: apps/mereka-lms/overlays/profiles/dev
              destination:
                namespace: mereka-lms-dev
              syncPolicy:
                automated:
                  prune: true
                  selfHeal: true
                syncOptions:
                  - ApplyOutOfSyncOnly=true
                  - CreateNamespace=true
        """,
    )
    write_file(
        infra / "argocd/applications/mereka-lms-staging.yaml",
        """
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        spec:
          source:
            repoURL: https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
            path: apps/mereka-lms/overlays/staging
          destination:
            namespace: stg-mereka-lms
          syncPolicy:
            automated:
              prune: false
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
              - Prune=false
              - RespectIgnoreDifferences=true
        """,
    )
    write_file(
        infra / "argocd/applications/mereka-lms-prod.yaml",
        """
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        spec:
          source:
            repoURL: https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git
            path: apps/mereka-lms/overlays/prod
          destination:
            namespace: mereka-lms
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
        """,
    )
    write_file(
        infra / "bootstrap/applicationsets/overlays/staging/kustomization.yaml",
        """
        resources:
          - ../../../../argocd/applications/mereka-lms-staging.yaml
        """,
    )

    return infra


def test_verify_argocd_drift_supports_staging_offline(tmp_path: Path) -> None:
    infra = make_infra_fixture(tmp_path)
    env = os.environ | {"BBI_INFRA": str(infra)}

    result = run_script(
        "scripts/qa/verify-argocd-drift.sh",
        "--app",
        "mereka-lms-staging",
        "--offline",
        env=env,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "overlay path exists: apps/mereka-lms/overlays/staging" in result.stdout
    assert "manifest destination.namespace matches expected: stg-mereka-lms" in result.stdout
    assert "manifest automated prune declared: false" in result.stdout
    assert "manifest automated selfHeal declared: true" in result.stdout
    assert "manifest syncOptions declared" in result.stdout


def test_verify_staging_activation_offline_accepts_live_staging_contract(tmp_path: Path) -> None:
    infra = make_infra_fixture(tmp_path)
    env = os.environ | {"BBI_INFRA_PATH": str(infra)}

    result = run_script("scripts/qa/verify-staging-activation.sh", "--offline", env=env)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "staging ArgoCD app destination namespace: stg-mereka-lms" in result.stdout
    assert "staging bootstrap overlay includes mereka-lms-staging application" in result.stdout
    assert "staging not yet activated" not in result.stdout


def test_verify_argocd_drift_online_uses_staging_git_sync_policy(tmp_path: Path) -> None:
    infra = make_infra_fixture(tmp_path)
    fake_bin = tmp_path / "bin"

    write_file(
        fake_bin / "kubectl",
        """
        #!/usr/bin/env bash
        set -euo pipefail

        if [[ "${1:-}" == "get" && "${2:-}" == "application" && "${3:-}" == "mereka-lms-staging" ]]; then
          cat <<'JSON'
        {
          "metadata": {
            "annotations": {}
          },
          "spec": {
            "source": {
              "path": "apps/mereka-lms/overlays/staging",
              "repoURL": "https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
            },
            "destination": {
              "namespace": "stg-mereka-lms"
            },
            "syncPolicy": {
              "automated": {
                "prune": false,
                "selfHeal": true
              },
              "syncOptions": [
                "CreateNamespace=true",
                "Prune=false",
                "RespectIgnoreDifferences=true"
              ]
            }
          },
          "status": {
            "sync": {
              "status": "Synced"
            },
            "health": {
              "status": "Healthy"
            },
            "resources": [],
            "operationState": {
              "phase": "Succeeded",
              "operation": {
                "initiatedBy": {
                  "automated": true
                }
              }
            }
          }
        }
        JSON
          exit 0
        fi

        echo "unexpected kubectl invocation: $*" >&2
        exit 1
        """,
    )
    fake_bin.joinpath("kubectl").chmod(0o755)

    env = os.environ | {
        "BBI_INFRA": str(infra),
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
    }

    result = run_script(
        "scripts/qa/verify-argocd-drift.sh",
        "--app",
        "mereka-lms-staging",
        "--online",
        env=env,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "automated prune matches git: false" in result.stdout
    assert "automated selfHeal matches git: true" in result.stdout
    assert "syncOptions match git" in result.stdout


def test_verify_argocd_drift_online_detects_staging_sync_policy_drift(tmp_path: Path) -> None:
    infra = make_infra_fixture(tmp_path)
    fake_bin = tmp_path / "bin"

    write_file(
        fake_bin / "kubectl",
        """
        #!/usr/bin/env bash
        set -euo pipefail

        if [[ "${1:-}" == "get" && "${2:-}" == "application" && "${3:-}" == "mereka-lms-staging" ]]; then
          cat <<'JSON'
        {
          "metadata": {
            "annotations": {}
          },
          "spec": {
            "source": {
              "path": "apps/mereka-lms/overlays/staging",
              "repoURL": "https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
            },
            "destination": {
              "namespace": "stg-mereka-lms"
            },
            "syncPolicy": {
              "automated": {
                "prune": true,
                "selfHeal": true
              },
              "syncOptions": [
                "CreateNamespace=true",
                "Prune=true",
                "RespectIgnoreDifferences=true"
              ]
            }
          },
          "status": {
            "sync": {
              "status": "Synced"
            },
            "health": {
              "status": "Healthy"
            },
            "resources": [],
            "operationState": {
              "phase": "Succeeded",
              "operation": {
                "initiatedBy": {
                  "automated": true
                }
              }
            }
          }
        }
        JSON
          exit 0
        fi

        echo "unexpected kubectl invocation: $*" >&2
        exit 1
        """,
    )
    fake_bin.joinpath("kubectl").chmod(0o755)

    env = os.environ | {
        "BBI_INFRA": str(infra),
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
    }

    result = run_script(
        "scripts/qa/verify-argocd-drift.sh",
        "--app",
        "mereka-lms-staging",
        "--online",
        env=env,
    )

    assert result.returncode != 0
    assert "DRIFT: automated prune 'true' != git 'false'" in result.stdout
    assert "DRIFT: syncOptions" in result.stdout
