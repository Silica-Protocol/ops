# Dependency Management Strategy

This document outlines how Silica Protocol manages dependencies across its multi-repository architecture.

## The Multi-Repo Challenge

With 19+ repositories, maintaining consistent dependencies presents challenges:

1. **Version Drift**: Repos can diverge on dependency versions
2. **Security Patches**: Vulnerabilities must be patched across all repos
3. **Breaking Changes**: Updates can break cross-repo compatibility
4. **Audit Complexity**: Security audits must cover all repos

## Solution Architecture

### Centralized Configuration

All canonical dependency versions live in `ops/config/`:

```
config/
├── versions.toml      # Protocol and package versions
├── dependencies.toml  # Shared dependency versions
└── repos.toml         # Repository metadata and dependencies
```

### Version Categories

#### 1. Locked Versions (Security Critical)

Cryptographic and security-sensitive dependencies are **version-locked** with exact versions:

```toml
[rust.cryptography]
sha3 = "=0.10.8"           # Exact version
blake3 = "=1.8.2"          # Exact version
ed25519-dalek = "=2.2.0"   # Exact version
```

**Rules:**
- Changes require security team approval
- Updates must pass full security audit
- Breaking changes require migration plan

#### 2. Pinned Versions (ABI Stability)

Serialization and data format dependencies are pinned for ABI stability:

```toml
[rust.serialization]
serde = "=1.0.228"
serde_json = "=1.0.148"
```

**Rules:**
- Must maintain backward compatibility
- Upgrades coordinated across all repos simultaneously

#### 3. Flexible Versions (Features)

Feature dependencies use semantic versioning ranges:

```toml
[rust.async]
tokio = "1.40"        # Compatible with 1.40.x
futures = "0.3"       # Compatible with 0.3.x
```

## Automation Workflows

### 1. Dependency Audit (Weekly)

```yaml
# .github/workflows/dependency-audit.yml
name: Weekly Dependency Audit
on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday
  workflow_dispatch: {}

jobs:
  audit-all-repos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: Silica-Protocol/ops
      
      - name: Audit all Rust repos
        run: |
          for repo in protocol protocol-core api miner sdk-rust; do
            gh repo clone Silica-Protocol/$repo /tmp/$repo
            cd /tmp/$repo
            cargo audit --json >> $GITHUB_STEP_SUMMARY
          done
```

### 2. Version Sync (On Release)

When `ops/config/dependencies.toml` changes:

1. Workflow triggers across all repos
2. Automated PRs update versions
3. CI validates compatibility
4. PRs auto-merge after checks pass

### 3. Security Alert Response

When GitHub/cargo-audit detects vulnerabilities:

1. Alert routed to security team
2. Evaluate impact across all repos
3. Update `dependencies.toml` 
4. Trigger sync workflow
5. Emergency release if critical

## Tooling

### Renovate Bot (Recommended)

Configure Renovate for automated dependency updates:

```json
// renovate.json (in each repo)
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",
    "github>Silica-Protocol/ops:renovate-preset"
  ],
  "packageRules": [
    {
      "matchPackagePatterns": ["^pqcrypto", "^ed25519", "^sha3", "^blake3"],
      "groupName": "cryptography",
      "automerge": false,
      "labels": ["security", "needs-review"]
    }
  ]
}
```

### Cargo Workspaces

For Rust repos, use workspace inheritance:

```toml
# Cargo.toml (workspace root)
[workspace.dependencies]
serde = { version = "=1.0.228", features = ["derive"] }

# Member Cargo.toml
[dependencies]
serde = { workspace = true }
```

### Dependabot Alternative

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      rust-crypto:
        patterns:
          - "pqcrypto-*"
          - "ed25519-*"
          - "sha3"
          - "blake3"
    labels:
      - "dependencies"
      - "security-review"
```

## Manual Sync Process

When automated sync isn't available:

```bash
# 1. Update ops/config/dependencies.toml

# 2. Run sync script
cd ops
./scripts/sync-dependencies.sh --dry-run  # Preview
./scripts/sync-dependencies.sh            # Apply

# 3. For each repo, create PR
for repo in protocol protocol-core api miner; do
    cd ../$repo
    git checkout -b deps/sync-$(date +%Y%m%d)
    # Apply changes from sync script
    cargo check
    cargo test
    git commit -am "chore: sync dependency versions"
    gh pr create --title "chore: sync dependency versions"
done
```

## Version Matrix

Track compatibility across repos:

| Component | silica-models | tokio | serde |
|-----------|--------------|-------|-------|
| protocol | 0.1.0 | 1.40 | 1.0.228 |
| api | 0.1.0 | 1.40 | 1.0.228 |
| miner | 0.1.0 | 1.40 | 1.0.228 |
| sdk-rust | 0.1.0 | 1.0 | 1.0 |

## Troubleshooting

### Cargo Version Conflicts

```bash
# Identify conflicting versions
cargo tree -d

# Find what depends on conflicting version
cargo tree -i package_name
```

### Breaking Change Detected

1. Check if change affects `silica-models` 
2. If yes, update protocol-core first
3. Then update dependent repos in order:
   - protocol
   - api, miner
   - sdk-rust
   - Other SDKs

## Security Considerations

- **Audit Trail**: All version changes tracked in git
- **Review Required**: Crypto deps require 2+ approvals
- **Supply Chain**: Use cargo-deny for license/advisory checks
- **Reproducibility**: Commit Cargo.lock for applications
