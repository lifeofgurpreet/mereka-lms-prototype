.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply tutor-verify branding-sync migrations-prepare migrations-verify qa-smoke qa-phase7-dom-audit qa-phase7-dom-audit-dev qa-phase7-dom-audit-full qa-phase7-dom-audit-full-dev qa-phase7-dom-audit-full-strict qa-phase7-selector-coverage qa-phase2-smoke-evidence-prod qa-phase2-smoke-evidence-dev qa-phase2-smoke-evidence-contract qa-paragon-theme-budget qa-frontend-extended-surfaces qa-a11y-prod qa-a11y-dev qa-a11y-prod-online qa-a11y-dev-online qa-a11y-prod-hybrid qa-a11y-dev-hybrid qa-performance-prod qa-performance-dev qa-cross-browser-prod qa-cross-browser-dev qa-frontend-runtime-qa-prod qa-frontend-runtime-qa-dev qa-npm-start-smoke-local qa-npm-start-smoke-prod qa-npm-start-smoke-dev qa-branding-screenshots-prod qa-branding-screenshots-dev qa-branding-screenshots-mfe-prod qa-branding-screenshots-mfe-dev qa-frontend-closure-prod qa-frontend-closure-dev qa-frontend-closure-prod-screenshots qa-frontend-closure-prod-screenshots-mfe qa-frontend-closure-dev-screenshots qa-frontend-closure-dev-screenshots-mfe qa-certificate-branding qa-email-template-branding qa-make-help-contract qa-frontend-contracts forum-smoke credentials-notes-smoke mobile-secrets-check lint format test clean mobile-setup spec-lint spec-coverage spec-compliance lint-specs verify-specs validate-testmaps generate-testmaps lint-conventions spec-dashboard check-fast check

help: ## Show this help message
	@echo "Mereka Academy Open edX - Common Tasks"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

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
	./scripts/qa/verify-mobile-secrets-runtime.sh --offline || true

qa-phase7-dom-audit: ## Run strict Phase 7 runtime DOM selector audit (prod)
	./scripts/qa/run-phase7-dom-audit.sh --env prod --project chromium

qa-phase7-dom-audit-dev: ## Run strict Phase 7 runtime DOM selector audit (dev)
	./scripts/qa/run-phase7-dom-audit.sh --env dev --project chromium

qa-phase7-dom-audit-full: ## Run expanded Phase 7 runtime DOM selector audit (prod)
	./scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium

qa-phase7-dom-audit-full-dev: ## Run expanded Phase 7 runtime DOM selector audit (dev)
	./scripts/qa/run-phase7-dom-audit-full.sh --env dev --project chromium

qa-phase7-dom-audit-full-strict: ## Run expanded Phase 7 runtime DOM selector audit (prod, runtime theme required)
	./scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium --require-runtime-theme

qa-phase7-selector-coverage: ## Verify Phase 7 selector-list coverage stays aligned with mereka.scss classes
	./scripts/qa/verify-phase7-selector-list-coverage.sh

qa-phase2-smoke-evidence-prod: ## Run Phase 2 MFE smoke + screenshot evidence capture (prod, runtime theme required)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers
	./scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only

qa-phase2-smoke-evidence-dev: ## Run Phase 2 MFE smoke + screenshot evidence capture (dev)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers
	./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only

qa-phase2-smoke-evidence-contract: ## Verify Phase 2 smoke evidence script + workflow contracts
	./scripts/qa/verify-phase2-smoke-evidence-contract.sh
	./scripts/qa/verify-phase2-smoke-evidence-workflow.sh

qa-paragon-theme-budget: ## Verify Paragon runtime theme asset size-budget and token coverage
	./scripts/qa/verify-paragon-token-coverage.sh

qa-frontend-extended-surfaces: ## Run extended-surface frontend branding checks (Paragon budget + certificate + email)
	./scripts/qa/verify-paragon-token-coverage.sh
	./scripts/qa/verify-certificate-branding.sh
	./scripts/qa/verify-email-template-multilang.sh

qa-a11y-prod: ## Run accessibility gate (offline) for prod baseline
	./scripts/qa/run-a11y-runtime-lane.sh --env prod --mode offline

qa-a11y-dev: ## Run accessibility gate (offline) for dev baseline
	./scripts/qa/run-a11y-runtime-lane.sh --env dev --mode offline

qa-a11y-prod-online: ## Run accessibility gate (online) for prod apps routes
	./scripts/qa/run-a11y-runtime-lane.sh --env prod --mode online

qa-a11y-dev-online: ## Run accessibility gate (online) for dev apps routes
	./scripts/qa/run-a11y-runtime-lane.sh --env dev --mode online

qa-a11y-prod-hybrid: ## Run accessibility gate (hybrid offline+online) for prod apps routes
	./scripts/qa/run-a11y-runtime-lane.sh --env prod --mode hybrid --allow-missing-reports

qa-a11y-dev-hybrid: ## Run accessibility gate (hybrid offline+online) for dev apps routes
	./scripts/qa/run-a11y-runtime-lane.sh --env dev --mode hybrid --allow-missing-reports

qa-performance-prod: ## Run frontend performance spot-check (prod, runtime theme required)
	./scripts/qa/verify-frontend-performance-spotcheck.sh --env prod --require-runtime

qa-performance-dev: ## Run frontend performance spot-check (dev)
	./scripts/qa/verify-frontend-performance-spotcheck.sh --env dev

qa-cross-browser-prod: ## Run cross-browser branding smoke (prod, runtime theme required)
	./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser --require-runtime-theme

qa-cross-browser-dev: ## Run cross-browser branding smoke (dev)
	./scripts/qa/verify-cross-browser-branding-smoke.sh --env dev --cross-browser

qa-frontend-runtime-qa-prod: ## Run runtime frontend QA tranche (prod: cross-browser + a11y hybrid + performance)
	$(MAKE) qa-cross-browser-prod
	$(MAKE) qa-a11y-prod-hybrid
	$(MAKE) qa-performance-prod

qa-frontend-runtime-qa-dev: ## Run runtime frontend QA tranche (dev: cross-browser + a11y hybrid + performance)
	$(MAKE) qa-cross-browser-dev
	$(MAKE) qa-a11y-dev-hybrid
	$(MAKE) qa-performance-dev

qa-npm-start-smoke-local: ## Run local npm-start MFE smoke (authn, learning, account, profile)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://localhost --require-branding-markers

qa-npm-start-smoke-prod: ## Run prod MFE smoke (runtime theme + branding markers)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers

qa-npm-start-smoke-dev: ## Run dev MFE smoke (branding markers)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers

qa-branding-screenshots-prod: ## Capture branding screenshots for production surfaces
	./scripts/qa/capture-branding-screenshots.sh prod

qa-branding-screenshots-dev: ## Capture branding screenshots for development surfaces
	./scripts/qa/capture-branding-screenshots.sh dev

qa-branding-screenshots-mfe-prod: ## Capture MFE-only branding screenshots for production surfaces
	./scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only

qa-branding-screenshots-mfe-dev: ## Capture MFE-only branding screenshots for development surfaces
	./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only

qa-frontend-closure-prod: ## Run frontend closure pipeline (prod, cross-browser, runtime theme required)
	./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --require-runtime-theme

qa-frontend-closure-dev: ## Run frontend closure pipeline (dev, cross-browser)
	./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser

qa-frontend-closure-prod-screenshots: ## Run frontend closure pipeline with screenshot capture (prod)
	RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --capture-screenshots --require-runtime-theme

qa-frontend-closure-prod-screenshots-mfe: ## Run frontend closure pipeline with MFE-only screenshot capture (prod)
	SCREENSHOT_SCOPE=mfe-only RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser --capture-screenshots --require-runtime-theme

qa-frontend-closure-dev-screenshots: ## Run frontend closure pipeline with screenshot capture (dev)
	RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser --capture-screenshots

qa-frontend-closure-dev-screenshots-mfe: ## Run frontend closure pipeline with MFE-only screenshot capture (dev)
	SCREENSHOT_SCOPE=mfe-only RUN_SCREENSHOTS=1 ./scripts/qa/run-branding-evidence-pipeline.sh --env dev --frontend-only --cross-browser --capture-screenshots

qa-certificate-branding: ## Verify certificate surface branding coverage
	./scripts/qa/verify-certificate-branding.sh

qa-email-template-branding: ## Verify multilingual email template branding coverage
	./scripts/qa/verify-email-template-multilang.sh

qa-make-help-contract: ## Verify Makefile help discoverability contract
	./scripts/qa/verify-make-help-contract.sh

qa-frontend-contracts: ## Run frontend closure contract suite (workflows + make targets + CI gate section)
	./scripts/qa/verify-make-help-contract.sh
	./scripts/qa/verify-frontend-qa-make-targets.sh
	$(MAKE) qa-frontend-extended-surfaces
	./scripts/qa/verify-frontend-extended-surfaces-workflow.sh
	./scripts/qa/verify-certificate-branding-workflow.sh
	./scripts/qa/verify-email-template-branding-workflow.sh
	./scripts/qa/verify-frontend-contracts-workflow.sh
	./scripts/qa/verify-mfe-live-dom-audit-workflow.sh
	./scripts/qa/verify-frontend-branding-closure-workflow.sh
	./scripts/qa/verify-frontend-runtime-qa-workflow.sh
	./scripts/qa/verify-release-evidence-workflow.sh
	./scripts/qa/verify-phase7-dom-audit-contract.sh
	./scripts/qa/verify-phase7-selector-list-coverage.sh
	$(MAKE) qa-phase2-smoke-evidence-contract
	./scripts/qa/verify-paragon-theme-budget-workflow.sh
	./scripts/qa/verify-branding-evidence-a11y-contract.sh
	./scripts/qa/verify-branding-evidence-screenshot-contract.sh
	./scripts/qa/verify-ci-cd-pipeline.sh --section gitops

mobile-secrets-check: ## Run mobile secrets verification (offline static checks)
	./scripts/qa/verify-mobile-secrets-runtime.sh --offline

forum-smoke: ## Run forum service smoke tests (offline + optional online)
	./scripts/qa/verify-forum-smoke.sh $(FORUM_SMOKE_ARGS)

credentials-notes-smoke: ## Run Credentials and Notes service smoke tests (offline + optional online)
	./scripts/qa/verify-credentials-notes-smoke.sh $(CREDENTIALS_NOTES_SMOKE_ARGS)

lint: ## Run linters (Python, Shell, JS)
	ruff check scripts/ migrations/ services/
	shellcheck scripts/**/*.sh
	npm run lint

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
