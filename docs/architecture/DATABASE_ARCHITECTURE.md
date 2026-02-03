# Database Architecture Guide
_Audience: Everyone • Owner: Infra Team • Last updated: 2025-11-11_

This document explains **what databases we use, where they run, and what they're for**. This is critical for understanding the system architecture.

## Quick Summary

| Database | Type | Location | Used By | Purpose |
|----------|------|----------|---------|---------|
| **MySQL** | SQL | Google Cloud SQL | LMS, CMS, Discovery, Ecommerce, Notes, XQueue | **Main application data** (courses, users, enrollments, content) |
| **MongoDB** | NoSQL | MongoDB Atlas (AWS) | Forum only | **Forum comments/discussions** |
| **Redis** | In-memory | GKE (in-cluster) | All services | **Caching & sessions** |
| **Elasticsearch** | Search | GKE (in-cluster) | Forum, Discovery | **Search indexing** |
| **ClickHouse** | Analytics | GKE (in-cluster) | Aspects | **Analytics data warehouse** |

---

## 1. MySQL (Cloud SQL) - The Main Database

**What it is:** MySQL 8.0 running on Google Cloud SQL (managed service)

**Where it runs:** Google Cloud SQL (not in Kubernetes)

**What it stores:**
- **LMS/CMS:** Courses, course content, users, enrollments, certificates, grades
- **Discovery:** Course catalog metadata
- **Ecommerce:** Payment transactions, orders
- **Notes:** ORA (Open Response Assessment) notes
- **XQueue:** Queue management

**Why Cloud SQL (not in-cluster):**
- Managed backups, updates, and high availability
- Better performance and reliability
- Easier to scale and maintain

**Connection:** Services connect via Private IP (VPC peering)

**Backups:** Automatic daily backups to Cloud Storage

---

## 2. MongoDB Atlas - Forum Only

**What it is:** MongoDB running on MongoDB Atlas (managed service)

**Where it runs:** MongoDB Atlas cloud (AWS ap-southeast-1 region)

**What it stores:** 
- **ONLY Forum data:** Comments, discussions, threads, replies
- Database name: `cs_comments_service`

**Why MongoDB Atlas (not in-cluster):**
- Forum service (`cs_comments_service`) requires MongoDB specifically
- Managed service = no maintenance, automatic backups
- Better reliability than running MongoDB in Kubernetes

**Why NOT for main data:**
- Open edX LMS/CMS uses MySQL for everything else
- MongoDB is ONLY for the forum feature

**Migration Status:** ✅ Migrated from in-cluster MongoDB StatefulSet to Atlas (2025-11-11)

**Connection:** Forum pods connect via `MONGODB_URI` environment variable

---

## 3. Redis - Caching & Sessions

**What it is:** Redis in-memory data store

**Where it runs:** GKE cluster (in-cluster StatefulSet)

**What it stores:**
- Session data
- Cache (course content, user data, etc.)
- Celery task queue backend

**Why in-cluster:**
- Fast access (low latency)
- Simple to manage for caching use case
- Can be replaced with Cloud Memorystore later if needed

---

## 4. Elasticsearch - Search

**What it is:** Elasticsearch search engine

**Where it runs:** GKE cluster (in-cluster Deployment)

**What it stores:**
- Search indexes for Forum discussions
- Search indexes for Discovery course catalog

**Why in-cluster:**
- Used only by Forum and Discovery services
- Can be replaced with managed OpenSearch later if needed

---

## 5. ClickHouse - Analytics

**What it is:** ClickHouse columnar database

**Where it runs:** GKE cluster (in-cluster StatefulSet)

**What it stores:**
- Analytics event data (from Aspects)
- Learning analytics metrics
- Reporting data warehouse

**Why in-cluster:**
- Used only by Aspects analytics service
- Can be replaced with BigQuery later if needed

---

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                     │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Google Kubernetes Engine (GKE)            │   │
│  │                                                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │   LMS    │  │   CMS    │  │  Forum   │          │   │
│  │  │  (Django)│  │  (Django)│  │ (Ruby)   │          │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘          │   │
│  │       │             │              │                 │   │
│  │       │             │              │                 │   │
│  │  ┌────▼─────────────▼──────────────▼────┐           │   │
│  │  │         Redis (Cache/Sessions)       │           │   │
│  │  └─────────────────────────────────────┘           │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────┐            │   │
│  │  │    Elasticsearch (Search Index)     │            │   │
│  │  └─────────────────────────────────────┘            │   │
│  │                                                       │   │
│  │  ┌─────────────────────────────────────┐            │   │
│  │  │    ClickHouse (Analytics)           │            │   │
│  │  └─────────────────────────────────────┘            │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Cloud SQL (MySQL) - Main Database           │   │
│  │  • LMS/CMS data (courses, users, enrollments)      │   │
│  │  • Discovery, Ecommerce, Notes, XQueue             │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              MongoDB Atlas (AWS ap-southeast-1)             │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         MongoDB Cluster (M10)                       │   │
│  │  • Forum comments/discussions ONLY                 │   │
│  │  • Database: cs_comments_service                   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Common Questions

### Q: Why do we have MongoDB if MySQL is the main database?

**A:** MongoDB is **ONLY** for the Forum service. The Forum (`cs_comments_service`) was originally built to use MongoDB. Everything else (LMS, CMS, courses, users) uses MySQL.

### Q: Can we use PostgreSQL instead of MySQL?

**A:** Open edX is designed for MySQL. Switching to PostgreSQL would require significant code changes and is not recommended.

### Q: Why MongoDB Atlas instead of running MongoDB in Kubernetes?

**A:** 
- Managed service = automatic backups, updates, monitoring
- Better reliability (no pod restarts, network issues)
- Easier to scale
- Production-grade setup

### Q: What about BigQuery?

**A:** BigQuery is Google's data warehouse. We're not using it yet, but could replace ClickHouse for analytics in the future.

### Q: Do we need all these databases?

**A:** 
- **MySQL:** Essential (main application data)
- **MongoDB:** Essential (forum requires it)
- **Redis:** Essential (caching/sessions)
- **Elasticsearch:** Needed for search features
- **ClickHouse:** Needed for analytics (Aspects)

---

## Database Sizes & Scaling

| Database | Current Size | Scaling Plan |
|----------|--------------|--------------|
| MySQL (Cloud SQL) | ~10GB | Auto-scales disk, can upgrade tier |
| MongoDB Atlas | M10 tier | Can upgrade to M20, M30, etc. |
| Redis | ~1GB | Can increase memory or move to Memorystore |
| Elasticsearch | ~5GB | Can increase storage or move to OpenSearch |
| ClickHouse | ~10GB | Can increase storage |

---

## Backup Strategy

| Database | Backup Method | Retention |
|----------|---------------|-----------|
| MySQL (Cloud SQL) | Automatic daily backups | 7 days |
| MongoDB Atlas | Automatic daily snapshots | 7 days |
| Redis | No backup (cache only) | N/A |
| Elasticsearch | Can rebuild indexes | N/A |
| ClickHouse | Can rebuild from events | N/A |

---

## Migration History

- **2025-11-11:** Migrated MongoDB from in-cluster StatefulSet → MongoDB Atlas
- **Ongoing:** MySQL runs on Cloud SQL (always has in production)

---

## Related Documentation

- [`MONGODB_ATLAS.md`](MONGODB_ATLAS.md) - MongoDB Atlas setup and migration
- [`docs/operations/GCP_ROADMAP.md`](../operations/GCP_ROADMAP.md) - Infrastructure roadmap
- [`analytics/ASPECTS_ANALYTICS.md`](analytics/ASPECTS_ANALYTICS.md) - Analytics setup


