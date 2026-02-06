#!/usr/bin/env bash
# Ensure Authentik admins are required to complete MFA (without forcing MFA on all users).
#
# Design:
# - Create an ExpressionPolicy that matches users in the "authentik Admins" group.
# - Create a dedicated AuthenticatorValidateStage whose not_configured_action is "configure".
# - Bind that stage into the default authentication flow with the policy attached,
#   so the stage only runs for Authentik admins.
#
# Why:
# - Today the default validate stage uses not_configured_action=skip, so MFA is optional.
# - We want MFA mandatory for the Authentik admin surface, without disrupting normal users.
#
# Usage:
#   ./scripts/infra/ensure-authentik-admin-mfa.sh --verify
#   ./scripts/infra/ensure-authentik-admin-mfa.sh --apply
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NAMESPACE="${NAMESPACE:-authentik}"
AUTHENTIK_DEPLOY="${AUTHENTIK_DEPLOY:-authentik-server}"

FLOW_SLUG="${FLOW_SLUG:-default-authentication-flow}"
ADMIN_GROUP_NAME="${ADMIN_GROUP_NAME:-authentik Admins}"

POLICY_NAME="${POLICY_NAME:-require-authentik-admins}"
STAGE_NAME="${STAGE_NAME:-authentik-admin-mfa-required}"
STAGE_BINDING_ORDER="${STAGE_BINDING_ORDER:-31}"

MODE="verify" # verify | apply

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --verify                  Verify only (default)
  --apply                   Apply changes (idempotent)
  --context K8S_CONTEXT     Kube context (default: $K8S_CONTEXT)
  --namespace NAMESPACE     Namespace (default: $NAMESPACE)
  --deploy DEPLOYMENT       Authentik server deployment name (default: $AUTHENTIK_DEPLOY)
  --flow-slug SLUG          Authentication flow slug (default: $FLOW_SLUG)
  --admin-group NAME        Admin group name (default: $ADMIN_GROUP_NAME)
  -h, --help                Show help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) MODE="verify"; shift ;;
    --apply) MODE="apply"; shift ;;
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --deploy) AUTHENTIK_DEPLOY="$2"; shift 2 ;;
    --flow-slug) FLOW_SLUG="$2"; shift 2 ;;
    --admin-group) ADMIN_GROUP_NAME="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

echo "Mode: $MODE"
echo "Context: $K8S_CONTEXT"
echo "Namespace: $NAMESPACE"
echo "Deploy: $AUTHENTIK_DEPLOY"
echo "Flow: $FLOW_SLUG"
echo "Admin group: $ADMIN_GROUP_NAME"
echo ""

kubectl --context "$K8S_CONTEXT" exec -i -n "$NAMESPACE" "deploy/$AUTHENTIK_DEPLOY" -- \
  env MODE="$MODE" FLOW_SLUG="$FLOW_SLUG" ADMIN_GROUP_NAME="$ADMIN_GROUP_NAME" POLICY_NAME="$POLICY_NAME" \
  STAGE_NAME="$STAGE_NAME" STAGE_BINDING_ORDER="$STAGE_BINDING_ORDER" \
  ak shell -c '
import os
mode = os.environ.get("MODE", "verify")
flow_slug = os.environ["FLOW_SLUG"].strip()
admin_group_name = os.environ["ADMIN_GROUP_NAME"].strip()
policy_name = os.environ["POLICY_NAME"].strip()
stage_name = os.environ["STAGE_NAME"].strip()
binding_order = int(os.environ.get("STAGE_BINDING_ORDER", "31"))

from authentik.core.models import Group
from authentik.flows.models import Flow, FlowStageBinding
from authentik.policies.models import PolicyBinding
from authentik.policies.expression.models import ExpressionPolicy
from authentik.stages.authenticator_validate.models import AuthenticatorValidateStage

def ok(msg): print("✓", msg)
def fail(msg): print("✗", msg); raise SystemExit(1)
def warn(msg): print("!", msg)

admin_group = Group.objects.filter(name=admin_group_name).first()
if not admin_group:
    fail(f"Admin group not found: {admin_group_name}")

flow = Flow.objects.filter(slug=flow_slug).first()
if not flow:
    fail(f"Flow not found: {flow_slug}")

expected_expression = (
    "return request.user.ak_groups.filter(name="
    + repr(admin_group_name)
    + ").exists()"
)

pol = ExpressionPolicy.objects.filter(name=policy_name).first()
if mode == "apply" and not pol:
    pol = ExpressionPolicy.objects.create(name=policy_name, expression=expected_expression)
if not pol:
    fail(f"ExpressionPolicy missing: {policy_name}")

if mode == "apply":
    changed = False
    if (pol.expression or "").strip() != expected_expression.strip():
        pol.expression = expected_expression
        changed = True
    if changed:
        pol.save(update_fields=["expression"])

stage = AuthenticatorValidateStage.objects.filter(name=stage_name).first()
if mode == "apply" and not stage:
    stage = AuthenticatorValidateStage.objects.create(
        name=stage_name,
        not_configured_action="configure",
        device_classes=["totp", "webauthn"],
    )
if not stage:
    fail(f"AuthenticatorValidateStage missing: {stage_name}")

desired_not_configured = "configure"
desired_device_classes = ["totp", "webauthn"]

if mode == "apply":
    changed = False
    if stage.not_configured_action != desired_not_configured:
        stage.not_configured_action = desired_not_configured
        changed = True
    # Keep order stable for comparison.
    cur = list(stage.device_classes or [])
    if sorted(cur) != sorted(desired_device_classes):
        stage.device_classes = desired_device_classes
        changed = True
    if changed:
        stage.save(update_fields=["not_configured_action", "device_classes"])

binding = FlowStageBinding.objects.filter(target=flow, stage=stage).first()
if mode == "apply" and not binding:
    binding = FlowStageBinding.objects.create(target=flow, stage=stage, order=binding_order)
if not binding:
    fail(f"FlowStageBinding missing for stage={stage_name} flow={flow_slug}")

if mode == "apply" and binding.order != binding_order:
    binding.order = binding_order
    binding.save(update_fields=["order"])

# Attach the policy so the stage only runs for Authentik admins.
pb = PolicyBinding.objects.filter(target=binding, policy=pol).first()
if mode == "apply" and not pb:
    # In authentik 2025.x, the FlowStageBinding->policies relation uses PolicyBinding
    # as a through model and requires a non-null "order" field.
    pb = PolicyBinding.objects.create(target=binding, policy=pol, order=0)

# Verify invariants
errs = []
if (pol.expression or "").strip() != expected_expression.strip():
    errs.append("ExpressionPolicy expression mismatch")
if stage.not_configured_action != desired_not_configured:
    errs.append(f"Stage not_configured_action={stage.not_configured_action} expected={desired_not_configured}")
if sorted(list(stage.device_classes or [])) != sorted(desired_device_classes):
    errs.append(f"Stage device_classes={stage.device_classes} expected={desired_device_classes}")
if binding.order != binding_order:
    errs.append(f"Binding order={binding.order} expected={binding_order}")
if PolicyBinding.objects.filter(target=binding).count() == 0:
    errs.append("Binding has no policies (should restrict to admin group)")
elif not PolicyBinding.objects.filter(target=binding, policy=pol).exists():
    errs.append("Binding missing required policy")

if errs:
    for e in errs:
        warn(e)
    raise SystemExit(1)

ok(f"Admin MFA stage present and gated by policy (flow={flow_slug}, stage={stage_name})")
print("OK")
'
