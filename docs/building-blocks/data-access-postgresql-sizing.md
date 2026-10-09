# Sizing PostgreSQL for Data Access

Every Data Access client shares one PostgreSQL `max_connections` budget (PostgreSQL default: `100`). That includes the eoAPI services (`stac`, `raster`, `vector`, `multidim`), the pgSTAC bootstrap jobs, `eoapi-notifier`, and the [Resource Discovery](resource-discovery.md) catalogue (pycsw) if it uses the same database.

Nothing pools these connections for you. The in-cluster Crunchy `PostgresCluster` does run a PgBouncer (`pgBouncerReplicas: 1`), but the eoAPI chart connects every service to the primary through the `host` key of the `eoapi-pguser-eoapi` secret, so PgBouncer never sees that traffic. External databases usually have no pooler at all. Either way, you have to keep the total within budget yourself.

## Connection budget

Each eoAPI pod runs `WEB_CONCURRENCY` worker processes, and each worker keeps its own pool of up to `DB_MAX_CONN_SIZE` connections:

```text
connections(service) = replicas × WEB_CONCURRENCY × pools × DB_MAX_CONN_SIZE
```

- **`replicas`**: use `autoscaling.maxReplicas` if the service autoscales, because the database has to survive the peak.
- **`pools`**: `1`, except for `stac` with transactions enabled (`ENABLE_TRANSACTIONS=yes`, which sets `ENABLE_TRANSACTIONS_EXTENSIONS`). It then opens a separate read pool and write pool per worker, so `pools = 2`.

Then add the other clients:

| Client | Demand |
| --- | --- |
| pgSTAC bootstrap / migrate jobs | A few, short-lived, on every install/upgrade |
| `queueProcessor` / `maintenance` CronJobs | A few, on schedule; only if `use_queue: "true"`, `update_collection_extent: "scheduled"` or `analyze: scheduled\|both` |
| `eoapi-notifier` (if enabled) | 1+ persistent `LISTEN` connection |
| pycsw (if it shares the database) | replicas × workers × pool size |
| PostgreSQL internals | `superuser_reserved_connections` (3), Patroni, pgBackRest, metrics exporter |
| Direct access (`psql`, ETL tools, a `TLSRoute`) | Unbounded, so reserve headroom |

The total plus headroom must fit within `max_connections`. Headroom has to cover two things:

- **Rolling updates.** New pods start before old ones stop, so the service being rolled briefly runs at up to 2× its replicas.
- **Jobs.** These can fire while the services are at peak.

### Pool caps set by this guide

The defaults of the eoAPI chart deployed here (0.17.2) already exceed a `max_connections` of 100: uncapped, **a single replica** of each service could open 164 connections. The deployment script therefore caps every service at `WEB_CONCURRENCY: "2"` and `DB_MAX_CONN_SIZE: "3"`:

| Service (1 replica) | Uncapped | Capped |
| --- | --- | --- |
| `stac` (transactions on) | 10 × 2 × 5 = 100 | 2 × 2 × 3 = 12 |
| `raster` | 4 × 3 = 12 | 2 × 3 = 6 |
| `vector` | 8 × 5 = 40 | 2 × 3 = 6 |
| `multidim` | 4 × 3 = 12 | 2 × 3 = 6 |
| **Total** | **164** | **30** |

To change the caps or enable autoscaling, edit `scripts/data-access/eoapi/values-template.yaml` or pass an extra `--values` file to `helm upgrade`. Don't edit `eoapi/generated-values.yaml`, because `configure-data-access.sh` overwrites it. To scale, prefer more replicas over more workers per pod, and recompute the budget whenever you change `maxReplicas`.

## Cap clients or raise `max_connections`?

- **Cap clients** (`DB_MAX_CONN_SIZE`, `WEB_CONCURRENCY`, `maxReplicas`) when the database is shared or its hardware is fixed. This keeps demand predictable.
- **Raise `max_connections`** only if you control the database and can back the extra connections with memory. `shared_buffers`, plus `work_mem` × concurrent sort/hash operations, plus `maintenance_work_mem` × `autovacuum_max_workers` must fit within the PostgreSQL pod's memory limit. Otherwise you trade connection errors for OOM kills.

For the in-cluster database, set parameters in the eoAPI values. Changing `max_connections` restarts PostgreSQL:

```yaml
postgrescluster:
  patroni:
    dynamicConfiguration:
      postgresql:
        parameters:
          max_connections: 200
          shared_buffers: 2GB
          work_mem: 32MB
```

For an external database, agree these values with its DBA. For autoscaling against a shared database, see the eoapi-k8s guide on [External / shared PostgreSQL](https://github.com/developmentseed/eoapi-k8s/blob/main/docs/autoscaling.md#external--shared-postgresql).

## Worked example

!!! info "Illustrative only"
    This example comes from the `eoepca-plus` develop cluster. Substitute your own services, replica limits and database size.

In this cluster, `stac` autoscales between 2 and 5 replicas (`WEB_CONCURRENCY=2`, `DB_MAX_CONN_SIZE=3`, transactions on). `raster`, `vector` and `multidim` each run one replica with one worker and `DB_MAX_CONN_SIZE=5`, and pycsw shares the database.

| Client | Connections at `stac` max scale |
| --- | --- |
| `stac` (5 × 2 × 2 × 3) | 60 |
| `raster` + `vector` + `multidim` (3 × 1 × 1 × 5) | 15 |
| `eoapi-notifier` | 1 |
| pycsw | ~10 |
| Exporter + Patroni | ~3 |
| `superuser_reserved_connections` | 3 |
| **Persistent peak** | **~92** |
| + CronJobs / pgSTAC hooks firing | ~107 |

With `stac` at `minReplicas`, the total is ~56. At maximum scale, `max_connections = 100` is deliberately tight: a job firing at peak, or a rolling restart of five `stac` pods, can exceed it. The cluster accepts that risk and relies on the HPA CPU target and the alert below. If you can't accept it, lower `stac` `maxReplicas` or raise `max_connections`.

The database is sized to that budget. The PostgreSQL pod requests 2 CPU / 16 Gi and is limited to 8 CPU / 32 Gi:

| Parameter | Value | Reason |
| --- | --- | --- |
| `max_connections` | 100 | Covers the ~92 persistent peak |
| `shared_buffers` | 8GB | 25% of the 32 Gi limit |
| `effective_cache_size` | 24GB | Planner hint only: 75% of the limit |
| `work_mem` | 64MB | Per sort/hash node; only a fraction of connections sort at once |
| `maintenance_work_mem` × `autovacuum_max_workers` | 2GB × 3 | Bounds autovacuum memory to 6 GB |
| `max_locks_per_transaction` | 128 | pgSTAC partitions and PostGIS indexes exceed the default of 64 |

## Monitoring

Alert on actual usage to catch drift and clients you didn't plan for. Use the Crunchy pgmonitor exporter, enabled with `postgrescluster.monitoring: true` (this guide deploys with `false`):

```promql
# warning for 10m; add a critical alert at ~0.9
ccp_connection_stats_total / ccp_connection_stats_max_connections > 0.8
```

With `postgres_exporter`, use `sum(pg_stat_activity_count) / pg_settings_max_connections` instead. Watch usage closely during rolling updates and job runs, when spikes happen.
