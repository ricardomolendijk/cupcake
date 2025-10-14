# Kubernetes Update Operator - Architecture

## Overview

The Kubernetes Update Operator is a production-ready system for orchestrating safe, resumable upgrades of kubeadm-based Kubernetes clusters.

## Components

### 1. Operator (Control Plane)

- **Technology**: Python with Kopf framework
- **Deployment**: Kubernetes Deployment with leader election
- **Responsibilities**:
  - Reconcile DirectUpdate, ScheduledUpdate, UpdateSchedule CRs
  - Compute upgrade plans (control-plane first, then workers)
  - Run preflight checks
  - Coordinate agent activities via node annotations
  - Manage CR.status as canonical state
  - Trigger etcd backups before control-plane upgrades
  - Export Prometheus metrics

### 2. Agent (Node-Local)

- **Technology**: Python
- **Deployment**: Privileged DaemonSet on all nodes
- **Responsibilities**:
  - Watch node annotations for work assignments
  - Execute node-local upgrade steps
  - Write checkpoint files to hostPath for resumability
  - Perform etcd snapshots (control-plane nodes)
  - Upload backups to external store
  - Update local progress markers

### 3. Custom Resources

#### DirectUpdate
- Immediate upgrade execution
- Supports rolling, parallel, and canary strategies
- Per-node status tracking
- Preflight validation

#### ScheduledUpdate
- Time-based upgrade scheduling
- Creates DirectUpdate at specified time

#### UpdateSchedule
- Recurring upgrades with cron syntax
- Maintenance window support
- Automatic version detection

## Data Flow

```
User creates DirectUpdate CR
    ↓
Operator detects CR via Kopf handler
    ↓
Operator computes plan (control-plane → workers)
    ↓
Operator runs preflight checks
    ↓
Operator updates CR.status to InProgress
    ↓
Operator annotates first control-plane node
    ↓
Agent on node detects annotation
    ↓
Agent creates operation directory in hostPath
    ↓
Agent executes upgrade steps sequentially
    ↓
Agent writes checkpoint files after each step
    ↓
Agent updates node annotation on completion
    ↓
Operator detects completion, moves to next node
    ↓
Process repeats for all nodes
    ↓
Operator marks CR.status as Succeeded
```

## State Management

### CR.status (Operator-Owned)
- Global operation state
- Per-node phase tracking
- Summary statistics
- Preflight check results
- Backup information

### HostPath (Agent-Owned)
- `/var/lib/cupcake/operation-<id>/`
- `metadata.json` - Operation details
- `step-NN-name.inprogress` - Current step
- `step-NN-name.done` - Completed steps
- `completed` or `failed` - Final state
- `logs/` - Step execution logs

### Node Annotations (Coordination)
- `cupcake.ricardomolendijk.com/operation-id` - Operation UUID
- `cupcake.ricardomolendijk.com/target-version` - Target K8s version
- `cupcake.ricardomolendijk.com/components` - Components to upgrade
- `cupcake.ricardomolendijk.com/status` - pending/completed/failed

## Resumability

### Operator Restart
1. Load CR.status from API
2. Rebuild in-memory state
3. Continue from last known per-node phase
4. Re-annotate nodes if needed

### Agent Restart
1. Scan hostPath for operation directories
2. Check for incomplete operations (no `completed` or `failed` marker)
3. Resume from last completed step (based on `.done` files)
4. Continue execution

### Node Reboot
- Agent restarts on boot
- Detects incomplete operation from hostPath
- Resumes from checkpoint
- May need to re-verify node state

## Control-Plane Upgrade Flow

1. **Backup Phase**
   - Operator triggers etcd snapshot
   - Agent on first control-plane node takes snapshot
   - Agent uploads to S3/GCS/MinIO (if enabled)
   - Agent creates status ConfigMap
   - Operator verifies backup success

2. **Upgrade Phase** (per node, sequential)
   - Download packages
   - Upgrade kubeadm
   - Run `kubeadm upgrade apply` (first node) or `kubeadm upgrade node`
   - Upgrade kubelet, kubectl
   - Restart kubelet
   - Verify node Ready

3. **Quorum Preservation**
   - Only one control-plane node upgraded at a time
   - Minimum 2 healthy nodes maintained (3+ node clusters)

## Worker Upgrade Flow

1. Drain node (cordon + evict pods)
2. Upgrade kubeadm
3. Run `kubeadm upgrade node`
4. Upgrade kubelet, kubectl
5. Restart kubelet
6. Verify node Ready
7. Uncordon node
8. Repeat for next batch (respecting concurrency)

## Backup Strategy

### When Backups Occur
- Before any control-plane upgrade
- Optional: before first worker in batch

### Backup Artifacts
- etcd snapshot (`.db` file)
- Compressed and uploaded to external store
- Local copy retained on node

### Backup Store Support
- S3-compatible (AWS S3, MinIO)
- Google Cloud Storage
- NFS (planned)

### Backup Failure Handling
- If upload fails: mark operation RequiresAttention
- Operator does NOT proceed with control-plane upgrade
- Manual intervention required

## Failure Modes & Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Operator crash | Kubernetes restarts pod | Resume from CR.status |
| Agent crash | Kubernetes restarts pod | Resume from hostPath |
| Node lost | Operation timeout | Mark node Failed, continue if safe |
| Backup fails | Agent reports error | Abort, RequiresAttention |
| Drain blocked | PDB/timeout | RequiresAttention |
| Upgrade fails | Step error | Mark node Failed, pause |
| API outage | Agent continues locally | Reconcile on API return |

## Metrics

### Operator Metrics
- `upgrade_operations_total{phase, operation_id}`
- `upgrade_operation_nodes_total{operation_id, status}`
- `upgrade_node_step_duration_seconds{operation_id, node, step}`
- `upgrade_in_progress{operation_id}`

### Consumption
- Prometheus scrapes operator `/metrics` endpoint
- ServiceMonitor can be enabled via Helm values

## Security Model

### Operator Permissions
- Full access to CRs
- Read/patch nodes
- Create/delete pods (for helper jobs)
- Create/delete ConfigMaps (for agent coordination)
- Create events

### Agent Permissions
- Read nodes (self)
- Read/write ConfigMaps (status reporting)
- Minimal cluster access

### Privileged Containers
- Agent runs as privileged DaemonSet
- Required for:
  - Host filesystem access
  - systemctl operations
  - Package management
  - Container runtime interaction

### Mitigations
- Image signing/verification
- NetworkPolicy restrictions
- RBAC minimization
- Audit logging

## Observability

### Logs
- Operator: structured JSON logs to stdout
- Agent: logs to stdout + hostPath
- Kubernetes Events for major transitions

### Status Visibility
- `kubectl get directupdate` shows phase and progress
- `kubectl describe directupdate` shows detailed status
- Per-node phase in `.status.nodes[node-name]`

### Debugging
- Check operator logs: `kubectl logs -n kube-system deployment/cupcake`
- Check agent logs: `kubectl logs -n kube-system daemonset/cupcake-agent -c agent --all-containers`
- Inspect node hostPath: `/var/lib/cupcake/operation-<id>/`
- Check node annotations: `kubectl describe node <name>`
