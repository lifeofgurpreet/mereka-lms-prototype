# Production Infrastructure Plan - Mereka LMS Open edX
**Created**: 2025-11-21
**Target Launch**: Q1 2026
**Budget**: $1,500-2,500/month
**Region**: asia-southeast1 (Singapore)

---

## Executive Summary

This document outlines the production infrastructure architecture for Mereka Academy's Open edX deployment on Google Cloud Platform. The plan scales from the current dev/staging configuration ($186-327/month) to a production-grade, highly available setup designed for 500-2,000 concurrent learners.

### Key Objectives
1. **High Availability**: Multi-zone deployment with automatic failover
2. **Scalability**: Auto-scaling to handle peak loads (enrollment periods, course launches)
3. **Resilience**: 99.9% uptime SLA with disaster recovery
4. **Security**: Network isolation, encryption at rest and in transit, IAM controls
5. **Cost Control**: Predictable monthly costs within $1,500-2,500 budget

### Architecture Highlights
- **GKE Autopilot**: Multi-zone cluster with 6-12 nodes for HA
- **Cloud SQL MySQL**: REGIONAL HA with 4 vCPU, read replicas
- **Memorystore Redis**: STANDARD_HA tier with automatic failover
- **MongoDB Atlas**: M10-M30 cluster with backup retention
- **Global Load Balancer**: HTTPS with managed SSL certificates
- **Cloud CDN**: Static asset delivery with edge caching

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Production Architecture](#2-production-architecture)
3. [Service Sizing & Specifications](#3-service-sizing--specifications)
4. [Cost Projections](#4-cost-projections)
5. [Terraform Multi-Environment Setup](#5-terraform-multi-environment-setup)
6. [Cutover Process](#6-cutover-process)
7. [Disaster Recovery](#7-disaster-recovery)
8. [Monitoring & Alerting](#8-monitoring--alerting)
9. [Production Readiness Checklist](#9-production-readiness-checklist)
10. [Timeline & Milestones](#10-timeline--milestones)

---

## 1. Current State Analysis

### 1.1 Development/Staging Configuration

| Component | Current Spec | Monthly Cost | Limitations |
|-----------|--------------|--------------|-------------|
| GKE Autopilot | 6 nodes, minimal pod resources | $400-550 | Low CPU/memory utilization (6-7%), not HA |
| Cloud SQL MySQL | db-f1-micro, ZONAL | $4 | 0.6GB RAM, no HA, single zone |
| Memorystore Redis | BASIC tier, 1GB | $19 | No HA, single zone, no failover |
| MongoDB | Local in-cluster or M0 FREE | $0 | 512MB limit, no backups |
| Static IP | 1 regional IP | $3 | Single point of failure |
| Load Balancer | 1 L7 LB | $18 | No geographic distribution |
| **TOTAL** | | **$444-594** | **NOT PRODUCTION-READY** |

### 1.2 Cost Optimization History

The team has successfully optimized dev/staging costs by **67-73%** through:
- Scaling down non-essential services (Discovery, Ecommerce, Forum, Notes, Analytics)
- Downgrading Cloud SQL from db-custom-2-7680 to db-f1-micro
- Switching Redis from STANDARD_HA 2GB to BASIC 1GB
- Migrating MongoDB from M10 to M0 FREE tier
- Reducing GKE node count from 9 to 6 through pod resource optimization

**Key Insight**: Current infrastructure is optimized for development workloads. Production requires strategic scale-up focused on availability and performance, not maximum resource allocation.

### 1.3 Identified Gaps for Production

| Gap | Impact | Mitigation Strategy |
|-----|--------|---------------------|
| Single-zone Cloud SQL | Service outage during zone failures | Enable REGIONAL HA with automatic failover |
| No Redis failover | Cache loss during restarts | Upgrade to STANDARD_HA with replica |
| Minimal pod resources | High latency under load | Right-size based on load testing |
| No read replicas | Database bottleneck during peak | Add Cloud SQL read replica for queries |
| No CDN | Slow asset delivery globally | Enable Cloud CDN with multi-region buckets |
| No backup testing | Unknown RTO/RPO | Implement quarterly DR drills |
| Basic monitoring | Late issue detection | Deploy comprehensive SLO-based alerting |
| No rate limiting | Vulnerability to traffic spikes | Implement Cloud Armor with rate limits |

---

## 2. Production Architecture

### 2.1 Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          INTERNET (Learners)                           │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Cloud DNS (Zone)      │
                    │  academyv2.mereka.io   │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │ Global Load Balancer    │
                    │ • HTTPS (443)           │
                    │ • Managed SSL Cert      │
                    │ • Cloud Armor (WAF)     │
                    │ • Cloud CDN enabled     │
                    └────────────┬─────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
    ┌────▼─────┐          ┌─────▼────┐          ┌──────▼────┐
    │ Zone A   │          │ Zone B   │          │  Zone C   │
    │ Backend  │          │ Backend  │          │  Backend  │
    └────┬─────┘          └─────┬────┘          └──────┬────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
┌───────────────────────────────▼────────────────────────────────────────┐
│                    GKE Autopilot Cluster (Regional)                    │
│                      asia-southeast1 (a, b, c)                         │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │                        Ingress (Caddy)                           │ │
│  │            routes to LMS, CMS, MFE, Discovery, etc.             │ │
│  └──────────────────────┬───────────────────────────────────────────┘ │
│                         │                                              │
│  ┌──────────────────────┼───────────────────────────────────────────┐ │
│  │   Application Tier (Multi-zone Pods)                             │ │
│  │                      │                                            │ │
│  │  ┌──────────┐  ┌─────▼────┐  ┌──────────┐  ┌──────────┐        │ │
│  │  │   LMS    │  │   CMS    │  │   MFE    │  │ Workers  │        │ │
│  │  │ 3 replicas│  │ 2 replicas│  │ 2 replicas│  │4 replicas│        │ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │ │
│  │       │             │              │             │               │ │
│  └───────┼─────────────┼──────────────┼─────────────┼───────────────┘ │
│          │             │              │             │                  │
└──────────┼─────────────┼──────────────┼─────────────┼──────────────────┘
           │             │              │             │
           └─────────────┴──────────────┴─────────────┘
                         │
        ┌────────────────┼─────────────────────────┐
        │                │                         │
        │    ┌───────────▼──────────┐   ┌─────────▼──────────┐
        │    │ Memorystore Redis   │   │ Cloud SQL MySQL    │
        │    │ STANDARD_HA         │   │ REGIONAL HA        │
        │    │ • Primary (Zone A)  │   │ • Master (Zone A)  │
        │    │ • Replica (Zone B)  │   │ • Standby (Zone B) │
        │    │ • Auto-failover     │   │ • Read Replica     │
        │    │ • 5GB memory        │   │ • 4 vCPU, 15GB RAM │
        │    └─────────────────────┘   └────────────────────┘
        │
        │    ┌────────────────────────────────────┐
        │    │   Cloud Storage (Multi-region)    │
        │    │ • Course content bucket           │
        │    │ • Backup bucket                   │
        │    │ • Static assets (CDN-enabled)     │
        │    └────────────────────────────────────┘
        │
        │    ┌────────────────────────────────────┐
        │    │      External Services             │
        │    │ • MongoDB Atlas M10 (AWS)         │
        │    │   - Multi-zone replica set        │
        │    │   - Continuous backup             │
        │    │ • SMTP (AWS SES)                  │
        │    │ • Video storage (S3 or YouTube)   │
        │    └────────────────────────────────────┘
        │
        └────────────────────────────────────────────┘
```

### 2.2 Multi-Zone Distribution Strategy

**GKE Autopilot Cluster:**
- **Cluster Mode**: Regional (asia-southeast1)
- **Zones**: asia-southeast1-a, asia-southeast1-b, asia-southeast1-c
- **Pod Distribution**:
  - Critical services (LMS, CMS): ≥3 replicas spread across zones
  - Support services (MFE, Workers): ≥2 replicas spread across zones
  - Background jobs (Celery): Can tolerate single-zone (non-critical path)

**Pod Anti-Affinity Rules:**
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - lms
        topologyKey: topology.kubernetes.io/zone
```

**Cloud SQL:**
- **Availability Type**: REGIONAL
- **Master Zone**: asia-southeast1-a
- **Standby Zone**: asia-southeast1-b (automatic failover)
- **Backup Location**: Multi-region (asia)
- **Read Replica**: asia-southeast1-c (for reporting queries)

**Memorystore Redis:**
- **Tier**: STANDARD_HA
- **Primary Zone**: asia-southeast1-a
- **Replica Zone**: asia-southeast1-b
- **Failover**: Automatic (<60 seconds)

### 2.3 High Availability Design Principles

1. **No Single Points of Failure**
   - All critical components have redundancy
   - Load balancer automatically routes around failed backends
   - Database failover is automatic and transparent

2. **Graceful Degradation**
   - Redis failure → Application uses database (slower but functional)
   - MongoDB failure → Forum read-only mode
   - CDN failure → Origin server serves assets directly

3. **Circuit Breakers**
   - Implement retry logic with exponential backoff
   - Connection pooling with health checks
   - Request timeouts (30s max)

4. **Data Durability**
   - RPO (Recovery Point Objective): <15 minutes
   - RTO (Recovery Time Objective): <30 minutes
   - Cross-region backup replication

---

## 3. Service Sizing & Specifications

### 3.1 GKE Autopilot Configuration

**Cluster Specifications:**
```hcl
# infrastructure/terraform/environments/prod/main.tf
module "gke" {
  source = "../../modules/gke"

  cluster_name      = "mereka-lms-prod"
  region            = "asia-southeast1"
  release_channel   = "REGULAR"
  deletion_protection = true

  # Autopilot automatically manages nodes based on pod requests
  # No need to specify node count or machine types
}
```

**Pod Resource Requests (Right-Sized for Production):**

| Service | Replicas | CPU Request | Memory Request | Notes |
|---------|----------|-------------|----------------|-------|
| **LMS** | 3 | 1000m | 2Gi | Main learner-facing service |
| **CMS** | 2 | 1000m | 2Gi | Course authoring (lower traffic) |
| **MFE** | 2 | 500m | 1Gi | Micro-frontends (static serving) |
| **LMS Worker** | 4 | 500m | 1.5Gi | Background jobs, parallel processing |
| **CMS Worker** | 2 | 500m | 1.5Gi | Content processing |
| **Nginx** | 2 | 250m | 512Mi | Reverse proxy |
| **Caddy** | 2 | 250m | 512Mi | Ingress controller |
| **Discovery** | 2 | 500m | 1Gi | Course catalog |
| **Forum** | 2 | 500m | 1Gi | Discussion forums |
| **Notes** | 1 | 250m | 512Mi | Annotation service (light usage) |
| **ClickHouse** | 1 | 1000m | 4Gi | Analytics data warehouse |
| **Superset** | 1 | 500m | 2Gi | Analytics dashboard |
| **Elasticsearch** | 1 | 1000m | 2Gi | Search indexing |

**Total Resource Requests:**
- **CPU**: ~10.75 vCPU
- **Memory**: ~26.5 GB
- **Expected Node Count**: 8-12 nodes (Autopilot e2-standard-4 or e2-standard-8)

**Auto-Scaling Configuration:**
```yaml
# Applied via Tutor k8s-override
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lms
  namespace: mereka-lms
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lms
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 25
        periodSeconds: 60
```

**Why These Numbers:**
- Based on Open edX community benchmarks for 500-2000 concurrent users
- 2Gi memory for Django apps prevents OOM under load (observed 1.2-1.5Gi actual usage at peak)
- 1000m CPU allows headroom for traffic spikes (typical usage 200-400m)
- Autopilot will provision appropriately sized nodes automatically
- HPA ensures auto-scaling during enrollment periods

### 3.2 Cloud SQL MySQL

**Instance Specification:**
```hcl
# infrastructure/terraform/environments/prod/terraform.tfvars
cloudsql_tier           = "db-custom-4-15360"  # 4 vCPU, 15 GB RAM
cloudsql_disk_size_gb   = 200
cloudsql_high_availability = true  # REGIONAL mode

# Module configuration
module "cloudsql" {
  source = "../../modules/cloudsql"

  tier              = var.cloudsql_tier
  high_availability = true
  disk_size_gb      = 200

  # Backup configuration
  backup_start_time = "03:00"  # 3 AM SGT (low traffic)

  # Maintenance window
  maintenance_day  = 7   # Sunday
  maintenance_hour = 22  # 10 PM SGT

  # Performance flags
  flags = [
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "10737418240"  # 10GB (67% of RAM)
    },
    {
      name  = "slow_query_log"
      value = "on"
    }
  ]
}
```

**Read Replica (for Analytics & Reporting):**
```hcl
resource "google_sql_database_instance" "read_replica" {
  name             = "mereka-lms-mysql-read"
  master_instance_name = google_sql_database_instance.mysql.name
  region           = "asia-southeast1"
  database_version = "MYSQL_8_0"

  replica_configuration {
    failover_target = false
  }

  settings {
    tier = "db-custom-2-7680"  # Smaller than master (read-only workload)
    disk_autoresize = true
  }
}
```

**Cost Breakdown:**
- **Master Instance (REGIONAL HA)**: $450/month
  - Compute (4 vCPU): $270/month
  - Storage (200GB PD-SSD): $34/month
  - HA standby: $140/month
  - Backups (200GB × 7 days): ~$6/month
- **Read Replica**: $135/month
  - Compute (2 vCPU): $110/month
  - Storage (200GB): $25/month
- **Total Cloud SQL**: ~$585/month

**Scaling Headroom:**
- Current allocation supports 300-500 concurrent database connections
- Can handle 2,000-3,000 queries per second
- Disk auto-resize enabled (max 65,536 GB)
- Can upgrade to db-custom-8-30720 if needed (8 vCPU, 30GB RAM)

**Why db-custom-4-15360:**
- Open edX is database-intensive (course content, user activity, grades)
- Dev/staging showed stable performance at db-f1-micro with <50 users
- Production estimate: 10x scale = need 40x resources (due to locking, joins)
- 4 vCPU strikes balance between performance and cost
- Alternative: Start with db-custom-2-7680 ($225/month), monitor, upgrade if CPU >70%

### 3.3 Memorystore Redis

**Instance Specification:**
```hcl
# infrastructure/terraform/environments/prod/terraform.tfvars
redis_tier         = "STANDARD_HA"
redis_memory_size  = 5  # GB

module "memorystore" {
  source = "../../modules/memorystore"

  tier           = "STANDARD_HA"
  memory_size_gb = 5
  redis_version  = "REDIS_7_X"

  # Automatic failover enabled with STANDARD_HA
  # Replica in different zone
}
```

**Usage Pattern:**
- **Session Storage**: ~100 bytes per session × 1,000 concurrent = 100 KB
- **Cache (Course Content)**: ~200 MB per course × 50 courses = 10 GB (with eviction)
- **Celery Queue**: ~1 MB per 1,000 tasks
- **Total Estimate**: 2-3 GB typical, 5 GB allows headroom

**Cost**: $175/month
- STANDARD_HA tier: $0.048/GB-hour
- 5 GB × 730 hours × $0.048 = $175/month

**Eviction Policy**: `allkeys-lru` (configured via Tutor)
```yaml
REDIS_MAXMEMORY_POLICY: allkeys-lru
```

**Why STANDARD_HA:**
- Automatic failover in <60 seconds
- Zero data loss during failover (replication)
- BASIC tier would cause 2-5 minute cache rebuild on restarts

### 3.4 MongoDB Atlas Configuration

**Cluster Tier: M10 (Recommended Starting Point)**

```yaml
# MongoDB Atlas Configuration (managed via Atlas UI or Terraform)
Cluster Name: mereka-lms-prod
Tier: M10
Region: AWS ap-southeast-1 (Singapore)
Cluster Type: Replica Set (3 nodes)
Backup: Continuous (point-in-time recovery)
Storage: 10GB (auto-scale to 32GB)
```

**Specifications:**
- **CPU**: 2 vCPU (shared)
- **RAM**: 2 GB
- **Storage**: 10GB → 32GB (auto-scale)
- **IOPS**: Burst to 3000
- **Connections**: Up to 1,500
- **Cost**: $87/month (AWS pricing in Singapore)

**Upgrade Path (if forum usage grows):**
- **M20**: 4GB RAM, 4 vCPU - $177/month
- **M30**: 8GB RAM, 4 vCPU - $277/month

**Backup Configuration:**
- **Continuous Backup**: Enabled
- **Retention**: 7 days (increase to 14 days for production)
- **Point-in-Time Recovery**: Yes
- **Backup Window**: 03:00-05:00 SGT (low traffic)

**Why MongoDB Atlas Instead of Self-Hosted:**
- Managed service = no MongoDB expertise required
- Automatic failover and replica management
- Built-in backup and point-in-time recovery
- Performance insights and monitoring
- VPC peering with GCP (low latency)

**VPC Peering Setup:**
```bash
# MongoDB Atlas → Network Access → Peering
# Peer MongoDB Atlas VPC with GCP VPC in asia-southeast1
# This ensures low-latency private connectivity
```

**Alternative: Self-Hosted MongoDB on GKE**
- **Pros**: Lower cost (~$50-80/month for StatefulSet + PD), full control
- **Cons**: Requires MongoDB expertise, manual backup management, higher operational burden
- **Recommendation**: Use Atlas for production, self-hosted acceptable for dev/staging

### 3.5 Load Balancing & TLS

**Global HTTPS Load Balancer:**
```hcl
# Automatically created by GKE Ingress
# infrastructure/k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mereka-lms-ingress
  namespace: mereka-lms
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "mereka-lms-prod-ip"
    networking.gke.io/managed-certificates: "mereka-lms-cert"
    kubernetes.io/ingress.allow-http: "false"  # HTTPS only
    ingress.gcp.kubernetes.io/pre-shared-cert: "mereka-lms-cert"
    cloud.google.com/armor-config: '{"mereka-lms-armor-policy": "mereka-lms-security-policy"}'
spec:
  rules:
  - host: academyv2.mereka.io
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: caddy
            port:
              number: 80
  - host: studio.academyv2.mereka.io
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: caddy
            port:
              number: 80
```

**Managed SSL Certificate:**
```yaml
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: mereka-lms-cert
  namespace: mereka-lms
spec:
  domains:
    - academyv2.mereka.io
    - studio.academyv2.mereka.io
    - apps.academyv2.mereka.io
    - discovery.academyv2.mereka.io
```

**Cost**: $18-25/month
- Forwarding rule: $18/month (first 5 rules)
- SSL certificate: Free (Google-managed)
- Cloud Armor: $0 base + $0.75 per 1M requests (adds $5-15/month at scale)

**Cloud Armor Security Policy:**
```hcl
resource "google_compute_security_policy" "mereka_lms" {
  name = "mereka-lms-security-policy"

  rule {
    action   = "rate_based_ban"
    priority = "100"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
    description = "Rate limit: 100 requests per minute per IP"
  }

  rule {
    action   = "deny(403)"
    priority = "200"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }
}
```

### 3.6 Cloud CDN & Storage

**Cloud Storage Buckets:**
```hcl
# Production course content
resource "google_storage_bucket" "content" {
  name          = "academy-mereka-io-content"
  location      = "ASIA"  # Multi-region for CDN
  storage_class = "STANDARD"

  cors {
    origin          = ["https://academyv2.mereka.io"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

# Backup bucket (lifecycle management)
resource "google_storage_bucket" "backup" {
  name          = "academy-mereka-io-backup"
  location      = "ASIA"
  storage_class = "NEARLINE"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}
```

**Cloud CDN Configuration:**
```hcl
# Enable via backend service annotation
resource "google_compute_backend_bucket" "static_assets" {
  name        = "mereka-lms-static-assets"
  bucket_name = google_storage_bucket.content.name
  enable_cdn  = true

  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = 3600
    max_ttl     = 86400
    client_ttl  = 3600
  }
}
```

**Storage Cost Estimate:**
- **Content Bucket (Multi-region)**: $0.026/GB-month
  - Estimate: 50GB course content = $1.30/month
  - CDN egress (cached): $0.04-0.08/GB (first 10TB/month)
- **Backup Bucket (NEARLINE)**: $0.010/GB-month
  - Estimate: 200GB backups = $2.00/month
- **Total Storage**: ~$5-10/month (excluding CDN egress)

---

## 4. Cost Projections

### 4.1 Base Production Cost Estimate

| Service | Specification | Monthly Cost (USD) | Annual Cost (USD) |
|---------|--------------|-------------------|-------------------|
| **GKE Autopilot** | 8-12 nodes, ~11 vCPU, 26GB RAM | $900-1,200 | $10,800-14,400 |
| **Cloud SQL MySQL (Master)** | db-custom-4-15360, REGIONAL HA, 200GB | $450 | $5,400 |
| **Cloud SQL Read Replica** | db-custom-2-7680, 200GB | $135 | $1,620 |
| **Memorystore Redis** | STANDARD_HA, 5GB | $175 | $2,100 |
| **MongoDB Atlas** | M10, 3-node replica set | $87 | $1,044 |
| **Load Balancer** | Global HTTPS LB + Cloud Armor | $25 | $300 |
| **Cloud Storage** | Content (50GB) + Backups (200GB) | $10 | $120 |
| **Artifact Registry** | Docker images (~20GB) | $5 | $60 |
| **Cloud DNS** | 1 zone, 10M queries/month | $1 | $12 |
| **Static IP** | 1 global IP | $3 | $36 |
| **Network Egress** | 500GB/month (CDN + API) | $40 | $480 |
| **Secret Manager** | 50 secrets, 10K access/month | $1 | $12 |
| **Cloud Logging** | 50GB/month ingestion + storage | $30 | $360 |
| **Cloud Monitoring** | Metrics + uptime checks | $10 | $120 |
| **Cloud CDN** | 200GB/month cached egress | $15 | $180 |
| **Backup Storage** | Cloud SQL backups (7 days) | $8 | $96 |
| **SMTP (AWS SES)** | 50,000 emails/month | $5 | $60 |
| **Buffer (10%)** | Unexpected costs, spikes | $100 | $1,200 |
| | | |
| **TOTAL (Conservative)** | | **$2,000** | **$24,000** |
| **TOTAL (Optimistic)** | | **$1,650** | **$19,800** |

### 4.2 Cost Optimization Levers

**Scenario 1: Budget-Conscious ($1,500-1,700/month)**
- Cloud SQL Master: db-custom-2-7680 instead of db-custom-4-15360 → Save $225/month
- Skip Read Replica initially → Save $135/month
- MongoDB Atlas M10 → M20 only if needed → Maintain $87/month
- Redis: 3GB instead of 5GB → Save $35/month
- **Total**: ~$1,580/month
- **Trade-off**: Less headroom for traffic spikes, might hit CPU limits at peak

**Scenario 2: Balanced Production ($1,900-2,100/month)**
- Recommended configuration as described above
- All HA features enabled
- Comfortable headroom for growth
- **Total**: ~$2,000/month

**Scenario 3: High-Performance ($2,400-2,600/month)**
- Cloud SQL: db-custom-8-30720 → Add $450/month
- MongoDB: M30 instead of M10 → Add $190/month
- Redis: 10GB instead of 5GB → Add $175/month
- **Total**: ~$2,515/month
- **Use case**: 3,000+ concurrent users, 50+ courses

**Recommended**: Start with **Scenario 2 (Balanced)**, monitor for 30 days, adjust based on actual utilization.

### 4.3 Cost Control Mechanisms

**Budget Alerts (Terraform):**
```hcl
# infrastructure/terraform/environments/prod/budgets.tf
resource "google_billing_budget" "prod_monthly" {
  billing_account = var.billing_account_id
  display_name    = "mereka-lms-prod-monthly"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "2200"  # $2,200 hard cap
    }
  }

  budget_filter {
    projects = ["projects/${var.project_id}"]
    labels = {
      environment = "production"
    }
  }

  threshold_rules {
    threshold_percent = 0.50  # Alert at 50% ($1,100)
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.75  # Alert at 75% ($1,650)
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.90  # Alert at 90% ($1,980)
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.00  # Alert at 100% ($2,200)
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email.name,
      google_monitoring_notification_channel.slack.name
    ]
  }
}
```

**Cost Anomaly Detection:**
```hcl
resource "google_monitoring_alert_policy" "cost_spike" {
  display_name = "Cost Spike Detection"
  combiner     = "OR"

  conditions {
    display_name = "Daily cost increase >50%"
    condition_threshold {
      filter          = "resource.type = \"global\" AND metric.type = \"billing.googleapis.com/costs/daily\""
      duration        = "3600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 100  # >$100/day increase
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}
```

**Automated Reporting:**
```bash
# scripts/infra/weekly-cost-report.sh
#!/usr/bin/env bash
# Weekly cost report via BigQuery billing export
# Scheduled via Cloud Scheduler → Cloud Run

bq query --use_legacy_sql=false --format=prettyjson '
SELECT
  service.description AS service,
  SUM(cost) AS total_cost,
  SUM(cost) - LAG(SUM(cost)) OVER (PARTITION BY service.description ORDER BY DATE(usage_start_time)) AS week_over_week_change
FROM `mereka-lms.billing_export.gcp_billing_export_v1_*`
WHERE DATE(usage_start_time) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) AND CURRENT_DATE()
GROUP BY service
ORDER BY total_cost DESC
LIMIT 10
'
```

### 4.4 Dev/Staging vs Production Cost Comparison

| Environment | Monthly Cost | Use Case | SLA Target |
|-------------|--------------|----------|------------|
| **Local Dev** | $0 | Individual developer testing | N/A |
| **Staging (Current)** | $186-327 | Integration testing, QA | 95% (best effort) |
| **Production (Proposed)** | $1,650-2,200 | Live learners, 500-2000 concurrent | 99.9% |

**Savings Opportunity**: Keep staging at current optimized cost ($186-327/month) by:
- Using BASIC Redis (no HA)
- Using ZONAL Cloud SQL (no HA)
- Using MongoDB M0 FREE or M2 ($9/month)
- Scaling down services when not actively testing

**Total Infrastructure Budget**:
- Staging: $300/month
- Production: $2,000/month
- **Combined**: $2,300/month

---

## 5. Terraform Multi-Environment Setup

### 5.1 Directory Structure

```
infrastructure/terraform/
├── modules/                      # Reusable modules (existing)
│   ├── artifact_registry/
│   ├── cloudsql/
│   ├── gke/
│   ├── memorystore/
│   ├── network/
│   ├── secret_manager/
│   └── storage/
│
├── environments/                 # NEW: Environment-specific configs
│   ├── dev/
│   │   ├── main.tf              # Calls modules with dev settings
│   │   ├── terraform.tfvars     # Dev-specific variable values
│   │   ├── backend.tf           # Remote state (GCS bucket: dev)
│   │   └── outputs.tf
│   │
│   ├── staging/
│   │   ├── main.tf              # Calls modules with staging settings
│   │   ├── terraform.tfvars     # Staging-specific variable values
│   │   ├── backend.tf           # Remote state (GCS bucket: staging)
│   │   └── outputs.tf
│   │
│   └── prod/
│       ├── main.tf              # Calls modules with prod settings
│       ├── terraform.tfvars     # Production-specific variable values
│       ├── backend.tf           # Remote state (GCS bucket: prod)
│       └── outputs.tf
│
├── budgets.tf                    # MOVED to environments/*/budgets.tf
├── main.tf                       # DEPRECATED (use environments/*/main.tf)
├── providers.tf                  # Shared provider configuration
├── variables.tf                  # Shared variable definitions
└── README.md                     # Updated with multi-env instructions
```

### 5.2 Environment-Specific Configurations

#### Development Environment
**File**: `infrastructure/terraform/environments/dev/terraform.tfvars`
```hcl
project_id                 = "mereka-lms-dev"
domain_root                = "academyv2.mereka.dev"
billing_account_id         = "01A879-A82798-7962E2"
monthly_budget_myr         = 500  # ~$115 USD

# Cloud SQL - Minimal for dev
cloudsql_tier              = "db-f1-micro"
cloudsql_disk_size_gb      = 20
cloudsql_high_availability = false  # ZONAL

# Redis - Minimal for dev
redis_tier                 = "BASIC"
redis_memory_size_gb       = 1

# Labels
labels = {
  environment = "dev"
  managed-by  = "terraform"
  project     = "mereka-lms"
}

# Secrets (loaded from Secret Manager or CI/CD)
cloudsql_root_password = ""  # Provided via TF_VAR_cloudsql_root_password
```

**File**: `infrastructure/terraform/environments/dev/backend.tf`
```hcl
terraform {
  backend "gcs" {
    bucket  = "mereka-lms-terraform-state-dev"
    prefix  = "terraform/state"
  }
}
```

#### Staging Environment
**File**: `infrastructure/terraform/environments/staging/terraform.tfvars`
```hcl
project_id                 = "mereka-lms"  # Current staging project
domain_root                = "academyv2.mereka.io"
billing_account_id         = "01A879-A82798-7962E2"
monthly_budget_myr         = 1500  # ~$345 USD

# Cloud SQL - Cost-optimized HA for staging
cloudsql_tier              = "db-custom-2-7680"
cloudsql_disk_size_gb      = 100
cloudsql_high_availability = true  # REGIONAL (for cutover rehearsal)

# Redis - Standard HA for staging
redis_tier                 = "STANDARD_HA"
redis_memory_size_gb       = 2

labels = {
  environment = "staging"
  managed-by  = "terraform"
  project     = "mereka-lms"
}
```

**File**: `infrastructure/terraform/environments/staging/backend.tf`
```hcl
terraform {
  backend "gcs" {
    bucket  = "mereka-lms-terraform-state-staging"
    prefix  = "terraform/state"
  }
}
```

#### Production Environment
**File**: `infrastructure/terraform/environments/prod/terraform.tfvars`
```hcl
project_id                 = "mereka-lms-prod"
domain_root                = "academyv2.mereka.io"
billing_account_id         = "01A879-A82798-7962E2"
monthly_budget_myr         = 9200  # ~$2,200 USD with 10% buffer

# Cloud SQL - Full production spec
cloudsql_tier              = "db-custom-4-15360"
cloudsql_disk_size_gb      = 200
cloudsql_high_availability = true  # REGIONAL HA

# Redis - Production HA
redis_tier                 = "STANDARD_HA"
redis_memory_size_gb       = 5

labels = {
  environment = "production"
  managed-by  = "terraform"
  project     = "mereka-lms"
  cost-center = "education"
}

# Enable deletion protection for production
deletion_protection = true
```

**File**: `infrastructure/terraform/environments/prod/backend.tf`
```hcl
terraform {
  backend "gcs" {
    bucket  = "mereka-lms-terraform-state-prod"
    prefix  = "terraform/state"
  }
}
```

**File**: `infrastructure/terraform/environments/prod/main.tf`
```hcl
# Production-specific infrastructure

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Local variables
locals {
  dns_zone_name = replace(var.domain_root, ".", "-")
  common_labels = merge(var.labels, {
    terraform-workspace = terraform.workspace
  })
}

# Network (shared VPC)
module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  region     = var.region
  labels     = local.common_labels
}

# GKE Autopilot Cluster
module "gke" {
  source = "../../modules/gke"
  providers = {
    google-beta = google-beta
  }

  project_id            = var.project_id
  region                = var.region
  cluster_name          = "mereka-lms-prod"
  network_self_link     = module.network.vpc_self_link
  subnetwork_self_link  = module.network.subnetwork_self_link
  pod_ip_range_name     = module.network.pod_secondary_range_name
  service_ip_range_name = module.network.service_secondary_range_name
  labels                = local.common_labels
  deletion_protection   = true
  release_channel       = "REGULAR"
}

# Cloud SQL MySQL (Master)
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id        = var.project_id
  region            = var.region
  network           = module.network.vpc_self_link
  instance_name     = "mereka-lms-mysql-prod"
  tier              = var.cloudsql_tier
  disk_size_gb      = var.cloudsql_disk_size_gb
  high_availability = var.cloudsql_high_availability
  root_username     = var.cloudsql_root_username
  root_password     = var.cloudsql_root_password
  labels            = local.common_labels
  deletion_protection = true

  # Production-specific MySQL flags
  flags = [
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "10737418240"  # 10GB
    }
  ]
}

# Cloud SQL Read Replica (for reporting)
module "cloudsql_read_replica" {
  source = "../../modules/cloudsql"

  project_id              = var.project_id
  region                  = var.region
  network                 = module.network.vpc_self_link
  instance_name           = "mereka-lms-mysql-read-prod"
  tier                    = "db-custom-2-7680"  # Smaller than master
  disk_size_gb            = var.cloudsql_disk_size_gb
  high_availability       = false  # Read replica doesn't need HA
  is_read_replica         = true
  master_instance_name    = module.cloudsql.instance_name
  labels                  = local.common_labels
}

# Memorystore Redis
module "memorystore" {
  source = "../../modules/memorystore"

  project_id     = var.project_id
  region         = var.region
  network        = module.network.vpc_self_link
  instance_name  = "mereka-lms-redis-prod"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  redis_version  = "REDIS_7_X"
  labels         = local.common_labels
}

# Cloud Storage Buckets
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  location    = "ASIA"  # Multi-region for CDN
  domain_root = var.domain_root
  labels      = local.common_labels

  # Enable CDN for content bucket
  enable_cdn  = true
}

# Artifact Registry
module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id = var.project_id
  location   = var.region
  repo_name  = "openedx"
  labels     = local.common_labels
}

# Secret Manager
module "secret_manager" {
  source = "../../modules/secret_manager"

  project_id = var.project_id
  secrets    = var.secrets
}

# Budgets and Alerts
module "budgets" {
  source = "../../modules/budgets"

  project_id                   = var.project_id
  billing_account_id           = var.billing_account_id
  monthly_budget_myr           = var.monthly_budget_myr
  budget_thresholds            = [0.50, 0.75, 0.90, 1.00]
  budget_monitoring_channels   = var.budget_monitoring_channels
}
```

### 5.3 Remote State Backend Setup

**One-Time Setup (Per Environment):**
```bash
# Create state buckets for each environment
# Run this ONCE before terraform init

# Dev state bucket
gcloud storage buckets create gs://mereka-lms-terraform-state-dev \
  --project=mereka-lms-dev \
  --location=asia-southeast1 \
  --uniform-bucket-level-access

# Staging state bucket
gcloud storage buckets create gs://mereka-lms-terraform-state-staging \
  --project=mereka-lms \
  --location=asia-southeast1 \
  --uniform-bucket-level-access

# Production state bucket
gcloud storage buckets create gs://mereka-lms-terraform-state-prod \
  --project=mereka-lms-prod \
  --location=asia-southeast1 \
  --uniform-bucket-level-access

# Enable versioning on all state buckets (for rollback)
gcloud storage buckets update gs://mereka-lms-terraform-state-dev --versioning
gcloud storage buckets update gs://mereka-lms-terraform-state-staging --versioning
gcloud storage buckets update gs://mereka-lms-terraform-state-prod --versioning
```

### 5.4 Service Account Configuration

**Terraform Service Accounts (Per Environment):**
```bash
# Create service accounts for Terraform in each environment

# Production Terraform SA
gcloud iam service-accounts create terraform-prod \
  --project=mereka-lms-prod \
  --description="Terraform service account for production infrastructure" \
  --display-name="Terraform Production"

# Grant necessary roles
gcloud projects add-iam-policy-binding mereka-lms-prod \
  --member="serviceAccount:terraform-prod@mereka-lms-prod.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding mereka-lms-prod \
  --member="serviceAccount:terraform-prod@mereka-lms-prod.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding mereka-lms-prod \
  --member="serviceAccount:terraform-prod@mereka-lms-prod.iam.gserviceaccount.com" \
  --role="roles/cloudsql.admin"

# Create and download key (store in GitHub Secrets)
gcloud iam service-accounts keys create terraform-prod-key.json \
  --iam-account=terraform-prod@mereka-lms-prod.iam.gserviceaccount.com

# Repeat for staging and dev environments
```

**Workload Identity for GKE Pods:**
```hcl
# infrastructure/terraform/modules/gke/workload-identity.tf
resource "google_service_account" "gke_workload" {
  account_id   = "gke-workload-${var.cluster_name}"
  display_name = "GKE Workload Identity for ${var.cluster_name}"
  project      = var.project_id
}

# Grant Cloud SQL Client role
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Grant Secret Manager accessor role
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Grant Storage Object Viewer role (for course content)
resource "google_project_iam_member" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_workload.email}"
}

# Bind Kubernetes SA to GCP SA
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.gke_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[mereka-lms/default]"
}
```

### 5.5 Usage Instructions

**Deploying to Staging:**
```bash
cd infrastructure/terraform/environments/staging

# Initialize backend
terraform init

# Plan changes
terraform plan -var-file=terraform.tfvars -out=staging.tfplan

# Apply changes
terraform apply staging.tfplan
```

**Deploying to Production:**
```bash
cd infrastructure/terraform/environments/prod

# Initialize backend
terraform init

# Plan changes (review carefully!)
terraform plan -var-file=terraform.tfvars -out=prod.tfplan

# Apply changes (require manual approval)
terraform apply prod.tfplan
```

**CI/CD Integration (GitHub Actions):**
```yaml
# .github/workflows/terraform-prod.yml
name: Terraform Production Deploy

on:
  push:
    branches:
      - main
    paths:
      - 'infrastructure/terraform/environments/prod/**'
      - 'infrastructure/terraform/modules/**'
  workflow_dispatch:

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_TERRAFORM_PROD_SA_KEY }}

      - name: Terraform Init
        working-directory: infrastructure/terraform/environments/prod
        run: terraform init

      - name: Terraform Plan
        working-directory: infrastructure/terraform/environments/prod
        run: terraform plan -var-file=terraform.tfvars -out=prod.tfplan
        env:
          TF_VAR_cloudsql_root_password: ${{ secrets.CLOUDSQL_ROOT_PASSWORD }}

      - name: Terraform Apply
        working-directory: infrastructure/terraform/environments/prod
        run: terraform apply -auto-approve prod.tfplan
```

---

## 6. Cutover Process

### 6.1 Pre-Cutover Preparation (T-30 Days)

**Week 1-2: Infrastructure Provisioning**
```bash
# Day 1: Create production GCP project
gcloud projects create mereka-lms-prod --name="Mereka LMS Production"
gcloud billing projects link mereka-lms-prod --billing-account=01A879-A82798-7962E2

# Day 2-3: Enable APIs
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  storage.googleapis.com \
  dns.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project=mereka-lms-prod

# Day 4-7: Deploy infrastructure via Terraform
cd infrastructure/terraform/environments/prod
terraform init
terraform plan -var-file=terraform.tfvars -out=prod.tfplan
terraform apply prod.tfplan

# Day 8-10: Configure MongoDB Atlas
# 1. Create M10 cluster in AWS ap-southeast-1
# 2. Set up VPC peering with GCP
# 3. Configure continuous backup (14-day retention)
# 4. Create database user with least privilege
```

**Week 3: Application Deployment**
```bash
# Day 15: Build and push images
export TUTOR_ROOT="$(pwd)/tutor_env_prod"
tutor config save --set DOMAIN=academyv2.mereka.io
tutor images build all --no-cache
tutor images push all

# Day 16-18: Deploy to GKE
tutor k8s quickstart

# Apply production-specific patches
./infrastructure/tutor/apply-patches.sh

# Configure HPA (Horizontal Pod Autoscaler)
kubectl apply -f infrastructure/k8s/prod/hpa.yaml

# Day 19-21: DNS and SSL setup
# 1. Update Cloudflare DNS to point to prod LB IP
# 2. Wait for Google-managed SSL cert provisioning (can take 15-60 min)
# 3. Verify HTTPS access
curl -I https://academyv2.mereka.io
```

**Week 4: Load Testing & Validation**
```bash
# Day 22-24: Load testing
# Use k6 or Locust to simulate 500-2000 concurrent users

# Install k6
brew install k6  # macOS
# or download from https://k6.io/docs/getting-started/installation/

# Run load test
k6 run --vus 500 --duration 30m scripts/qa/load-test-prod.js

# Monitor during load test
kubectl top nodes
kubectl top pods -n mereka-lms
gcloud sql operations list --instance=mereka-lms-mysql-prod --limit=10

# Day 25-27: Fix any identified issues
# - Adjust pod resources if CPU/memory bottlenecks
# - Tune MySQL connection pool if seeing connection errors
# - Scale Redis if cache miss ratio is high

# Day 28-30: Chaos testing (optional but recommended)
# Use Chaos Mesh or manually simulate failures:
# - Kill LMS pods: kubectl delete pod -l app=lms -n mereka-lms
# - Trigger Cloud SQL failover: gcloud sql instances failover mereka-lms-mysql-prod
# - Restart Redis: kubectl rollout restart statefulset redis -n mereka-lms
```

### 6.2 Data Migration Strategy

**Option A: Minimal Downtime Migration (Recommended)**
```bash
# T-7 Days: Create final staging snapshot
tutor local do backup-db
gsutil cp /path/to/backup gs://staging-academy-mereka-io-backup/final-staging-backup-$(date +%Y%m%d).sql.gz

# T-3 Days: Test migration on production (with dummy data)
gcloud sql instances create mereka-lms-mysql-test --tier=db-f1-micro --region=asia-southeast1
gsutil cp gs://staging-academy-mereka-io-backup/final-staging-backup-*.sql.gz - | gunzip | \
  gcloud sql import sql mereka-lms-mysql-test gs://staging-academy-mereka-io-backup/final-staging-backup-*.sql.gz

# Measure migration time (for planning)
# Expected: 10GB database = ~15-30 minutes import time

# T-Day (Cutover Day):
# 1. Enable maintenance mode on staging
tutor local do lms exec ./manage.py lms set_maintenance_mode on

# 2. Wait for in-flight requests to complete (2-5 minutes)
sleep 300

# 3. Final backup from staging
tutor local do backup-db
BACKUP_FILE="final-cutover-$(date +%Y%m%d-%H%M).sql.gz"
gsutil cp /path/to/backup gs://staging-academy-mereka-io-backup/$BACKUP_FILE

# 4. Import to production Cloud SQL
gcloud sql import sql mereka-lms-mysql-prod gs://staging-academy-mereka-io-backup/$BACKUP_FILE \
  --database=openedx

# 5. Migrate MongoDB (forum data)
# Use mongodump/mongorestore or Atlas Live Migration
mongodump --uri="mongodb://staging-mongodb-uri" --out=/tmp/forum-dump
mongorestore --uri="mongodb://prod-atlas-uri" --drop /tmp/forum-dump

# 6. Update DNS to point to production
# Update Cloudflare DNS record for academyv2.mereka.io to prod LB IP
# TTL: 300 seconds (5 minutes)

# 7. Disable maintenance mode on production
tutor k8s do lms exec ./manage.py lms set_maintenance_mode off

# 8. Monitor for 30 minutes
watch kubectl get pods -n mereka-lms
tutor k8s logs --tail=100 lms
tutor k8s logs --tail=100 cms

# Total downtime estimate: 30-60 minutes
```

**Option B: Blue-Green Deployment (Zero Downtime)**
```
1. Production (Green) runs on new infrastructure
2. Staging (Blue) continues to run on old infrastructure
3. Set up database replication: Staging MySQL → Production MySQL
4. Monitor replication lag until <1 second
5. Switch DNS from Blue to Green
6. Monitor for 24 hours
7. If issues, switch DNS back to Blue (rollback)
8. After 7 days of stability, decommission Blue

Requirements:
- Cloud SQL replica from staging to production (supported)
- MongoDB Atlas replica set (manual syncing via mongosync)
- Additional cost during overlap period (~$500-1000 for 7 days)
```

**Recommended**: Use **Option A (Minimal Downtime)** for initial cutover. Schedule during low-traffic window (e.g., Saturday 2-4 AM SGT).

### 6.3 Rollback Plan

**Scenario 1: Issue Detected Within 1 Hour of Cutover**
```bash
# 1. Switch DNS back to staging immediately
# Update Cloudflare DNS to point to staging LB IP

# 2. Restore staging from pre-cutover backup (if needed)
gsutil cp gs://staging-academy-mereka-io-backup/final-cutover-*.sql.gz - | gunzip | \
  mysql -h staging-mysql-host -u root -p openedx

# 3. Disable maintenance mode on staging
tutor local do lms exec ./manage.py lms set_maintenance_mode off

# 4. Investigate production issue offline
# Expected downtime: 5-10 minutes (DNS propagation)
```

**Scenario 2: Issue Detected 1-24 Hours After Cutover**
```bash
# 1. Enable maintenance mode on production
tutor k8s do lms exec ./manage.py lms set_maintenance_mode on

# 2. Export any new data created on production (enrollments, progress, etc.)
tutor k8s do lms exec ./manage.py lms dumpdata > prod-new-data.json

# 3. Switch DNS back to staging

# 4. Import new data to staging (manual merge required)
# This is complex - avoid by fixing production issues instead of rolling back

# 5. Alternative: Fix production issue without rollback
# Preferred approach if issue is fixable within 2-4 hours
```

**Rollback Decision Matrix:**
| Issue Severity | Time Since Cutover | Action |
|----------------|-------------------|--------|
| Critical (site down) | <1 hour | Immediate DNS rollback to staging |
| Critical (site down) | 1-24 hours | Fix production in place if possible, else rollback |
| Major (degraded performance) | Any time | Fix production in place |
| Minor (UI glitch, non-critical feature) | Any time | Fix via hotfix deployment |

### 6.4 Post-Cutover Validation (T+7 Days)

**Day 1 (Cutover Day):**
- [ ] Verify all services are running: `kubectl get pods -n mereka-lms`
- [ ] Check database connections: `tutor k8s do lms exec ./manage.py lms dbshell`
- [ ] Test user login (existing user)
- [ ] Test new user registration
- [ ] Test course enrollment
- [ ] Test video playback
- [ ] Test quiz submission
- [ ] Test certificate generation
- [ ] Check error rates in logs: `tutor k8s logs --tail=500 lms | grep ERROR`

**Day 2-3:**
- [ ] Review Cloud Monitoring dashboards for anomalies
- [ ] Check database CPU/memory utilization (should be <70%)
- [ ] Verify backups are running: `gcloud sql backups list --instance=mereka-lms-mysql-prod`
- [ ] Test course content upload via Studio
- [ ] Monitor user-reported issues (support tickets)

**Day 4-7:**
- [ ] Perform load testing to validate auto-scaling
- [ ] Review cost dashboard (should align with projections)
- [ ] Schedule DR drill (simulate database failover)
- [ ] Document any configuration changes made post-cutover
- [ ] Decommission staging infrastructure (or scale down to minimal)

---

## 7. Disaster Recovery

### 7.1 Backup Strategy

**Cloud SQL MySQL:**
```hcl
# Configured via Terraform (already in modules/cloudsql)
settings {
  backup_configuration {
    enabled                        = true
    binary_log_enabled             = true
    start_time                     = "03:00"  # 3 AM SGT
    transaction_log_retention_days = 7
    backup_retention_settings {
      retained_backups = 30
      retention_unit   = "COUNT"
    }
  }
}
```

**Backup Schedule:**
- **Automated Daily Backups**: 03:00 SGT (low traffic period)
- **Retention**: 30 days of automated backups
- **Transaction Logs**: 7 days (point-in-time recovery)
- **Manual Pre-Change Backups**: Before major deployments

**MongoDB Atlas:**
- **Continuous Backup**: Enabled (point-in-time recovery)
- **Snapshot Frequency**: Every 6 hours
- **Retention**: 14 days
- **Cross-Region Replica**: Optional (adds ~$50/month)

**Application Data (Cloud Storage):**
- **Versioning**: Enabled on all buckets
- **Lifecycle Policy**:
  - 0-30 days: STANDARD storage
  - 31-90 days: NEARLINE storage
  - 91-365 days: COLDLINE storage
  - >365 days: ARCHIVE storage
- **Cross-Region Replication**: Enabled for backup bucket

### 7.2 Recovery Point Objective (RPO) & Recovery Time Objective (RTO)

| Data Type | RPO | RTO | Backup Method |
|-----------|-----|-----|---------------|
| **MySQL (User Data, Courses)** | 15 minutes | 30 minutes | Cloud SQL automated backups + transaction logs |
| **MongoDB (Forum Data)** | 6 hours | 1 hour | Atlas continuous backup |
| **Redis (Cache)** | N/A (ephemeral) | 5 minutes | None required (cache rebuild) |
| **Cloud Storage (Content)** | 0 (versioned) | 10 minutes | Object versioning + cross-region replication |
| **Configuration (Tutor)** | 0 (Git) | 15 minutes | Git repository |

### 7.3 Disaster Recovery Scenarios

**Scenario 1: Single Zone Failure (asia-southeast1-a outage)**

**Impact:**
- GKE pods automatically reschedule to zones B and C (5-10 min)
- Cloud SQL automatically fails over to standby in zone B (<60 sec)
- Redis fails over to replica in zone B (<60 sec)
- Load balancer routes traffic to healthy backends

**Recovery Steps:**
1. Monitor automatic failover via Cloud Console
2. Verify services are healthy: `kubectl get pods -o wide`
3. Check for any stuck pods: `kubectl get pods | grep Pending`
4. No manual intervention required (automatic)

**Expected Downtime**: 1-2 minutes (time for health checks to detect failure)

**Scenario 2: Regional Failure (asia-southeast1 complete outage)**

**Impact:**
- All GKE pods down
- Cloud SQL primary and standby down
- Redis down
- Load balancer down

**Recovery Steps:**
1. Provision new GKE cluster in asia-southeast2 (Jakarta)
2. Restore Cloud SQL from latest backup to new region
3. Deploy application to new cluster
4. Update DNS to point to new region
5. Restore MongoDB from Atlas backup

**Expected Downtime**: 2-4 hours (manual process)

**Mitigation**: Multi-region setup (adds ~$1,500/month) - NOT recommended for current scale

**Scenario 3: Data Corruption (e.g., accidental deletion of courses)**

**Impact:**
- Specific data loss (courses, user data)
- Platform operational but data missing

**Recovery Steps:**
```bash
# 1. Identify corruption time (e.g., 10:30 AM today)
# 2. Use Cloud SQL point-in-time recovery
gcloud sql backups restore $BACKUP_ID \
  --backup-instance=mereka-lms-mysql-prod \
  --restore-instance=mereka-lms-mysql-prod-restored

# 3. Export affected tables from restored instance
gcloud sql export sql mereka-lms-mysql-prod-restored \
  gs://academy-mereka-io-backup/recovery-$(date +%Y%m%d-%H%M).sql \
  --database=openedx \
  --table=course_overviews_courseoverview,course_modes_coursemode

# 4. Import to production (requires downtime or careful merge)
# 5. Validate data integrity
```

**Expected Downtime**: 1-2 hours (depending on data volume)

**Scenario 4: Complete GCP Account Compromise**

**Impact:**
- Loss of access to GCP console and APIs
- Potential data deletion by attacker

**Recovery Steps:**
1. Contact Google Cloud Support immediately
2. Restore from off-GCP backups (requires separate backup strategy)
3. Deploy to new GCP organization/account
4. Restore data from external backups

**Expected Downtime**: 1-3 days (worst case)

**Mitigation**:
- Enable 2FA for all admin accounts
- Use Cloud IAM with least privilege
- Set up billing alerts for anomalous usage
- Maintain off-GCP backups (e.g., weekly export to AWS S3 or on-premise)

### 7.4 DR Testing Schedule

| Test Type | Frequency | Scope | Downtime Required |
|-----------|-----------|-------|-------------------|
| **Backup Restoration** | Monthly | Restore staging from prod backup | No (staging only) |
| **Database Failover** | Quarterly | Trigger Cloud SQL failover | Yes (5-10 min) |
| **Zone Failure Simulation** | Quarterly | Cordon nodes in one zone | No (GKE auto-recovery) |
| **Full DR Drill** | Annually | Restore entire platform to new project | No (separate project) |

**DR Drill Checklist (Quarterly):**
```bash
# 1. Schedule during low-traffic period (Saturday 2-4 AM SGT)

# 2. Announce maintenance window to users
tutor k8s do lms exec ./manage.py lms set_maintenance_mode on

# 3. Trigger Cloud SQL failover
gcloud sql instances failover mereka-lms-mysql-prod --project=mereka-lms-prod

# 4. Monitor failover (should complete in <60 seconds)
watch gcloud sql instances describe mereka-lms-mysql-prod --format="value(state)"

# 5. Verify application connectivity
tutor k8s do lms exec ./manage.py lms dbshell

# 6. Re-enable platform
tutor k8s do lms exec ./manage.py lms set_maintenance_mode off

# 7. Document results and lessons learned
```

---

## 8. Monitoring & Alerting

### 8.1 Observability Stack

**Cloud Monitoring Dashboards:**
```hcl
# infrastructure/terraform/modules/monitoring/dashboards.tf
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "Mereka LMS Production Overview"
    dashboardFilters = []
    gridLayout = {
      widgets = [
        # GKE Pod Health
        {
          title = "Pod Status"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_pod\" resource.labels.namespace_name=\"mereka-lms\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_COUNT"
                  }
                }
              }
            }]
          }
        },
        # Cloud SQL CPU
        {
          title = "Cloud SQL CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloudsql_database\" metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        # Redis Memory
        {
          title = "Redis Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"redis_instance\" metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        # HTTP Request Rate
        {
          title = "HTTP Request Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_pod\" metric.type=\"kubernetes.io/pod/network/received_bytes_count\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}
```

### 8.2 Alert Policies

**Critical Alerts (Page On-Call):**
```hcl
# infrastructure/terraform/modules/monitoring/alerts.tf

# Alert 1: LMS Pod Crash Loop
resource "google_monitoring_alert_policy" "pod_crash_loop" {
  display_name = "LMS Pod Crash Loop"
  combiner     = "OR"

  conditions {
    display_name = "Pod restarts > 5 in 10 minutes"
    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" resource.labels.namespace_name=\"mereka-lms\" resource.labels.pod_name=monitoring.regex.full_match(\"lms-.*\") metric.type=\"kubernetes.io/pod/restart_count\""
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.pagerduty.name]

  alert_strategy {
    auto_close = "3600s"
  }
}

# Alert 2: High Error Rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High HTTP 5xx Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "5xx rate > 5% for 5 minutes"
    condition_threshold {
      filter          = "resource.type=\"k8s_pod\" metric.type=\"kubernetes.io/pod/network/sent_bytes_count\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05  # 5%
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        group_by_fields    = ["resource.labels.pod_name"]
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.pagerduty.name,
    google_monitoring_notification_channel.slack.name
  ]
}

# Alert 3: Database CPU Saturation
resource "google_monitoring_alert_policy" "cloudsql_cpu_high" {
  display_name = "Cloud SQL CPU > 80%"
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization > 80% for 10 minutes"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack.name]
}

# Alert 4: Disk Space Running Low
resource "google_monitoring_alert_policy" "cloudsql_disk_high" {
  display_name = "Cloud SQL Disk > 85%"
  combiner     = "OR"

  conditions {
    display_name = "Disk utilization > 85%"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.pagerduty.name,
    google_monitoring_notification_channel.slack.name
  ]
}

# Alert 5: Redis Memory Eviction
resource "google_monitoring_alert_policy" "redis_eviction" {
  display_name = "Redis Memory Eviction Rate High"
  combiner     = "OR"

  conditions {
    display_name = "Evicted keys > 100/min"
    condition_threshold {
      filter          = "resource.type=\"redis_instance\" metric.type=\"redis.googleapis.com/stats/evicted_keys\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 100
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.slack.name]
}

# Alert 6: SSL Certificate Expiry
resource "google_monitoring_alert_policy" "ssl_expiry" {
  display_name = "SSL Certificate Expiring Soon"
  combiner     = "OR"

  conditions {
    display_name = "Certificate expires in < 14 days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\""
      duration        = "600s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1209600  # 14 days in seconds
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MIN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}
```

**Warning Alerts (Email/Slack Only):**
- Database CPU > 60% for 30 minutes
- Redis memory usage > 70%
- Pod memory usage > 80%
- Slow query detected (>5 seconds)
- Failed backup job

### 8.3 Notification Channels

```hcl
# infrastructure/terraform/modules/monitoring/notification-channels.tf

# Email notification
resource "google_monitoring_notification_channel" "email" {
  display_name = "Tech Admin Email"
  type         = "email"
  labels = {
    email_address = "techadmin@biji-biji.com"
  }
}

# Slack notification
resource "google_monitoring_notification_channel" "slack" {
  display_name = "Slack #alerts"
  type         = "slack"
  labels = {
    channel_name = "#mereka-lms-alerts"
  }
  sensitive_labels {
    auth_token = var.slack_webhook_url
  }
}

# PagerDuty (for critical alerts)
resource "google_monitoring_notification_channel" "pagerduty" {
  display_name = "PagerDuty On-Call"
  type         = "pagerduty"
  sensitive_labels {
    service_key = var.pagerduty_service_key
  }
}
```

### 8.4 SLO (Service Level Objectives)

**Availability SLO: 99.9% Uptime**
- **Target**: 99.9% availability (43.2 minutes downtime/month)
- **Measurement**: Uptime checks on LMS homepage (5-minute intervals)
- **Error Budget**: 0.1% (43.2 minutes/month)

**Latency SLO: 95% of Requests < 2s**
- **Target**: 95th percentile response time < 2 seconds
- **Measurement**: Load balancer latency metrics
- **Error Budget**: 5% of requests can exceed 2s

**Data Durability SLO: 99.999%**
- **Target**: No data loss (RPO < 15 minutes)
- **Measurement**: Backup success rate + transaction log retention
- **Error Budget**: Minimal (critical data)

**SLO Dashboard:**
```yaml
# Create SLO via Cloud Console or gcloud
gcloud monitoring slos create \
  --service=mereka-lms-prod \
  --slo-id=availability \
  --display-name="LMS Availability SLO" \
  --goal=0.999 \
  --calendar-period=MONTH \
  --request-based-sli \
  --filter="resource.type=\"k8s_pod\" resource.labels.namespace_name=\"mereka-lms\""
```

### 8.5 Log Aggregation

**Centralized Logging:**
- All GKE pod logs → Cloud Logging (automatic)
- Cloud SQL logs → Cloud Logging (enabled via settings)
- MongoDB Atlas logs → Atlas UI (separate)

**Log Retention:**
- Default: 30 days in Cloud Logging
- Long-term: Export to BigQuery (90 days)
- Archival: Export to Cloud Storage (7 years for compliance)

**Log Export to BigQuery:**
```bash
# Create BigQuery dataset
bq mk --dataset --location=asia-southeast1 mereka-lms-prod:logs

# Create log sink
gcloud logging sinks create prod-logs-bigquery \
  bigquery.googleapis.com/projects/mereka-lms-prod/datasets/logs \
  --log-filter='resource.type="k8s_pod" resource.labels.namespace_name="mereka-lms"' \
  --project=mereka-lms-prod
```

**Useful Log Queries:**
```bash
# Find all 5xx errors in last hour
gcloud logging read 'resource.type="k8s_pod" AND severity="ERROR" AND timestamp>="2025-01-01T00:00:00Z"' --limit=100 --format=json

# Find slow database queries
gcloud logging read 'resource.type="cloudsql_database" AND textPayload=~"Query_time: [0-9]+" AND timestamp>="2025-01-01T00:00:00Z"' --limit=50

# Find authentication failures
gcloud logging read 'jsonPayload.message=~"Authentication failed" AND timestamp>="2025-01-01T00:00:00Z"' --limit=100
```

---

## 9. Production Readiness Checklist

### 9.1 Infrastructure Readiness

**GCP Project Setup:**
- [ ] Production GCP project created (`mereka-lms-prod`)
- [ ] Billing account linked
- [ ] Required APIs enabled (Compute, Container, SQL, Redis, DNS, etc.)
- [ ] IAM roles configured (least privilege)
- [ ] Service accounts created (Terraform, GKE Workload Identity)
- [ ] Budget alerts configured ($2,200/month threshold)

**Network & Security:**
- [ ] VPC created with appropriate CIDR ranges
- [ ] Firewall rules configured (default deny, explicit allow)
- [ ] Cloud Armor security policy applied
- [ ] SSL certificates provisioned (Google-managed)
- [ ] DNS records configured (academyv2.mereka.io → prod LB)
- [ ] VPC peering configured (MongoDB Atlas)

**Kubernetes Cluster:**
- [ ] GKE Autopilot cluster created (regional, multi-zone)
- [ ] Workload Identity enabled
- [ ] Cluster logging enabled (SYSTEM_COMPONENTS + WORKLOADS)
- [ ] Cluster monitoring enabled
- [ ] Pod Security Policies configured
- [ ] Network Policies configured (namespace isolation)
- [ ] Resource quotas set (prevent runaway pods)

**Databases:**
- [ ] Cloud SQL MySQL provisioned (db-custom-4-15360, REGIONAL HA)
- [ ] Cloud SQL read replica created (for reporting)
- [ ] Automated backups enabled (daily, 30-day retention)
- [ ] Transaction logs enabled (7-day PITR)
- [ ] Maintenance window configured (Sunday 10 PM SGT)
- [ ] Query Insights enabled
- [ ] MongoDB Atlas M10 cluster created
- [ ] MongoDB VPC peering configured
- [ ] MongoDB continuous backup enabled (14-day retention)
- [ ] Memorystore Redis provisioned (STANDARD_HA, 5GB)

**Storage:**
- [ ] Cloud Storage buckets created (content, backup)
- [ ] Bucket versioning enabled
- [ ] Lifecycle policies configured
- [ ] CORS policies configured
- [ ] Cloud CDN enabled for content bucket
- [ ] Artifact Registry repository created

**Monitoring & Alerting:**
- [ ] Cloud Monitoring dashboards created
- [ ] Alert policies configured (critical + warning)
- [ ] Notification channels configured (email, Slack, PagerDuty)
- [ ] Uptime checks configured (LMS, Studio, MFE)
- [ ] SLOs defined and tracked
- [ ] Log exports to BigQuery configured
- [ ] On-call rotation established

### 9.2 Application Readiness

**Open edX Deployment:**
- [ ] Tutor production config created (`config.prod.yml`)
- [ ] All images built and pushed to Artifact Registry
- [ ] Application deployed to GKE (`tutor k8s quickstart`)
- [ ] Apply-patches script executed
- [ ] HPA (Horizontal Pod Autoscaler) configured
- [ ] Pod resource requests/limits set appropriately
- [ ] Pod anti-affinity rules configured (multi-zone spread)
- [ ] Liveness and readiness probes verified
- [ ] ConfigMaps and Secrets mounted correctly
- [ ] Persistent volumes claimed (if any)

**Configuration:**
- [ ] `LMS_HOST` set to `academyv2.mereka.io`
- [ ] `CMS_HOST` set to `studio.academyv2.mereka.io`
- [ ] `ENABLE_HTTPS` set to `true`
- [ ] `SMTP_HOST` configured (AWS SES)
- [ ] `CONTACT_EMAIL` set to support@mereka.io
- [ ] OAuth2 credentials configured (Google, Facebook, etc.)
- [ ] Analytics tracking configured (Google Analytics, Mixpanel)
- [ ] Payment gateway configured (if using Ecommerce)
- [ ] CDN URLs configured for static assets
- [ ] CORS settings configured for MFEs

**Data Migration:**
- [ ] Staging database backup created
- [ ] Test migration performed on non-prod instance
- [ ] Migration runbook documented
- [ ] Downtime window scheduled and communicated
- [ ] Rollback plan documented and tested
- [ ] Data validation scripts prepared

**Testing:**
- [ ] Smoke tests passed (login, enrollment, video, quiz)
- [ ] Load testing completed (500-2000 concurrent users)
- [ ] Failover testing completed (database, Redis, zone failure)
- [ ] Security testing completed (OWASP Top 10, penetration test)
- [ ] Performance testing completed (response times, throughput)
- [ ] Accessibility testing completed (WCAG 2.1 AA)

### 9.3 Operational Readiness

**Documentation:**
- [ ] Architecture diagram updated
- [ ] Runbook created (deployment, scaling, incident response)
- [ ] Disaster recovery plan documented
- [ ] On-call procedures documented
- [ ] Escalation matrix defined
- [ ] User-facing status page created (e.g., status.mereka.io)

**Team Readiness:**
- [ ] Team trained on GKE operations
- [ ] Team trained on Tutor deployment process
- [ ] Team trained on monitoring tools
- [ ] Team trained on incident response procedures
- [ ] On-call schedule established
- [ ] Communication channels established (Slack, email lists)

**Compliance & Legal:**
- [ ] Privacy policy updated (data storage locations)
- [ ] Terms of service updated
- [ ] GDPR compliance verified (for EU learners)
- [ ] Data retention policy documented
- [ ] Incident response plan documented (data breach procedures)
- [ ] Backup and disaster recovery plan documented

**Business Continuity:**
- [ ] Backup strategy tested and validated
- [ ] Disaster recovery drill completed
- [ ] Rollback plan tested
- [ ] Communication plan for outages (status page, email, social media)
- [ ] SLA commitments defined (internal or customer-facing)

### 9.4 Go/No-Go Decision Criteria

**GO Criteria (All Must Be Met):**
1. All critical infrastructure components healthy (green status)
2. All smoke tests passing
3. Load test results within acceptable thresholds (p95 < 2s)
4. Security vulnerabilities remediated (high/critical severity)
5. On-call team staffed and trained
6. Rollback plan documented and tested
7. Communication plan ready (stakeholders informed)
8. Monitoring and alerting verified (test alerts received)

**NO-GO Criteria (Any One Triggers Delay):**
1. Critical infrastructure component failing (database, GKE cluster)
2. Smoke tests failing (login, enrollment, core features)
3. Load test showing unacceptable performance (p95 > 5s, error rate > 1%)
4. Unresolved critical security vulnerabilities
5. On-call team not ready or trained
6. Rollback plan not tested
7. Major external dependency unavailable (MongoDB Atlas, DNS provider)

**Post-Go/No-Go Review:**
- Document decision rationale
- If NO-GO, create action plan with timeline to remediate blockers
- If GO, proceed with cutover plan (Section 6)

---

## 10. Timeline & Milestones

### 10.1 Proposed Timeline (90-Day Plan)

**Phase 1: Planning & Design (Days 1-14)**
- **Week 1**:
  - [ ] Finalize infrastructure architecture (this document)
  - [ ] Review and approve budget ($1,500-2,500/month)
  - [ ] Identify team roles and responsibilities
  - [ ] Set up project tracking (Jira, Asana, or similar)

- **Week 2**:
  - [ ] Create Terraform multi-environment setup
  - [ ] Set up GitHub Actions CI/CD pipelines
  - [ ] Document deployment procedures
  - [ ] Create production readiness checklist

**Phase 2: Infrastructure Provisioning (Days 15-30)**
- **Week 3**:
  - [ ] Create production GCP project
  - [ ] Deploy Terraform infrastructure (dev, staging, prod)
  - [ ] Configure VPC peering with MongoDB Atlas
  - [ ] Set up Cloud DNS zones

- **Week 4**:
  - [ ] Deploy GKE Autopilot cluster
  - [ ] Configure Cloud SQL MySQL (REGIONAL HA)
  - [ ] Configure Memorystore Redis (STANDARD_HA)
  - [ ] Set up MongoDB Atlas M10 cluster
  - [ ] Configure Cloud Storage buckets and CDN

**Phase 3: Application Deployment (Days 31-45)**
- **Week 5**:
  - [ ] Build Open edX images for production
  - [ ] Deploy to GKE via Tutor
  - [ ] Configure Ingress and SSL certificates
  - [ ] Test basic functionality (login, enrollment)

- **Week 6**:
  - [ ] Configure HPA and resource limits
  - [ ] Set up monitoring dashboards
  - [ ] Configure alert policies
  - [ ] Implement Cloud Armor security policies

**Phase 4: Testing & Validation (Days 46-60)**
- **Week 7**:
  - [ ] Perform smoke testing (all critical paths)
  - [ ] Conduct load testing (500-2000 concurrent users)
  - [ ] Test database failover scenarios
  - [ ] Test zone failure scenarios

- **Week 8**:
  - [ ] Security testing (OWASP Top 10, penetration test)
  - [ ] Performance tuning based on test results
  - [ ] Fix identified issues
  - [ ] Re-test until all tests pass

**Phase 5: Migration Preparation (Days 61-75)**
- **Week 9**:
  - [ ] Create data migration scripts
  - [ ] Test migration on non-prod instance
  - [ ] Document migration runbook
  - [ ] Create rollback procedures

- **Week 10**:
  - [ ] Train team on production operations
  - [ ] Set up on-call rotation
  - [ ] Conduct disaster recovery drill
  - [ ] Create communication plan for cutover

**Phase 6: Cutover (Days 76-90)**
- **Week 11**:
  - [ ] Schedule cutover window (Saturday 2-4 AM SGT)
  - [ ] Communicate cutover plan to stakeholders
  - [ ] Perform final staging backup
  - [ ] Execute go/no-go decision

- **Week 12**:
  - [ ] Execute cutover (migrate data, switch DNS)
  - [ ] Monitor for 24 hours (on-call team active)
  - [ ] Validate all services operational
  - [ ] Decommission or scale down staging (if desired)

- **Week 13** (Post-Cutover):
  - [ ] Monitor cost vs. projections
  - [ ] Tune auto-scaling based on actual traffic
  - [ ] Document lessons learned
  - [ ] Plan for future optimizations

### 10.2 Critical Path Items

**Blockers (Must Complete Before Cutover):**
1. Production GCP project creation and billing setup (Week 3)
2. Terraform infrastructure deployment (Week 4)
3. Application deployment and smoke tests passing (Week 5)
4. Load testing validation (Week 7)
5. Data migration testing (Week 9)
6. Team training completion (Week 10)

**Dependencies:**
- MongoDB Atlas VPC peering requires GCP VPC to exist first
- SSL certificate provisioning takes 15-60 minutes (plan accordingly)
- Database migration duration depends on data size (test to estimate)
- DNS propagation can take 5-60 minutes (use low TTL during cutover)

### 10.3 Success Metrics (Post-Cutover)

**Week 1 Post-Cutover:**
- [ ] 99.9% uptime achieved
- [ ] P95 response time < 2 seconds
- [ ] Error rate < 0.5%
- [ ] No critical incidents
- [ ] User satisfaction score ≥ 4.5/5 (if surveyed)

**Month 1 Post-Cutover:**
- [ ] Actual costs within 10% of projections
- [ ] Auto-scaling working as expected (no manual intervention)
- [ ] Zero data loss incidents
- [ ] All backups completing successfully
- [ ] Team comfortable with production operations

**Month 3 Post-Cutover:**
- [ ] SLO compliance ≥ 99.5% (allowing for 0.5% grace)
- [ ] Cost optimizations identified and implemented
- [ ] Scalability validated (can handle 2x projected load)
- [ ] Disaster recovery procedures validated (quarterly drill)
- [ ] Roadmap for future enhancements defined

---

## Appendix A: Terraform Module Enhancements

### Read Replica Module

**File**: `infrastructure/terraform/modules/cloudsql-replica/main.tf`
```hcl
# New module for Cloud SQL read replicas

variable "project_id" { type = string }
variable "region" { type = string }
variable "master_instance_name" { type = string }
variable "tier" { type = string }
variable "labels" { type = map(string) }

resource "google_sql_database_instance" "read_replica" {
  name                 = "${var.master_instance_name}-read"
  master_instance_name = var.master_instance_name
  region               = var.region
  database_version     = "MYSQL_8_0"
  project              = var.project_id

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.tier
    disk_autoresize   = true
    user_labels       = var.labels

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.self_link
    }
  }
}

data "google_compute_network" "vpc" {
  name = "mereka-lms-vpc"
}

output "replica_connection_name" {
  value = google_sql_database_instance.read_replica.connection_name
}

output "replica_private_ip" {
  value = google_sql_database_instance.read_replica.private_ip_address
}
```

### Monitoring Module

**File**: `infrastructure/terraform/modules/monitoring/main.tf`
```hcl
# Centralized monitoring module

variable "project_id" { type = string }
variable "notification_emails" { type = list(string) }
variable "slack_webhook_url" { type = string sensitive = true }
variable "pagerduty_service_key" { type = string sensitive = true }

# Notification channels (from Section 8.3)
# Alert policies (from Section 8.2)
# Dashboards (from Section 8.1)

# See full implementation in Section 8
```

### Budgets Module

**File**: `infrastructure/terraform/modules/budgets/main.tf`
```hcl
# Centralized budgets module

variable "project_id" { type = string }
variable "billing_account_id" { type = string }
variable "monthly_budget_usd" { type = number }
variable "notification_channels" { type = list(string) }

resource "google_billing_budget" "monthly" {
  # See implementation in Section 4.3
}
```

---

## Appendix B: Cost Optimization Playbook

### Immediate Savings Opportunities (Post-Launch)

**1. Right-Size Cloud SQL After 30 Days**
```bash
# Check actual CPU/memory utilization
gcloud sql instances describe mereka-lms-mysql-prod --format="value(settings.tier)"

# If CPU consistently <50%, consider downgrade
# db-custom-4-15360 → db-custom-2-7680 (save $225/month)
gcloud sql instances patch mereka-lms-mysql-prod --tier=db-custom-2-7680
```

**2. Optimize Redis Memory**
```bash
# Check actual memory usage
gcloud redis instances describe mereka-lms-redis-prod --region=asia-southeast1 --format="value(memorySizeGb,currentUsageBytes)"

# If usage consistently <60%, consider downgrade
# 5GB → 3GB (save $35/month)
gcloud redis instances update mereka-lms-redis-prod --size=3 --region=asia-southeast1
```

**3. Remove Read Replica if Unused**
```bash
# Check read replica query volume
gcloud sql instances describe mereka-lms-mysql-read-prod --format="value(stats.totalQueryCount)"

# If <100 queries/day, consider removing (save $135/month)
gcloud sql instances delete mereka-lms-mysql-read-prod
```

**4. Implement Committed Use Discounts (CUD)**
```bash
# For stable workloads, purchase 1-year or 3-year CUDs
# Saves 25-37% on Compute Engine and GKE
# Purchase via GCP Console > Billing > Commitments
# Estimate: Save $200-400/month on GKE
```

### Long-Term Optimization Strategies

**1. Migrate to Newer Instance Types**
- E2 → N2 (better performance per dollar for some workloads)
- Monitor for new GCP instance types (T2D, C3, etc.)

**2. Implement Auto-Pause for Non-Prod**
- Auto-shutdown staging/dev environments during non-business hours
- Save ~50% on dev/staging costs ($150-200/month)

**3. Storage Lifecycle Management**
- Move old course content to NEARLINE or COLDLINE storage
- Save ~70% on storage costs for content >90 days old

**4. Network Egress Optimization**
- Use Cloud CDN for all static assets (already planned)
- Consider multi-region storage for global learners
- Compress responses (enable gzip in Caddy/Nginx)

---

## Appendix C: Contact Information

**Stakeholders:**
- **Platform Engineering**: techadmin@biji-biji.com
- **Finance Team**: team@mereka.io
- **On-Call Rotation**: TBD (to be set up in Week 10)

**Vendor Contacts:**
- **GCP Support**: Enterprise Support (if purchased)
- **MongoDB Atlas Support**: support@mongodb.com
- **Cloudflare Support**: (if using Cloudflare for DNS)

**Documentation References:**
- This Plan: `docs/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md`
- GCP Roadmap: `docs/operations/GCP_ROADMAP.md`
- Cost Analysis: `GCP_BILLING_ANALYSIS.md`
- Troubleshooting: `docs/operations/TROUBLESHOOTING.md`
- Tutor Guide: `CLAUDE.md`

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-21 | Claude Code | Initial production infrastructure plan |

---

**Next Steps**: Review this plan with stakeholders, adjust budget/timeline as needed, then proceed with Phase 1 (Planning & Design).
