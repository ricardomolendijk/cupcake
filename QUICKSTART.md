# Quick Start Guide

Get the Kubernetes Update Operator running in 5 minutes.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured with cluster-admin access
- Helm 3.x

## Installation

### Option 1: Using Helm (Recommended)

```bash
# Install from OCI registry (if published)
helm install cupcake \
  oci://docker.io/rmolendijk/cupcake \
  --namespace kube-system \
  --create-namespace

# Or install from local chart
helm install cupcake ./helm \
  --namespace kube-system \
  --create-namespace
```

### Option 2: Production with External Backup

```bash
# Create S3 credentials secret
kubectl create secret generic backup-store-credentials \
  --from-literal=access-key=YOUR_AWS_ACCESS_KEY \
  --from-literal=secret-key=YOUR_AWS_SECRET_KEY \
  -n kube-system

# Install with backup enabled
helm install cupcake ./helm \
  --namespace kube-system \
  --create-namespace \
  --set externalStore.enabled=true \
  --set externalStore.type=s3 \
  --set externalStore.s3.bucket=my-kube-backups \
  --set externalStore.s3.region=us-east-1 \
  --set externalStore.s3.existingSecret=backup-store-credentials \
  --set operator.replicaCount=2
```

### Option 3: Testing/Development

```bash
# Install with minimal resources and no backups
helm install cupcake ./helm \
  --namespace kube-system \
  --create-namespace \
  --values values-test.yaml
```

## Verify Installation

```bash
# Check operator deployment
kubectl get deployment -n kube-system cupcake
kubectl get pods -n kube-system -l app.kubernetes.io/name=cupcake

# Check agent daemonset
kubectl get daemonset -n kube-system cupcake-agent
kubectl get pods -n kube-system -l app.kubernetes.io/component=agent

# Verify CRDs are installed
kubectl get crd | grep cupcake.ricardomolendijk.com
```

Expected output:
```
directupdates.cupcake.ricardomolendijk.com
scheduledupdates.cupcake.ricardomolendijk.com
updateschedules.cupcake.ricardomolendijk.com
```

## Create Your First Upgrade

### 1. Create DirectUpdate CR

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: my-first-upgrade
spec:
  targetVersion: "1.27.4"
  components:
    - kubeadm
    - kubelet
  strategy: rolling
  concurrency: 1
  preflightChecks: true
EOF
```

### 2. Watch Progress

```bash
# Watch overall status
watch kubectl get directupdate my-first-upgrade

# Get detailed status
kubectl get directupdate my-first-upgrade -o yaml

# Check operator logs
kubectl logs -n kube-system deployment/cupcake -f
```

### 3. Monitor Per-Node Progress

```bash
# Get node status
kubectl get directupdate my-first-upgrade -o jsonpath='{.status.nodes}' | jq

# Check agent logs on specific node
kubectl logs -n kube-system daemonset/cupcake-agent \
  --field-selector spec.nodeName=YOUR_NODE_NAME
```

## Using the Makefile

The included Makefile simplifies common tasks:

```bash
# Build images
make build

# Install operator
make install

# Create example upgrade
make example-basic

# Watch upgrades
make watch

# View operator logs
make logs-operator

# View agent logs
make logs-agent

# Get upgrade status
make status

# Uninstall
make uninstall

# Run tests
make test
```

## Testing with Kind

For local testing with a disposable cluster:

```bash
# Create cluster, build images, install, and test
./test.sh all

# Or step by step:
./test.sh cluster  # Create kind cluster + registry
./test.sh build    # Build images
./test.sh install  # Install operator
./test.sh test     # Run integration tests
./test.sh cleanup  # Clean up everything
```

## Common Operations

### Pause an Upgrade

```bash
kubectl annotate directupdate my-first-upgrade \
  cupcake.ricardomolendijk.com/paused=true
```

### Resume a Paused Upgrade

```bash
kubectl annotate directupdate my-first-upgrade \
  cupcake.ricardomolendijk.com/paused-
```

### Check Preflight Results

```bash
kubectl get directupdate my-first-upgrade \
  -o jsonpath='{.status.preflightResults}' | jq
```

### View Backup Information

```bash
kubectl get directupdate my-first-upgrade \
  -o jsonpath='{.status.backupInfo}' | jq
```

### Delete an Upgrade

```bash
kubectl delete directupdate my-first-upgrade
```

## Troubleshooting

### Operator Not Starting

```bash
# Check logs
kubectl logs -n kube-system deployment/cupcake

# Check events
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

### Agent Not Running

```bash
# Check daemonset
kubectl get daemonset -n kube-system

# Check agent pod logs
kubectl logs -n kube-system daemonset/cupcake-agent --all-containers
```

### Upgrade Stuck

```bash
# Check CR status
kubectl describe directupdate my-first-upgrade

# Check node annotations
kubectl describe node YOUR_NODE | grep cupcake.ricardomolendijk.com

# Check hostPath on node
kubectl exec -n kube-system AGENT_POD -- \
  ls -la /var/lib/cupcake/
```

## Next Steps

- Read [Architecture](docs/architecture.md) to understand the system
- Review [Runbook](docs/runbook.md) for operational procedures
- Check [Security](docs/security.md) for security best practices
- Explore [examples/](examples/) for more upgrade scenarios

## Getting Help

- Check logs: `make logs-operator` or `make logs-agent`
- Review documentation in `docs/`
- File issues on GitHub
- Consult the runbook for common issues

## Clean Up

```bash
# Uninstall operator
helm uninstall cupcake -n kube-system

# Delete CRDs (this will delete all CR instances)
kubectl delete -f crds/

# Or use Makefile
make uninstall
```

---

Happy upgrading! 🚀
