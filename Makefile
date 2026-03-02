.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply tutor-verify infra-sync-vendored-mfe-caddyfile infra-sync-gitops-prod-tags branding-sync migrations-prepare migrations-verify qa-smoke qa-phase7-dom-audit qa-phase7-dom-audit-dev qa-phase7-dom-audit-full qa-phase7-dom-audit-full-dev qa-phase7-dom-audit-full-strict qa-phase7-selector-coverage qa-phase2-smoke-evidence-prod qa-phase2-smoke-evidence-dev qa-phase2-smoke-evidence-contract qa-runtime-theme-mode-prod qa-runtime-theme-mode-dev qa-runtime-theme-drift-diagnose qa-paragon-theme-budget qa-frontend-extended-surfaces qa-a11y-prod qa-a11y-dev qa-a11y-prod-online qa-a11y-dev-online qa-a11y-prod-hybrid qa-a11y-dev-hybrid qa-performance-prod qa-performance-dev qa-cross-browser-prod qa-cross-browser-dev qa-frontend-runtime-qa-prod qa-frontend-runtime-qa-dev qa-frontend-runtime-blocker-sweep qa-frontend-runtime-blocker-sweep-both qa-frontend-runtime-blocker-sweep-dev qa-frontend-runtime-blocker-sweep-prod qa-runtime-blocker-refresh qa-runtime-blocker-infra-prompt qa-runtime-blocker-status qa-npm-start-smoke qa-npm-start-smoke-local qa-branding-screenshots qa-branding-before-after qa-frontend-closure qa-frontend-closure-prod qa-frontend-closure-dev qa-frontend-closure-prod-screenshots qa-frontend-closure-prod-screenshots-mfe qa-frontend-closure-dev-screenshots qa-frontend-closure-dev-screenshots-mfe qa-certificate-branding qa-email-template-branding qa-make-help-contract qa-frontend-contracts forum-smoke credentials-notes-smoke mobile-secrets-check lint format test clean mobile-setup spec-lint spec-coverage spec-compliance lint-specs verify-specs validate-testmaps generate-testmaps lint-conventions spec-dashboard check-fast check

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

infra-sync-vendored-mfe-caddyfile: ## Dry-run vendored MFE Caddyfile sync check against infra checkout
	./scripts/infra/sync-vendored-mfe-caddyfile.sh

infra-sync-gitops-prod-tags: ## Dry-run prod image-tag sync check against infra checkout
	./scripts/infra/sync-gitops-prod-image-tags.sh

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
	./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.io --require-runtime --require-slot-markers
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers
	./scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only

qa-phase2-smoke-evidence-dev: ## Run Phase 2 MFE smoke + screenshot evidence capture (dev)
	./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers
	./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only

qa-phase2-smoke-evidence-contract: ## Verify Phase 2 smoke evidence script + workflow contracts
	./scripts/qa/verify-phase2-smoke-evidence-contract.sh

qa-runtime-theme-mode-prod: ## Fast runtime theme-mode preflight (prod)
	./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.io --require-runtime --require-slot-markers

qa-runtime-theme-mode-dev: ## Fast runtime theme-mode preflight (dev)
	./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers

qa-runtime-theme-drift-diagnose: ## Diagnose runtime theme drift (prod/dev preflight + GitOps parity)
	./scripts/qa/diagnose-runtime-theme-drift.sh

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

qa-frontend-runtime-blocker-sweep: ## Run canonical frontend runtime blocker sweep (set QA_ENV=dev|prod|both; default both)
	@if [ -z "$(QA_ENV)" ]; then \
		QA_ENV=both; \
	else \
		QA_ENV="$(QA_ENV)"; \
	fi; \
	if [ "$$QA_ENV" != "dev" ] && [ "$$QA_ENV" != "prod" ] && [ "$$QA_ENV" != "both" ]; then \
		echo "ERROR: QA_ENV must be dev, prod, or both (got '$$QA_ENV')"; \
		exit 2; \
	fi; \
	./scripts/qa/run-frontend-runtime-blocker-sweep.sh --env "$$QA_ENV"

qa-frontend-runtime-blocker-sweep-both: ## Run canonical frontend runtime blocker sweep (both)
	$(MAKE) qa-frontend-runtime-blocker-sweep QA_ENV=both

qa-frontend-runtime-blocker-sweep-dev: ## Run canonical frontend runtime blocker sweep (dev)
	$(MAKE) qa-frontend-runtime-blocker-sweep QA_ENV=dev

qa-frontend-runtime-blocker-sweep-prod: ## Run canonical frontend runtime blocker sweep (prod)
	$(MAKE) qa-frontend-runtime-blocker-sweep QA_ENV=prod

qa-runtime-blocker-refresh: ## Run blocker sweep + always emit prompt/status artifacts; exit with sweep status
	@mkdir -p var/qa; \
	set +e; \
	$(MAKE) qa-frontend-runtime-blocker-sweep-both; \
	sweep_exit=$$?; \
	set -e; \
	$(MAKE) qa-runtime-blocker-infra-prompt OUTPUT_FILE=var/qa/frontend-runtime-blocker-infra-prompt.txt; \
	$(MAKE) qa-runtime-blocker-infra-prompt OUTPUT_FILE=var/qa/frontend-runtime-blocker-infra-prompt.md FORMAT=markdown; \
	$(MAKE) qa-runtime-blocker-status OUTPUT_FILE=var/qa/frontend-runtime-blocker-status.txt; \
	$(MAKE) qa-runtime-blocker-status OUTPUT_FILE=var/qa/frontend-runtime-blocker-status.md FORMAT=markdown; \
	exit $$sweep_exit

qa-runtime-blocker-infra-prompt: ## Generate infra prompt (INPUT_JSON/OUTPUT_FILE optional; FORMAT=text|markdown)
	@args=""; \
	if [ -n "$(INPUT_JSON)" ]; then args="$$args --input \"$(INPUT_JSON)\""; fi; \
	if [ -n "$(OUTPUT_FILE)" ]; then args="$$args --output \"$(OUTPUT_FILE)\""; fi; \
	if [ -n "$(FORMAT)" ]; then args="$$args --format \"$(FORMAT)\""; fi; \
	eval "./scripts/qa/generate-runtime-blocker-infra-prompt.sh $$args"

qa-runtime-blocker-status: ## Print blocker status (INPUT_JSON/OUTPUT_FILE optional; FORMAT=text|markdown; STRICT=1 fail on blockers)
	@args=""; \
	if [ -n "$(INPUT_JSON)" ]; then args="$$args --input \"$(INPUT_JSON)\""; fi; \
	if [ -n "$(OUTPUT_FILE)" ]; then args="$$args --output \"$(OUTPUT_FILE)\""; fi; \
	if [ -n "$(FORMAT)" ]; then args="$$args --format \"$(FORMAT)\""; fi; \
	if [ "$(STRICT)" = "1" ]; then args="$$args --strict"; fi; \
	eval "./scripts/qa/print-runtime-blocker-status.sh $$args"

qa-npm-start-smoke-local: ## Run local npm-start MFE smoke (authn, learning, account, profile)
	./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://localhost --require-branding-markers

qa-npm-start-smoke: ## Run env-based MFE smoke (set QA_ENV=prod|dev; set REQUIRE_RUNTIME_THEME=1 for strict runtime mode)
	@if [ "$(QA_ENV)" = "prod" ]; then \
		args="--base-url https://academyv2.mereka.io --require-branding-markers"; \
		if [ "$(REQUIRE_RUNTIME_THEME)" = "1" ]; then args="$$args --require-runtime-theme"; fi; \
	elif [ "$(QA_ENV)" = "dev" ]; then \
		args="--base-url https://academyv2.mereka.dev --require-branding-markers"; \
	else \
		echo "ERROR: QA_ENV must be prod or dev (got '$(QA_ENV)')"; \
		exit 2; \
	fi; \
	./scripts/qa/verify-npm-start-mfe-smoke.sh $$args

qa-branding-screenshots: ## Capture branding screenshots (set QA_ENV=prod|dev; set QA_MFE_ONLY=1 for MFE-only scope)
	@if [ "$(QA_ENV)" != "prod" ] && [ "$(QA_ENV)" != "dev" ]; then \
		echo "ERROR: QA_ENV must be prod or dev (got '$(QA_ENV)')"; \
		exit 2; \
	fi; \
	args="--env $(QA_ENV)"; \
	if [ "$(QA_MFE_ONLY)" = "1" ]; then args="$$args --mfe-only"; fi; \
	./scripts/qa/capture-branding-screenshots.sh $$args

qa-branding-before-after: ## Build before/after branding visual report (set QA_ENV=prod|dev; set QA_MFE_ONLY=1 for MFE-only scope)
	@if [ "$(QA_ENV)" != "prod" ] && [ "$(QA_ENV)" != "dev" ]; then \
		echo "ERROR: QA_ENV must be prod or dev (got '$(QA_ENV)')"; \
		exit 2; \
	fi; \
	args="--env $(QA_ENV)"; \
	if [ "$(QA_MFE_ONLY)" = "1" ]; then args="$$args --mfe-only"; fi; \
	./scripts/qa/build-branding-before-after-report.sh $$args

qa-frontend-closure: ## Run frontend closure pipeline (set QA_ENV=prod|dev; optional: QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1 QA_REQUIRE_RUNTIME_THEME=1 QA_CROSS_BROWSER=0)
	@if [ "$(QA_ENV)" != "prod" ] && [ "$(QA_ENV)" != "dev" ]; then \
		echo "ERROR: QA_ENV must be prod or dev (got '$(QA_ENV)')"; \
		exit 2; \
	fi; \
	args="--env $(QA_ENV) --frontend-only"; \
	if [ "$(QA_CROSS_BROWSER)" != "0" ]; then args="$$args --cross-browser"; fi; \
	if [ "$(QA_CAPTURE_SCREENSHOTS)" = "1" ]; then args="$$args --capture-screenshots"; fi; \
	if [ "$(QA_REQUIRE_RUNTIME_THEME)" = "1" ]; then args="$$args --require-runtime-theme"; fi; \
	env_prefix=""; \
	if [ "$(QA_CAPTURE_SCREENSHOTS)" = "1" ]; then env_prefix="RUN_SCREENSHOTS=1"; fi; \
	if [ "$(QA_MFE_ONLY)" = "1" ]; then env_prefix="$$env_prefix SCREENSHOT_SCOPE=mfe-only"; fi; \
	eval "$$env_prefix ./scripts/qa/run-branding-evidence-pipeline.sh $$args"

qa-frontend-closure-prod: ## Run frontend closure pipeline (prod, cross-browser, runtime theme required)
	$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_REQUIRE_RUNTIME_THEME=1

qa-frontend-closure-dev: ## Run frontend closure pipeline (dev, cross-browser)
	$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1

qa-frontend-closure-prod-screenshots: ## Run frontend closure pipeline with screenshot capture (prod)
	$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_REQUIRE_RUNTIME_THEME=1

qa-frontend-closure-prod-screenshots-mfe: ## Run frontend closure pipeline with MFE-only screenshot capture (prod)
	$(MAKE) qa-frontend-closure QA_ENV=prod QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1 QA_REQUIRE_RUNTIME_THEME=1

qa-frontend-closure-dev-screenshots: ## Run frontend closure pipeline with screenshot capture (dev)
	$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1

qa-frontend-closure-dev-screenshots-mfe: ## Run frontend closure pipeline with MFE-only screenshot capture (dev)
	$(MAKE) qa-frontend-closure QA_ENV=dev QA_CROSS_BROWSER=1 QA_CAPTURE_SCREENSHOTS=1 QA_MFE_ONLY=1

qa-certificate-branding: ## Verify certificate surface branding coverage
	./scripts/qa/verify-certificate-branding.sh

qa-email-template-branding: ## Verify multilingual email template branding coverage
	./scripts/qa/verify-email-template-multilang.sh

qa-make-help-contract: ## Verify Makefile help discoverability contract
	./scripts/qa/verify-make-help-contract.sh

qa-frontend-contracts: ## Run frontend closure contract suite (Makefile lanes + CI gate section)
	./scripts/qa/verify-make-help-contract.sh
	./scripts/qa/verify-frontend-qa-make-targets.sh
	$(MAKE) qa-frontend-extended-surfaces
	./scripts/qa/verify-release-automation.sh
	./scripts/qa/verify-phase7-dom-audit-contract.sh
	./scripts/qa/verify-phase7-selector-list-coverage.sh
	./scripts/qa/verify-runtime-theme-drift-lane.sh
	./scripts/qa/verify-phase2-smoke-evidence-contract.sh
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
