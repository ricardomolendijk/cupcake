# Kubernetes Update Operator - Security

## Security Model

The Kubernetes Update Operator requires elevated privileges to perform cluster upgrades. This document outlines security considerations and mitigation strategies.

## Threat Model

### Assets to Protect
1. Kubernetes cluster availability
2. etcd data integrity
3. Node system integrity
4. Backup credentials
5. Operator control plane

### Threats
1. **Malicious CR creation** - Unauthorized users triggering upgrades
2. **Compromised agent** - Agent pod exploitation leading to node compromise
3. **Backup exfiltration** - Unauthorized access to etcd snapshots
4. **Supply chain attacks** - Malicious operator/agent images
5. **Network interception** - MitM attacks on backup uploads
6. **Privilege escalation** - Agent privileges abused

## RBAC Configuration

### Operator ServiceAccount

Minimum required permissions:

```yaml
rules:
  # Custom resources - full control
  - apiGroups: ["cupcake.ricardomolendijk.com"]
    resources: ["directupdates", "scheduledupdates", "updateschedules"]
    verbs: ["*"]
  
  - apiGroups: ["cupcake.ricardomolendijk.com"]
    resources: ["*/status"]
    verbs: ["get", "update", "patch"]
  
  # Nodes - read and patch
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch", "patch"]
  
  # Pods - for drain/evict
  - apiGroups: [""]
    resources: ["pods", "pods/eviction"]
    verbs: ["get", "list", "delete", "create"]
  
  # ConfigMaps - agent coordination
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Events - auditing
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
```

### Agent ServiceAccount

Minimum required permissions:

```yaml
rules:
  # Nodes - read only (self)
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  
  # ConfigMaps - status reporting
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update"]
```

### Restricting CR Creation

Create RBAC to limit who can create upgrade CRs:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: update-operator-user
rules:
  - apiGroups: ["cupcake.ricardomolendijk.com"]
    resources: ["directupdates", "scheduledupdates"]
    verbs: ["create", "get", "list", "watch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: update-operator-users
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: update-operator-user
subjects:
  - kind: Group
    name: cluster-admins
    apiGroup: rbac.authorization.k8s.io
```

## Privileged Container Security

### Why Privileged?

Agent requires privileged mode for:
- Access to host filesystem (`/etc/kubernetes`, `/var/lib/kubelet`)
- systemctl operations (restart kubelet)
- Package management (apt/yum)
- Container runtime interaction

### Mitigations

1. **Image Integrity**
```yaml
# Use image signing and verification
operator:
  image:
    repository: registry.example.com/cupcake
    tag: v0.1.0
    pullPolicy: Always
  imagePullSecrets:
    - name: registry-credentials

# Enable Pod Security Standards
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
```

2. **Read-Only Root Filesystem** (Operator)
```yaml
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

3. **Host Path Restrictions**
```yaml
# Limit hostPath mounts to minimum required
volumes:
  - name: etc-kubernetes
    hostPath:
      path: /etc/kubernetes
      type: Directory  # Enforce type
```

4. **Network Policies**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: agent-netpol
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: agent
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
      - protocol: UDP
        port: 53
    
    # Allow Kubernetes API
    - to:
      - namespaceSelector: {}
      ports:
      - protocol: TCP
        port: 443
    
    # Allow backup store (S3/GCS)
    - to:
      - podSelector: {}
      ports:
      - protocol: TCP
        port: 443
```

## Secrets Management

### Backup Store Credentials

**Option 1: Kubernetes Secret (default)**
```bash
kubectl create secret generic backup-store-creds \
  --from-literal=access-key=<key> \
  --from-literal=secret-key=<secret> \
  -n kube-system
```

**Option 2: External Secrets Operator**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: backup-store-creds
  namespace: kube-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: backup-store-creds
  data:
    - secretKey: access-key
      remoteRef:
        key: cupcake/s3-access-key
```

**Option 3: IAM Roles (AWS)**
```yaml
# Use IRSA (IAM Roles for Service Accounts)
operator:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/cupcake
```

### Secret Rotation

```bash
# Rotate backup credentials
kubectl create secret generic backup-store-creds \
  --from-literal=access-key=<new-key> \
  --from-literal=secret-key=<new-secret> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new credentials
kubectl rollout restart -n kube-system deployment/cupcake
kubectl rollout restart -n kube-system daemonset/cupcake-agent
```

## Backup Security

### Encryption at Rest

**S3:**
```yaml
externalStore:
  s3:
    bucket: kube-upgrades
    serverSideEncryption: AES256
    # Or use KMS
    kmsKeyId: arn:aws:kms:region:account:key/key-id
```

**GCS:**
```yaml
externalStore:
  gcs:
    bucket: kube-upgrades
    encryption:
      kmsKeyName: projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY
```

### Encryption in Transit

- Always use HTTPS for backup uploads
- Verify TLS certificates
- Use VPC endpoints when available (AWS PrivateLink, GCP Private Service Connect)

### Backup Access Control

**S3 Bucket Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/cupcake"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::kube-upgrades/*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::kube-upgrades/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

## Audit Logging

### Enable Audit Logs

**Kubernetes Audit Policy:**
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log all CR changes
  - level: RequestResponse
    resources:
      - group: cupcake.ricardomolendijk.com
        resources: ["*"]
  
  # Log node modifications
  - level: Request
    resources:
      - group: ""
        resources: ["nodes"]
    verbs: ["patch", "update"]
```

### Monitoring Suspicious Activity

Alert on:
- DirectUpdate CR created by non-admin users
- Operator/agent pod modifications
- Backup credential access
- Failed authentication attempts
- Unexpected privilege escalation

## Network Security

### mTLS for Etcd

Ensure etcd snapshot operations use mTLS:
```bash
etcdctl snapshot save /tmp/snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Service Mesh Integration

If using Istio/Linkerd, configure for operator/agent:
```yaml
podAnnotations:
  sidecar.istio.io/inject: "false"  # Agents don't need mesh
```

## Compliance

### PCI-DSS
- Enable encryption at rest and in transit
- Implement access controls
- Enable audit logging
- Regular security assessments

### HIPAA
- Use encrypted backup storage
- Implement role-based access control
- Enable comprehensive audit trails
- Secure credential management

### SOC 2
- Document security procedures
- Implement change management
- Enable monitoring and alerting
- Regular vulnerability scanning

## Vulnerability Management

### Image Scanning

```bash
# Scan operator image
trivy image registry.example.com/cupcake:v0.1.0

# Scan agent image
trivy image registry.example.com/cupcake-agent:v0.1.0
```

### Dependency Scanning

```bash
# Python dependencies
safety check -r operator/requirements.txt
safety check -r agent/requirements.txt

# Container base images
docker scan python:3.11-slim
```

### Patch Management

- Subscribe to security advisories
- Test patches in staging
- Document patching procedures
- Maintain patch history

## Incident Response

### Suspected Compromise

1. **Isolate**
   ```bash
   # Scale down operator
   kubectl scale deployment/cupcake --replicas=0 -n kube-system
   
   # Delete agent pods
   kubectl delete daemonset/cupcake-agent -n kube-system
   ```

2. **Investigate**
   - Review audit logs
   - Check backup access logs
   - Inspect hostPath directories
   - Analyze network traffic

3. **Remediate**
   - Rotate all credentials
   - Rebuild images from known-good sources
   - Review and update RBAC
   - Re-deploy with increased monitoring

4. **Document**
   - Create incident report
   - Update runbooks
   - Conduct post-mortem
   - Implement preventive measures

## Security Checklist

- [ ] RBAC configured with minimum required permissions
- [ ] CR creation restricted to authorized users
- [ ] Backup credentials stored securely (Secrets/external)
- [ ] Backup encryption enabled (at rest and in transit)
- [ ] Image scanning enabled in CI/CD
- [ ] Network policies applied
- [ ] Audit logging enabled
- [ ] Monitoring and alerting configured
- [ ] Incident response plan documented
- [ ] Security reviews conducted quarterly
- [ ] Vulnerability scanning automated
- [ ] Patch management process in place
