.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply tutor-verify infra-sync-vendored-mfe-caddyfile infra-sync-gitops-prod-tags branding-sync migrations-prepare migrations-verify qa-smoke qa-phase7-dom-audit qa-phase7-dom-audit-dev qa-phase7-dom-audit-full qa-phase7-dom-audit-full-dev qa-phase7-dom-audit-full-strict qa-phase7-selector-coverage qa-phase2-smoke-evidence-prod qa-phase2-smoke-evidence-dev qa-phase2-smoke-evidence-contract qa-runtime-theme-mode-prod qa-runtime-theme-mode-dev qa-runtime-theme-drift-diagnose qa-paragon-theme-budget qa-frontend-extended-surfaces qa-a11y-prod qa-a11y-dev qa-a11y-prod-online qa-a11y-dev-online qa-a11y-prod-hybrid qa-a11y-dev-hybrid qa-performance-prod qa-performance-dev qa-cross-browser-prod qa-cross-browser-dev qa-frontend-runtime-qa-prod qa-frontend-runtime-qa-dev qa-frontend-runtime-blocker-sweep qa-runtime-blocker-refresh qa-runtime-blocker-handoff-md qa-runtime-blocker-handoff-bundle qa-runtime-blocker-infra-prompt qa-runtime-blocker-status qa-npm-start-smoke qa-npm-start-smoke-local qa-branding-screenshots qa-branding-before-after qa-frontend-closure qa-certificate-branding qa-email-template-branding qa-make-help-contract qa-frontend-contracts forum-smoke credentials-notes-smoke mobile-secrets-check lint format test clean mobile-setup spec-lint spec-coverage spec-compliance lint-specs verify-specs validate-testmaps generate-testmaps lint-conventions spec-dashboard check-fast check validate-deploy-contract validate-deploy-contract-strict

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
	source infrastructure/tutor/tutor-env.sh && export TUTOR_ROOT="$(PWD)/tutor_env" && ./scripts/infra/tutor-config-save.sh && tutor local restart

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

qa-phase7-dom-audit-full-dev-auth: ## Run expanded Phase 7 authenticated learner-dashboard DOM audit (dev)
	./scripts/qa/run-phase7-dom-audit-full.sh --env dev --authenticated --context rke2-nonprod --namespace mereka-lms-dev --project chromium

qa-phase7-dom-audit-full-strict: ## Run expanded Phase 7 runtime DOM selector audit (prod, runtime theme required)
	./scripts/qa/run-phase7-dom-audit-full.sh --env prod --project chromium --require-runtime-theme

qa-mfe-selector-coverage: ## Verify the canonical MFE selector inventory stays aligned with runtime classes
	./scripts/qa/verify-mfe-selector-coverage.sh

qa-phase7-selector-coverage: ## Deprecated alias for qa-mfe-selector-coverage
	$(MAKE) qa-mfe-selector-coverage

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

qa-runtime-blocker-refresh: ## Run blocker sweep + always emit prompt/status artifacts; exit with sweep status
	@mkdir -p var/qa; \
	set +e; \
	$(MAKE) qa-frontend-runtime-blocker-sweep QA_ENV=both; \
	sweep_exit=$$?; \
	set -e; \
	$(MAKE) qa-runtime-blocker-infra-prompt OUTPUT_FILE=var/qa/frontend-runtime-blocker-infra-prompt.txt; \
	$(MAKE) qa-runtime-blocker-infra-prompt OUTPUT_FILE=var/qa/frontend-runtime-blocker-infra-prompt.md FORMAT=markdown; \
	$(MAKE) qa-runtime-blocker-status OUTPUT_FILE=var/qa/frontend-runtime-blocker-status.txt; \
	$(MAKE) qa-runtime-blocker-status OUTPUT_FILE=var/qa/frontend-runtime-blocker-status.md FORMAT=markdown; \
	$(MAKE) qa-runtime-blocker-handoff-md OUTPUT_FILE=var/qa/frontend-runtime-blocker-handoff.md; \
	$(MAKE) qa-runtime-blocker-handoff-bundle OUTPUT_FILE=var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz; \
	exit $$sweep_exit

qa-runtime-blocker-handoff-md: ## Build single markdown handoff from prompt/status markdown artifacts
	@out_file="$(if $(OUTPUT_FILE),$(OUTPUT_FILE),var/qa/frontend-runtime-blocker-handoff.md)"; \
	status_md="var/qa/frontend-runtime-blocker-status.md"; \
	prompt_md="var/qa/frontend-runtime-blocker-infra-prompt.md"; \
	mkdir -p "$$(dirname "$$out_file")"; \
	{ \
		echo "# Runtime Blocker Handoff"; \
		echo ""; \
		echo "- generated_utc: $$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
		echo "- source_status: \`$$status_md\`"; \
		echo "- source_prompt: \`$$prompt_md\`"; \
		echo ""; \
		echo "## Status"; \
		echo ""; \
		if [ -f "$$status_md" ]; then cat "$$status_md"; else echo "_missing status markdown: $$status_md_"; fi; \
		echo ""; \
		echo "## Infra Prompt"; \
		echo ""; \
		if [ -f "$$prompt_md" ]; then cat "$$prompt_md"; else echo "_missing prompt markdown: $$prompt_md_"; fi; \
	} > "$$out_file"; \
	echo "wrote $$out_file"

qa-runtime-blocker-handoff-bundle: ## Package runtime blocker artifacts into one tar.gz (STRICT=1 fail if any missing)
	@out_file="$(if $(OUTPUT_FILE),$(OUTPUT_FILE),var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz)"; \
	args="--output \"$$out_file\""; \
	if [ "$(STRICT)" = "1" ]; then args="$$args --strict"; fi; \
	eval "./scripts/qa/build-runtime-blocker-handoff-bundle.sh $$args"

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

qa-certificate-branding: ## Verify certificate surface branding coverage
	./scripts/qa/verify-certificate-branding.sh

qa-email-template-branding: ## Verify multilingual email template branding coverage
	./scripts/qa/verify-email-template-multilang.sh

mobile-secrets-check: ## Run mobile secrets verification (offline static checks)
	./scripts/qa/verify-mobile-secrets-runtime.sh --offline

forum-smoke: ## Run forum service smoke tests (offline + optional online)
	./scripts/qa/verify-forum-smoke.sh $(FORUM_SMOKE_ARGS)

credentials-notes-smoke: ## Run Credentials and Notes service smoke tests (offline + optional online)
	./scripts/qa/verify-credentials-notes-smoke.sh $(CREDENTIALS_NOTES_SMOKE_ARGS)

lint: ## Run linters (Python, Shell, JS)
	ruff check scripts/ services/
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
	./scripts/qa/clean-python-caches.sh

mobile-setup: ## Enable mobile API for iOS/Android apps
	./scripts/infra/setup-mobile-api.sh

spec-lint: ## Run spec integrity gates (lint + verify + format + coverage)
	./scripts/qa/run-spec-integrity-gates.sh

spec-coverage: ## Show spec coverage report (text)
	python3 scripts/qa/spec-tools/spec_coverage_report.py \
		--specs-dir specs/ --scan-dirs scripts/ tests/ deploy/ infrastructure/ services/ \
		--manual-file specs/plans/manual_verifications.yaml --repo-root . --format text

spec-compliance: ## Run automated tests and report spec compliance (repo-local only)
	python3 scripts/qa/spec-tools/run_spec_compliance.py --mode local --timeout 30

lint-specs: ## Fast spec lint only (Mereka rules, errors only)
	python3 scripts/qa/spec-tools/mereka_spec_lint.py specs/ --severity-filter error

verify-specs: ## Verify @covers annotations match spec ACs
	python3 scripts/qa/spec-tools/mereka_spec_verify.py specs/ --repo-root . \
		--scan-dirs scripts/ tests/ \
		--manual-file specs/plans/manual_verifications.yaml

validate-testmaps: ## Validate testmap YAML format
	python3 scripts/qa/spec-tools/validate_testmap_format.py specs/_generated/testmaps/

generate-testmaps: ## Generate per-spec testmaps from @covers annotations
	@for spec in specs/*_spec.md; do \
		name=$$(basename "$$spec" .md); \
		python3 scripts/qa/spec-tools/discover_testmap.py \
			--spec "$$spec" \
			--scan-dirs scripts/ tests/ deploy/ infrastructure/ services/ \
			--manual-file specs/plans/manual_verifications.yaml --repo-root . \
			--format yaml --output "specs/_generated/testmaps/$${name}.testmap.yml"; \
	done

lint-conventions: ## Check repo file/naming conventions (glob-ability, grep-ability, boundaries)
	./scripts/qa/lint-repo-conventions.sh

check-fast: lint-specs validate-testmaps lint-conventions ## Fast quality gates (<30s)
	@echo "Fast checks passed."

spec-dashboard: ## Show per-spec coverage dashboard
	python3 scripts/qa/spec-tools/spec_coverage_dashboard.py \
		--specs-dir specs/ --testmaps-dir specs/_generated/testmaps/

check: lint-specs validate-testmaps lint-conventions verify-specs spec-coverage ## Full spec quality suite
	@echo "All spec checks passed."

.PHONY: adr-governance adr-impact
adr-governance: ## Run ADR governance suite (blocking local gate)
	./scripts/qa/run-adr-gates.sh

adr-impact: ## Print ADR impact summary for a diff range (requires DIFF_RANGE, e.g. make adr-impact DIFF_RANGE=HEAD~1...HEAD)
	@test -n "$(DIFF_RANGE)" || (echo "DIFF_RANGE is required (e.g. make adr-impact DIFF_RANGE=HEAD~1...HEAD)"; exit 2)
	python3 scripts/qa/resolve_adr_impact.py --diff-range "$(DIFF_RANGE)"

## Spec Quality Gates
check-specs: lint-specs validate-testmaps ## Run all spec quality checks
	@echo "All spec quality checks passed."

spec-verify: verify-specs ## Verify AC-IDs and testmap traceability (alias)

spec-fix: ## Bulk-add AC-IDs to spec checkboxes
	python3 scripts/qa/spec-tools/spec_fix.py specs/ --add-ac-ids

validate-deploy-contract: ## Validate deploy package contract (checks 4+5 are WARN)
	@scripts/qa/validate-deploy-contract.sh
	@scripts/qa/verify-runtime-authority-map.sh

validate-deploy-contract-strict: ## Validate deploy package contract (all checks blocking)
	@scripts/qa/validate-deploy-contract.sh --strict
	@scripts/qa/verify-runtime-authority-map.sh

.PHONY: domains-generate domains-check domains-audit
domains-generate: ## Regenerate all domain artifacts from tenant-registry.yaml
	python3 scripts/domains/generate_domain_authority_matrix.py
	python3 scripts/domains/generate_config_domains.py
	python3 scripts/domains/generate_domain_env.py
	@echo "All domain artifacts regenerated"

domains-check: ## CI gate: verify all domain generated files are current
	python3 scripts/domains/generate_domain_authority_matrix.py --check
	python3 scripts/domains/generate_config_domains.py --check
	python3 scripts/domains/generate_domain_env.py --check
	@echo "All domain generated files are current"

domains-audit: ## Run full domain runtime audit (requires network)
	python3 scripts/domains/generate_domain_runtime_audit.py
	@echo "Domain runtime audit complete"
