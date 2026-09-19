# Architecture Decisions

## Region Pair: ap-south-2 (primary) + ap-south-1 (secondary)

**Why:** Project 1's existing infrastructure already runs in ap-south-2
(Hyderabad) — kept as-is rather than migrated, to avoid touching a working
project. ap-south-1 (Mumbai) is the natural DR pair: same country (low
replication latency), and AWS RDS cross-region read replicas are fully
supported between these two regions.

## RDS Cross-Region Read Replica, not Aurora Global Database

**Why:** Standard RDS PostgreSQL supports cross-region read replicas
natively — no engine migration required from Project 1's existing
`postgres` RDS instance. Aurora Global Database offers faster failover
but requires migrating to the Aurora engine, which is out of scope for
a 5-7 day project building on existing infrastructure.

**Trade-off:** RDS cross-region replica failover is manual (promote the
replica) rather than Aurora's faster automated failover. This is
measured, not assumed — see the failover drill results later in this
project for the real RTO this trade-off produces.

## VPC CIDR Plan (avoiding overlap between regions)

- Primary (ap-south-2): 10.0.0.0/16 (existing, unchanged)
- Secondary (ap-south-1): 10.1.0.0/16 (new, non-overlapping)

Non-overlapping CIDRs are good practice even though this design does not
require VPC peering between regions (the RDS replica replicates over
AWS's internal backbone, not app-level networking).
