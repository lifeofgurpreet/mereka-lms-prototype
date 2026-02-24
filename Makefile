.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply tutor-verify branding-sync migrations-prepare migrations-verify qa-smoke forum-smoke credentials-notes-smoke lint format test clean mobile-setup spec-lint spec-coverage spec-compliance lint-specs verify-specs validate-testmaps generate-testmaps lint-conventions spec-dashboard check-fast check

help: ## Show this help message
	@echo "Mereka Academy Open edX - Common Tasks"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

bootstrap: ## Set up development environment (venv, pre-commit)
	python3 -m venv .venv || true
	. .venv/bin/activate && pip install -U pip uv || true
	pre-commit install || echo "pre-commit not installed, skipping"

tutor-start: ## Start Tutor local environment
	source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && tutor local start -d

tutor-stop: ## Stop Tutor local environment
	source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && tutor local stop

tutor-restart: ## Restart Tutor local environment
	source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && tutor local restart

tutor-apply: ## Apply Tutor patches after config changes
	source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && tutor config save && ./infrastructure/tutor/apply-patches.sh && tutor local restart

tutor-verify: ## Verify Tutor config patches applied correctly
	@echo "Verifying Tutor configuration patches..."
	@source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && \
	if [ ! -f tutor_env/env/local/docker-compose.yml ]; then \
		echo "❌ Tutor config not initialized. Run 'make tutor-apply' first."; \
		exit 1; \
	fi && \
	echo "Checking AC-001: MySQL authentication patch..." && \
	if ! grep -q "mysql_native_password" tutor_env/env/local/docker-compose.yml; then \
		echo "❌ FAILED: MySQL native password patch not applied"; \
		exit 1; \
	fi && \
	echo "✅ AC-001 PASSED: MySQL authentication patch applied" && \
	echo "Checking AC-002: MFE Node.js memory patch..." && \
	if ! grep -q "NODE_OPTIONS.*6144" tutor_env/env/build/openedx/Dockerfile; then \
		echo "❌ FAILED: MFE Node.js memory patch not applied"; \
		exit 1; \
	fi && \
	echo "✅ AC-002 PASSED: MFE Node.js patch applied" && \
	echo "Checking AC-003: Multi-site domains..." && \
	if ! grep -q "academy.biji-biji.com" tutor_env/env/apps/openedx/settings/lms/production.py; then \
		echo "❌ FAILED: Multi-site domains not configured"; \
		exit 1; \
	fi && \
	echo "✅ AC-003 PASSED: Multi-site domains configured" && \
	echo "Checking AC-004: mfe_oauth_fix app..." && \
	if ! grep -q "mfe_oauth_fix" tutor_env/env/apps/openedx/settings/lms/production.py; then \
		echo "❌ FAILED: mfe_oauth_fix app not installed"; \
		exit 1; \
	fi && \
	echo "✅ AC-004 PASSED: mfe_oauth_fix app installed" && \
	echo "Checking AC-005: django_prometheus..." && \
	if ! grep -q "django_prometheus" tutor_env/env/apps/openedx/settings/lms/production.py; then \
		echo "❌ FAILED: django_prometheus not installed"; \
		exit 1; \
	fi && \
	echo "✅ AC-005 PASSED: django_prometheus installed" && \
	echo "" && \
	echo "✅ All Tutor configuration verifications passed!"

branding-sync: ## Sync branding assets to Tutor themes
	./scripts/branding/sync-brand-assets.sh

migrations-prepare: ## Prepare Kajabi migration imports
	python scripts/migrations/kajabi/prepare_openedx_imports.py

migrations-verify: ## Verify Kajabi migration imports
	python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py

qa-smoke: ## Run smoke tests
	./scripts/qa/smoke-test.sh
	./scripts/qa/verify-forum-smoke.sh --offline
	./scripts/qa/verify-credentials-notes-smoke.sh --offline

forum-smoke: ## Run forum service smoke tests (offline + optional online)
	./scripts/qa/verify-forum-smoke.sh $(FORUM_SMOKE_ARGS)

credentials-notes-smoke: ## Run Credentials and Notes service smoke tests (offline + optional online)
	./scripts/qa/verify-credentials-notes-smoke.sh $(CREDENTIALS_NOTES_SMOKE_ARGS)

lint: ## Run linters (Python, Shell, JS)
	ruff check scripts/ migrations/ services/ || true
	shellcheck scripts/**/*.sh || true
	npm run lint || true

format: ## Format code (Python, Shell, JS)
	ruff format scripts/ migrations/ services/ || true
	shfmt -w scripts/**/*.sh || true
	npm run format || true

test: ## Run tests
	pytest tests/ || echo "No tests configured"

clean: ## Clean generated files
	rm -rf var/logs/* var/exports/* var/migrations/*/output/*
	find . -type d -name __pycache__ -exec rm -rf {} + || true
	find . -type f -name "*.pyc" -delete || true

mobile-setup: ## Enable mobile API for iOS/Android apps
	./scripts/infra/setup-mobile-api.sh

spec-lint: ## Run spec integrity gates (lint + verify + format + coverage)
	./scripts/qa/run-spec-integrity-gates.sh

spec-coverage: ## Show spec coverage report (text)
	python3 scripts/qa/spec-tools/spec_coverage_report.py \
		--specs-dir specs/ --scan-dirs scripts/ tests/ deploy/ infrastructure/ services/ \
		--manual-file specs/manual_verifications.yaml --repo-root . --format text

spec-compliance: ## Run automated tests and report spec compliance (repo-local only)
	python3 scripts/qa/spec-tools/run_spec_compliance.py --mode local --timeout 30

lint-specs: ## Fast spec lint only (Mereka rules, errors only)
	python3 scripts/qa/spec-tools/mereka_spec_lint.py specs/ --severity-filter error

verify-specs: ## Verify @covers annotations match spec ACs
	python3 scripts/qa/spec-tools/mereka_spec_verify.py specs/ --repo-root . \
		--scan-dirs scripts/ tests/ \
		--manual-file specs/manual_verifications.yaml

validate-testmaps: ## Validate testmap YAML format
	python3 scripts/qa/spec-tools/validate_testmap_format.py specs/testmaps/

generate-testmaps: ## Generate per-spec testmaps from @covers annotations
	@for spec in specs/*_spec.md; do \
		name=$$(basename "$$spec" .md); \
		python3 scripts/qa/spec-tools/discover_testmap.py \
			--spec "$$spec" \
			--scan-dirs scripts/ tests/ deploy/ infrastructure/ services/ \
			--manual-file specs/manual_verifications.yaml --repo-root . \
			--format yaml --output "specs/testmaps/$${name}.testmap.yml"; \
	done

lint-conventions: ## Check repo file/naming conventions (glob-ability, grep-ability, boundaries)
	./scripts/qa/lint-repo-conventions.sh

check-fast: lint-specs validate-testmaps lint-conventions ## Fast quality gates (<30s)
	@echo "Fast checks passed."

spec-dashboard: ## Show per-spec coverage dashboard
	python3 scripts/qa/spec-tools/spec_coverage_dashboard.py \
		--specs-dir specs/ --testmaps-dir specs/testmaps/

check: lint-specs validate-testmaps lint-conventions verify-specs spec-coverage ## Full spec quality suite
	@echo "All spec checks passed."

## Spec Quality Gates
check-specs: lint-specs validate-testmaps ## Run all spec quality checks
	@echo "All spec quality checks passed."

spec-verify: verify-specs ## Verify AC-IDs and testmap traceability (alias)

spec-fix: ## Bulk-add AC-IDs to spec checkboxes
	python3 scripts/qa/spec-tools/spec_fix.py specs/ --add-ac-ids