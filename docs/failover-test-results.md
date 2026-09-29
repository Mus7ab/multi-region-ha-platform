# Failover Test Results

## Test Objective

The purpose of the failover drill was to verify that application traffic could transition from the primary AWS region to the secondary region after the primary application capacity was intentionally removed.

The test also measured the observed recovery interval between the start of the failure and the first confirmed application response from the secondary region.

---

## Test Environment

| Component | Primary | Secondary |
|---|---|---|
| AWS Region | `ap-south-2` | `ap-south-1` |
| Application | ALB + ASG + EC2 | ALB + ASG + EC2 |
| Database | `project7-primary-db` | `three-tier-webapp-dr-db-replica` |
| DNS | Route 53 failover | Route 53 failover |

The drill used the Route 53 authoritative nameserver directly rather than relying on a public recursive resolver.

The tested DNS name was:

```text
app.project7-drtest.com
```

## Pre-Failover Verification

Before the failure was initiated, the application responded from the primary region.

Captured response:

<h1>PRIMARY REGION - ip-10-2-1-120.ap-south-2.compute.internal</h1>

The pre-failover DNS lookup returned:

16.112.22.13
40.192.124.101

The primary database ARN captured as evidence was:

arn:aws:rds:ap-south-2:342677169816:db:project7-primary-db
## Failover Method

The failover was initiated by scaling the primary Auto Scaling Group to zero:

project7-primary-asg

This intentionally removed the primary application capacity.

The drill script then repeatedly checked:

Route 53 health-check status
Authoritative DNS resolution
HTTP response from the returned IP

The script defined:

T0 — primary failure initiated
T1 — standalone Route 53 health-check API reported unhealthy
T2 — application traffic was observed reaching the secondary region

The measured RTO was calculated as:

RTO = T2 - T0
## Primary Failover Run

The representative failover run began at:

T0: 2026-09-28T06:27:15Z

The primary application was initially still observed:

2026-09-28T06:27:17Z
health: Success
body: PRIMARY REGION

During the transition, an intermediate request returned:

503 Service Temporarily Unavailable

At:

2026-09-28T06:27:44Z

DNS returned secondary-region ALB addresses:

13.205.54.158
43.204.207.75

The HTTP response identified the secondary region:

<h1>SECONDARY REGION - ip-10-1-2-67.ap-south-1.compute.internal</h1>

This was recorded as:

T2: 2026-09-28T06:27:44Z

The drill calculated:

MEASURED RTO (T2 - T0): 32 seconds
## Health-Check Observation

The standalone Route 53 health-check API did not report failure until:

T1: 2026-09-28T06:28:39Z

The resulting interval was:

T1 - T0 = 91 seconds

Therefore, the test observed:

Event	Time	Offset from T0
Primary failure initiated	06:27:15Z	0 sec
Secondary traffic observed	06:27:44Z	32 sec
Standalone health-check API reported failure	06:28:39Z	91 sec

The traffic transition therefore occurred before the standalone health-check API observation.

This distinction is important: the 32-second RTO measurement is based on the observed traffic transition, while the 91-second value is the later standalone health-check observation.

## Secondary Verification

After failover, the application responded from the secondary region:

<h1>SECONDARY REGION - ip-10-1-2-67.ap-south-1.compute.internal</h1>

The DNS response during the successful transition returned:

13.205.54.158
43.204.207.75

This provided direct evidence that application traffic had moved from the primary ALB to the secondary ALB.

## Measured RTO

### Representative result
T0 = 2026-09-28T06:27:15Z
T2 = 2026-09-28T06:27:44Z

Measured RTO = 32 seconds

The 32-second result is the authoritative measurement produced by the drill script's epoch-based calculation.

The displayed UTC timestamps themselves differ by 29 seconds. The repository retains the script's calculated 32-second interval as the test measurement.

This result represents the observed Route 53 failover transition under the specific test conditions.

It is not presented as a universal production RTO guarantee.

## Second Drill Run

A second drill was recorded later:

T0: 2026-09-28T06:29:50Z
T1: 2026-09-28T06:29:52Z
T2: 2026-09-28T06:29:52Z

Measured RTO: 5 seconds

This run is not used as the representative RTO.

The primary application was already unavailable when this second run began, so it did not reproduce the same healthy-primary-to-failed-primary starting condition as the first run.

The 32-second result is therefore retained as the representative failover measurement.

## RPO Assessment

The architecture uses asynchronous cross-region RDS replication.

The failover drill did not perform a controlled database write-loss experiment or measure replication lag at the moment of failure.

Therefore:

Numeric RPO: Not experimentally measured

The practical recovery point would depend on the replication state and lag at the time of an actual primary-region failure.

The test verified application traffic failover, not database promotion or end-to-end database recovery.

## Measurement Boundaries

The drill measured Route 53 detection/routing behavior using an authoritative Route 53 nameserver.

It did not measure:

Public recursive DNS caching
Production-domain TTL behavior
End-user ISP resolver behavior
Controlled database write loss
RDS replication lag
Automated database promotion
Application/database consistency after promotion

There was no registered production domain used for the drill, so public DNS resolver and TTL behavior were intentionally excluded.

## Evidence Files

The raw evidence for this test is stored under:

evidence/failover-drill/
├── failover-timeline.txt
├── pre-failover-dns.txt
├── primary-curl-response.txt
├── primary-db-arn.txt
└── secondary-curl-response.txt

The failover procedure is implemented in:

scripts/failover-drill.sh

The script records the timestamps, health-check observations, DNS results, application responses, and calculated recovery intervals.

## Result

The failover drill successfully demonstrated application traffic transition from the primary region to the secondary region.

The representative measured result was:

Observed traffic transition: 32 seconds
Standalone health-check failure observation: 91 seconds
Numeric RPO: Not experimentally measured

The infrastructure was subsequently destroyed and independently verified through AWS CLI checks to confirm that the tested AWS resources were no longer running.
