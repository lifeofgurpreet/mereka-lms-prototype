# Credentials & Configuration Summary
**Date**: 2025-11-21
**All credentials backed up in GCP Secret Manager (project: mereka-lms)**

## GCP Secret Manager - All Secrets

| Secret Name | Version | Value | Usage |
|------------|---------|-------|-------|
| `mongodb-atlas-uri` | 5 (latest) | `mongodb+srv://cs_comments_user:CR3ATIVITY@cluster-mereka-lms.2pjex4s.mongodb.net/cs_comments_service?retryWrites=true&w=majority` | Forum database connection |
| `ses-smtp-username` | 1 | `AKIAXHZNJFIAT74VKX4U` | SES SMTP authentication |
| `ses-smtp-password` | 1 | `BP3cAl8RoylPkxYmSz3VC77ASdegdbhDP6s38NVCyaOe` | SES SMTP authentication |
| `aws-access-key-id` | 1 | `AKIAXHZNJFIA6RKX7XST` | AWS IAM (ses-cli-user) |
| `aws-secret-access-key` | 1 | `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` | AWS IAM (ses-cli-user) |

**Retrieve any secret:**
```bash
gcloud secrets versions access latest --secret="SECRET_NAME"
```

## MongoDB Atlas

**Cluster**: cluster-mereka-lms
**Version**: MongoDB 8.0.16
**Tier**: M10
**Region**: AWS ap-southeast-1
**Status**: IDLE (healthy)

**Connection Details**:
- **Hostname**: `cluster-mereka-lms.2pjex4s.mongodb.net`
- **Database**: `cs_comments_service` (for Open edX forum)
- **User**: `cs_comments_user`
- **Password**: `CR3ATIVITY`
- **Full URI**: See GCP secret `mongodb-atlas-uri`

**Network Access**:
- ✅ 45.83.126.9/32 - This PC
- ✅ 34.142.147.42/32 - GKE node
- ✅ 150.228.197.92/32 - GKE node
- ✅ 35.187.247.18/32 - GKE node
- ✅ 35.247.164.211/32 - GKE node

**Atlas CLI** (logged in):
```bash
"/c/Program Files (x86)/MongoDB Atlas CLI/atlas.exe" clusters list
```

## AWS SES

**Account Status**: PRODUCTION (not sandbox)
**Region**: ap-southeast-1
**Enforcement**: HEALTHY
**IAM User**: ses-cli-user (limited permissions)

**Sending Limits**:
- Daily quota: 200,000 emails
- Send rate: 100 emails/second
- Sent today: 4 emails

**SMTP Configuration**:
- **Host**: `email-smtp.ap-southeast-1.amazonaws.com`
- **Port**: `587` (TLS)
- **Username**: See GCP secret `ses-smtp-username`
- **Password**: See GCP secret `ses-smtp-password`
- **From Email**: `learn@mereka.my` (or any verified address)

**Verified Domains** (14 total):
- mereka.io ✅
- mereka.my ✅
- learn.mereka.my ✅
- biji-biji.com ✅
- rumahrakyat.org ✅
- penyupangkor.org ✅
- orphancare.org.my ✅
- aseanmil.org ✅
- advocasea.asia ✅
- proreca.org ✅
- stclawasia.com ✅
- seadbamboo.com ✅
- materialsinworks.com ✅
- identifake.my ⚠️ (temporary failure)

**Verified Email Addresses**:
- learn@mereka.my ✅ **← PRIMARY for Open edX**
- taylors@mereka.my ✅
- comms@biji-biji.com ✅
- notify@mereka.my ❌ (failed)

**AWS CLI** (configured):
```bash
aws ses get-account-sending-enabled
aws sesv2 get-account
aws sesv2 list-email-identities
```

## GCP Configuration

**Project ID**: mereka-lms
**Region**: asia-southeast1
**Authenticated As**: gurpreet@biji-biji.com

**Artifact Registry** (for Docker images):
- **Registry**: `asia-southeast1-docker.pkg.dev`
- **Repository**: `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`

**Usage**:
```bash
# Push images to GCP
docker tag IMAGE_NAME:TAG asia-southeast1-docker.pkg.dev/mereka-lms/openedx/IMAGE_NAME:TAG
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/IMAGE_NAME:TAG
```

## Tutor Configuration (tutor_env/config.yml)

**Generated Secrets** (in config.yml):
```yaml
CMS_OAUTH2_SECRET: mbogYijnMUyqm4PBe0rryAvM
ID: LgWN9sbtTjHHjIJifx3l0YkY
MYSQL_ROOT_PASSWORD: WvdPmUfF
OPENEDX_MYSQL_PASSWORD: aFifpplQ
OPENEDX_SECRET_KEY: UeCMQQglnc0O68rTJQezNNSt
```

**JWT RSA Private Key**: Stored in `tutor_env/config.yml` (2048-bit RSA)

**Local Development Hosts**:
```yaml
LMS_HOST: localhost
CMS_HOST: studio.localhost
MFE_HOST: apps.localhost
```

**Local Databases** (Docker containers):
```yaml
MONGODB_HOST: mongodb
MONGODB_PORT: 27017
MYSQL_HOST: mysql
MYSQL_PORT: 3306
REDIS_HOST: redis
REDIS_PORT: 6379
RUN_MONGODB: true
```

## Docker Images

### Built Images:
1. **OpenEdX Platform**: `overhangio/openedx:18.2.2-indigo` (5.04GB)
   - Includes: LMS, Studio, workers
2. **MFE** (building): `overhangio/openedx-mfe:18.1.0-indigo`
   - Includes: All micro-frontends (authn, account, learning, etc.)

### Check Images:
```bash
docker images --filter "reference=*openedx*"
```

## Security Notes

### Best Practices Followed:
- ✅ AWS IAM user (ses-cli-user) instead of root credentials
- ✅ All secrets in GCP Secret Manager (encrypted at rest)
- ✅ IP whitelist for MongoDB Atlas
- ✅ TLS required for all external connections
- ✅ .env files in .gitignore (never committed)
- ✅ Separate credentials for SMTP vs API access

### Action Items:
- ⚠️ Rotate AWS IAM keys every 90 days
- ⚠️ Update MongoDB IP whitelist when deploying to GKE
- ⚠️ Never commit tutor_env/config.yml (contains secrets)
- ⚠️ Use .env.example as template, never commit .env

## Quick Reference Commands

### Retrieve Secrets from GCP:
```bash
# MongoDB Atlas URI
gcloud secrets versions access latest --secret="mongodb-atlas-uri"

# SES SMTP credentials
gcloud secrets versions access latest --secret="ses-smtp-username"
gcloud secrets versions access latest --secret="ses-smtp-password"

# AWS IAM credentials
gcloud secrets versions access latest --secret="aws-access-key-id"
gcloud secrets versions access latest --secret="aws-secret-access-key"
```

### Test Connections:
```bash
# MongoDB Atlas
mongosh "$(gcloud secrets versions access latest --secret="mongodb-atlas-uri")" --eval "db.runCommand({ ping: 1 })"

# AWS SES
aws ses get-account-sending-enabled --region ap-southeast-1
```

### Tutor Commands:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"

# Launch local environment
tutor local launch -I --skip-build

# Apply patches after config changes
./infrastructure/tutor/apply-patches.sh
tutor local restart

# View logs
tutor local logs --tail=100 lms
```

## Emergency Recovery

If you need to rebuild from scratch:

1. **Restore Tutor Config**:
   ```bash
   # Config is in tutor_env/config.yml (gitignored)
   # Use tutor config save to regenerate, then apply patches
   export TUTOR_ROOT="$(pwd)/tutor_env"
   tutor config save
   ./infrastructure/tutor/apply-patches.sh
   ```

2. **Restore Credentials**:
   ```bash
   # All credentials are in GCP Secret Manager
   gcloud secrets list --project=mereka-lms
   ```

3. **Rebuild Images**:
   ```bash
   tutor images build openedx  # 30-45 min
   tutor images build mfe      # 15-20 min
   ```

---

**Last Updated**: 2025-11-21
**Status**: All credentials verified and backed up
**Next**: Complete MFE build, launch local environment
