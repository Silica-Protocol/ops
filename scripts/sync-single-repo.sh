#!/bin/bash
# Sync dependencies to a single repository
# Usage: ./sync-single-repo.sh <repo-path> <repo-name>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$OPS_DIR/config/dependencies.toml"
VERSIONS_FILE="$OPS_DIR/config/versions.toml"

REPO_PATH="$1"
REPO_NAME="$2"

if [ -z "$REPO_PATH" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-path> <repo-name>"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Parse TOML value (simple implementation)
get_toml_value() {
    local file=$1
    local section=$2
    local key=$3
    
    sed -n "/^\[$section\]/,/^\[/p" "$file" | grep "^$key" | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/'
}

# Get version from versions.toml
get_version() {
    local package=$1
    local section=""
    
    case $package in
        silica-models|silica|chert-sdk|chert-contracts|chert-api)
            section="packages"
            ;;
        rust|typescript|python|go|csharp)
            section="sdks"
            ;;
        *)
            section="protocol"
            ;;
    esac
    
    get_toml_value "$VERSIONS_FILE" "$section" "$package"
}

# Sync Rust Cargo.toml
sync_rust() {
    local cargo_toml="$REPO_PATH/Cargo.toml"
    
    if [ ! -f "$cargo_toml" ]; then
        log_warning "No Cargo.toml found in $REPO_PATH"
        return
    fi
    
    log_info "Syncing Rust dependencies for $REPO_NAME..."
    
    # Create backup
    cp "$cargo_toml" "$cargo_toml.bak"
    
    # Note: For production use, you'd want a proper TOML parser like `toml-cli` or `yq`
    # This is a simplified version that handles basic cases
    
    # Sync critical crypto versions
    declare -A CRYPTO_DEPS
    CRYPTO_DEPS["sha3"]=$(get_toml_value "$CONFIG_FILE" "rust.cryptography" "sha3")
    CRYPTO_DEPS["blake3"]=$(get_toml_value "$CONFIG_FILE" "rust.cryptography" "blake3")
    CRYPTO_DEPS["ed25519-dalek"]=$(get_toml_value "$CONFIG_FILE" "rust.cryptography" "ed25519-dalek")
    CRYPTO_DEPS["pqcrypto-dilithium"]=$(get_toml_value "$CONFIG_FILE" "rust.post_quantum" "pqcrypto-dilithium")
    CRYPTO_DEPS["pqcrypto-kyber"]=$(get_toml_value "$CONFIG_FILE" "rust.post_quantum" "pqcrypto-kyber")
    
    for dep in "${!CRYPTO_DEPS[@]}"; do
        version="${CRYPTO_DEPS[$dep]}"
        if [ -n "$version" ]; then
            # Handle both simple and complex dependency declarations
            # Pattern: dep = "version" or dep = { version = "version", ... }
            sed -i "s/$dep = \"[^\"]*\"/$dep = \"$version\"/" "$cargo_toml"
            sed -i "s/\($dep.*version = \)\"[^\"]*\"/\1\"$version\"/" "$cargo_toml"
        fi
    done
    
    # Verify the file is still valid TOML
    if command -v cargo &> /dev/null; then
        if ! (cd "$REPO_PATH" && cargo verify-project > /dev/null 2>&1); then
            log_warning "Cargo.toml may be invalid - restoring backup"
            mv "$cargo_toml.bak" "$cargo_toml"
            return 1
        fi
    fi
    
    rm "$cargo_toml.bak"
    log_info "Done syncing $REPO_NAME"
}

# Sync Node.js package.json
sync_node() {
    local package_json="$REPO_PATH/package.json"
    
    if [ ! -f "$package_json" ]; then
        log_warning "No package.json found in $REPO_PATH"
        return
    fi
    
    log_info "Syncing Node.js dependencies for $REPO_NAME..."
    
    # Get TypeScript version from config
    TS_VERSION=$(get_toml_value "$CONFIG_FILE" "typescript.core" "typescript")
    
    if [ -n "$TS_VERSION" ] && command -v npm &> /dev/null; then
        (cd "$REPO_PATH" && npm pkg set devDependencies.typescript="$TS_VERSION" 2>/dev/null || true)
    fi
    
    log_info "Done syncing $REPO_NAME"
}

# Sync Python setup
sync_python() {
    log_info "Syncing Python dependencies for $REPO_NAME..."
    
    # Python dependencies would be synced via pyproject.toml or requirements.txt
    # This is a placeholder for the pattern
    
    log_info "Done syncing $REPO_NAME"
}

# Determine repo type and sync
case $REPO_NAME in
    protocol|protocol-core|api|miner|oracle|contracts|protocol-contracts|sdk-rust)
        sync_rust
        ;;
    sdk-typescript|explorer|wallet)
        sync_node
        # Wallet also has Rust (Tauri)
        if [ "$REPO_NAME" = "wallet" ]; then
            sync_rust
        fi
        ;;
    sdk-python)
        sync_python
        ;;
    *)
        log_warning "Unknown repo type: $REPO_NAME"
        ;;
esac
