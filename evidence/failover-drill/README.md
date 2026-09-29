# Failover Drill Evidence

This directory contains the raw evidence captured during the multi-region failover drill.

The evidence supports the documented failover test results in:

`docs/failover-test-results.md`

## Evidence Files

### `failover-timeline.txt`

Raw output from the failover drill.

It records:

- Failure initiation time (`T0`)
- Route 53 health-check observations
- Authoritative DNS responses
- HTTP responses during the transition
- Secondary-region traffic observation (`T2`)
- Standalone health-check failure observation (`T1`)
- Calculated recovery intervals

The representative run recorded:

`T0: 2026-09-28T06:27:15Z`

`T2: 2026-09-28T06:27:44Z`

**Measured RTO: 32 seconds**

A later standalone health-check observation occurred at:

`T1: 2026-09-28T06:28:39Z`

**Detection interval: 91 seconds**

A second run produced a 5-second result but was not used as the representative RTO because the primary application was already unavailable when that run began.

### `pre-failover-dns.txt`

DNS resolution captured before the failover.

The addresses corresponded to the primary ALB at the beginning of the test.

### `primary-curl-response.txt`

HTTP response captured from the primary application before the failure.

It provides direct application-level evidence that traffic was initially served by the primary region.

### `primary-db-arn.txt`

The ARN of the primary RDS database used by the Project 7 architecture.

`arn:aws:rds:ap-south-2:342677169816:db:project7-primary-db`

### `secondary-curl-response.txt`

HTTP response captured after failover.

It provides direct application-level evidence that traffic reached the secondary region.

## Measurement Scope

The drill measured the observed Route 53 failover transition using the authoritative Route 53 nameserver.

The test did not measure:

- Public recursive DNS caching
- Production-domain TTL behavior
- End-user ISP resolver behavior
- Controlled database write loss
- RDS replication lag
- Automated database promotion
- Application/database consistency after promotion

Therefore, the measured 32-second result is an observed test result under these specific conditions, not a universal production RTO guarantee.

The numeric RPO was not experimentally measured.

## Reproduction

The failover procedure is implemented in:

`scripts/failover-drill.sh`

The script performs the failure test, monitors Route 53 health status, checks authoritative DNS resolution, verifies the returned application response, and calculates the observed recovery interval.

## Cleanup Verification

After the drill, the primary and secondary infrastructure was destroyed.

AWS CLI verification confirmed that the tested resources were no longer running in both regions, and the temporary Route 53 test resources were also removed.
