# Tutor Plugin Migration Runbook
_Audience: Platform Eng • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers procedures for Tutor version upgrades and plugin migration.

> **Spec**: `specs/tutor-configuration-resilience_spec.md`
> **Testmap**: `specs/testmaps/tutor-configuration-resilience_spec.testmap.yml`
> **ADR**: `docs/adr/006-tutor-plugin-based-configuration.md`

## Prerequisites

- Current Tutor version documented in `requirements.txt` or `Makefile`
- Backup of current `tutor_env/config.yml`
- Understanding of current patches in `infrastructure/tutor/apply-patches.sh`

---

## Tutor Version Upgrade Procedure

### Pre-Upgrade Checklist
1. Document current Tutor version:
   ```bash
   tutor --version
   ```
2. Review Tutor release notes for the target version:
   - Breaking changes
   - New configuration options
   - Deprecated features
3. Back up current configuration:
   ```bash
   cp -r tutor_env/config.yml tutor_env/config.yml.backup-$(date +%Y%m%d)
   ```
4. Review `apply-patches.sh` for compatibility:
   - Check if patched files have changed upstream
   - Check if any patches are now upstream defaults
   - Identify patches that need adaptation

### Upgrade Procedure
1. Update Tutor version in dependency specification
2. Install new version:
   ```bash
   pip install "tutor[full]==<new_version>"
   ```
3. Run config save with patches:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   ```
4. Verify patches applied cleanly:
   ```bash
   ./scripts/infra/verify-tutor-config.sh
   ```
5. Test locally before deploying:
   ```bash
   tutor local launch -I
   ```
6. Run smoke tests:
   ```bash
   make qa-smoke
   ```

### Post-Upgrade Verification
1. All services start and respond
2. LMS login works
3. Studio course editing works
4. MFE pages load
5. MongoDB Atlas connection is functional
6. Celery workers process tasks

### Rollback Procedure
1. Restore backed-up configuration:
   ```bash
   cp tutor_env/config.yml.backup-<date> tutor_env/config.yml
   ```
2. Reinstall previous Tutor version:
   ```bash
   pip install "tutor[full]==<previous_version>"
   ```
3. Regenerate environment:
   ```bash
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   tutor local restart
   ```

### Acceptance
- New Tutor version installs without errors
- All patches apply cleanly on new version
- All services start and pass health checks
- No regression in existing functionality
- Rollback procedure is tested and documented
