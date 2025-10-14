# Kubernetes Update Operator - Runbook

## Installation

### Prerequisites
- Kubernetes 1.24+
- kubeadm-based cluster
- Helm 3.x
- kubectl access with cluster-admin privileges

### Install Steps

```bash
# Add Helm repository (if published)
helm repo add kube-update https://example.com/charts

# Or use local chart
cd helm/

# Install CRDs first
kubectl apply -f ../crds/

# Install operator with default settings (test environment)
helm install cupcake . \
  --namespace kube-system \
  --create-namespace

# Install with backup enabled (production)
helm install cupcake . \
  --namespace kube-system \
  --create-namespace \
  --set externalStore.enabled=true \
  --set externalStore.type=s3 \
  --set externalStore.s3.bucket=my-kube-upgrades \
  --set externalStore.s3.accessKey=<key> \
  --set externalStore.s3.secretKey=<secret>
```

### Verify Installation

```bash
# Check operator is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=cupcake

# Check agent daemonset
kubectl get daemonset -n kube-system -l app.kubernetes.io/component=agent

# Verify CRDs
kubectl get crd | grep cupcake.ricardomolendijk.com
```

## Starting an Upgrade

### 1. Create DirectUpdate CR

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: upgrade-to-1-27-4
spec:
  targetVersion: "1.27.4"
  components:
    - kubeadm
    - kubelet
    - kubectl
  strategy: rolling
  concurrency: 1
  preflightChecks: true
EOF
```

### 2. Monitor Progress

```bash
# Watch overall status
kubectl get directupdate upgrade-to-1-27-4 -w

# Get detailed status
kubectl get directupdate upgrade-to-1-27-4 -o yaml

# Check specific fields
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.phase}'
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.summary}'

# Watch operator logs
kubectl logs -n kube-system deployment/cupcake -f

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep DirectUpdate
```

### 3. Check Node-Level Status

```bash
# Get per-node status
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.nodes}' | jq

# Check node annotations
kubectl describe node <node-name> | grep cupcake.ricardomolendijk.com

# Check agent logs on specific node
kubectl logs -n kube-system daemonset/cupcake-agent --field-selector spec.nodeName=<node-name>
```

## Pausing and Resuming

### Pausing an Operation

```bash
# Update CR to set pause annotation
kubectl annotate directupdate upgrade-to-1-27-4 cupcake.ricardomolendijk.com/paused=true

# Or delete CR to stop (not recommended mid-upgrade)
kubectl delete directupdate upgrade-to-1-27-4
```

### Resuming a Paused Operation

```bash
# Remove pause annotation
kubectl annotate directupdate upgrade-to-1-27-4 cupcake.ricardomolendijk.com/paused-

# Operator will resume from last checkpoint
```

## Handling RequiresAttention State

When an operation enters RequiresAttention phase, investigate and resolve:

### 1. Check Preflight Failures

```bash
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.preflightResults}' | jq
```

Common issues:
- Nodes not ready → Fix node issues first
- Low disk space → Free up space
- PDBs blocking → Temporarily relax PDBs

### 2. Check Backup Failures

```bash
# Check backup info
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.backupInfo}' | jq

# Check agent logs
kubectl logs -n kube-system daemonset/cupcake-agent --field-selector spec.nodeName=<control-plane-node>

# Verify S3 credentials
kubectl get secret -n kube-system cupcake-backup-store -o yaml
```

Resolution:
- Fix S3/GCS credentials
- Check network connectivity
- Verify bucket permissions
- Delete CR and recreate after fix

### 3. Check Node Upgrade Failures

```bash
# Get failed node details
kubectl get directupdate upgrade-to-1-27-4 -o jsonpath='{.status.nodes}' | jq '.[] | select(.phase=="Failed")'

# Check node hostPath
kubectl exec -n kube-system -it <agent-pod-on-node> -- ls -la /var/lib/cupcake/operation-*/

# Read failure marker
kubectl exec -n kube-system -it <agent-pod-on-node> -- cat /var/lib/cupcake/operation-*/failed
```

Resolution:
- Fix node-specific issue (disk, network, package repo)
- Manual intervention may be needed
- Can mark specific node for retry

## Retrying Failed Nodes

### Manual Retry

```bash
# Remove failed marker from hostPath
kubectl exec -n kube-system -it <agent-pod-on-node> -- rm /var/lib/cupcake/operation-*/failed

# Update node annotation to trigger retry
kubectl annotate node <node-name> cupcake.ricardomolendijk.com/status=pending --overwrite

# Update CR status (requires edit permissions)
kubectl edit directupdate upgrade-to-1-27-4
# Change node phase from Failed to Pending
```

## Rollback Procedure

**Important**: Kubernetes upgrades are generally forward-only. Rollback is NOT automatic.

### Control-Plane Rollback

1. Stop the upgrade operation
2. Restore etcd from snapshot (see below)
3. Manually downgrade kubeadm, kubelet on affected nodes
4. Run `kubeadm upgrade apply` with previous version

### Worker Rollback

1. Cordon node
2. Drain node
3. Manually downgrade packages
4. Restart kubelet
5. Uncordon node

### Etcd Restore from Backup

```bash
# List available backups
aws s3 ls s3://my-kube-upgrades/etcd-snapshots/

# Download snapshot
aws s3 cp s3://my-kube-upgrades/etcd-snapshots/etcd-snapshot-<id>-<timestamp>.db /tmp/snapshot.db

# Stop etcd on all control-plane nodes
ssh control-plane-1 'sudo systemctl stop etcd'

# Restore snapshot (on first control-plane node)
sudo ETCDCTL_API=3 etcdctl snapshot restore /tmp/snapshot.db \
  --name control-plane-1 \
  --initial-cluster control-plane-1=https://10.0.0.1:2380 \
  --initial-advertise-peer-urls https://10.0.0.1:2380 \
  --data-dir /var/lib/etcd-restore

# Move restored data
sudo rm -rf /var/lib/etcd
sudo mv /var/lib/etcd-restore /var/lib/etcd

# Start etcd
sudo systemctl start etcd

# Verify cluster health
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## Troubleshooting

### Operator Not Reconciling

```bash
# Check operator logs
kubectl logs -n kube-system deployment/cupcake

# Check leader election
kubectl get lease -n kube-system cupcake

# Restart operator
kubectl rollout restart -n kube-system deployment/cupcake
```

### Agent Not Processing Work

```bash
# Check agent logs
kubectl logs -n kube-system daemonset/cupcake-agent --all-containers

# Verify node annotation
kubectl get node <node-name> -o jsonpath='{.metadata.annotations}' | jq

# Check hostPath exists and is writable
kubectl exec -n kube-system <agent-pod> -- ls -la /var/lib/cupcake/

# Restart agent
kubectl delete pod -n kube-system <agent-pod-name>
```

### Drain Stuck

```bash
# Check which pods are blocking
kubectl get pods -A --field-selector spec.nodeName=<node-name>

# Check PDBs
kubectl get pdb -A

# Force drain (use with caution)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force --grace-period=0
```

### Backup Upload Failing

```bash
# Test S3 access from agent pod
kubectl exec -n kube-system <agent-pod> -- aws s3 ls s3://my-bucket/

# Check credentials
kubectl exec -n kube-system <agent-pod> -- env | grep AWS

# Test upload manually
kubectl exec -n kube-system <agent-pod> -- aws s3 cp /tmp/test.txt s3://my-bucket/test.txt
```

## Metrics and Monitoring

### Prometheus Queries

```promql
# Current in-progress operations
upgrade_in_progress > 0

# Failed operations in last 24h
increase(upgrade_operations_total{phase="Failed"}[24h])

# Average upgrade time per node
rate(upgrade_node_step_duration_seconds_sum[1h]) / rate(upgrade_node_step_duration_seconds_count[1h])

# Nodes pending upgrade
upgrade_operation_nodes_total{status="pending"}
```

### Grafana Dashboard

Import dashboard from `monitoring/grafana-dashboard.json` (to be created).

## Maintenance

### Cleanup Old Operations

```bash
# List all completed DirectUpdates
kubectl get directupdate -o jsonpath='{range .items[?(@.status.phase=="Succeeded")]}{.metadata.name}{"\n"}{end}'

# Delete old operations
kubectl delete directupdate <name>

# Agent hostPath cleanup (run on each node)
find /var/lib/cupcake/ -name "operation-*" -mtime +30 -exec rm -rf {} \;
```

### Upgrade Operator Itself

```bash
# Check current version
helm list -n kube-system

# Upgrade
helm upgrade cupcake ./helm \
  --namespace kube-system \
  --reuse-values

# Verify
kubectl rollout status -n kube-system deployment/cupcake
```

## Best Practices

1. **Always run preflight checks** in production
2. **Enable backups** for control-plane upgrades
3. **Test in staging first** with identical configuration
4. **Use canary strategy** for large worker pools
5. **Monitor metrics** during upgrades
6. **Schedule during maintenance windows**
7. **Keep operator and agent images in sync**
8. **Verify backup integrity** periodically
9. **Document node-specific customizations**
10. **Have rollback plan ready**
