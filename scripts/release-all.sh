#!/bin/bash
# Silica Protocol - Coordinated Release Script
# Releases all packages with the same version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$OPS_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VERSION=""
DRY_RUN=false
CHANNEL="stable"  # dev, alpha, beta, stable
SKIP_TESTS=false

usage() {
    echo "Usage: $0 <version> [options]"
    echo ""
    echo "Arguments:"
    echo "  version    Semantic version (e.g., 0.2.0)"
    echo ""
    echo "Options:"
    echo "  --dry-run       Preview changes without executing"
    echo "  --channel       Release channel: dev, alpha, beta, stable (default: stable)"
    echo "  --skip-tests    Skip test verification (dangerous!)"
    echo "  --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 0.2.0                      # Stable release"
    echo "  $0 0.2.0 --channel alpha      # Alpha release"
    echo "  $0 0.2.0 --dry-run            # Preview only"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$1"
            else
                log_error "Unknown argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate version
if [ -z "$VERSION" ]; then
    log_error "Version is required"
    usage
    exit 1
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_error "Invalid version format. Expected: X.Y.Z"
    exit 1
fi

# Validate channel
case $CHANNEL in
    dev|alpha|beta|stable) ;;
    *)
        log_error "Invalid channel: $CHANNEL"
        exit 1
        ;;
esac

echo "========================================"
echo "Silica Protocol - Coordinated Release"
echo "========================================"
echo ""
echo "Version:  $VERSION"
echo "Channel:  $CHANNEL"
echo "Dry Run:  $DRY_RUN"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE - No changes will be made"
    echo ""
fi

# Define repositories in release order
RUST_CORE_REPOS=("protocol-core")
RUST_MAIN_REPOS=("protocol" "api" "miner" "oracle" "contracts")
SDK_REPOS=("sdk-rust" "sdk-typescript" "sdk-python" "sdk-go" "sdk-csharp")
FRONTEND_REPOS=("wallet" "explorer")

# Step 1: Update version registry
log_info "Updating version registry..."
VERSION_FILE="$OPS_DIR/config/versions.toml"

if [ "$DRY_RUN" = false ]; then
    sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$VERSION_FILE"
    sed -i "s/^channel = \".*\"/channel = \"$CHANNEL\"/" "$VERSION_FILE"
    sed -i "s/^release_date = \".*\"/release_date = \"$(date -I)\"/" "$VERSION_FILE"
    
    # Update all SDK versions
    for lang in rust typescript python go csharp; do
        sed -i "s/^$lang = \".*\"/$lang = \"$VERSION\"/" "$VERSION_FILE"
    done
    
    log_success "Updated $VERSION_FILE"
else
    log_info "Would update $VERSION_FILE"
fi

# Step 2: Pre-flight checks
log_info "Running pre-flight checks..."

# Check if all repos exist
for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}" "${SDK_REPOS[@]}"; do
    if [ ! -d "$WORKSPACE_DIR/$repo" ]; then
        log_warning "Repository not found: $repo"
    fi
done

# Check for uncommitted changes
for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}" "${SDK_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ -d "$repo_path/.git" ]; then
        if ! git -C "$repo_path" diff --quiet 2>/dev/null; then
            log_warning "$repo has uncommitted changes"
        fi
    fi
done

# Step 3: Run tests (unless skipped)
if [ "$SKIP_TESTS" = false ]; then
    log_info "Running tests..."
    
    for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}"; do
        repo_path="$WORKSPACE_DIR/$repo"
        if [ -d "$repo_path" ] && [ -f "$repo_path/Cargo.toml" ]; then
            log_info "Testing $repo..."
            if [ "$DRY_RUN" = false ]; then
                (cd "$repo_path" && cargo test --workspace) || {
                    log_error "Tests failed for $repo"
                    exit 1
                }
            fi
        fi
    done
    
    log_success "All tests passed"
else
    log_warning "Skipping tests (--skip-tests)"
fi

# Step 4: Update versions in each repository
log_info "Updating version numbers..."

# Rust repos
for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}" "sdk-rust"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ -d "$repo_path" ] && [ -f "$repo_path/Cargo.toml" ]; then
        log_info "Updating $repo/Cargo.toml..."
        if [ "$DRY_RUN" = false ]; then
            # Update main package version
            sed -i "0,/^version = \".*\"/s//version = \"$VERSION\"/" "$repo_path/Cargo.toml"
        fi
    fi
done

# TypeScript SDK
TS_REPO="$WORKSPACE_DIR/sdk-typescript"
if [ -d "$TS_REPO" ] && [ -f "$TS_REPO/package.json" ]; then
    log_info "Updating sdk-typescript/package.json..."
    if [ "$DRY_RUN" = false ]; then
        cd "$TS_REPO"
        npm version "$VERSION" --no-git-tag-version
    fi
fi

# Python SDK
PY_REPO="$WORKSPACE_DIR/sdk-python"
if [ -d "$PY_REPO" ]; then
    log_info "Updating sdk-python..."
    if [ "$DRY_RUN" = false ]; then
        if [ -f "$PY_REPO/setup.py" ]; then
            sed -i "s/version=.*,/version=\"$VERSION\",/" "$PY_REPO/setup.py"
        fi
        if [ -f "$PY_REPO/pyproject.toml" ]; then
            sed -i "s/^version = \".*\"/version = \"$VERSION\"/" "$PY_REPO/pyproject.toml"
        fi
    fi
fi

log_success "Version numbers updated"

# Step 5: Generate changelog entries
log_info "Changelog update reminder..."
echo ""
echo "Remember to update CHANGELOG.md in each repo with:"
echo ""
echo "## [$VERSION] - $(date -I)"
echo ""
echo "### Added"
echo "- (your features)"
echo ""
echo "### Changed"
echo "- (your changes)"
echo ""
echo "### Fixed"
echo "- (your fixes)"
echo ""

# Step 6: Create release commits and tags
if [ "$DRY_RUN" = false ]; then
    log_info "Creating release commits..."
    
    for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}" "${SDK_REPOS[@]}"; do
        repo_path="$WORKSPACE_DIR/$repo"
        if [ -d "$repo_path/.git" ]; then
            cd "$repo_path"
            if ! git diff --quiet 2>/dev/null; then
                git add -A
                git commit -m "chore: release v$VERSION"
                log_success "$repo: committed"
            fi
        fi
    done
    
    log_info "Creating tags..."
    for repo in "${RUST_CORE_REPOS[@]}" "${RUST_MAIN_REPOS[@]}" "${SDK_REPOS[@]}"; do
        repo_path="$WORKSPACE_DIR/$repo"
        if [ -d "$repo_path/.git" ]; then
            cd "$repo_path"
            git tag -a "v$VERSION" -m "Release v$VERSION"
            log_success "$repo: tagged v$VERSION"
        fi
    done
fi

# Summary
echo ""
echo "========================================"
echo "Release Preparation Complete"
echo "========================================"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "This was a dry run. No changes were made."
    echo ""
    echo "To execute the release, run:"
    echo "  $0 $VERSION --channel $CHANNEL"
else
    echo "Next steps:"
    echo ""
    echo "1. Review changes in each repo:"
    echo "   git diff HEAD~1"
    echo ""
    echo "2. Push changes and tags:"
    echo "   for repo in protocol protocol-core api miner sdk-rust sdk-typescript sdk-python; do"
    echo "     cd \$repo && git push && git push --tags && cd .."
    echo "   done"
    echo ""
    echo "3. GitHub Actions will automatically:"
    echo "   - Run CI checks"
    echo "   - Publish to package registries"
    echo "   - Create GitHub releases"
    echo ""
    echo "4. Monitor releases at:"
    echo "   https://github.com/Silica-Protocol"
fi
