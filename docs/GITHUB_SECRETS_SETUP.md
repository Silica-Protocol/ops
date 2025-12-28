# GitHub Secrets Setup Guide

This document explains how to configure GitHub secrets for cross-repository automation.

## Required Secrets

### Organization-Level Secrets (Recommended)

Set these at the **organization level** so all repos can access them:

**GitHub Settings → Organizations → Silica-Protocol → Settings → Secrets and variables → Actions**

| Secret Name | Purpose | How to Generate |
|-------------|---------|-----------------|
| `REPO_ADMIN_TOKEN` | Cross-repo PR creation | Personal Access Token with `repo` scope |
| `CRATES_IO_TOKEN` | Publish Rust packages | crates.io API token |
| `NPM_TOKEN` | Publish npm packages | npm access token |
| `PYPI_TOKEN` | Publish Python packages | PyPI API token |
| `NUGET_API_KEY` | Publish NuGet packages | NuGet API key |

### Step-by-Step: Create REPO_ADMIN_TOKEN

This is the most important secret - it enables cross-repo automation.

1. **Go to GitHub Settings**
   ```
   https://github.com/settings/tokens?type=beta
   ```

2. **Generate new token (Fine-grained)**
   - Token name: `silica-ops-automation`
   - Expiration: 90 days (or custom)
   - Resource owner: `Silica-Protocol`

3. **Repository access**
   - Select: "All repositories" (or select specific repos)

4. **Permissions needed:**
   ```
   Repository permissions:
   ├── Contents: Read and write
   ├── Pull requests: Read and write
   ├── Workflows: Read and write
   └── Metadata: Read-only (automatically selected)
   ```

5. **Generate and copy the token**

6. **Add to organization secrets:**
   ```
   https://github.com/organizations/Silica-Protocol/settings/secrets/actions
   ```
   - Name: `REPO_ADMIN_TOKEN`
   - Value: (paste token)
   - Repository access: All repositories

### Step-by-Step: Create Package Registry Tokens

#### crates.io (Rust)

1. Go to https://crates.io/settings/tokens
2. Create new token with `publish-update` scope
3. Add as `CRATES_IO_TOKEN` in GitHub secrets

#### npm (TypeScript)

1. Go to https://www.npmjs.com/settings/YOUR_USERNAME/tokens
2. Create new "Automation" token
3. Add as `NPM_TOKEN` in GitHub secrets

#### PyPI (Python)

1. Go to https://pypi.org/manage/account/token/
2. Create new API token (scope: Entire account or specific project)
3. Add as `PYPI_TOKEN` in GitHub secrets

#### NuGet (C#)

1. Go to https://www.nuget.org/account/apikeys
2. Create new API key with push scope
3. Add as `NUGET_API_KEY` in GitHub secrets

## Repository-Specific Secrets

Some repos may need additional secrets:

### wallet repo
- `TAURI_PRIVATE_KEY` - Code signing key
- `TAURI_KEY_PASSWORD` - Key password

### infrastructure repo
- `TF_API_TOKEN` - Terraform Cloud token
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- `AZURE_CREDENTIALS`

### api repo
- `DATABASE_URL` - For integration tests

## Verifying Setup

Run this workflow to verify secrets are configured:

```yaml
# .github/workflows/verify-secrets.yml
name: Verify Secrets

on:
  workflow_dispatch: {}

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Check REPO_ADMIN_TOKEN
        run: |
          if [ -z "${{ secrets.REPO_ADMIN_TOKEN }}" ]; then
            echo "❌ REPO_ADMIN_TOKEN not set"
            exit 1
          fi
          echo "✓ REPO_ADMIN_TOKEN is configured"

      - name: Check CRATES_IO_TOKEN
        run: |
          if [ -z "${{ secrets.CRATES_IO_TOKEN }}" ]; then
            echo "⚠ CRATES_IO_TOKEN not set (optional for non-publish repos)"
          else
            echo "✓ CRATES_IO_TOKEN is configured"
          fi
```

## Security Best Practices

1. **Use fine-grained tokens** instead of classic PATs
2. **Set expiration dates** and rotate regularly
3. **Minimum scope** - only grant necessary permissions
4. **Organization secrets** - easier to manage than per-repo
5. **Audit regularly** - review token usage in GitHub audit log

## Troubleshooting

### "Resource not accessible by integration"
- Token doesn't have necessary permissions
- Solution: Regenerate with correct scopes

### "Bad credentials"
- Token expired or revoked
- Solution: Generate new token

### Cross-repo workflow not triggering
- `REPO_ADMIN_TOKEN` needs `workflow` permission
- Check "Repository access" includes target repo

## Quick Setup Script

After creating tokens, run this to verify:

```bash
# Test GitHub API access
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/orgs/Silica-Protocol/repos

# Should return list of repos if token is valid
```
