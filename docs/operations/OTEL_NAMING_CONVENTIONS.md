# OpenTelemetry Naming Conventions

_Last updated: 2026-02-24_

This document is the authoritative naming contract for all OpenTelemetry metrics and traces
produced by Mereka LMS services. Dashboards, alerts, and exporters **must** reference only names
listed in the registry (`infrastructure/monitoring/otel-metric-registry.yaml`). The verification
script (`scripts/qa/verify-otel-naming.sh`) enforces this contract automatically.

---

## Metric Naming

### Format

```
mereka.lms.<service>.<metric_name>
```

- All segments are lowercase, dot-separated.
- `<service>` is the short service identifier (see Reserved Namespaces below).
- `<metric_name>` uses underscores within a segment: `request_duration_seconds`.
- No consecutive dots, no trailing dot, no uppercase letters.

### Examples

| Metric | Service | Description |
|---|---|---|
| `mereka.lms.caddy.request_duration_seconds` | caddy | HTTP request latency histogram |
| `mereka.lms.caddy.request_total` | caddy | Total HTTP requests (counter) |
| `mereka.lms.openedx.active_users` | openedx | Concurrent authenticated sessions |
| `mereka.lms.openedx.celery_task_duration_seconds` | openedx | Celery task execution time |
| `mereka.lms.forum.request_duration_seconds` | forum | Forum API response latency |
| `mereka.lms.meilisearch.query_duration_seconds` | meilisearch | Search query latency |
| `mereka.lms.mysql.query_duration_seconds` | mysql | DB query execution time |
| `mereka.lms.mysql.connection_pool_active` | mysql | Active DB connections (gauge) |
| `mereka.lms.redis.cache_hit_ratio` | redis | Cache hit-to-total ratio (gauge) |
| `mereka.lms.redis.connected_clients` | redis | Active Redis client connections |

### Metric Types

| Type | Suffix convention | Use for |
|---|---|---|
| `counter` | `_total` (optional but preferred) | Monotonically increasing counts |
| `gauge` | no suffix or `_ratio`, `_active`, `_count` | Values that go up and down |
| `histogram` | `_seconds`, `_bytes`, `_duration_seconds` | Latency, size distributions |

### Units

Follow OpenTelemetry semantic conventions:

- Duration: always in **seconds** (`_seconds` suffix).
- Memory/data size: always in **bytes** (`_bytes` suffix).
- Ratios: dimensionless float in `[0, 1]`.
- Counts: dimensionless integer.

---

## Trace / Span Naming

### Format

```
<service>/<operation>
```

- `<service>` matches the service segment used in metrics (e.g., `caddy`, `openedx`).
- `<operation>` is a short, lowercase, underscore-separated description of the work performed.
- Forward slash separates service from operation — not a dot, not a colon.

### Examples

| Span Name | Meaning |
|---|---|
| `caddy/handle_request` | Caddy processing an inbound HTTP request |
| `openedx/course_grade_update` | LMS recalculating a learner's course grade |
| `openedx/celery_task_execute` | A Celery worker running a task |
| `forum/post_create` | Forum service creating a new post |
| `meilisearch/search_query` | Meilisearch executing a search request |
| `mysql/query_execute` | MySQL running a SQL statement |
| `redis/cache_get` | Redis GET operation |

### Span Attributes

Follow [OpenTelemetry semantic conventions](https://opentelemetry.io/docs/specs/semconv/) where applicable:

| Attribute | Semantic convention key | Example value |
|---|---|---|
| HTTP method | `http.request.method` | `GET` |
| HTTP status code | `http.response.status_code` | `200` |
| DB system | `db.system` | `mysql` |
| DB statement | `db.statement` | `SELECT ...` (sanitized) |
| RPC service | `rpc.service` | `openedx.grades` |
| Error flag | `error` | `true` |
| Service name | `service.name` | `caddy` |
| K8s namespace | `k8s.namespace.name` | `mereka-lms` |
| K8s pod name | `k8s.pod.name` | `caddy-7d9f8b-xr4wz` |

---

## Reserved Namespaces

Each namespace is owned by a single service team. Adding a metric to a namespace requires
updating the registry file.

| Namespace | Service | Owner |
|---|---|---|
| `mereka.lms.caddy.*` | Caddy reverse proxy | Platform |
| `mereka.lms.openedx.*` | Open edX LMS + CMS + workers | LMS |
| `mereka.lms.forum.*` | openedx-forum service | LMS |
| `mereka.lms.meilisearch.*` | Meilisearch | Platform |
| `mereka.lms.mysql.*` | Cloud SQL / MySQL exporter | Platform |
| `mereka.lms.redis.*` | Redis | Platform |
| `mereka.lms.discovery.*` | Open edX Discovery | LMS |
| `mereka.lms.ecommerce.*` | Purchase Gateway / Ecommerce | LMS |

---

## Dashboard Contract

Every metric name referenced in a Grafana dashboard JSON under
`infrastructure/monitoring/dashboards/` **must** appear in the registry:

```
infrastructure/monitoring/otel-metric-registry.yaml
```

The contract is verified by:

```bash
./scripts/qa/verify-otel-naming.sh
```

The script exits 0 if all checks pass, 1 if any violation is found.

**Adding a new metric:**

1. Add an entry to `infrastructure/monitoring/otel-metric-registry.yaml`.
2. Instrument the service to emit the metric using the approved name.
3. Run `./scripts/qa/verify-otel-naming.sh` to confirm compliance.
4. Reference the metric in a dashboard or alert.

---

## Registry File Format

The registry lives at `infrastructure/monitoring/otel-metric-registry.yaml`.

```yaml
metrics:
  - name: mereka.lms.caddy.request_duration_seconds
    type: histogram        # counter | gauge | histogram
    unit: seconds
    description: "HTTP request processing time measured at the Caddy reverse proxy."
    service: caddy
```

Fields:

| Field | Required | Values |
|---|---|---|
| `name` | yes | Must match `mereka\.lms\.<service>\.<metric>` |
| `type` | yes | `counter`, `gauge`, or `histogram` |
| `unit` | yes | `seconds`, `bytes`, `ratio`, `requests`, `connections`, `tasks`, `none` |
| `description` | yes | Human-readable, max ~120 chars |
| `service` | yes | Must match a reserved namespace segment |

---

## Compliance Checklist

Before shipping a new service or dashboard:

- [ ] All metric names start with `mereka.lms.<service>.`
- [ ] All metric names exist in `otel-metric-registry.yaml`
- [ ] Histograms use `_seconds` or `_bytes` suffix
- [ ] Span names follow `<service>/<operation>` pattern
- [ ] Span attributes use OTel semantic convention keys
- [ ] `verify-otel-naming.sh` exits 0 with no FAIL lines
