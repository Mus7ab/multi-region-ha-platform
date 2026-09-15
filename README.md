# Project 7 — Multi-Region HA Platform

Status: In Progress

A two-region, highly-available deployment of the three-tier web application
(Project 1), using Route 53 health-check-based failover and a cross-region
RDS read replica. Includes a real, executed failover test with measured
RTO/RPO — not an estimated one.

Scope (5-7 days): two-region EC2/ALB deployment, Route 53 failover,
RDS cross-region read replica, one real failover drill.
Explicitly out of scope: multi-region EKS, Aurora Global Database,
cross-region observability tooling — see README "Honest Trade-offs"
section (to be completed) for reasoning.
