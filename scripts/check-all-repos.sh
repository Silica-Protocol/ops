#!/bin/bash
# Silica Protocol - Multi-Repository Consistency Checker
# Validates that all repos follow organization standards

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$OPS_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load repository list from config
REPOS=(
    "protocol"
    "protocol-core"
    "api"
    "miner"
    "oracle"
    "contracts"
    "protocol-contracts"
    "sdk-rust"
    "sdk-typescript"
    "sdk-python"
    "sdk-go"
    "sdk-csharp"
    "wallet"
    "explorer"
    "site-chert"
    "site-silica"
    "infrastructure"
)

RUST_REPOS=("protocol" "protocol-core" "api" "miner" "oracle" "contracts" "protocol-contracts" "sdk-rust")
NODE_REPOS=("sdk-typescript" "explorer" "wallet")
PYTHON_REPOS=("sdk-python")
GO_REPOS=("sdk-go")

ERRORS=0
WARNINGS=0

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
    ((ERRORS++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNINGS++))
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_info() {
    echo -e "   $1"
}

echo "========================================"
echo "Silica Protocol - Repository Consistency Check"
echo "========================================"
echo ""

# Check 1: Required files
echo "📁 Checking required files..."
for repo in "${REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        log_warning "$repo - Directory not found"
        continue
    fi

    # Check LICENSE
    if [ ! -f "$repo_path/LICENSE-MIT" ] && [ ! -f "$repo_path/LICENSE" ]; then
        log_error "$repo - Missing LICENSE file"
    fi

    # Check README
    if [ ! -f "$repo_path/README.md" ]; then
        log_error "$repo - Missing README.md"
    fi

    # Check .gitignore
    if [ ! -f "$repo_path/.gitignore" ]; then
        log_warning "$repo - Missing .gitignore"
    fi
done
echo ""

# Check 2: Rust repositories - Cargo.toml consistency
echo "🦀 Checking Rust repos (Cargo.toml)..."
for repo in "${RUST_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        continue
    fi

    cargo_toml="$repo_path/Cargo.toml"
    if [ ! -f "$cargo_toml" ]; then
        log_error "$repo - Missing Cargo.toml"
        continue
    fi

    # Check for workspace edition
    if ! grep -q 'edition = "2024"\|edition.workspace = true' "$cargo_toml"; then
        log_warning "$repo - Not using edition 2024 or workspace edition"
    fi

    # Check for license
    if ! grep -q 'license.*MIT.*Apache\|license.workspace = true' "$cargo_toml"; then
        log_warning "$repo - Missing dual MIT/Apache-2.0 license"
    fi

    # Check for deny.toml (cargo-deny)
    if [ ! -f "$repo_path/deny.toml" ]; then
        log_warning "$repo - Missing deny.toml for cargo-deny"
    fi

    # Check for clippy.toml
    if [ ! -f "$repo_path/clippy.toml" ]; then
        log_info "$repo - Consider adding clippy.toml for lint configuration"
    fi
done
echo ""

# Check 3: Node.js repositories
echo "📦 Checking Node.js repos (package.json)..."
for repo in "${NODE_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        continue
    fi

    package_json="$repo_path/package.json"
    if [ ! -f "$package_json" ]; then
        log_error "$repo - Missing package.json"
        continue
    fi

    # Check for lockfile
    if [ ! -f "$repo_path/package-lock.json" ] && [ ! -f "$repo_path/pnpm-lock.yaml" ]; then
        log_warning "$repo - Missing lockfile (package-lock.json or pnpm-lock.yaml)"
    fi

    # Check for test script
    if ! grep -q '"test"' "$package_json"; then
        log_warning "$repo - Missing 'test' script in package.json"
    fi

    # Check for lint script
    if ! grep -q '"lint"' "$package_json"; then
        log_warning "$repo - Missing 'lint' script in package.json"
    fi
done
echo ""

# Check 4: Python repositories
echo "🐍 Checking Python repos..."
for repo in "${PYTHON_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        continue
    fi

    if [ ! -f "$repo_path/setup.py" ] && [ ! -f "$repo_path/pyproject.toml" ]; then
        log_error "$repo - Missing setup.py or pyproject.toml"
    fi

    if [ ! -f "$repo_path/requirements.txt" ] && [ ! -f "$repo_path/pyproject.toml" ]; then
        log_warning "$repo - Missing requirements.txt"
    fi
done
echo ""

# Check 5: Go repositories
echo "🐹 Checking Go repos..."
for repo in "${GO_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        continue
    fi

    if [ ! -f "$repo_path/go.mod" ]; then
        log_error "$repo - Missing go.mod"
    fi

    if [ ! -f "$repo_path/go.sum" ]; then
        log_warning "$repo - Missing go.sum"
    fi
done
echo ""

# Check 6: GitHub Actions workflows
echo "🔧 Checking CI/CD workflows..."
for repo in "${REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    workflows_path="$repo_path/.github/workflows"
    
    if [ ! -d "$workflows_path" ]; then
        log_warning "$repo - Missing .github/workflows directory"
    fi
done
echo ""

# Check 7: Security files
echo "🔐 Checking security configuration..."
for repo in "${RUST_REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    if [ ! -d "$repo_path" ]; then
        continue
    fi

    # Check for Cargo.lock (for reproducible builds)
    if [ -f "$repo_path/Cargo.toml" ] && [ ! -f "$repo_path/Cargo.lock" ]; then
        # Libraries typically don't commit Cargo.lock
        if grep -q '^\[lib\]' "$repo_path/Cargo.toml" 2>/dev/null; then
            log_info "$repo - Library without Cargo.lock (OK for libraries)"
        else
            log_warning "$repo - Binary/application missing Cargo.lock"
        fi
    fi
done
echo ""

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Errors: $ERRORS${NC}"
fi
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
fi

echo ""
echo "Run './scripts/sync-dependencies.sh' to fix version inconsistencies"
echo "Run './scripts/generate-configs.sh' to generate missing configuration files"

exit $ERRORS
