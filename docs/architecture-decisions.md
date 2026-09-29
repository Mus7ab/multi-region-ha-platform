# Architecture Decisions

## 1. Multi-Region Design

The platform uses two AWS regions:

| Region | CIDR | Role |
|---|---|---|
| `ap-south-2` | `10.2.0.0/16` | Primary |
| `ap-south-1` | `10.1.0.0/16` | Secondary / DR |

The primary and secondary environments are independently managed Terraform configurations.

The secondary region is designed to provide application recovery capability if the primary region becomes unavailable.

---

## 2. Independent Primary VPC

The primary environment uses a dedicated VPC created specifically for this platform.

Primary VPC:

- Region: `ap-south-2`
- CIDR: `10.2.0.0/16`
- Public subnets for the application load balancer
- Private subnets for application instances
- Private database subnets for RDS
- Internet Gateway
- Route tables
- Security groups

This keeps the architecture self-contained and avoids coupling the disaster-recovery platform to an unrelated existing application environment.

---

## 3. Secondary VPC

The secondary environment uses an independent VPC in `ap-south-1`.

Secondary VPC:

- Region: `ap-south-1`
- CIDR: `10.1.0.0/16`
- Public subnets for the application load balancer
- Private subnets for the application instances
- Private database subnets for the RDS replica
- Internet Gateway
- Route tables
- Security groups

The CIDR ranges are intentionally different between regions so the two VPCs remain independently addressable.

---

## 4. Application Recovery Architecture

Each region contains its own application infrastructure:

```text
                    Route 53
                       |
              Failover Routing
                 /           \
                /             \
        PRIMARY REGION     SECONDARY REGION
         ap-south-2          ap-south-1
             |                    |
            ALB                  ALB
             |                    |
            ASG                  ASG
             |                    |
          EC2 App              EC2 App
```

The application layer is therefore available in both regions rather than requiring the secondary environment to be created during an outage.

---

## 5. Database Disaster-Recovery Mechanism

The database architecture uses Amazon RDS with a cross-region read replica.

Primary RDS
ap-south-2
     |
     | asynchronous replication
     v
RDS Read Replica
ap-south-1

Primary database:

Identifier: project7-primary-db
Region: ap-south-2

Secondary replica:

Identifier: three-tier-webapp-dr-db-replica
Region: ap-south-1

During the build/test cycle, the cross-region replica was successfully created and reached the available state.

The project does not claim that database promotion or application/database consistency during a real write failure was experimentally verified.

---

## 6. Route 53 Failover Strategy

Route 53 failover routing was used to direct traffic between the primary and secondary ALBs.

The configuration contains:

Primary failover record
Secondary failover record
Health checks
Alias records targeting the regional ALBs
evaluate_target_health = true

The failover behavior was tested by intentionally removing the primary application's capacity and observing when traffic reached the secondary region.

---

## 7. RTO Measurement

The primary failover drill recorded:

T0: 2026-09-28T06:27:15Z
T2: 2026-09-28T06:27:44Z

Measured RTO: 32 seconds

The 32-second value is the epoch-based measurement produced by the failover drill script.

The drill directly queried an authoritative Route 53 nameserver and then tested the returned application endpoint.

The measurement therefore represents the observed transition from the primary application to the secondary application under this specific test setup.

It is not presented as a universal production RTO guarantee.

The standalone Route 53 health-check API reported failure later:

T1: 2026-09-28T06:28:39Z
Detection observation: 91 seconds after T0

The observed traffic transition occurred before this standalone health-check API observation.

The drill therefore distinguishes:

T0 — primary failure initiated
T1 — standalone health-check API reported failure
T2 — traffic was observed reaching the secondary region
---

## 8. RPO Scope

The architecture provides asynchronous cross-region database replication.

However, this project did not perform:

controlled write-loss testing
replication-lag measurement during failure
database consistency comparison at failure time
automated database promotion
end-to-end application recovery using the promoted database

Therefore, no numeric RPO is claimed.

The practical RPO would depend on the replication state and lag at the moment of failure.

---

## 9. Cost-Control Strategy

The project was intentionally operated as a build-test-destroy workflow.

The workflow was:

Build
  ↓
Verify
  ↓
Run failover test
  ↓
Capture evidence
  ↓
Destroy
  ↓
Independently verify AWS resources

The final cleanup was independently checked using AWS CLI queries in both regions.

The verification covered the resources used by the project, including:

RDS instances
EC2 instances
Application Load Balancers
Auto Scaling Groups
Project VPCs
Route 53 hosted zone
Route 53 health checks

The final verification returned no remaining resources in the tested scope.

---

## 10. Infrastructure as Code

Terraform is used for infrastructure provisioning.

The configuration is separated by responsibility:

terraform/
├── primary-region/
├── secondary-region/
└── route53/

This separation allows each regional environment and the DNS failover configuration to be managed independently.

Terraform state is stored remotely in Amazon S3.

---

## 11. Verification Philosophy

The project follows an evidence-driven workflow.

Infrastructure is not considered verified merely because Terraform reports a successful apply.

Verification includes:

Terraform outputs
AWS CLI resource inspection
Application curl responses
RDS status verification
Route 53 DNS resolution
Failover testing
Measured recovery timing
Final AWS resource cleanup verification

This approach is intended to distinguish infrastructure that was merely provisioned from infrastructure that was actually exercised and tested.

---

## 12. Known Limitations

The project demonstrates application traffic failover and cross-region database replication, but it does not represent a complete production DR implementation.

Known limitations include:

No automated database promotion
No controlled database write-loss experiment
No measured replication lag
No numeric RPO measurement
No production-domain DNS resolver/TTL test
No application-level data consistency test during failover
No automated infrastructure recreation during a regional outage
No formal AWS Billing Console cost measurement

The measured 32-second RTO should therefore be interpreted within the exact test conditions documented by the failover drill.
