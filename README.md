# Multi-Region HA Platform

**Status: Completed**

A Terraform-based, two-region AWS deployment with Route 53 health-check/failover-based traffic routing and a cross-region RDS read replica, validated with a real, timed failure drill rather than an architecture diagram alone.

## Key Result

The primary region's application capacity was deliberately removed (Auto Scaling Group scaled to 0). Traffic was observed reaching the secondary region **32 seconds** later, confirmed by an actual HTTP response from the secondary application, not just a changed DNS record.

> This is a single observed test result under the documented conditions below. It is not presented as a guaranteed production RTO.

**Notable finding:** the standalone Route 53 health check did not report failure until **91 seconds** after the failure began — after traffic had already moved. The routing change was driven by the Route 53 alias records' `evaluate_target_health` reacting to the ALB losing targets, not by the standalone health check's own polling cycle. Both are documented separately below rather than being collapsed into one number.

## Problem Statement

The three-tier application from an earlier portfolio project runs in a single AWS region with no failover path. This project builds a second, independent region, wires DNS-based failover between them, and proves — with a real, executed test — that traffic actually moves when the primary fails, rather than assuming a diagram implies working failover.

## Architecture

```text
                         Route 53
                    Failover Routing (Primary/Secondary + Health Checks)
                             |
                +------------+------------+
                |                         |
                v                         v
        PRIMARY REGION            SECONDARY REGION
         ap-south-2                 ap-south-1
                |                         |
               ALB                       ALB
                |                         |
          EC2 Auto Scaling          EC2 Auto Scaling
                |                         |
          RDS PostgreSQL  ---async--->  RDS Read Replica
        (project7-primary-db)      (three-tier-webapp-dr-db-replica)
```

Each region is a fully independent, dedicated VPC — not a shared or reused network.

| Region | CIDR | Role |
|---|---|---|
| `ap-south-2` | `10.2.0.0/16` | Primary |
| `ap-south-1` | `10.1.0.0/16` | Secondary / DR |

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC, subnets, IGW, route tables | Isolated networking per region |
| EC2 + Auto Scaling Group | Application compute |
| Application Load Balancer | Regional traffic entry, target health |
| RDS PostgreSQL | Primary database |
| RDS Cross-Region Read Replica | Database DR mechanism |
| Route 53 | Health-check-based failover routing |
| IAM | EC2 instance profile (SSM) |
| Terraform | Infrastructure as code, remote S3 state |

## Repository Structure

```text
multi-region-ha-platform/
├── README.md
├── terraform/
│   ├── primary-region/
│   ├── secondary-region/
│   └── route53/
├── docs/
│   ├── architecture-decisions.md
│   └── failover-test-results.md
├── evidence/
│   └── failover-drill/
│       ├── README.md
│       ├── failover-timeline.txt
│       ├── pre-failover-dns.txt
│       ├── primary-curl-response.txt
│       ├── primary-db-arn.txt
│       └── secondary-curl-response.txt
└── scripts/
    └── failover-drill.sh
```

## How This Was Deployed and Tested

Each Terraform directory is applied independently, in dependency order:

```bash
cd terraform/primary-region && terraform apply
cd terraform/secondary-region && terraform apply -var="primary_db_arn=<primary ARN>"
cd terraform/route53 && terraform apply -var="primary_alb_dns_name=..." -var="primary_alb_zone_id=..." -var="secondary_alb_dns_name=..." -var="secondary_alb_zone_id=..."
```

The failover drill itself is automated in `scripts/failover-drill.sh`, which scales the primary ASG to 0, then polls the Route 53 health check status, the authoritative DNS answer, and the live HTTP response until traffic is confirmed reaching the secondary region.

This project was **not** left running. Everything is destroyed after each test session — see Teardown below.

## Failover Test — What Was Actually Measured

Full write-up with the annotated timeline: [`docs/failover-test-results.md`](docs/failover-test-results.md). Raw evidence: [`evidence/failover-drill/`](evidence/failover-drill/).

**Representative run:**

| Event | Time (UTC) | Offset from T0 |
|---|---|---|
| T0 — primary ASG scaled to 0 | 06:27:15 | 0s |
| T2 — secondary application confirmed serving traffic | 06:27:44 | 32s (script's epoch measurement; displayed timestamps differ by 29s — see note below) |
| T1 — standalone Route 53 health check reports failure | 06:28:39 | 91s |

**Why 29s (timestamps) and 32s (script) differ, stated honestly:** the script prints a timestamp before making that loop's DNS/HTTP calls, then calculates T2's epoch after those calls return. The ~3-second gap is the round-trip time of that iteration's `dig`/`curl` calls, not measurement error. The script's epoch-based value (32s) is the one treated as authoritative here, and this explanation is recorded so the discrepancy isn't silently unexplained.

**A second run** produced a 5-second result, but it started with the primary already down from the first run — not a clean healthy-to-failed transition — so it is not used as the representative measurement. It's kept in the raw evidence for transparency, not hidden.

**Test domain:** `app.project7-drtest.com`, an unregistered, test-only Route 53 hosted zone. Verification queried the zone's own authoritative nameserver directly. Public DNS resolution was never possible and was not tested — see Known Limitations.

## RTO vs RPO

**RTO (Recovery Time Objective):** this project measured **32 seconds** from a deliberate primary failure to confirmed application traffic reaching the secondary region, via direct HTTP response content, not just an authoritative DNS answer. This is a single measured result under controlled test conditions, not a general production guarantee, and it reflects Route 53's alias target-health evaluation, not the standalone health check's polling interval (which reported 91s later).

**RPO (Recovery Point Objective):** **not numerically measured.** The architecture includes a cross-region RDS read replica, confirmed to reach `available` status, but no write was made to the primary and compared against the replica, no replication lag was measured, and no replica promotion was performed. Claiming a numeric RPO without that evidence would be exactly the kind of unsupported claim this project's methodology is built to avoid.

## Design Decisions and Trade-offs

Full detail: [`docs/architecture-decisions.md`](docs/architecture-decisions.md).

| Decision | Why | Trade-off |
|---|---|---|
| Standard RDS cross-region read replica, not Aurora Global Database | No engine migration required; matches the existing PostgreSQL setup | Replica promotion is manual, not automatic; no numeric RPO established |
| Dedicated, self-contained VPCs per region | This platform does not depend on any other project's infrastructure existing | More setup than reusing an existing VPC |
| EC2 + ASG, not multi-region EKS | Keeps scope on networking, failover and DR mechanics rather than cluster federation | Less representative of a Kubernetes-based production stack |
| Route 53 standard (30s) health check interval, not fast (10s) | Avoids an extra monthly surcharge for a same-day test | Adds up to ~60-90s to standalone health-check detection time (not to the measured RTO, which was driven by target-health evaluation) |
| Test-only, unregistered hosted zone | No domain was available for this project | Public DNS resolution and resolver/TTL caching behavior could not be tested |

## Honest Trade-offs and Known Limitations

- Numeric RPO was not measured — stated above, not glossed over.
- The measured RTO is a single test run under specific conditions, not a statistically robust or production-representative number.
- Public recursive DNS resolver behavior, TTL propagation, and ISP-level caching were not testable without a registered domain.
- Database replica promotion was never performed or timed.
- A formal AWS Billing Console cost figure was not pulled for this project; cost was controlled operationally (see Teardown), not verified after the fact.
- Multi-region EKS, Aurora Global Database, and centralized cross-region observability were explicitly out of scope from the start.

## Cost Estimate

Not verified in the AWS Billing Console. Cost was controlled operationally: infrastructure was provisioned only for active test sessions (without relying on a specific billing estimate), and fully destroyed at the end of every session.

## Teardown

Destroyed in dependency order — Route 53, then secondary region (replica before its source), then primary region:

```bash
cd terraform/route53 && terraform destroy -var="..."
cd terraform/secondary-region && terraform destroy -var="primary_db_arn=..."
cd terraform/primary-region && terraform destroy
```

Independently verified via AWS CLI (not just Terraform's exit code) across both regions and Route 53 — RDS instances, EC2 instances, load balancers, and Auto Scaling Groups all confirmed empty, and no hosted zones or health checks remained.

## Lessons Learned

1. **A diagram doesn't prove failover works.** Only a real, timed failure test does.
2. **RTO and RPO are different claims and need different evidence.** This project has strong RTO evidence and deliberately claims no RPO number, rather than inventing one.
3. **"Health-check-based failover" needed a more precise explanation once the data came in.** The standalone health check and the actual routing change didn't happen at the same time — the honest write-up separates the two instead of quietly picking whichever sounds better.
4. **A successful `terraform apply` proves resources exist, not that the application works.** Every stage was verified with a real `curl`, not just an apply exit code.
5. **Teardown is part of the deliverable, not an afterthought.** Independent AWS CLI verification, not just trusting Terraform, closed out every session.
