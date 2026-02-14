# Content Libraries v2: GCS Bucket Setup

## Overview

Content Libraries v2 uses Blockstore for content storage. In production,
Blockstore stores library data (XBlock definitions, assets) in a Google Cloud
Storage (GCS) bucket.

## Bucket Configuration

### Bucket Name

| Environment | Bucket Name | Region |
|-------------|-------------|--------|
| Production  | `lms-blockstore` | `asia-southeast1` |
| Local       | N/A (filesystem) | N/A |

### Terraform Module

The GCS bucket is managed via Terraform at:
```
infrastructure/terraform/modules/storage/main.tf
```

To add the Blockstore bucket, add this resource to the module:

```hcl
resource "google_storage_bucket" "blockstore" {
  name                        = "lms-blockstore"
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }
  labels = merge(var.labels, { purpose = "blockstore" })
}
```

### Service Account Permissions

The Blockstore service needs a GCP service account with:

| Permission | Resource | Purpose |
|------------|----------|---------|
| `storage.objects.create` | `gs://lms-blockstore/*` | Write library content |
| `storage.objects.get` | `gs://lms-blockstore/*` | Read library content |
| `storage.objects.list` | `gs://lms-blockstore/*` | List library bundles |
| `storage.objects.delete` | `gs://lms-blockstore/*` | Delete library content |

**IAM Role**: `roles/storage.objectAdmin` on the bucket.

### Setup Steps

1. **Create bucket** (via Terraform or gsutil):
   ```bash
   gsutil mb -p mereka-lms -l asia-southeast1 gs://lms-blockstore/
   gsutil versioning set on gs://lms-blockstore/
   ```

2. **Grant service account access**:
   ```bash
   gsutil iam ch \
     serviceAccount:blockstore@mereka-lms.iam.gserviceaccount.com:objectAdmin \
     gs://lms-blockstore/
   ```

3. **Configure environment variables**:
   ```bash
   BLOCKSTORE_BUCKET_NAME=lms-blockstore
   ```

4. **Verify access**:
   ```bash
   gsutil ls gs://lms-blockstore/
   echo "test" | gsutil cp - gs://lms-blockstore/test.txt
   gsutil rm gs://lms-blockstore/test.txt
   ```

### Secrets

| Secret | Location | Purpose |
|--------|----------|---------|
| `BLOCKSTORE_BUCKET_NAME` | Env var / ConfigMap | GCS bucket name |
| GCP service account key | K8s Secret (Workload Identity) | Bucket auth |

### Local Development

For local development with Tutor, Blockstore uses filesystem storage:
```
TUTOR_ROOT/env/data/blockstore/
```

No GCS configuration is needed for local development.

### Monitoring

Monitor bucket usage:
```bash
gsutil du -s gs://lms-blockstore/
```

Set up a budget alert for storage costs:
- Expected: < 10 GB for initial deployment
- Alert threshold: 50 GB
