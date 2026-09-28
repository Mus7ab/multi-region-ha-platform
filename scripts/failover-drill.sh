#!/bin/bash
set -u
cd ~/project-7-multi-region-ha/terraform/route53
NS="ns-1469.awsdns-55.org"
FQDN="app.project7-drtest.com"
HC_ID=$(terraform output -raw primary_health_check_id)
LOG=~/project-7-multi-region-ha/evidence/day4/failover-timeline.txt

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
epoch() { date -u +%s; }

T0=$(epoch)
echo "T0 (primary ASG scaled to 0): $(ts)" | tee -a "$LOG"
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name project7-primary-asg \
  --min-size 0 --desired-capacity 0 --region ap-south-2

T1=""; T2=""
for i in $(seq 1 60); do
  now=$(ts)
  status=$(aws route53 get-health-check-status --health-check-id "$HC_ID" --region us-east-1 \
    --query 'HealthCheckObservations[0].StatusReport.Status' --output text 2>/dev/null)
  ips=$(dig +short @"$NS" "$FQDN" A | tr '\n' ' ')
  first=$(echo "$ips" | awk '{print $1}')
  body=""
  [ -n "$first" ] && body=$(curl -s -m 3 "http://$first" 2>/dev/null)
  echo "$now | health: $status | dns: $ips| body: $(echo "$body" | cut -c1-60)" | tee -a "$LOG"

  if [ -z "$T1" ] && [ -n "$status" ] && [ "$status" != "None" ] && [[ "$status" != Success* ]]; then
    T1=$(epoch); echo ">>> T1 (health check unhealthy) observed at $now" | tee -a "$LOG"
  fi
  if [ -z "$T2" ] && echo "$body" | grep -q "SECONDARY REGION"; then
    T2=$(epoch); echo ">>> T2 (traffic reaching secondary) observed at $now" | tee -a "$LOG"
  fi
  if [ -n "$T1" ] && [ -n "$T2" ]; then break; fi
  sleep 10
done

echo "----- RESULTS -----" | tee -a "$LOG"
[ -n "$T1" ] && echo "Detection time (T1 - T0): $((T1 - T0)) seconds" | tee -a "$LOG"
[ -n "$T2" ] && echo "MEASURED RTO (T2 - T0): $((T2 - T0)) seconds" | tee -a "$LOG"
[ -z "$T2" ] && echo "T2 NOT observed within 10 minutes - investigate before teardown" | tee -a "$LOG"
echo "NOTE: Measures Route 53 detection + routing only, sampled every ~10-15s. Excludes public resolver/TTL caching (no registered domain to test)." | tee -a "$LOG"
