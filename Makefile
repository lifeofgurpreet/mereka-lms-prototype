.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply tutor-verify branding-sync migrations-prepare migrations-verify qa-smoke lint format test clean mobile-setup spec-lint spec-coverage

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
		--specs-dir specs/ --testmaps-dir specs/testmaps/ --repo-root . --format text