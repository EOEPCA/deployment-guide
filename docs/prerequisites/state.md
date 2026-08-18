# EOEPCA+ State

Deployment scripts read and write a shared config file at `~/.eoepca/state`, sourced by every script via `scripts/common/utils.sh`. Values set once (ingress domain, storage class, etc.) carry over to every Building Block deployed afterwards.

There's no separate init command. If `~/.eoepca/state` is missing `HTTP_SCHEME`/`INGRESS_CLASS`, the next script you run triggers first-time setup before doing anything else.

---

## First Run

Prompts, in order:

| Variable | Prompt | Default |
| --- | --- | --- |
| `HTTP_SCHEME` | HTTP scheme for EOEPCA services (`http`/`https`) | `https` |
| `INGRESS_CLASS` | Ingress class (`apisix`/`nginx`) | `apisix` |
| `INGRESS_HOST` | Base domain name | `example.com` |
| `PERSISTENT_STORAGECLASS` | StorageClass for `ReadWriteOnce` data | `local-path` |
| `USE_CERT_MANAGER` | Automatic cert issuance via cert-manager? (yes/no) | |
| `CLUSTER_ISSUER` | ClusterIssuer name (only if `USE_CERT_MANAGER=yes`) | `letsencrypt-http01-apisix` |

These are shared across BBs, so they're asked once. Each BB's own `configure-<bb>.sh` still asks its own questions on top (client IDs, sizing, feature toggles).

---

## Later Runs

Already-set variables prompt instead of asking fresh:

```
INGRESS_HOST is already set to 'example.com'. Do you want to update it? (y/n)
```

Answer `n` to keep the current value.

---

## Resetting

Delete `~/.eoepca/state` to start over. If changing `INGRESS_CLASS`, also delete `~/.eoepca/annotations.yaml`.
