# Multi-Step Version Upgrades

CUPCAKE automatically handles multi-step Kubernetes version upgrades when skipping minor versions is required.

## Kubernetes Upgrade Constraints

Kubernetes enforces the following upgrade constraints:

- ✅ **Patch upgrades**: Can skip patches (1.27.1 → 1.27.9 in one step)
- ✅ **Single minor upgrade**: Can upgrade one minor version (1.27 → 1.28)
- ❌ **Skipping minor versions**: Cannot skip minor versions (1.27 → 1.29 directly)

## How CUPCAKE Handles This

When you specify a target version that requires skipping minor versions, CUPCAKE:

1. **Detects the version gap**: Compares current and target versions
2. **Calculates upgrade path**: Determines intermediate versions needed
3. **Validates compatibility**: Checks for breaking changes and deprecations
4. **Logs warnings**: Alerts about API removals and other concerns
5. **Executes sequentially**: Upgrades through each minor version in order

## Example Scenarios

### Scenario 1: Patch Upgrade (No Multi-Step)

```yaml
Current: 1.27.2
Target:  1.27.9
Path:    1.27.2 → 1.27.9 (single step)
```

```bash
kubectl apply -f - <<EOF
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: patch-upgrade
spec:
  targetVersion: "1.27.9"
  strategy: rolling
  concurrency: 1
EOF
```

### Scenario 2: Single Minor Version (No Multi-Step)

```yaml
Current: 1.27.4
Target:  1.28.0
Path:    1.27.4 → 1.28.0 (single step)
```

```bash
kubectl apply -f - <<EOF
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: minor-upgrade
spec:
  targetVersion: "1.28.0"
  strategy: rolling
EOF
```

### Scenario 3: Multi-Step Required

```yaml
Current: 1.25.3
Target:  1.28.0
Path:    1.25.3 → 1.26.0 → 1.27.0 → 1.28.0 (three steps)
```

```bash
kubectl apply -f - <<EOF
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: multi-step-upgrade
spec:
  targetVersion: "1.28.0"
  strategy: rolling
  concurrency: 1
  # Extended timeout for multiple upgrade steps
  operationTimeout: "6h"
EOF
```

**CUPCAKE automatically**:
- Upgrades to 1.26.0 first (all control-plane, then workers)
- Takes etcd backup before each control-plane upgrade
- Waits for cluster stability
- Proceeds to 1.27.0 (all control-plane, then workers)
- Takes another etcd backup
- Waits for stability
- Finally upgrades to 1.28.0

### Scenario 4: Large Version Jump

```yaml
Current: 1.22.5
Target:  1.27.0
Path:    1.22.5 → 1.23.0 → 1.24.0 → 1.25.0 → 1.26.0 → 1.27.0 (five steps)
```

This will take significant time as each minor version requires:
- Control-plane upgrades (sequential)
- Worker upgrades (parallel with concurrency limit)
- Verification steps

**Recommended**: Upgrade in smaller increments and test between major jumps.

## Monitoring Multi-Step Upgrades

### Check Upgrade Path

```bash
kubectl get directupdate multi-step-upgrade -o yaml
```

Look for the `upgradePath` field in status:

```yaml
status:
  upgradePath:
    currentVersion: "1.25.3"
    targetVersion: "1.28.0"
    steps:
      - "1.26.0"
      - "1.27.0"
      - "1.28.0"
    currentStep: 1
    totalSteps: 3
  message: "Step 2/3: Upgrading to 1.27.0"
```

### Watch Progress

```bash
# Watch the upgrade
kubectl get directupdate multi-step-upgrade -w

# Check detailed status
kubectl describe directupdate multi-step-upgrade

# View operator logs
kubectl logs -n kube-system deployment/cupcake -f
```

## Breaking Changes and Warnings

CUPCAKE warns about known breaking changes:

### 1.21 → 1.22+
- Several APIs removed (beta versions)
- Must migrate to stable APIs

### 1.24 → 1.25+
- PodSecurityPolicy removed
- Must migrate to Pod Security Standards

### 1.25 → 1.26+
- Additional beta API removals
- CronJob v1beta1 removed

CUPCAKE logs these warnings during upgrade planning:

```
WARNING: Upgrading from 1.21 or earlier to 1.22+: Several APIs have been removed
WARNING: Upgrading to 1.25+: PodSecurityPolicy has been removed
```

## Best Practices

### 1. Test in Staging First
```bash
# Create test upgrade in staging
kubectl apply -f - <<EOF
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: test-multi-step
spec:
  targetVersion: "1.28.0"
  dryRun: true  # Optional: simulate without making changes
EOF
```

### 2. Use Extended Timeouts
```yaml
spec:
  operationTimeout: "6h"  # For multi-step (default: 2h)
  nodeTimeout: "45m"      # Per node (default: 30m)
```

### 3. Enable Backup
```yaml
# In Helm values
externalStore:
  enabled: true
  type: s3
  s3:
    bucket: cupcake-backups
```

Each step automatically backs up etcd before control-plane upgrade.

### 4. Monitor Cluster Health
Between each step, verify:
```bash
# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -A

# Check API health
kubectl get --raw /healthz

# Check component status
kubectl get componentstatuses
```

### 5. Plan Maintenance Window
Estimate time for multi-step upgrade:
- Per-step time: ~30-60 minutes (depends on cluster size)
- 3-step upgrade: ~2-3 hours
- 5-step upgrade: ~4-5 hours

### 6. Review API Deprecations
Before major jumps, check:
```bash
# Use kubectl-deprecations plugin
kubectl deprecations

# Or check manually
kubectl api-resources
```

## Troubleshooting

### Upgrade Stuck on Intermediate Version

```bash
# Check current state
kubectl get directupdate multi-step -o jsonpath='{.status.upgradePath}'

# Check operator logs
kubectl logs -n kube-system deployment/cupcake --tail=100

# Check specific node
kubectl describe node <node-name>
```

### Rollback Between Steps

If an intermediate step fails:

1. **Check the failure**:
   ```bash
   kubectl get directupdate multi-step -o yaml
   ```

2. **Review logs**:
   ```bash
   kubectl logs -n kube-system daemonset/cupcake-agent \
     --field-selector spec.nodeName=<failed-node>
   ```

3. **Manual intervention** may be needed:
   - Fix the issue on the failed node
   - Resume by deleting and recreating the DirectUpdate
   - Or restore from etcd backup (see runbook)

### Version Detection Failed

If CUPCAKE can't detect current version:

```bash
# Manually check version
kubectl version --short

# Check operator logs
kubectl logs -n kube-system deployment/cupcake | grep "cluster version"
```

## Automation Recommendations

### Gradual Rollout Strategy

Instead of jumping from 1.22 to 1.27 immediately:

**Week 1**: 1.22 → 1.23
```bash
kubectl apply -f upgrade-to-1.23.yaml
```

**Week 2**: Validate, then 1.23 → 1.24
```bash
kubectl apply -f upgrade-to-1.24.yaml
```

**Week 3**: Validate, then 1.24 → 1.25
```bash
kubectl apply -f upgrade-to-1.25.yaml
```

This approach:
- Reduces risk
- Allows time for validation
- Makes rollback easier
- Identifies issues earlier

### Using ScheduledUpdate for Staged Rollouts

```yaml
# Stage 1: Upgrade to intermediate version
apiVersion: cupcake.ricardomolendijk.com/v1
kind: ScheduledUpdate
metadata:
  name: stage-1-upgrade
spec:
  targetVersion: "1.26.0"
  scheduleAt: "2024-12-20T02:00:00Z"
  strategy: rolling
  concurrency: 1
---
# Stage 2: Upgrade to next version (schedule 1 week later)
apiVersion: cupcake.ricardomolendijk.com/v1
kind: ScheduledUpdate
metadata:
  name: stage-2-upgrade
spec:
  targetVersion: "1.27.0"
  scheduleAt: "2024-12-27T02:00:00Z"
  strategy: rolling
  concurrency: 1
```

## API Reference

### DirectUpdate Status Fields

```yaml
status:
  upgradePath:
    currentVersion: string      # Starting version
    targetVersion: string        # Final target version
    steps: []string             # Ordered list of versions
    currentStep: integer        # Current step (0-indexed)
    totalSteps: integer         # Total number of steps
  message: string               # Current status message
```

## See Also

- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [Kubernetes Release Notes](https://kubernetes.io/docs/setup/release/)
- [CUPCAKE Architecture](architecture.md)
- [CUPCAKE Operations Runbook](runbook.md)
