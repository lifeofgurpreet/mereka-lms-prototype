# OpenEdX Memory Optimization Plan

## Current State (48GB VPS)

| Component | Current Memory | Workers | Notes |
|-----------|---------------|---------|-------|
| LMS uwsgi | ~17GB | 2 | 8.5GB per worker! |
| Ecommerce uwsgi | ~8.4GB | 2 | Using LocMemCache (fixed) |
| Discovery uwsgi | ~8.4GB | 1 | Was crashing, now stable |
| CMS Celery | ~3.9GB | 13 | Excessive workers |
| LMS Celery | ~3.8GB | 13 | Excessive workers |
| Elasticsearch | ~1.4GB | 1 | -Xms1g -Xmx1g |
| MySQL | ~440MB | 1 | |
| K8s overhead | ~1GB | - | API server, etcd, etc |
| Other services | ~2GB | - | MongoDB, Redis, MFE, etc |
| **TOTAL** | **~41GB** | | 85% of 48GB |

---

## Completed Fixes

- [x] Ecommerce: Added Redis cache (was LocMemCache)
- [x] uwsgi: Added `lazy-apps=true`, `max-requests=1000`, `reload-on-rss=2048`
- [x] Discovery: Reduced to 1 worker, added resource limits

---

## Phase 1: Quick Wins (No Service Disruption)

### 1.1 Reduce LMS/CMS uwsgi workers: 2 → 1
**Savings: ~8.5GB**

```bash
# Set environment variable in deployment
kubectl set env deployment/lms UWSGI_WORKERS=1 -n mereka-lms
kubectl set env deployment/cms UWSGI_WORKERS=1 -n mereka-lms
```

### 1.2 Reduce Celery workers: 13 → 2
**Savings: ~6GB**

Edit the worker deployments to use `--concurrency=2`:
```bash
# LMS worker
kubectl patch deployment lms-worker -n mereka-lms --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
    "celery", "--app=lms.celery", "worker", "--loglevel=info",
    "--hostname=edx.lms.core.default.%h",
    "--queues=edx.lms.core.default,edx.lms.core.high,edx.lms.core.high_mem",
    "--concurrency=2", "--max-tasks-per-child=100"
  ]}
]'

# CMS worker
kubectl patch deployment cms-worker -n mereka-lms --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
    "celery", "--app=cms.celery", "worker", "--loglevel=info",
    "--hostname=edx.cms.core.default.%h",
    "--queues=edx.cms.core.default,edx.cms.core.high,edx.cms.core.low",
    "--concurrency=2", "--max-tasks-per-child=100"
  ]}
]'
```

### 1.3 Add resource limits to all deployments
**Prevents OOM cascade**

| Deployment | Memory Request | Memory Limit |
|------------|---------------|--------------|
| lms | 2Gi | 4Gi |
| cms | 2Gi | 4Gi |
| lms-worker | 512Mi | 1Gi |
| cms-worker | 512Mi | 1Gi |
| ecommerce | 1Gi | 2Gi |
| ecommerce-worker | 256Mi | 512Mi |
| discovery | 4Gi | 12Gi (already set) |
| elasticsearch | 1Gi | 2Gi |
| mysql | 512Mi | 1Gi |
| mongodb | 256Mi | 512Mi |
| redis | 128Mi | 256Mi |
| mfe | 128Mi | 256Mi |
| caddy | 64Mi | 128Mi |
| forum | 256Mi | 512Mi |
| notes | 128Mi | 256Mi |
| xqueue | 256Mi | 512Mi |
| smtp | 32Mi | 64Mi |

**Phase 1 Total Savings: ~14.5GB** → System would use ~26.5GB

---

## Phase 2: Optional Service Review

### Questions to answer:

1. **Do you need Ecommerce?** (course purchases, payments)
   - If NO → disable, save ~8GB

2. **Do you need Discovery?** (course catalog API, program management)
   - If NO → disable, save ~8GB

3. **Do you need Forum?** (discussion boards)
   - If NO → disable, save ~200MB

4. **Do you need Notes?** (student notes feature)
   - If NO → disable, save ~200MB

5. **Do you need XQueue?** (external graders)
   - If NO → disable, save ~200MB

### To disable a service:
```bash
kubectl scale deployment/<service> --replicas=0 -n mereka-lms
```

---

## Phase 3: Architecture Changes (Long-term)

### 3.1 Replace Elasticsearch with Meilisearch
- Meilisearch uses ~50MB vs Elasticsearch's ~1.4GB
- Tutor has meilisearch plugin: `pip install tutor-meilisearch`
- **Savings: ~1.3GB**

### 3.2 Move databases to managed services
- MySQL → Cloud SQL (GCP) or RDS (AWS)
- MongoDB → MongoDB Atlas (already using for prod?)
- **Savings: ~1GB + better reliability**

### 3.3 Consider splitting workloads
- Run LMS on dedicated node
- Run workers on separate node
- Better resource isolation

---

## Recommended Execution Order

1. **Immediate** (Phase 1.1): Reduce uwsgi workers → saves 8.5GB
2. **Immediate** (Phase 1.2): Reduce Celery workers → saves 6GB
3. **This week** (Phase 1.3): Add resource limits
4. **Evaluate** (Phase 2): Review which services you actually need
5. **Later** (Phase 3): Architecture improvements

---

## Monitoring Commands

```bash
# Memory by process
ps aux --sort=-%mem | head -20

# Overall memory
free -h

# K8s pod memory
kubectl top pods -n mereka-lms

# Watch memory over time
watch -n 5 'free -h && echo "---" && ps aux --sort=-%mem | head -10'
```

---

## Expected Final State

After Phase 1 + disabling unused services:

| Scenario | Memory Used | Headroom |
|----------|-------------|----------|
| Current | 41GB | 7GB (14%) |
| Phase 1 only | ~26GB | 22GB (46%) |
| Phase 1 + no ecommerce | ~18GB | 30GB (62%) |
| Phase 1 + no ecommerce + no discovery | ~10GB | 38GB (79%) |

---

## References

- [Tutor Scaling Guide](https://docs.tutor.edly.io/tutorials/scale.html)
- [OpenEdX Production Guidelines](https://edx.readthedocs.io/projects/edx-installing-configuring-and-running/)
- [uWSGI Memory Management](https://uwsgi-docs.readthedocs.io/en/latest/ThingsToKnow.html)
