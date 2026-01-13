.PHONY: help bootstrap tutor-start tutor-stop tutor-restart tutor-apply branding-sync migrations-prepare migrations-verify qa-smoke lint format test clean mobile-setup

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
