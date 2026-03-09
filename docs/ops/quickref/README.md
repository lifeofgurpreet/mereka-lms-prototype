# Quick Reference Cards

_Audience: Operators • Owner: SRE Team • Last verified: 2026-03-06 • Status: canonical_

One-page quick reference guides for common Mereka LMS operations.

---

## Available Cards

| Card | Purpose | Use When |
|------|---------|----------|
| [kubectl-cheatsheet.md](./kubectl-cheatsheet.md) | Kubernetes operations | Managing pods, services, deployments in GKE |
| [tutor-commands.md](./tutor-commands.md) | Tutor operations | Building images, config changes, local development |
| [verification-scripts.md](./verification-scripts.md) | Automated testing | Running verifications, checking spec coverage |
| [common-troubleshooting.md](./common-troubleshooting.md) | Troubleshooting | Site down, performance issues, config problems |

## Additional quick references

- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) for the general operator quick reference bundle
- [access-urls.md](./access-urls.md) for service URLs and local access points
- [local-access-info.md](./local-access-info.md) for local environment entrypoints
- [local-production-parity.md](./local-production-parity.md) for parity expectations between local and production
- [local-work-remaining.md](./local-work-remaining.md) for local environment follow-up work
- [discovery-quickstart.md](./discovery-quickstart.md) for Discovery service quickstart steps
- [checklists/doc-delivery-checklist.md](./checklists/doc-delivery-checklist.md) for docs delivery verification
- [checklists/spec-delivery-checklist.md](./checklists/spec-delivery-checklist.md) for spec delivery verification

---

## Quick Start

### Site is Down

1. **Run 5-command diagnostic** ([common-troubleshooting.md](./common-troubleshooting.md#site-down))
   ```bash
   kubectl get pods -n mereka-lms
   kubectl get endpoints -n mereka-lms
   kubectl get svc caddy -n mereka-lms
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50
   ```

2. **Most common fix**: Empty endpoints
   ```bash
   ./scripts/infra/fix-service-selectors.sh
   ```

### Need to Update Tutor Config

1. **Use safe wrapper** ([tutor-commands.md](./tutor-commands.md#configuration-management))
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   ./scripts/infra/tutor-config-save.sh --set KEY=value
   tutor local restart
   ```

2. **Verify patches applied**
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ```

### Debugging K8s Services

1. **Check endpoints** ([kubectl-cheatsheet.md](./kubectl-cheatsheet.md#endpoint-checks-critical))
   ```bash
   kubectl get svc,endpoints -n mereka-lms
   ```

2. **View pod logs** ([kubectl-cheatsheet.md](./kubectl-cheatsheet.md#pod-logs))
   ```bash
   kubectl logs -f deployment/lms -n mereka-lms
   ```

3. **Test connectivity** ([kubectl-cheatsheet.md](./kubectl-cheatsheet.md#service-connectivity-tests))
   ```bash
   kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms \
     -- curl -I http://lms:8000
   ```

### Running Verifications

1. **Quick checks** ([verification-scripts.md](./verification-scripts.md#quick-checks))
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ./scripts/qa/verify-k8s-images.sh
   ```

2. **Full suite**
   ```bash
   make qa-smoke
   ```

3. **Check spec coverage** ([verification-scripts.md](./verification-scripts.md#generate-coverage-report))
   ```bash
   cd scripts/qa/spec-tools
   python spec_coverage_report.py
   ```

---

## Common Workflows

### Deploy New Image to Production

```bash
# 1. Build image locally
tutor images build openedx

# 2. Tag with date-SHA
docker tag openedx:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:$(date +%Y%m%d)-ulmo-$(git rev-parse --short HEAD)

# 3. Push to registry
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:$(date +%Y%m%d)-ulmo-$(git rev-parse --short HEAD)

# 4. Update kustomization
# Edit deploy/k8s/overlays/production/kustomization.yaml

# 5. Apply to cluster
kubectl apply -k deploy/k8s/overlays/production

# 6. Watch rollout
kubectl rollout status deployment/lms -n mereka-lms

# 7. CRITICAL: Check endpoints
kubectl get endpoints -n mereka-lms
```

### Update Configuration

```bash
# 1. Modify config (safe wrapper applies patches automatically)
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set LMS_HOST=new-domain.com

# 2. Rebuild if needed
tutor images build openedx

# 3. Restart services
tutor local restart

# 4. Verify
curl -I http://localhost
```

### Investigate Performance Issue

```bash
# 1. Check resource usage
kubectl top pods -n mereka-lms
kubectl top nodes

# 2. Check pod restarts (OOM indicator)
kubectl get pods -n mereka-lms

# 3. Check slow queries
kubectl logs -n mereka-lms deployment/lms --tail=100 | grep -i "slow"

# 4. Scale if needed
kubectl scale deployment/lms --replicas=3 -n mereka-lms

# 5. Monitor
kubectl logs -f deployment/lms -n mereka-lms
```

---

## Format

All cards follow a consistent format:

- **Tables and code blocks** - Maximum information density
- **Minimal prose** - Get to the command quickly
- **One page** - Print-friendly (though multi-page for comprehensive coverage)
- **Real examples** - Actual commands used in production

---

## Contribution

When adding new cards:

1. **Keep it concise**: Focus on commands, not explanations
2. **Use tables**: Great for comparisons and options
3. **Include context**: Brief description of what/when/why
4. **Cross-reference**: Link to full guides for deep dives
5. **Test commands**: Verify all commands work as written

---

## See Also

### Full Guides

- [K8s Operations Guide](../../guides/admin/K8S_OPERATIONS_GUIDE.md) - Comprehensive K8s procedures
- [Secrets Management Guide](../../guides/admin/SECRETS_MANAGEMENT_GUIDE.md) - Full secrets workflow
- [Multi-Site Guide](../../guides/admin/MULTI_SITE_GUIDE.md) - Multi-tenancy operations
- [Observability Guide](../../guides/admin/OBSERVABILITY_GUIDE.md) - Monitoring and alerting

### Other References

- [access-urls.md](access-urls.md) - All service URLs and credentials
- [DEPLOYMENT_VERIFICATION.md](../../operations/DEPLOYMENT_VERIFICATION.md) - Post-deploy checklist
- [TUTOR_CONFIG_SAFETY.md](../../operations/TUTOR_CONFIG_SAFETY.md) - Config best practices
- [VERIFICATION_REPORT.md](../../operations/VERIFICATION_REPORT.md) - Latest validation results

### Project Documentation

- [CLAUDE.md](../../../CLAUDE.md) - Project overview and rules
- [AGENTS.md](../../../AGENTS.md) - Repository guidelines
- [docs/README.md](../../README.md) - Documentation index
