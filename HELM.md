# Publishing and Using the Kubernetes Update Operator Helm Chart

This guide covers packaging, publishing, and consuming the Kubernetes Update Operator Helm chart.

## Table of Contents

- [Packaging the Chart](#packaging-the-chart)
- [Publishing Options](#publishing-options)
  - [OCI Registry (Recommended)](#oci-registry-recommended)
  - [GitHub Pages](#github-pages)
  - [ChartMuseum](#chartmuseum)
  - [Artifact Hub](#artifact-hub)
- [Using the Published Chart](#using-the-published-chart)
- [Versioning Strategy](#versioning-strategy)
- [CI/CD Integration](#cicd-integration)

## Packaging the Chart

### Prerequisites

- Helm 3.x installed
- Access to a container registry or chart repository
- Chart validated and tested

### Package the Chart

```bash
# Lint the chart first
helm lint ./helm

# Package the chart
helm package ./helm

# This creates: cupcake-0.1.0.tgz
```

### Generate Chart Index

If hosting in a traditional Helm repository:

```bash
# Create index file
helm repo index . --url https://your-domain.com/charts

# This creates: index.yaml
```

## Publishing Options

### OCI Registry (Recommended)

OCI (Open Container Initiative) registries are the modern approach for Helm chart distribution.

#### Docker Hub

```bash
# Login to Docker Hub
helm registry login registry-1.docker.io -u YOUR_USERNAME

# Package and push
helm package ./helm
helm push cupcake-0.1.0.tgz oci://registry-1.docker.io/YOUR_USERNAME
```

#### GitHub Container Registry (ghcr.io)

```bash
# Create GitHub Personal Access Token with write:packages scope
export CR_PAT=YOUR_TOKEN

# Login
echo $CR_PAT | helm registry login ghcr.io -u YOUR_USERNAME --password-stdin

# Push chart
helm push cupcake-0.1.0.tgz oci://ghcr.io/YOUR_ORG
```

#### AWS ECR

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  helm registry login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Push chart
helm push cupcake-0.1.0.tgz \
  oci://123456789012.dkr.ecr.us-east-1.amazonaws.com
```

#### Google Artifact Registry

```bash
# Configure authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push chart
helm push cupcake-0.1.0.tgz \
  oci://us-central1-docker.pkg.dev/PROJECT_ID/helm-charts
```

#### Azure Container Registry (ACR)

```bash
# Login
az acr login --name myregistry

# Push chart
helm push cupcake-0.1.0.tgz \
  oci://myregistry.azurecr.io/helm
```

### GitHub Pages

Host charts on GitHub Pages for free static hosting. This repository includes automated GitHub Pages deployment via GitHub Actions.

#### Automated Setup (Recommended)

The repository includes a workflow that automatically publishes Helm charts to GitHub Pages when releases are created.

**See [GitHub Pages Setup Guide](docs/github-pages-setup.md) for detailed configuration instructions.**

Quick setup:
1. Enable GitHub Pages in repository Settings → Pages
2. Select source: **GitHub Actions**
3. Configure workflow permissions in Settings → Actions → General
4. Push a release tag (e.g., `v0.1.0`) to trigger deployment

Your charts will be automatically available at:
```
https://ricardomolendijk.github.io/cupcake
```

#### Manual Setup (Alternative)

If you prefer manual deployment:

```bash
# Create gh-pages branch
git checkout --orphan gh-pages
git rm -rf .

# Add chart packages
mkdir charts
cp *.tgz charts/

# Generate index
helm repo index charts --url https://YOUR_USERNAME.github.io/cupcake/charts

# Commit and push
git add charts/
git commit -m "Publish Helm charts"
git push origin gh-pages
```

Then enable GitHub Pages:
1. Go to repository Settings
2. Navigate to Pages
3. Select `gh-pages` branch as source
4. Save

### ChartMuseum

Self-hosted Helm chart repository.

#### Deploy ChartMuseum

```bash
# Using Docker
docker run -d \
  -p 8080:8080 \
  -e STORAGE=local \
  -e STORAGE_LOCAL_ROOTDIR=/charts \
  -v $(pwd)/charts:/charts \
  ghcr.io/helm/chartmuseum:latest

# Using Helm
helm repo add chartmuseum https://chartmuseum.github.io/charts
helm install chartmuseum chartmuseum/chartmuseum
```

#### Upload Charts

```bash
# Using curl
curl --data-binary "@cupcake-0.1.0.tgz" \
  http://localhost:8080/api/charts

# Using Helm plugin
helm plugin install https://github.com/chartmuseum/helm-push
helm cm-push cupcake-0.1.0.tgz chartmuseum
```

### Artifact Hub

List your chart on [Artifact Hub](https://artifacthub.io) for community discovery.

#### Requirements

1. Chart hosted in a public OCI registry or HTTP repository
2. `artifacthub-repo.yml` metadata file
3. Submit repository to Artifact Hub

#### Create Metadata File

```yaml
# artifacthub-repo.yml
repositoryID: 12345678-1234-1234-1234-123456789012
owners:
  - name: Your Name
    email: your.email@example.com
```

#### Submit Repository

1. Visit https://artifacthub.io
2. Sign in with GitHub
3. Add Repository → Control Panel
4. Enter repository URL
5. Artifact Hub will automatically index your charts

## Using the Published Chart

### From OCI Registry

```bash
# Docker Hub
helm install cupcake \
  oci://registry-1.docker.io/YOUR_USERNAME/cupcake \
  --version 0.1.0 \
  --namespace kube-system \
  --create-namespace

# GitHub Container Registry
helm install cupcake \
  oci://ghcr.io/YOUR_ORG/cupcake \
  --version 0.1.0 \
  --namespace kube-system

# AWS ECR
helm install cupcake \
  oci://123456789012.dkr.ecr.us-east-1.amazonaws.com/cupcake \
  --version 0.1.0 \
  --namespace kube-system
```

### From Traditional Helm Repository

```bash
# Add repository
helm repo add kube-update https://your-domain.com/charts
helm repo update

# Install chart
helm install cupcake kube-update/cupcake \
  --version 0.1.0 \
  --namespace kube-system \
  --create-namespace

# With custom values
helm install cupcake kube-update/cupcake \
  --version 0.1.0 \
  --namespace kube-system \
  --values custom-values.yaml
```

### From GitHub Pages

```bash
# Add repository
helm repo add kube-update https://YOUR_USERNAME.github.io/cupcake/charts
helm repo update

# Install
helm install cupcake kube-update/cupcake \
  --version 0.1.0 \
  --namespace kube-system
```

## Versioning Strategy

Follow [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR** (1.x.x): Breaking changes
- **MINOR** (x.1.x): New features, backward compatible
- **PATCH** (x.x.1): Bug fixes, backward compatible

### Chart.yaml Versioning

```yaml
apiVersion: v2
name: cupcake
version: 0.1.0          # Chart version
appVersion: "0.1.0"     # Application version
```

### Bumping Versions

```bash
# Update Chart.yaml
# version: 0.1.0 -> 0.2.0

# Update appVersion if application changed
# appVersion: "0.1.0" -> "0.2.0"

# Package new version
helm package ./helm

# Publish
helm push cupcake-0.2.0.tgz oci://registry-1.docker.io/YOUR_USERNAME
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/release-chart.yml
name: Release Helm Chart

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Install Helm
        uses: azure/setup-helm@v3
        with:
          version: v3.12.0

      - name: Login to GitHub Container Registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | helm registry login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Package Chart
        run: |
          helm package ./helm

      - name: Push Chart
        run: |
          helm push cupcake-*.tgz oci://ghcr.io/${{ github.repository_owner }}

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: cupcake-*.tgz
```

### GitLab CI

```yaml
# .gitlab-ci.yml
publish-chart:
  stage: deploy
  image: alpine/helm:latest
  script:
    - helm registry login $CI_REGISTRY -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
    - helm package ./helm
    - helm push cupcake-*.tgz oci://$CI_REGISTRY/$CI_PROJECT_PATH
  only:
    - tags
```

### Jenkins

```groovy
pipeline {
    agent any
    
    stages {
        stage('Package') {
            steps {
                sh 'helm package ./helm'
            }
        }
        
        stage('Publish') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry-creds', 
                                                 usernameVariable: 'USER', 
                                                 passwordVariable: 'PASS')]) {
                    sh '''
                        echo $PASS | helm registry login registry.example.com -u $USER --password-stdin
                        helm push cupcake-*.tgz oci://registry.example.com/charts
                    '''
                }
            }
        }
    }
}
```

## Chart Documentation

### README for Chart Users

Include a `README.md` in your chart:

```markdown
# Kubernetes Update Operator

## Installation

\`\`\`bash
helm install cupcake oci://ghcr.io/YOUR_ORG/cupcake
\`\`\`

## Configuration

See [values.yaml](values.yaml) for configuration options.

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `operator.replicaCount` | Number of operator replicas | `1` |
| `externalStore.enabled` | Enable backup to external store | `false` |
```

### Values Documentation

Use comments in `values.yaml`:

```yaml
# Number of operator replicas
# Recommended: 2+ for production
operator:
  replicaCount: 1
```

## Security

### Signing Charts

```bash
# Generate key pair
gpg --gen-key

# Export public key
gpg --export-secret-keys > ~/.gnupg/secring.gpg

# Package and sign
helm package --sign --key 'Your Name' --keyring ~/.gnupg/secring.gpg ./helm

# Verify
helm verify cupcake-0.1.0.tgz
```

### Using Cosign

```bash
# Install cosign
brew install cosign

# Generate keys
cosign generate-key-pair

# Sign the chart
cosign sign --key cosign.key registry-1.docker.io/YOUR_USERNAME/cupcake:0.1.0

# Verify
cosign verify --key cosign.pub registry-1.docker.io/YOUR_USERNAME/cupcake:0.1.0
```

## Best Practices

1. **Version everything**: Chart version, app version, image tags
2. **Test before publishing**: Use `helm lint` and `helm test`
3. **Immutable releases**: Never overwrite published versions
4. **Changelog**: Maintain CHANGELOG.md for all releases
5. **Security scanning**: Scan images and charts for vulnerabilities
6. **Documentation**: Keep README.md updated
7. **Semantic versioning**: Follow SemVer strictly
8. **Provenance**: Sign charts for verification

## Troubleshooting

### Chart Not Found

```bash
# Verify repository
helm repo list

# Update index
helm repo update

# Search for chart
helm search repo cupcake
```

### OCI Push Fails

```bash
# Check authentication
helm registry login --help

# Verify permissions
docker login registry-1.docker.io

# Test with Docker
docker push registry-1.docker.io/YOUR_USERNAME/test:latest
```

### Version Conflicts

```bash
# List all versions
helm search repo cupcake --versions

# Install specific version
helm install cupcake oci://... --version 0.1.0
```

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm OCI Support](https://helm.sh/docs/topics/registries/)
- [Artifact Hub](https://artifacthub.io/)
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
