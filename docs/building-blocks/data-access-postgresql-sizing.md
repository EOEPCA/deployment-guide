# Sizing PostgreSQL for Data Access

The Data Access Building Block and its neighbours — the [Resource Discovery](resource-discovery.md) catalogue (pycsw), pgSTAC jobs, and `eoapi-notifier` — all talk to **one** PostgreSQL. By default **no connection pooler (PgBouncer) sits in front of it**: neither the in-chart Crunchy `PostgresCluster` nor a typical external instance. Every client therefore connects directly, and the database's `max_connections` is a single budget shared by all of them.

That budget is easy to blow. Each eoAPI worker keeps its own connection pool, so demand grows with `replicas × workers × pools × pool size`. With the chart's stock defaults a single service can open hundreds of connections; summed across services the total dwarfs a typical `max_connections`.

This guide gives you a **methodology** to compute the peak connection demand for *your* deployment, walks through a **real worked example** (the `eoepca-plus` develop cluster), and shows where each knob lives so you can adjust the defaults to your own hardware and workload.

!!! warning "Compute for your topology"
    There is no single correct value for `max_connections`, pool sizes, or replica counts. The numbers in the worked example are specific to one cluster and one node flavor. Work through the formula with **your** service list, **your** replica/HPA limits, and **your** database resources, then size from there.

---

## When this applies

Connection budgeting matters whenever a single PostgreSQL is shared and no pooler bounds the total — which is the **default** for Data Access:

- The in-chart database (`postgrescluster.enabled: true`) is a Crunchy `PostgresCluster` deployed **without** `spec.proxy.pgBouncer` (the default), so clients connect directly to the primary.
- Or an external / centrally managed database (`postgrescluster.enabled: false`) is shared by several consumers (eoAPI services, pycsw, pgSTAC jobs).
- One or more services may additionally **autoscale** (`autoscaling.enabled: true`, `maxReplicas > 1`), which multiplies demand linearly.

!!! note "There is no automatic safety net"
    Because no PgBouncer is deployed by default, the **database** — not any single service — is the shared constraint. If the sum of all client pools can exceed `max_connections`, you will eventually hit connection exhaustion: under load, during a rolling update, or when several services scale at once. You have two levers: keep the per-service pool caps in sync with `max_connections`, or add a pooler (`spec.proxy.pgBouncer`) to absorb the pressure. Either way, **you** own the budget.

---

## 1. Connection budget formula

Compute the peak connections for each autoscaling eoAPI service, then add fixed estimates for every other client, then compare the total against `max_connections`.

### Per eoAPI service

```text
connections(service) = maxReplicas
                     × WEB_CONCURRENCY        # uvicorn/gunicorn workers per pod
                     × pools_per_worker       # SQLAlchemy/asyncpg pools per worker
                     × DB_MAX_CONN_SIZE       # max connections per pool
```

- **`maxReplicas`**: the HPA upper bound for the service. Use the ceiling, not the average; the database must survive the peak.
- **`WEB_CONCURRENCY`**: number of worker processes per pod. The eoAPI chart default is relatively high (e.g. `10`), and **each worker maintains its own connection pool**.
- **`pools_per_worker`**: usually `1`, but see the transactions note below.
- **`DB_MAX_CONN_SIZE`**: the maximum size of each connection pool (chart default for `stac` is e.g. `5`).

!!! danger "`stac` with transactions opens two pools (2× multiplier)"
    When `ENABLE_TRANSACTIONS_EXTENSIONS: "TRUE"` (set by `ENABLE_TRANSACTIONS=yes` in the configuration script), the `stac` service opens **both a read pool and a write pool per worker**. Use `pools_per_worker = 2` for `stac` in that case. This doubling is a common cause of unexpected exhaustion.

So a single transactions-enabled `stac` service at `maxReplicas=3`, `WEB_CONCURRENCY=10`, `DB_MAX_CONN_SIZE=5` can demand:

```text
3 × 10 × 2 × 5 = 300 connections
```

on its own, before any other service or client is counted.

### Fixed-estimate clients (count every one that applies)

Beyond the autoscaling eoAPI front-ends, the same database is used by a number of other clients. Estimate each and add them to the budget:

| Client | Typical demand | Notes |
| --- | --- | --- |
| **pycsw** (Resource Discovery / resource catalogue) | replicas × workers × pool | Counts only if pycsw shares this database. Cap its pool, see [configuration](#3-where-to-configure-what). |
| **pgSTAC migrate / bootstrap job** | a few, short-lived | Runs on install/upgrade (`pgstacBootstrap`); transient but coincides with deploys. |
| **pgSTAC hook jobs** | a few, short-lived | Post-install/upgrade hooks. |
| **`queueProcessor` CronJob** | a few, periodic | Created when `use_queue: "true"`; runs on its schedule. |
| **`extentUpdater` CronJob** | a few, periodic | Created when `update_collection_extent: "false"`; runs on its schedule. |
| **`eoapi-notifier`** (LISTEN/NOTIFY) | 1+ persistent | Holds long-lived `LISTEN` connection(s) when enabled. Must use a **direct** connection — transaction-mode pooling is incompatible with `LISTEN`, so keep it on the direct `host` even if a PgBouncer is added later. |
| **`geoparquet-exporter`** (periodic batch) | a few, periodic | Runs on its schedule when enabled. |
| **External / direct TCP access** | unbounded ⚠️ | Clients reaching PostgreSQL via a `TLSRoute` or other direct route do **not** respect the chart pool caps. Treat as an unbounded source and reserve headroom. |
| **PostgreSQL internals & monitoring** | several | `superuser_reserved_connections` (default 3), Patroni, pgBackRest, and the pgmonitor exporter (`ccp_monitoring`) each hold connections. |

Sum everything:

```text
total = Σ connections(eoAPI service)
      + pycsw
      + pgSTAC jobs (migrate + hooks)
      + cron jobs (queueProcessor + extentUpdater)
      + notifier
      + external/direct access
      + Postgres internals + monitoring
```

Your deployment is safe only when `total + rolling-update headroom ≤ max_connections`.

---

## 2. When to cap client pools vs. raise `max_connections`

Once you have the total, you can either **reduce demand** (cap client pools / `WEB_CONCURRENCY` / `maxReplicas`) or **increase supply** (raise `max_connections`). Usually you need a bit of both. The trade-offs:

### Raising `max_connections` is not free

Each connection is a backend process with memory cost. The two parameters that scale with concurrency:

- **`work_mem`**: allocated *per sort/hash operation*, so peak memory roughly scales with `work_mem × concurrent operations`. Many connections running complex queries multiply this quickly.
- **`maintenance_work_mem` × `autovacuum_max_workers`**: autovacuum/maintenance memory is reserved per worker and is independent of client connections, but competes for the same RAM.

If you raise `max_connections`, confirm the database pod/host has memory to back it: `shared_buffers` + (`work_mem` × expected concurrency) + (`maintenance_work_mem` × `autovacuum_max_workers`) + per-connection overhead must fit comfortably within the **memory request/limit** of the PostgreSQL pod (or the host's RAM for an external server). Setting `max_connections` high without backing memory trades connection errors for OOM kills.

### Reserve headroom you cannot use for clients

- **`superuser_reserved_connections`**: connections reserved for superusers; subtract from the usable budget.
- **Rolling-update doubling**: during a Deployment rolling update, new pods start **before** old pods terminate, so a service can briefly run close to `2× replicas`. Size headroom for at least the largest service doubling, ideally concurrent rollouts.
- **CronJob / job spikes**: `queueProcessor`, `extentUpdater`, and pgSTAC migrate/hook jobs can fire while services are at peak. Their connections are short-lived but real.

### Rule of thumb

Prefer **capping client pools** (lower `DB_MAX_CONN_SIZE`, `WEB_CONCURRENCY`, or `maxReplicas`) when the database hardware is fixed or shared with other tenants, it makes demand predictable. Prefer **raising `max_connections`** only when you control the database and can back the extra connections with memory. Always leave headroom for rolling updates and job spikes rather than sizing to the steady-state sum.

---

## 3. Where to configure what

Sizing spans three ownership boundaries. Set the right knob in the right place.

### eoAPI values (per service)

In `eoapi/generated-values.yaml`, under each service (`stac`, `raster`, `vector`, `multidim`), set explicit pool caps rather than relying on defaults:

```yaml
stac:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5             # the ceiling that multiplies everything below
    type: "cpu"
    targets:
      cpu: 50
  settings:
    envVars:
      WEB_CONCURRENCY: "2"      # workers per pod (lower than the chart default)
      DB_MIN_CONN_SIZE: "1"     # min connections per pool
      DB_MAX_CONN_SIZE: "3"     # max connections per pool, the hard cap per worker
```

With transactions enabled, `stac` opens a read **and** a write pool per worker, so each replica costs `2 workers × 2 pools × 3 = 12` connections. Apply explicit caps to every service and keep `maxReplicas` in the budget. See the eoapi-k8s documentation for the authoritative parameter list:

- [eoapi-k8s autoscaling](https://github.com/developmentseed/eoapi-k8s/blob/main/docs/autoscaling.md)
- [eoapi-k8s configuration options](https://github.com/developmentseed/eoapi-k8s/blob/main/docs/configuration.md)

### PostgresCluster spec / external DBA

`max_connections`, `autovacuum_max_workers`, `shared_buffers`, and `work_mem` live on the database, not in the eoAPI chart. For a Crunchy `PostgresCluster` they go under `spec.patroni.dynamicConfiguration.postgresql.parameters`; for an external/centrally managed instance, coordinate with the DBA. Whoever owns the database must:

- Set `max_connections` to cover the computed total plus headroom.
- Ensure the pod **memory request/limit** (or host RAM) backs that connection count and the maintenance/work memory derived from it.
- Keep `autovacuum_max_workers` sane relative to available memory.

### pycsw (Resource Discovery / resource catalogue)

If the [Resource Discovery](resource-discovery.md) catalogue shares this database, its pycsw workers add to the budget. Cap its worker/pool count rather than leaving it open-ended. Reference the worker cap configuration in the [rm-resource-catalogue Helm chart](https://github.com/EOEPCA/rm-resource-catalogue) (once the documented worker cap is available) and count it in your total.

### Unbounded sources to call out

Some clients **ignore** the chart pool caps and must be reasoned about separately:

- **Direct TCP / external routes** (e.g. a `TLSRoute` exposing PostgreSQL), any external tool opening its own connections. Bound these with a dedicated PgBouncer or a per-route connection limit, or reserve fixed headroom.
- **Ad-hoc clients** (psql sessions, ETL tools, dashboards) that connect directly rather than through a pooled service.

---

## 4. Worked example — the `eoepca-plus` develop cluster

!!! info "Illustrative only"
    These numbers are specific to one cluster (one autoscaling service plus single-replica services, one node flavor). They show how the formula and the database parameters fit together. Substitute your own service list, replica/HPA limits, and database size.

### Why the chart defaults overflow

Left at the chart defaults, `stac` alone is dangerous. With the transaction extension (two pools per worker), `WEB_CONCURRENCY` up to the CPU-core count, and `DB_MAX_CONN_SIZE = 10`, five replicas demand:

```text
stac = 5 replicas × 10 workers × 2 pools × 10 conns = 1 000 connections
```

— ten times a typical `max_connections = 100`, before any other client is counted. The develop cluster therefore **pins explicit caps** on every service rather than trusting the defaults.

### A tuned mixed-scaling deployment

The develop cluster pins explicit pool caps on every service and connects directly to the primary. Only `stac` autoscales — it runs `minReplicas: 2`, `maxReplicas: 5` on a 50% CPU target with `WEB_CONCURRENCY = 2` and `DB_MAX_CONN_SIZE = 3` (and, with transactions enabled, a read **and** a write pool per worker). The other services stay at a single replica with `DB_MAX_CONN_SIZE = 5`.

Because `stac` scales, the budget is a range. The table below shows the **worst case** — `stac` at `maxReplicas = 5` — against `max_connections = 100`:

| Client | Connections (stac at max scale) |
| --- | --- |
| `stac` (5 pods × 2 workers × read+write pool × 3) | 60 |
| `raster` (1 pod × 1 worker × 5) | 5 |
| `vector` (1 pod × 1 worker × 5) | 5 |
| `multidim` (1 pod × 1 worker × 5) | 5 |
| `eoapi-notifier` | 1 |
| pycsw core + protected | ~10 |
| monitoring exporter + Patroni | ~3 |
| `superuser_reserved_connections` (default) | 3 |
| **Persistent peak** | **~92** |
| `pgstac-queueProcessor` / `extentUpdater` / `geoparquet-exporter` (periodic) | ~10 (burst) |
| pgSTAC Helm hooks (`pgstacMigrate`, …) | ~5 (burst) |
| **Peak with a CronJob or hook firing at max scale** | **~96–100+** |

At the normal `minReplicas = 2` the `stac` term is only `2 × 2 × 2 × 3 = 24`, so the persistent total sits around ~56 — comfortably inside `max_connections = 100`. But when `stac` scales to five replicas under load the persistent peak reaches ~92, and a CronJob or pgSTAC hook firing in that window can brush — or briefly exceed — 100. **This is a deliberately tight budget.** It is held in check not by spare headroom but by the HPA CPU target (which only scales `stac` up under real load) and the 80% connection-utilisation alert (see [§5](#5-monitoring)); a rolling `stac` restart at max scale temporarily doubles its pods, so those two controls, not raw headroom, are what keep the database inside its limit.

!!! warning "Sources not bounded by the per-service caps"
    - **`stac` autoscaling** — each extra replica adds `2 × 2 × 3 = 12` connections; `maxReplicas` is the real ceiling, keep it in the arithmetic.
    - **pycsw** — gunicorn workers are not pinned in the current Helm values (estimated ~10; see [§3 pycsw](#3-where-to-configure-what)).
    - **pgSTAC CronJobs / hooks** — burst connections bounded by job runtime, not strictly capped.
    - **Any client that bypasses a cap** — raising `WEB_CONCURRENCY`/`DB_MAX_CONN_SIZE`/`maxReplicas` without updating the budget, or adding a new service, can silently exhaust connections.

### Sizing the database to that budget

The develop worker nodes use the CloudFerro `eo2a.3xlarge` flavor — **16 vCPU, 64 GiB RAM**. The PostgreSQL pod is scheduled against its **requests** (2 CPU / 16 Gi) and may burst to its **limits** (8 CPU / 32 Gi); the rest of the node stays free for co-resident workloads.

!!! note "GiB vs GB"
    OpenStack reports RAM in GiB, and PostgreSQL parses `GB` in `postgresql.conf` as GiB. The arithmetic below is internally consistent on that basis.

Memory parameters are sized against the pod **limit** (32 Gi), the cgroup ceiling that includes the OS page cache:

| Parameter | Value | Reason |
| --- | --- | --- |
| `max_connections` | 100 | Covers the ~92 max-scale persistent peak; headroom is intentionally thin and guarded by the 80% alert |
| `shared_buffers` | 8 GB | Real startup allocation; 25% of the 32 Gi limit. Fits inside the 16 Gi request, leaving ~8 Gi for backends, WAL writer, and OS |
| `effective_cache_size` | 24 GB | Planner hint only (no allocation); 75% of the 32 Gi limit, since inside a cgroup the page cache counts against the limit |
| `work_mem` | 64 MB | Per sort/hash node; even at the ~92-connection ceiling only a fraction run sort/hash nodes at once, so aggregate `work_mem` stays within the limit |
| `maintenance_work_mem` | 2 GB | Per autovacuum/`VACUUM` worker; 3 × 2 GB = 6 GB stays within the limit alongside `shared_buffers` |
| `autovacuum_max_workers` | 3 | Pinned so concurrent autovacuum × `maintenance_work_mem` is deterministic |
| `temp_buffers` | 256 MB | Per-session temp-table buffer, allocated lazily |
| `random_page_cost` | 1.1 | Low random-access penalty on NFS-backed SSD |
| `max_locks_per_transaction` | 128 | Default (64) is too low for pgSTAC/PostGIS schemas with many partitions and spatial indexes |

The pod **resources** follow directly from those parameters:

| | Request | Limit | Reasoning |
| --- | --- | --- | --- |
| **Memory** | 16 Gi | 32 Gi | Request covers `shared_buffers` (8 GB) + ~8 Gi baseline overhead. Limit adds the concurrency-bound consumers: 3 × `maintenance_work_mem` (6 GB) plus peak `work_mem`/`temp_buffers`, all bounded by the ~92-connection budget. |
| **CPU** | 2 | 8 | Request guarantees a baseline; limit allows bursting to ~50% of the node for heavy vacuum or analytical queries. |

The connection budget is what keeps the variable consumers (`work_mem`, `temp_buffers`) inside the memory limit. **Raising per-service pool caps or `maxReplicas` without re-checking this arithmetic** can turn connection errors into OOM kills — change the budget table, `max_connections`, and the pool caps together.

---

## 5. Monitoring

Compute-time budgeting is necessary but not sufficient, alert on **actual** connection usage so you catch drift, leaks, and unplanned clients.

If the eoAPI monitoring stack (`eoapi-support`) or Crunchy pgmonitor is deployed, alert on the ratio of in-use to maximum connections. With the Crunchy pgmonitor exporter, the relevant metrics are:

```promql
# Fraction of max_connections currently in use
ccp_connection_stats_total / ccp_connection_stats_max_connections
```

The `eoepca-plus` develop cluster ships a `PostgresConnectionsHigh` alert built on exactly this ratio:

```promql
(ccp_connection_stats_total / ccp_connection_stats_max_connections) > 0.8
for: 10m   # severity: warning
```

It fires when more than 80% of `max_connections` is in use for 10 consecutive minutes, leaving headroom to react before exhaustion. Suggested practice for your own deployment:

- **Warning** when sustained usage crosses a high-water mark (e.g. ~75–80% of `max_connections`).
- **Critical** as it approaches saturation (e.g. ~90%), before clients start receiving connection errors.
- Watch the metric **during rolling updates and CronJob windows**, that is when transient spikes push usage toward the ceiling.

For deployments without pgmonitor, any equivalent exporter (e.g. `postgres_exporter`'s `pg_stat_activity` count vs. `pg_settings_max_connections`) works the same way.
