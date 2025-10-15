# GitHub Pages Setup for Helm Repository

This guide explains how to set up GitHub Pages to host your CUPCAKE Helm repository.

## Prerequisites

- Repository admin access
- GitHub Actions enabled in your repository

## Setup Steps

### 1. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click on **Settings** → **Pages**
3. Under **Source**, select:
   - Source: **GitHub Actions**
   - (This replaces the old gh-pages branch method)
4. Click **Save**

### 2. Configure Repository Permissions

The workflow needs the following permissions:

1. Go to **Settings** → **Actions** → **General**
2. Scroll to **Workflow permissions**
3. Select **Read and write permissions**
4. Check **Allow GitHub Actions to create and approve pull requests**
5. Click **Save**

### 3. Create a Personal Access Token (Optional but Recommended)

For the PR creation in the build-and-push workflow to trigger other workflows:

1. Go to your GitHub profile → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set the following:
   - **Note**: `CUPCAKE CI/CD`
   - **Expiration**: Choose appropriate expiration
   - **Scopes**: 
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
4. Click **Generate token**
5. Copy the token (you won't see it again!)
6. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
7. Click **New repository secret**
8. Name: `GH_TOKEN` (Note: GitHub doesn't allow "GITHUB" in secret names)
9. Value: Paste your token
10. Click **Add secret**

## How It Works

### Workflow Triggers

The `release-helm-chart.yaml` workflow triggers on:

1. **Tag pushes** (`v*`) - When you create a release tag
2. **Published releases** - When the `build-and-push` workflow creates a GitHub release
3. **Manual dispatch** - You can manually trigger it from the Actions tab

### What Happens

1. **Package Chart**: The Helm chart is packaged into a `.tgz` file
2. **Upload to Release**: The package is attached to the GitHub release
3. **Update Helm Index**: 
   - Downloads all chart packages from all releases
   - Generates `index.yaml` with chart metadata
   - Creates a nice landing page (`index.html`)
   - Deploys everything to GitHub Pages

### Repository Structure

After deployment, your GitHub Pages will have:

```
https://<username>.github.io/<repo>/
├── index.html              # Landing page
├── index.yaml              # Helm repository index
└── charts/
    ├── cupcake-0.1.0.tgz  # Chart packages
    ├── cupcake-0.2.0.tgz
    └── index.yaml          # Duplicate for compatibility
```

## Using Your Helm Repository

Once GitHub Pages is set up and the workflow has run at least once:

```bash
# Add your Helm repository
helm repo add cupcake https://<username>.github.io/<repo>

# Update repositories
helm repo update

# Search for charts
helm search repo cupcake

# Install CUPCAKE
helm install cupcake cupcake/cupcake --namespace kube-system
```

For your repository specifically:

```bash
helm repo add cupcake https://ricardomolendijk.github.io/cupcake
helm repo update
helm install cupcake cupcake/cupcake --namespace kube-system
```

## Verification

### Check GitHub Pages Deployment

1. Go to **Actions** tab in your repository
2. Look for the **Release Helm Chart** workflow
3. Check the deployment status
4. Visit your GitHub Pages URL to see the landing page

### Test the Helm Repository

```bash
# Add the repository
helm repo add cupcake https://ricardomolendijk.github.io/cupcake

# List available charts
helm search repo cupcake

# Show chart details
helm show chart cupcake/cupcake
```

## Troubleshooting

### GitHub Pages Not Deploying

**Issue**: Workflow succeeds but pages don't update

**Solution**:
- Ensure GitHub Pages is set to **GitHub Actions** source (not gh-pages branch)
- Check that workflow has `pages: write` permission
- Wait a few minutes for DNS propagation

### Chart Not Found in Repository

**Issue**: `helm search repo cupcake` returns nothing

**Solution**:
- Verify the workflow completed successfully
- Check that the release has the `.tgz` file attached
- Update your Helm repositories: `helm repo update`
- Verify the URL is correct: `curl https://ricardomolendijk.github.io/cupcake/index.yaml`

### Permission Denied Errors

**Issue**: Workflow fails with permission errors

**Solution**:
- Check Actions permissions in repository settings
- Ensure `GH_TOKEN` secret is set correctly
- Verify the token hasn't expired

### Multiple Chart Versions

**Issue**: Old chart versions not appearing in repository

**Solution**:
- The workflow downloads from ALL releases
- Ensure previous releases have the chart `.tgz` file attached
- Re-run the workflow to regenerate the index with all versions

## Manual Deployment

If you need to manually update the Helm repository:

```bash
# Trigger the workflow manually
gh workflow run release-helm-chart.yaml
```

Or from the GitHub UI:
1. Go to **Actions** tab
2. Select **Release Helm Chart** workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Additional Resources

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [Helm Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/)
- [GitHub Actions for Pages](https://github.com/actions/deploy-pages)
