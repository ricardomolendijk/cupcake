# GitHub CI/CD Quick Reference

## Required Secrets Setup

1. Go to: `https://github.com/ricardomolendijk/cupcake/settings/secrets/actions`

2. Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | Your Docker Hub account name |
| `DOCKERHUB_TOKEN` | Access token | https://hub.docker.com/settings/security |

## Create Docker Hub Access Token

```bash
1. Visit: https://hub.docker.com/settings/security
2. Click: "New Access Token"
3. Name: "cupcake-github-actions"
4. Permissions: Read, Write, Delete
5. Copy token immediately
6. Add to GitHub secrets as DOCKERHUB_TOKEN
```

## Create Docker Hub Repositories

```bash
Repository 1: cupcake-operator
Repository 2: cupcake-agent

URL: https://hub.docker.com/repository/create
Visibility: Public
```

## Triggering Builds

### Push to Main (Build + Push)
```bash
git checkout main
git add .
git commit -m "feat: new feature"
git push origin main
```

### Create Release (Build + Push + Release)
```bash
git tag v0.1.0
git push origin v0.1.0
```

### Pull Request (Build Only, No Push)
```bash
git checkout -b feature
git push origin feature
# Create PR on GitHub
```

## Image Tags Generated

| Trigger | Tags Created |
|---------|--------------|
| Push to `main` | `latest`, `main`, `main-<sha>` |
| Tag `v1.2.3` | `v1.2.3`, `1.2.3`, `1.2`, `1`, `latest` |
| PR #42 | `pr-42` (not pushed) |
| Branch `develop` | `develop`, `develop-<sha>` |

## Workflow Files

| File | Purpose | Triggers |
|------|---------|----------|
| `build-and-push.yaml` | Build Docker images | Push, PR, Tags |
| `helm-lint.yaml` | Lint Helm chart | Helm changes |
| `test.yaml` | Run tests | Push, PR |

## Verifying Success

### Check Workflow Status
```
https://github.com/ricardomolendijk/cupcake/actions
```

### Pull Published Images
```bash
docker pull ricardomolendijk/cupcake-operator:latest
docker pull ricardomolendijk/cupcake-agent:latest
```

### Check Release
```
https://github.com/ricardomolendijk/cupcake/releases
```

## Troubleshooting

### Build fails with "Permission denied"
- ✅ Check `DOCKERHUB_USERNAME` is correct
- ✅ Check `DOCKERHUB_TOKEN` is valid
- ✅ Regenerate token if needed

### Images not on Docker Hub
- ✅ Check repositories exist on Docker Hub
- ✅ Check workflow completed successfully
- ✅ Check you're not on a PR (PRs don't push)

### Multi-arch not working
- ✅ Check `platforms: linux/amd64,linux/arm64` is set
- ✅ Check buildx is enabled in workflow

## Manual Workflow Run

```bash
1. Go to: Actions tab
2. Select: "Build and Push Docker Images"
3. Click: "Run workflow"
4. Choose: Branch
5. Click: "Run workflow" button
```

## Complete Release Checklist

```bash
# 1. Update changelog
vim CHANGELOG.md

# 2. Commit changes
git add CHANGELOG.md
git commit -m "chore: prepare v0.2.0"
git push origin main

# 3. Create tag
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin v0.2.0

# 4. Wait for CI (~5-10 minutes)

# 5. Verify
docker pull ricardomolendijk/cupcake-operator:v0.2.0
docker pull ricardomolendijk/cupcake-agent:v0.2.0

# 6. Test
helm install cupcake ./helm \
  --set operator.image.tag=v0.2.0 \
  --set agent.image.tag=v0.2.0
```

## Quick Links

- **GitHub Actions**: https://github.com/ricardomolendijk/cupcake/actions
- **Docker Hub Profile**: https://hub.docker.com/u/ricardomolendijk
- **Operator Image**: https://hub.docker.com/r/ricardomolendijk/cupcake-operator
- **Agent Image**: https://hub.docker.com/r/ricardomolendijk/cupcake-agent
- **Releases**: https://github.com/ricardomolendijk/cupcake/releases

## Status Badges

Add to README.md:

```markdown
[![Build](https://github.com/ricardomolendijk/cupcake/actions/workflows/build-and-push.yaml/badge.svg)](https://github.com/ricardomolendijk/cupcake/actions/workflows/build-and-push.yaml)
[![Tests](https://github.com/ricardomolendijk/cupcake/actions/workflows/test.yaml/badge.svg)](https://github.com/ricardomolendijk/cupcake/actions/workflows/test.yaml)
```
