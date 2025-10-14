# CUPCAKE 🧁

**C**ontrol-plane **U**pgrade **P**latform for **C**ontinuous **K**ubernetes **A**utomation and **E**volution

Production-ready Kubernetes operator for orchestrating safe, resumable upgrades of kubeadm-based clusters.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub](https://img.shields.io/badge/GitHub-ricardomolendijk%2Fcupcake-blue)](https://github.com/ricardomolendijk/cupcake)

## Quick Install

Install CUPCAKE using Helm:

```bash
# Add Helm repository (if published)
helm repo add cupcake https://ricardomolendijk.github.io/cupcake
helm repo update

# Or use OCI registry
helm install cupcake \
  oci://ghcr.io/ricardomolendijk/cupcake \
  --namespace kube-system \
  --create-namespace

# Or from local chart
helm install cupcake ./helm \
  --namespace kube-system \
  --create-namespace
```

For production deployments with backup enabled:

```bash
# Create backup credentials
kubectl create secret generic backup-store-credentials \
  --from-literal=access-key=YOUR_KEY \
  --from-literal=secret-key=YOUR_SECRET \
  -n kube-system

# Install with production settings
helm install cupcake ./helm \
  --namespace kube-system \
  --create-namespace \
  --set externalStore.enabled=true \
  --set externalStore.type=s3 \
  --set externalStore.s3.bucket=my-backups \
  --set externalStore.s3.existingSecret=backup-store-credentials
```

## Create Your First Upgrade

```bash
# Create upgrade
kubectl apply -f - <<EOF
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: upgrade-to-1-27-4
spec:
  targetVersion: "1.27.4"
  components: [kubeadm, kubelet, kubectl]
  strategy: rolling
  concurrency: 1
EOF

# Monitor progress
kubectl get directupdate upgrade-to-1-27-4 -w
```

## What is CUPCAKE?

CUPCAKE (**C**ontrol-plane **U**pgrade **P**latform for **C**ontinuous **K**ubernetes **A**utomation and **E**volution) is a production-ready Kubernetes operator that automates the complex process of upgrading kubeadm-based clusters. It handles everything from etcd backups to rolling node updates, with full resumability and safety guarantees.

### Smart Multi-Step Upgrades

CUPCAKE automatically handles Kubernetes version skew constraints:
- **Detects version gaps**: If you specify 1.25 → 1.28, CUPCAKE automatically upgrades through 1.26, 1.27, then 1.28
- **Patch upgrades**: Directly jumps to target patch version (1.27.1 → 1.27.9)
- **Breaking change warnings**: Alerts about API deprecations and removals
- **Sequential safety**: Each step backs up etcd and verifies cluster health

[Learn more about multi-step upgrades →](docs/multi-step-upgrades.md)

## Features

- ✅ **Control-plane-first upgrades** with automatic etcd snapshots
- ✅ **Rolling worker updates** with configurable concurrency
- ✅ **Canary deployments** for gradual rollouts
- ✅ **Fully resumable** after operator or node restarts
- ✅ **Preflight validation** (API, nodes, disk, PDBs)
- ✅ **External backups** to S3/GCS/MinIO with automatic uploads
- ✅ **Production-ready** with HA support and leader election
- ✅ **Observability** via Prometheus metrics and Kubernetes Events
- ✅ **Air-gap support** for disconnected environments

## Documentation

- [Quick Start Guide](QUICKSTART.md) - Get started in 5 minutes
- [Multi-Step Upgrades](docs/multi-step-upgrades.md) - Automatic version skew handling
- [Helm Publishing Guide](HELM.md) - Package and publish the chart
- [GitHub Actions CI/CD](docs/github-actions.md) - Automated builds and releases
- [Architecture](docs/architecture.md) - System design and components
- [Operations Runbook](docs/runbook.md) - Day-to-day operations
- [Security Guide](docs/security.md) - Security best practices

## Repository Structure

```
.
├── agent/              # Node-local agent (DaemonSet)
├── crds/               # CustomResourceDefinitions
├── docs/               # Documentation
├── examples/           # Example CRs
├── helm/               # Helm chart
├── operator/           # Operator code (Kopf)
│   ├── handlers/       # CR handlers
│   └── lib/            # Core logic
└── tests/              # Unit and integration tests
```

## Development

### Build Images

```bash
# Build both operator and agent
./build.sh

# Or build with custom registry
REGISTRY=ghcr.io/ricardomolendijk TAG=v0.1.0 ./build.sh

# Build and push
PUSH=true ./build.sh
```

### Run Tests

```bash
# Unit tests
make test

# Integration tests (requires kind, helm, kubectl)
./test.sh
```

### Local Development

```bash
# Create kind cluster with local registry
./test.sh cluster

# Build and load images
./test.sh build

# Install operator
./test.sh install

# Run integration tests
./test.sh test

# Cleanup
./test.sh cleanup
```

## Configuration

### Key Configuration Options

```yaml
# Operator configuration
operator:
  replicaCount: 2              # HA setup for production
  image:
    repository: your-registry/cupcake
    tag: "0.1.0"
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi

# Agent configuration
agent:
  enabled: true
  hostPath: /var/lib/cupcake
  tolerations:
    - operator: Exists          # Run on all nodes

# External backup store
externalStore:
  enabled: true                 # Enable for production
  type: s3                      # s3, gcs, or minio
  s3:
    bucket: kube-upgrades
    region: us-east-1
    existingSecret: backup-credentials
```

See [values.yaml](helm/values.yaml) for all available options.

## Usage Examples

### Basic Upgrade

```yaml
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: upgrade-to-1-27-4
spec:
  targetVersion: "1.27.4"
  components: [kubeadm, kubelet, kubectl]
  strategy: rolling
  concurrency: 1
```

### Canary Deployment

```yaml
apiVersion: cupcake.ricardomolendijk.com/v1
kind: DirectUpdate
metadata:
  name: canary-upgrade
spec:
  targetVersion: "1.27.4"
  strategy: canary
  canary:
    enabled: true
    nodes: [worker-01, worker-02]
  concurrency: 2
```

### Scheduled Upgrade

```yaml
apiVersion: cupcake.ricardomolendijk.com/v1
kind: ScheduledUpdate
metadata:
  name: weekend-upgrade
spec:
  targetVersion: "1.27.4"
  scheduleAt: "2024-12-21T02:00:00Z"
```

## Monitoring and Observability

### Prometheus Metrics

The operator exposes metrics at `:8080/metrics`:

```promql
# Active upgrades
upgrade_in_progress{operation_id="..."}

# Operations by phase
upgrade_operations_total{phase="Succeeded"}

# Node status distribution
upgrade_operation_nodes_total{operation_id="...", status="completed"}

# Step duration
histogram_quantile(0.95, upgrade_node_step_duration_seconds)
```

### Kubernetes Events

```bash
# Watch upgrade events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep DirectUpdate

# Events for specific upgrade
kubectl describe directupdate my-upgrade
```

### Logs

```bash
# Operator logs
kubectl logs -n kube-system deployment/cupcake -f

# Agent logs (specific node)
kubectl logs -n kube-system daemonset/cupcake-agent \
  --field-selector spec.nodeName=worker-1 -f
```

## Troubleshooting

See [Runbook](docs/runbook.md) for detailed troubleshooting procedures.

Common issues:

- **Operator not reconciling**: Check leader election and logs
- **Agent not processing**: Verify node annotations and hostPath
- **Backup failures**: Check S3/GCS credentials and connectivity
- **Drain stuck**: Review PodDisruptionBudgets

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- GitHub Issues: Report bugs and request features
- Documentation: See `docs/` directory
- Examples: Check `examples/` directory

## Roadmap

- [ ] Multi-distro support (Ubuntu, RHEL, Amazon Linux)
- [ ] Automatic version detection
- [ ] Rollback automation
- [ ] Web UI dashboard
- [ ] Cost estimation
- [ ] Blue/green cluster upgrades

## Acknowledgments

Built with:
- [Kopf](https://kopf.readthedocs.io/) - Kubernetes Operator Framework
- [Kubernetes Python Client](https://github.com/kubernetes-client/python)
- [Helm](https://helm.sh/) - Kubernetes package manager
