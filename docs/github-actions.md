# GitHub Actions CI/CD Setup

This guide explains how to set up the GitHub Actions workflows for CUPCAKE to automatically build and push Docker images to Docker Hub.

## Overview

CUPCAKE uses GitHub Actions for:
- **Building** multi-arch Docker images (amd64, arm64)
- **Testing** code and Helm charts
- **Publishing** images to Docker Hub
- **Releasing** versioned artifacts
- **Validating** manifests and documentation

## Workflows

### 1. Build and Push (`build-and-push.yaml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Git tags starting with `v*` (e.g., `v0.1.0`)
- Manual dispatch

**What it does:**
- Builds Operator and Agent Docker images
- Pushes to Docker Hub (except for PRs)
- Creates multi-arch images (linux/amd64, linux/arm64)
- Tags images appropriately:
  - `latest` for main branch
  - `v1.2.3` for version tags
  - `main-abc1234` for branch commits
  - `pr-123` for pull requests
- Updates Helm chart versions on release
- Creates GitHub releases with release notes

### 2. Helm Chart Lint (`helm-lint.yaml`)

**Triggers:**
- Changes to `helm/**` or `crds/**`
- Pull requests
- Manual dispatch

**What it does:**
- Lints Helm chart
- Validates CRDs
- Templates chart with different configurations
- Tests installation in Kind cluster
- Verifies all resources are created correctly
- Tests creating DirectUpdate CRs

### 3. Tests (`test.yaml`)

**Triggers:**
- Push to `main` or `develop`
- Pull requests
- Manual dispatch

**What it does:**
- Runs unit tests on Python 3.10, 3.11, 3.12
- Validates version management
- Lints code with flake8
- Validates YAML manifests
- Checks documentation completeness

## Required GitHub Secrets

To enable Docker Hub publishing, you need to configure these secrets in your GitHub repository:

### Setting up Secrets

1. **Go to Repository Settings**
   ```
   GitHub Repo → Settings → Secrets and variables → Actions → New repository secret
   ```

2. **Create Docker Hub Secrets**

   #### `DOCKERHUB_USERNAME`
   - Your Docker Hub username
   - Example: `ricardomolendijk`

   #### `DOCKERHUB_TOKEN`
   - Docker Hub access token (NOT your password)
   - Create at: https://hub.docker.com/settings/security

### Creating a Docker Hub Access Token

1. Log in to Docker Hub
2. Go to **Account Settings** → **Security**
3. Click **New Access Token**
4. Name: `cupcake-github-actions`
5. Access permissions: **Read, Write, Delete**
6. Copy the token (you can't see it again!)
7. Add to GitHub secrets as `DOCKERHUB_TOKEN`

## Docker Hub Repository Setup

### Create Docker Hub Repositories

Create these repositories on Docker Hub:

1. **Operator Repository**
   ```
   https://hub.docker.com/repository/create
   Name: cupcake-operator
   Visibility: Public (or Private)
   Description: CUPCAKE Kubernetes upgrade operator
   ```

2. **Agent Repository**
   ```
   https://hub.docker.com/repository/create
   Name: cupcake-agent
   Visibility: Public (or Private)
   Description: CUPCAKE node upgrade agent
   ```

### Repository URLs

After creation, your images will be available at:
- `docker.io/ricardomolendijk/cupcake-operator:<tag>`
- `docker.io/ricardomolendijk/cupcake-agent:<tag>`

## Testing the Workflows

### Test PR Build (No Push)

```bash
# Create a branch
git checkout -b test-ci

# Make a change
echo "# CI Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: CI workflow"
git push origin test-ci

# Create PR on GitHub
# Workflow will build but NOT push images
```

### Test Main Branch Build

```bash
# Merge PR to main
git checkout main
git merge test-ci
git push origin main

# Workflow will build AND push images with tags:
# - latest
# - main-<commit-sha>
```

### Test Release Build

```bash
# Create and push a version tag
git tag v0.1.0
git push origin v0.1.0

# Workflow will:
# 1. Build and push images with tags:
#    - v0.1.0
#    - 0.1.0
#    - 0.1
#    - 0
# 2. Update Helm chart version
# 3. Create GitHub release
```

## Workflow Status

Check workflow status:
- **GitHub Actions Tab**: https://github.com/ricardomolendijk/cupcake/actions
- **Status Badge**: Add to README.md

```markdown
[![Build](https://github.com/ricardomolendijk/cupcake/actions/workflows/build-and-push.yaml/badge.svg)](https://github.com/ricardomolendijk/cupcake/actions/workflows/build-and-push.yaml)
```

## Image Tags Explained

### For Commits to Main

```yaml
Commit: abc1234
Tags:
  - latest
  - main
  - main-abc1234
```

### For Version Tags

```yaml
Tag: v1.2.3
Tags:
  - v1.2.3
  - 1.2.3
  - 1.2
  - 1
  - latest (if on default branch)
```

### For Pull Requests

```yaml
PR #42:
Tags:
  - pr-42
Note: Images built but NOT pushed to Docker Hub
```

## Customizing Workflows

### Change Docker Registry

Edit `.github/workflows/build-and-push.yaml`:

```yaml
env:
  REGISTRY: ghcr.io  # Change from docker.io
  OPERATOR_IMAGE_NAME: ricardomolendijk/cupcake-operator
  AGENT_IMAGE_NAME: ricardomolendijk/cupcake-agent
```

For GitHub Container Registry:
- Use `ghcr.io` as registry
- Use `secrets.GITHUB_TOKEN` (no setup needed)
- Images at `ghcr.io/ricardomolendijk/cupcake-operator`

### Change Image Names

Edit `.github/workflows/build-and-push.yaml`:

```yaml
env:
  OPERATOR_IMAGE_NAME: myorg/my-operator  # Change here
  AGENT_IMAGE_NAME: myorg/my-agent        # And here
```

### Add Build Notifications

Add notification step (example: Slack):

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Troubleshooting

### Build Fails: "Permission denied"

**Problem:** GitHub Actions can't push to Docker Hub

**Solution:**
1. Verify `DOCKERHUB_USERNAME` is correct
2. Verify `DOCKERHUB_TOKEN` is valid
3. Regenerate token if needed
4. Check token has Write permissions

### Build Fails: "Repository not found"

**Problem:** Docker Hub repositories don't exist

**Solution:**
1. Create repositories on Docker Hub manually
2. Ensure repository names match workflow config
3. Check repository visibility (public vs private)

### Images Not Multi-Arch

**Problem:** Only amd64 image available

**Solution:**
- Build uses `docker/setup-buildx-action@v3` for multi-arch
- Check workflow logs for platform builds
- Verify `platforms: linux/amd64,linux/arm64` is set

### Helm Chart Version Not Updated

**Problem:** Helm chart version doesn't match tag

**Solution:**
1. Check `update-helm-chart` job ran
2. Verify bot has permissions to commit
3. May need to enable "Allow GitHub Actions to create PRs"
4. Check repository settings → Actions → General → Workflow permissions

### Version Tests Fail

**Problem:** Version module tests failing in CI

**Solution:**
```bash
# Test locally first
python tests/test_version.py

# Check Python version
python --version  # Should be 3.10+

# Install dependencies
pip install -r operator/requirements.txt
```

## Manual Workflow Dispatch

Run workflows manually from GitHub:

1. Go to **Actions** tab
2. Select workflow (e.g., "Build and Push")
3. Click **Run workflow**
4. Choose branch
5. Click **Run workflow** button

## Viewing Build Artifacts

### Docker Images

Pull images after successful build:

```bash
# Latest from main branch
docker pull ricardomolendijk/cupcake-operator:latest
docker pull ricardomolendijk/cupcake-agent:latest

# Specific version
docker pull ricardomolendijk/cupcake-operator:v0.1.0
docker pull ricardomolendijk/cupcake-agent:v0.1.0

# Verify multi-arch
docker manifest inspect ricardomolendijk/cupcake-operator:latest
```

### Helm Charts

Download packaged charts from workflow artifacts:

1. Go to workflow run
2. Scroll to **Artifacts** section
3. Download `helm-chart`
4. Extract and install:

```bash
tar -xzf cupcake-*.tgz
helm install cupcake ./cupcake --namespace kube-system
```

## Best Practices

### 1. Version Tags

Use semantic versioning:

```bash
git tag v0.1.0   # Initial release
git tag v0.2.0   # New features
git tag v0.2.1   # Bug fixes
git tag v1.0.0   # Major release
```

### 2. Branch Protection

Enable branch protection for `main`:
- Require PR reviews
- Require status checks to pass
- Require branches to be up to date

### 3. Dependabot

Enabled via `.github/dependabot.yml`:
- Updates GitHub Actions weekly
- Updates Python dependencies weekly
- Updates Docker base images weekly

### 4. Security Scanning

Add security scanning (optional):

```yaml
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ricardomolendijk/cupcake-operator:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'
```

## GitHub Actions Limits

**Free tier (public repos):**
- Unlimited minutes
- 2,000 concurrent jobs

**Free tier (private repos):**
- 2,000 minutes/month
- 20 concurrent jobs

**Pro tips:**
- Use caching to speed up builds
- Use `paths` filters to avoid unnecessary runs
- Use `concurrency` groups to cancel old runs

## Example: Full Release Process

```bash
# 1. Finish feature development
git checkout main
git pull

# 2. Update CHANGELOG.md
echo "## v0.2.0 - $(date +%Y-%m-%d)" >> CHANGELOG.md
echo "- Added multi-step upgrade support" >> CHANGELOG.md

# 3. Commit changes
git add CHANGELOG.md
git commit -m "chore: prepare v0.2.0 release"
git push origin main

# 4. Create and push tag
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin v0.2.0

# 5. Watch Actions build
# https://github.com/ricardomolendijk/cupcake/actions

# 6. Verify release created
# https://github.com/ricardomolendijk/cupcake/releases/tag/v0.2.0

# 7. Verify images published
docker pull ricardomolendijk/cupcake-operator:v0.2.0
docker pull ricardomolendijk/cupcake-agent:v0.2.0

# 8. Test installation
helm install cupcake ./helm \
  --namespace kube-system \
  --set operator.image.tag=v0.2.0 \
  --set agent.image.tag=v0.2.0
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [Helm Chart Publishing](https://helm.sh/docs/topics/chart_repository/)
- [Semantic Versioning](https://semver.org/)

## Support

If you encounter issues with CI/CD:

1. Check workflow logs in GitHub Actions tab
2. Review this documentation
3. Check GitHub Actions status: https://www.githubstatus.com/
4. Check Docker Hub status: https://status.docker.com/
5. Open an issue: https://github.com/ricardomolendijk/cupcake/issues
