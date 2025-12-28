# Silica Protocol - Operations & Cross-Repository Management

Central hub for managing operational consistency across all Silica Protocol repositories.

## Repository Inventory

### Core Repositories
| Repo | Type | Language | Description |
|------|------|----------|-------------|
| `protocol` | Core | Rust | Main blockchain node (Silica v2) |
| `protocol-core` | Library | Rust | Shared data models (`silica-models`) |
| `api` | Service | Rust | REST/RPC API server |
| `miner` | Application | Rust | Mining node implementation |
| `oracle` | Service | Rust | Price/data oracle service |
| `contracts` | WASM | Rust | Smart contract SDK & examples |
| `protocol-contracts` | Contracts | Rust | Protocol-level contracts |

### SDK Repositories
| Repo | Package Registry | Language |
|------|------------------|----------|
| `sdk-rust` | crates.io | Rust |
| `sdk-typescript` | npm | TypeScript |
| `sdk-python` | PyPI | Python |
| `sdk-go` | Go modules | Go |
| `sdk-csharp` | NuGet | C# |

### Frontend & Sites
| Repo | Framework | Description |
|------|-----------|-------------|
| `wallet` | Tauri + Vue | Desktop wallet application |
| `explorer` | Angular | Block explorer |
| `site-chert` | Static | Chert marketing site |
| `site-silica` | Static | Silica documentation site |

### Infrastructure
| Repo | Purpose |
|------|---------|
| `infrastructure` | IaC (OpenTofu/Terraform), Ansible, Docker, K8s |
| `ops` | CI/CD, automation, cross-repo management |
| `.github` | Organization-wide settings, templates |

## Quick Start

```bash
# Clone ops repo
git clone git@github.com:Silica-Protocol/ops.git
cd ops

# Run consistency checks across all repos
./scripts/check-all-repos.sh

# Sync dependency versions
./scripts/sync-dependencies.sh

# Validate SDK version consistency
./scripts/validate-sdks.sh
```

## Directory Structure

```
ops/
├── .github/workflows/           # Reusable workflow templates
├── scripts/                     # Automation scripts
│   ├── check-all-repos.sh      # Multi-repo consistency checks
│   ├── sync-dependencies.sh    # Version synchronization
│   ├── validate-sdks.sh        # SDK compatibility validation
│   └── release-all.sh          # Coordinated release
├── config/                      # Centralized configurations
│   ├── versions.toml           # Master version registry
│   ├── dependencies.toml       # Shared dependency versions
│   └── repos.toml              # Repository metadata
├── templates/                   # Shared templates
│   ├── .gitignore.rust
│   ├── .gitignore.node
│   ├── dependabot.yml
│   └── renovate.json
└── docs/                        # Documentation
    ├── DEPENDENCY_MANAGEMENT.md
    ├── SDK_CONSISTENCY.md
    ├── RELEASE_WORKFLOW.md
    └── AUTOMATION.md
```

## Documentation

- [Dependency Management Strategy](./docs/DEPENDENCY_MANAGEMENT.md)
- [SDK Consistency Guide](./docs/SDK_CONSISTENCY.md)
- [Release Workflow](./docs/RELEASE_WORKFLOW.md)
- [Automation Overview](./docs/AUTOMATION.md)

## License

MIT OR Apache-2.0
