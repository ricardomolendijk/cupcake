 # Changelog

All notable changes to the Kubernetes Update Operator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-15

### Added

#### Core Features
- Initial release of Kubernetes Update Operator
- DirectUpdate CR for immediate upgrades
- ScheduledUpdate CR for time-based upgrades
- UpdateSchedule CR for recurring cron-based upgrades
- Kopf-based operator with leader election support
- Privileged DaemonSet agent for node-local operations

#### Upgrade Capabilities
- Control-plane-first upgrade orchestration
- Rolling worker node updates with configurable concurrency
- Canary deployment support for gradual rollouts
- Automatic kubeadm, kubelet, kubectl upgrades
- Containerd runtime upgrades
- Support for Debian/Ubuntu (apt) and RHEL/CentOS (yum) package managers

#### Reliability
- Full resumability after operator restarts
- Node-local checkpoint system using hostPath
- Automatic recovery from agent crashes
- Graceful handling of API server unavailability during control-plane upgrades

#### Backup & Recovery
- Automatic etcd snapshot before control-plane upgrades
- S3-compatible backup storage (AWS S3, MinIO)
- Google Cloud Storage (GCS) support
- Automatic snapshot verification
- Upload retry mechanism with exponential backoff

#### Safety Features
- Comprehensive preflight checks (API, nodes, disk, PDBs)
- Node drain/uncordon automation
- PodDisruptionBudget awareness
- Configurable operation and node timeouts
- Abort on backup failure for control-plane nodes

#### Observability
- Prometheus metrics endpoint (/metrics)
- Four core metrics: operations, nodes, duration, in-progress
- Kubernetes Events for major state transitions
- Structured logging (JSON format)
- Per-node upgrade status tracking
- Real-time progress summary

#### Deployment
- Complete Helm chart with 8 templates
- CRDs included in Helm chart (optional install)
- Production and test value configurations
- RBAC with minimum required permissions
- Support for multiple replicas with leader election
- Air-gap deployment support

#### Documentation
- Comprehensive architecture documentation
- Operations runbook with troubleshooting guide
- Security best practices guide
- Quick start guide (5-minute setup)
- Helm chart publishing guide
- 4 example Custom Resources

#### Testing
- Unit tests for planner and state modules
- Integration test suite with Kind
- Makefile for development automation
- CI/CD pipeline examples (GitHub Actions, GitLab CI, Jenkins)

### Technical Details

#### Operator Components
- Python 3.11 with Kopf framework
- Kubernetes Python client library
- Prometheus client for metrics
- Boto3 for S3 operations
- Google Cloud Storage client

#### Agent Components
- Python 3.11 runtime
- Kubernetes API client
- etcdctl for etcd operations
- kubectl for cluster operations
- systemctl for service management
- Support for apt and yum package managers

#### State Management
- CR.status: Global operation state (operator-owned)
- HostPath: Node-local checkpoints (agent-owned)
- Node annotations: Operator-agent coordination
- ConfigMaps: Backup request/status communication

#### Supported Platforms
- Kubernetes 1.24+
- kubeadm-based clusters
- Debian/Ubuntu Linux
- RHEL/CentOS Linux
- x86_64 architecture

### Security
- Privileged agent containers (required for node operations)
- RBAC with minimum required permissions
- Secret-based credential management
- Support for existing secrets (external secrets management)
- TLS verification for etcd operations
- Secure backup uploads (HTTPS only)

### Known Limitations
- Single-architecture support (x86_64 only)
- Limited to kubeadm-based clusters
- No automatic rollback (manual process documented)
- Debian/Ubuntu and RHEL/CentOS only (other distros untested)
- External etcd clusters not yet supported
- No multi-cluster orchestration

### Migration Notes
N/A - Initial release

### Dependencies
- Kubernetes 1.24+
- Helm 3.x
- Python 3.11+
- Docker (for image builds)

### Upgrade Notes
N/A - Initial release

### Deprecation Notices
None

---

## Release Process

To create a new release:

1. Update version in `helm/Chart.yaml`
2. Update CHANGELOG.md with release notes
3. Commit changes: `git commit -m "Release vX.Y.Z"`
4. Tag release: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push: `git push && git push --tags`
6. Build and push images: `TAG=vX.Y.Z PUSH=true ./build.sh`
7. Package chart: `make helm-package CHART_VERSION=X.Y.Z`
8. Publish chart: `make helm-push`

## Versioning Strategy

- **MAJOR**: Breaking changes to CRDs or configuration
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

Example:
- `0.1.0` → `0.2.0`: New UpdateSchedule CR added
- `0.2.0` → `0.2.1`: Bug fix in backup logic
- `0.2.1` → `1.0.0`: CRD schema breaking change
