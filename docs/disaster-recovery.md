# Disaster recovery plan

Building AI Infrastructure, Part 7: "When something big fails."

> A recovery plan only counts after you have tested it. Write the RTO/RPO targets, then run the drill. Until then, it's a hope, not a plan.

## Pattern: active-passive (start here)

The fleet is **not** active-active for the application data plane (see [ARCHITECTURE.md](../ARCHITECTURE.md)). One cluster serves production traffic, and a standby on another provider can take over.

| Role | Cluster | Notes |
| --- | --- | --- |
| Primary | `prod-aks` (Azure) | Serves traffic |
| Standby | `staging-gke` (GCP), or a dedicated `dr-*` cluster | Reconciled from the same Git repo, so its platform layer is always current |
| Optional | `onprem-openshift` | For data that may not leave the building |

Why active-passive: it's simpler and cheaper, and it covers a full region or provider outage. Active-active (global load balancing plus continuous data sync) recovers fastest, but it's the hardest and most expensive to build and run. Only move to it when the business case for a lower RTO justifies that cost.

## Targets

Fill these in with the service owner and get them signed off.

| Service | RTO (max downtime) | RPO (max data loss) | Data to recover |
| --- | --- | --- | --- |
| `rag-api` | _e.g. 1 h_ | n/a (stateless) | Nothing; redeployed from Git |
| Vector DB (Qdrant) | _e.g. 4 h_ | _e.g. 24 h_ | Snapshots in object storage (`helm/charts/vector-db` backup CronJob) |
| MLflow registry | _e.g. 8 h_ | _e.g. 24 h_ | Postgres backup + artifact bucket |
| Source documents | _e.g. 8 h_ | _e.g. 1 h_ | Object storage with cross-region / cross-cloud replication |

## What makes failover possible

1. **Platform from Git.** Every cluster reconciles from `flux/clusters/<name>` (or `argocd/clusters/<name>`). The standby already runs the same controllers, policies, observability and app versions.
2. **Data copied on a schedule.** The vector DB snapshots and the MLflow backups land in object storage that is replicated outside the primary's provider.
3. **Traffic switch.** DNS with a health-checked failover record (low TTL), or a global load balancer.
4. **Same SLOs and runbooks everywhere,** so whoever is on call knows the standby the same way they know the primary.

## Failover runbook (outline)

1. Declare the incident and confirm the primary is down for longer than the RTO allows (see [incident runbooks](runbooks/)).
2. Scale up the standby app layer by merging the prepared PR that raises replicas under `flux/clusters/<standby>/apps.yaml`.
3. Restore the latest vector DB snapshot and MLflow backup into the standby.
4. Run smoke tests: `/readyz`, plus a known query with a known answer.
5. Switch DNS or the global load balancer to the standby.
6. Watch the SLO dashboards for one full burn-rate window.
7. Fail back later, during a planned window, using the same steps in reverse.

## Drill schedule

| When | Drill | Pass criteria |
| --- | --- | --- |
| Quarterly | Restore a vector DB snapshot into a scratch namespace | Restore completes within the RTO; spot-check queries match |
| Twice a year | Full failover to the standby during a maintenance window | Traffic served from the standby within the RTO; data loss within the RPO |
| Monthly | `scripts/chaos/` failure injection | SLOs hold |

Record every drill: date, the times you measured, what broke, and the follow-up PRs. If you can't show when it was last tested, the plan doesn't count.
