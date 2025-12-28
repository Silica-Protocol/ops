# Multi-Repository Automation

Strategies and workflows for managing Silica Protocol's distributed repository architecture.

## The Multi-Repo vs Monorepo Tradeoff

### Why Multi-Repo?

Silica Protocol uses multiple repositories because:

1. **Independent release cycles** - SDKs can release independently
2. **Language-specific tooling** - Each ecosystem has its own CI/CD
3. **Access control** - Fine-grained permissions per component
4. **Community contributions** - Easier to fork single components
5. **Package registry requirements** - crates.io, npm, PyPI expect separate repos

### Challenges We Solve

| Challenge | Solution |
|-----------|----------|
| Version drift | Centralized version registry (`ops/config/`) |
| Dependency inconsistency | Sync scripts + Renovate/Dependabot |
| Cross-repo changes | Coordinated PR workflows |
| Security patches | Automated propagation |
| Documentation sync | Central docs site with API reference |

## Automation Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ops repository                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   config/   │  │   scripts/  │  │   .github/workflows/    │ │
│  │             │  │             │  │                         │ │
│  │ versions    │  │ sync-deps   │  │ ┌─────────────────────┐ │ │
│  │ deps        │◄─┤ validate    │  │ │ Reusable Workflows  │ │ │
│  │ repos       │  │ release     │  │ │ - rust-ci.yml       │ │ │
│  └─────────────┘  └─────────────┘  │ │ - node-ci.yml       │ │ │
│                                     │ │ - python-ci.yml     │ │ │
│                                     │ │ - security.yml      │ │ │
│                                     │ └─────────────────────┘ │ │
└────────────────────────────────────│─────────────────────────│─┘
                                     │                         │
          ┌──────────────────────────┴─────────────────────────┴──┐
          │                                                       │
          ▼                                                       ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    protocol     │ │   sdk-rust      │ │ sdk-typescript  │ │   sdk-python    │
│                 │ │                 │ │                 │ │                 │
│ .github/        │ │ .github/        │ │ .github/        │ │ .github/        │
│  workflows/     │ │  workflows/     │ │  workflows/     │ │  workflows/     │
│   ci.yml ──────►│ │   ci.yml ──────►│ │   ci.yml ──────►│ │   ci.yml ──────►│
│                 │ │                 │ │                 │ │                 │
│ Uses reusable   │ │ Uses reusable   │ │ Uses reusable   │ │ Uses reusable   │
│ workflows from  │ │ workflows from  │ │ workflows from  │ │ workflows from  │
│ ops repo        │ │ ops repo        │ │ ops repo        │ │ ops repo        │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Reusable Workflows

### Rust CI Template

```yaml
# ops/.github/workflows/rust-ci.yml
name: Rust CI (Reusable)

on:
  workflow_call:
    inputs:
      rust-version:
        description: 'Rust toolchain version'
        default: 'stable'
        type: string
      run-security-audit:
        description: 'Run cargo-audit'
        default: true
        type: boolean
    secrets:
      CRATES_IO_TOKEN:
        required: false

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: dtolnay/rust-toolchain@master
        with:
          toolchain: ${{ inputs.rust-version }}
          components: rustfmt, clippy

      - name: Cache
        uses: Swatinem/rust-cache@v2

      - name: Format check
        run: cargo fmt --all -- --check

      - name: Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

      - name: Tests
        run: cargo test --workspace --all-features

      - name: Security audit
        if: inputs.run-security-audit
        run: |
          cargo install cargo-audit
          cargo audit
```

### Usage in Individual Repos

```yaml
# protocol/.github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  rust-ci:
    uses: Silica-Protocol/ops/.github/workflows/rust-ci.yml@main
    with:
      rust-version: 'stable'
      run-security-audit: true
    secrets: inherit
```

## Dependency Sync Automation

### GitHub Action: Dependency Propagation

```yaml
# ops/.github/workflows/sync-dependencies.yml
name: Sync Dependencies

on:
  push:
    paths:
      - 'config/dependencies.toml'
  workflow_dispatch: {}

jobs:
  sync:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repo:
          - protocol
          - protocol-core
          - api
          - miner
          - sdk-rust
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Checkout target repo
        uses: actions/checkout@v4
        with:
          repository: Silica-Protocol/${{ matrix.repo }}
          path: target-repo
          token: ${{ secrets.REPO_TOKEN }}

      - name: Run sync script
        run: |
          ./scripts/sync-single-repo.sh target-repo

      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          path: target-repo
          token: ${{ secrets.REPO_TOKEN }}
          commit-message: 'chore: sync dependency versions'
          title: 'chore: sync dependency versions from ops'
          body: |
            Automated dependency sync from ops/config/dependencies.toml
            
            See changes in the ops repo for details.
          branch: deps/auto-sync
          labels: dependencies, automated
```

## Security Scanning

### Cross-Repo Security Workflow

```yaml
# ops/.github/workflows/security-scan-all.yml
name: Security Scan All Repos

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch: {}

jobs:
  scan-rust-repos:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        repo: [protocol, protocol-core, api, miner, sdk-rust, contracts]
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          repository: Silica-Protocol/${{ matrix.repo }}
      
      - name: Cargo audit
        run: |
          cargo install cargo-audit
          cargo audit --json > audit-${{ matrix.repo }}.json
        continue-on-error: true
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: audit-${{ matrix.repo }}
          path: audit-${{ matrix.repo }}.json

  aggregate-results:
    needs: scan-rust-repos
    runs-on: ubuntu-latest
    steps:
      - name: Download all results
        uses: actions/download-artifact@v4
      
      - name: Aggregate and report
        run: |
          # Combine all audit results
          jq -s '.' audit-*/audit-*.json > combined-audit.json
          
          # Check for critical vulnerabilities
          CRITICAL=$(jq '[.[] | .vulnerabilities.list[] | select(.severity == "CRITICAL")] | length' combined-audit.json)
          
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Found $CRITICAL critical vulnerabilities"
            exit 1
          fi
      
      - name: Create issue if vulnerabilities found
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: 'ops',
              title: '🚨 Security vulnerabilities detected',
              body: 'Daily security scan found critical vulnerabilities. See workflow run for details.',
              labels: ['security', 'critical']
            })
```

## Cross-Repo PR Coordination

### Linked PR Workflow

When a change in `protocol-core` requires updates in `protocol`:

```yaml
# protocol-core/.github/workflows/notify-dependents.yml
name: Notify Dependent Repos

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'rs-models/src/**'  # API changes

jobs:
  check-breaking-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Detect breaking changes
        id: breaking
        run: |
          # Use cargo-semver-checks or similar
          cargo install cargo-semver-checks
          cargo semver-checks check-release 2>&1 | tee semver-report.txt
          if grep -q "BREAKING" semver-report.txt; then
            echo "breaking=true" >> $GITHUB_OUTPUT
          else
            echo "breaking=false" >> $GITHUB_OUTPUT
          fi

      - name: Notify dependent repos
        if: steps.breaking.outputs.breaking == 'true'
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.REPO_TOKEN }}
          script: |
            const dependents = ['protocol', 'api', 'miner', 'sdk-rust'];
            for (const repo of dependents) {
              await github.rest.issues.create({
                owner: 'Silica-Protocol',
                repo: repo,
                title: `⚠️ Breaking change in protocol-core PR #${context.issue.number}`,
                body: `protocol-core has breaking changes that may affect this repo.\n\nPR: ${context.payload.pull_request.html_url}`
              });
            }
```

## Monitoring and Alerts

### Repository Health Dashboard

Create a GitHub Action that generates a dashboard:

```yaml
# ops/.github/workflows/repo-health.yml
name: Repository Health Check

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday
  workflow_dispatch: {}

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Check all repos
        run: |
          ./scripts/check-all-repos.sh > health-report.md
      
      - name: Update dashboard
        run: |
          # Update README or wiki with health report
          cat health-report.md >> docs/HEALTH_DASHBOARD.md
          git add docs/HEALTH_DASHBOARD.md
          git commit -m "chore: update health dashboard"
          git push
```

## Recommended Tools

### Renovate Bot

Best for automated dependency updates:

```json
// ops/renovate-preset.json
{
  "extends": ["config:base"],
  "schedule": ["every weekend"],
  "packageRules": [
    {
      "matchPackagePatterns": ["*"],
      "groupName": "all dependencies",
      "groupSlug": "all"
    },
    {
      "matchPackagePatterns": ["pqcrypto-*", "ed25519-*"],
      "groupName": "cryptography",
      "automerge": false,
      "labels": ["security"]
    }
  ],
  "prHourlyLimit": 2,
  "prConcurrentLimit": 5
}
```

### act (Local Workflow Testing)

Test GitHub Actions locally:

```bash
# Install
brew install act

# Run workflow locally
cd ops
act -W .github/workflows/sync-dependencies.yml
```

### GitHub CLI Automation

```bash
# Bulk operations across repos
for repo in protocol protocol-core api miner; do
    gh repo clone Silica-Protocol/$repo /tmp/$repo
    cd /tmp/$repo
    gh pr list --state open --json number,title
done
```

## Best Practices Summary

1. **Centralize configuration** in `ops/config/`
2. **Use reusable workflows** for consistent CI/CD
3. **Automate dependency updates** with Renovate/Dependabot
4. **Version together** for SDK releases
5. **Security scan regularly** across all repos
6. **Document dependencies** between repos
7. **Test locally** before pushing workflows
8. **Monitor health** with automated dashboards
