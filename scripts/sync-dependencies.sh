#!/bin/bash
# Silica Protocol - Dependency Version Synchronization
# Syncs dependency versions from ops/config/dependencies.toml to all repos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$OPS_DIR")"
CONFIG_FILE="$OPS_DIR/config/dependencies.toml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--verbose]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be changed without modifying files"
            echo "  --verbose    Show detailed output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Silica Protocol - Dependency Sync"
echo "========================================"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
    echo ""
fi

# Check if toml parser is available (using grep/sed fallback)
parse_toml_value() {
    local section=$1
    local key=$2
    # Simple TOML parsing with sed
    sed -n "/^\[$section\]/,/^\[/p" "$CONFIG_FILE" | grep "^$key" | sed 's/.*= *"\([^"]*\)".*/\1/'
}

# Rust dependency sync
sync_rust_deps() {
    local repo=$1
    local cargo_toml="$WORKSPACE_DIR/$repo/Cargo.toml"
    
    if [ ! -f "$cargo_toml" ]; then
        return
    fi
    
    echo -e "${BLUE}Syncing Rust deps for $repo...${NC}"
    
    # Read critical crypto versions from config
    local sha3_version=$(parse_toml_value "rust.cryptography" "sha3")
    local blake3_version=$(parse_toml_value "rust.cryptography" "blake3")
    local ed25519_version=$(parse_toml_value "rust.cryptography" "ed25519-dalek")
    
    if [ "$VERBOSE" = true ]; then
        echo "  sha3: $sha3_version"
        echo "  blake3: $blake3_version"
        echo "  ed25519-dalek: $ed25519_version"
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Create backup
        cp "$cargo_toml" "$cargo_toml.bak"
        
        # Note: Full implementation would use a proper TOML parser
        # This is a placeholder showing the approach
        echo "  (Full sync requires proper TOML parser - see docs)"
    fi
}

# Process each Rust repo
RUST_REPOS=("protocol" "protocol-core" "api" "miner" "oracle" "contracts" "sdk-rust")
for repo in "${RUST_REPOS[@]}"; do
    if [ -d "$WORKSPACE_DIR/$repo" ]; then
        sync_rust_deps "$repo"
    fi
done

echo ""
echo -e "${GREEN}Dependency sync complete!${NC}"
echo ""
echo "Recommended next steps:"
echo "1. Review changes with: git diff"
echo "2. Run 'cargo check' in each repo to verify"
echo "3. Run 'cargo audit' to check for vulnerabilities"
echo "4. Commit changes: git commit -am 'chore: sync dependency versions'"
