# Infrastructure Configuration

This directory contains all infrastructure-as-code, configuration templates, and deployment artifacts.

## Structure

```
infrastructure/
├── tutor/              # Tutor configuration and patches
│   ├── apply-patches.sh
│   ├── config.example.yml
│   ├── tutor-env.sh
│   └── themes/         # Mereka branding themes
├── terraform/          # Terraform modules and configs
├── k8s/                # Kubernetes manifests
├── monitoring/         # Monitoring and alerting configs
├── cloudflare/         # Cloudflare DNS/zone configs
└── storage/            # Storage bucket configs
```

## Usage

### Tutor Local Development

For a new local sandbox, use the repository wrapper from the repo root:

```bash
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

For manual Tutor config changes, use the governed wrapper:

```bash
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$PWD/tutor_env"

./scripts/infra/tutor-config-save.sh --set KEY=value
./scripts/infra/prepare-tutor-build-context.sh --target all
```

The wrapper syncs the repo-owned Tutor plugin, renders Tutor output, and runs
the residual compatibility layer in the correct order. Do not call
`infrastructure/tutor/apply-patches.sh` directly for normal local development;
it is an implementation detail behind `tutor-config-save.sh` and
`prepare-tutor-build-context.sh`.

To rebuild local images explicitly:

```bash
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

Then start or restart Tutor:

```bash
tutor local start -d
```

### Terraform

See `infrastructure/terraform/README.md` for Terraform usage.

### Kubernetes

See `infrastructure/k8s/README.md` for Kubernetes deployment.

## Migration Notes

**⚠️ Compatibility**: The old `ops/` directory contains compatibility shims pointing to these new locations. Update your scripts to use `infrastructure/` paths directly.
