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

### Tutor Configuration

```bash
# Source the Tutor environment
source infrastructure/tutor/tutor-env.sh

# Apply patches after config changes
./infrastructure/tutor/apply-patches.sh

# Start Tutor
tutor local start -d
```

### Terraform

See `infrastructure/terraform/README.md` for Terraform usage.

### Kubernetes

See `infrastructure/k8s/README.md` for Kubernetes deployment.

## Migration Notes

**⚠️ Compatibility**: The old `ops/` directory contains compatibility shims pointing to these new locations. Update your scripts to use `infrastructure/` paths directly.

