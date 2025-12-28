# Release Workflow

Coordinated release process for Silica Protocol's multi-repository architecture.

## Version Strategy

### Semantic Versioning

All packages follow [SemVer](https://semver.org/):

```
MAJOR.MINOR.PATCH[-PRERELEASE]

0.1.0        - Initial development
0.1.1        - Patch release
0.2.0-alpha  - Pre-release
1.0.0        - First stable release
```

### Version Channels

| Channel | Purpose | Stability | Auto-Deploy |
|---------|---------|-----------|-------------|
| `dev` | Development builds | Unstable | No |
| `alpha` | Early testing | Breaking changes expected | Testnet |
| `beta` | Feature complete | API stable | Testnet |
| `stable` | Production ready | Full compatibility | Mainnet |

## Release Types

### 1. Patch Release (0.1.X)

Bug fixes, security patches. No breaking changes.

**Trigger:** Critical bug or security vulnerability

**Process:**
1. Create hotfix branch from latest release tag
2. Apply fix
3. Update patch version
4. PR → review → merge
5. Automated release

### 2. Minor Release (0.X.0)

New features, non-breaking changes.

**Trigger:** Feature milestone completion

**Process:**
1. Feature freeze on `develop`
2. Create release branch `release/v0.X.0`
3. QA and stabilization
4. Update version numbers
5. Final review → merge to `main`
6. Tag and release

### 3. Major Release (X.0.0)

Breaking changes, major milestones.

**Trigger:** Protocol upgrade, breaking API changes

**Process:**
1. Publish migration guide
2. Extended beta period
3. Coordinated release across all repos
4. Mainnet upgrade procedure

## Release Checklist

### Pre-Release

```markdown
## Release v0.X.0 Checklist

### Code Quality
- [ ] All CI checks passing
- [ ] No critical/high vulnerabilities (cargo audit)
- [ ] Test coverage maintained (>80%)
- [ ] No TODO/FIXME in release code

### Documentation
- [ ] CHANGELOG.md updated
- [ ] API documentation current
- [ ] Migration guide (if breaking changes)
- [ ] README version badges updated

### Cross-Repo Coordination
- [ ] ops/config/versions.toml updated
- [ ] All SDK versions aligned
- [ ] Dependency versions synced
- [ ] Integration tests passing

### Security
- [ ] Security review completed
- [ ] Cryptographic changes audited
- [ ] No hardcoded credentials
- [ ] Container images scanned

### Testing
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Testnet deployment verified
- [ ] SDK compatibility verified
```

## Automated Release Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate version consistency
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          # Check all package versions match
          ./scripts/validate-versions.sh $VERSION

  release-rust:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      
      - name: Publish to crates.io
        run: cargo publish --token ${{ secrets.CRATES_IO_TOKEN }}

  release-npm:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          registry-url: 'https://registry.npmjs.org'
      
      - name: Publish to npm
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

  create-github-release:
    needs: [release-rust, release-npm]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate release notes
        run: |
          # Extract changelog for this version
          ./scripts/extract-changelog.sh > RELEASE_NOTES.md
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          body_path: RELEASE_NOTES.md
          generate_release_notes: true
```

## Release Coordination Script

```bash
#!/bin/bash
# scripts/release-all.sh
# Coordinates release across all repositories

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.2.0"
    exit 1
fi

REPOS=(
    "protocol-core"
    "protocol"
    "api"
    "miner"
    "sdk-rust"
    "sdk-typescript"
    "sdk-python"
    "sdk-go"
    "sdk-csharp"
)

echo "🚀 Starting release v$VERSION"

# Step 1: Update version in ops/config
echo "📝 Updating version registry..."
sed -i "s/version = \".*\"/version = \"$VERSION\"/" config/versions.toml
git add config/versions.toml
git commit -m "chore: bump version to $VERSION"
git push

# Step 2: Create release PRs in each repo
for repo in "${REPOS[@]}"; do
    echo "📦 Processing $repo..."
    
    # Clone if needed
    if [ ! -d "/tmp/release-$repo" ]; then
        gh repo clone Silica-Protocol/$repo /tmp/release-$repo
    fi
    
    cd /tmp/release-$repo
    git checkout main
    git pull
    git checkout -b release/v$VERSION
    
    # Update version (repo-specific)
    case $repo in
        protocol*|api|miner|sdk-rust)
            sed -i "s/version = \".*\"/version = \"$VERSION\"/" Cargo.toml
            cargo check  # Verify
            ;;
        sdk-typescript)
            npm version $VERSION --no-git-tag-version
            ;;
        sdk-python)
            sed -i "s/version=.*,/version=\"$VERSION\",/" setup.py
            ;;
        sdk-go)
            # Go uses git tags, no version file
            ;;
        sdk-csharp)
            sed -i "s/<Version>.*<\/Version>/<Version>$VERSION<\/Version>/" *.csproj
            ;;
    esac
    
    git add -A
    git commit -m "chore: release v$VERSION"
    git push -u origin release/v$VERSION
    
    # Create PR
    gh pr create \
        --title "Release v$VERSION" \
        --body "Automated release PR for v$VERSION" \
        --label "release"
    
    cd -
done

echo "✅ Release PRs created"
echo ""
echo "Next steps:"
echo "1. Review and merge all release PRs"
echo "2. Tag each repo: git tag v$VERSION && git push --tags"
echo "3. GitHub Actions will handle publishing"
```

## Post-Release

### Announcement Template

```markdown
# Silica Protocol v0.X.0 Released

We're excited to announce the release of Silica Protocol v0.X.0!

## Highlights

- Feature 1
- Feature 2
- Performance improvements

## Installation

### Rust
```toml
[dependencies]
chert-sdk = "0.X.0"
```

### TypeScript
```bash
npm install @silica-protocol/sdk@0.X.0
```

### Python
```bash
pip install chert-sdk==0.X.0
```

## Migration Guide

See [MIGRATION.md](link) for breaking changes.

## Full Changelog

See [CHANGELOG.md](link) for complete details.
```

### Rollback Procedure

If critical issues discovered post-release:

1. **Immediate:** Publish advisory, yank/deprecate package
2. **Short-term:** Hotfix or revert to previous version
3. **Communication:** Update status page, notify users

```bash
# Yank Rust package
cargo yank --version 0.X.0 chert-sdk

# Deprecate npm package
npm deprecate @silica-protocol/sdk@0.X.0 "Critical bug - use 0.X.1"

# Revert Python
# (PyPI doesn't support yanking - publish 0.X.1 quickly)
```

## Version History

Track all releases in `ops/RELEASES.md`:

```markdown
# Release History

## v0.1.0 (2025-01-XX)
- Initial public release
- Core protocol implementation
- All five SDKs

## v0.0.1-alpha (2024-XX-XX)
- Internal testing release
```
