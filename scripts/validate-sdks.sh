#!/bin/bash
# Silica Protocol - SDK Consistency Validator
# Ensures all SDKs implement the same API surface and version

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

echo "========================================"
echo "Silica Protocol - SDK Consistency Validator"
echo "========================================"
echo ""

ERRORS=0

# Define required SDK methods/endpoints
REQUIRED_METHODS=(
    "getBalance"
    "sendTransaction"
    "getTransaction"
    "getBlock"
    "getBlockByHash"
    "getLatestBlock"
    "connect"
    "disconnect"
)

check_rust_sdk() {
    local sdk_path="$WORKSPACE_DIR/sdk-rust/src"
    echo -e "${BLUE}Checking sdk-rust...${NC}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}  sdk-rust/src not found${NC}"
        ((ERRORS++))
        return
    fi
    
    for method in "${REQUIRED_METHODS[@]}"; do
        # Convert camelCase to snake_case for Rust
        local rust_method=$(echo "$method" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
        
        if grep -rq "fn $rust_method\|pub fn $rust_method\|pub async fn $rust_method" "$sdk_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $rust_method"
        else
            echo -e "  ${YELLOW}⚠${NC} $rust_method - not found"
        fi
    done
}

check_typescript_sdk() {
    local sdk_path="$WORKSPACE_DIR/sdk-typescript/src"
    echo -e "${BLUE}Checking sdk-typescript...${NC}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}  sdk-typescript/src not found${NC}"
        ((ERRORS++))
        return
    fi
    
    for method in "${REQUIRED_METHODS[@]}"; do
        if grep -rq "$method\|$method(" "$sdk_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $method"
        else
            echo -e "  ${YELLOW}⚠${NC} $method - not found"
        fi
    done
}

check_python_sdk() {
    local sdk_path="$WORKSPACE_DIR/sdk-python/chert_sdk"
    echo -e "${BLUE}Checking sdk-python...${NC}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}  sdk-python/chert_sdk not found${NC}"
        ((ERRORS++))
        return
    fi
    
    for method in "${REQUIRED_METHODS[@]}"; do
        # Convert camelCase to snake_case for Python
        local python_method=$(echo "$method" | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
        
        if grep -rq "def $python_method\|async def $python_method" "$sdk_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $python_method"
        else
            echo -e "  ${YELLOW}⚠${NC} $python_method - not found"
        fi
    done
}

check_go_sdk() {
    local sdk_path="$WORKSPACE_DIR/sdk-go"
    echo -e "${BLUE}Checking sdk-go...${NC}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}  sdk-go not found${NC}"
        ((ERRORS++))
        return
    fi
    
    for method in "${REQUIRED_METHODS[@]}"; do
        # Convert first letter to uppercase for Go
        local go_method=$(echo "$method" | sed 's/^\(.\)/\U\1/')
        
        if grep -rq "func.*$go_method\|func ($go_method" "$sdk_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $go_method"
        else
            echo -e "  ${YELLOW}⚠${NC} $go_method - not found"
        fi
    done
}

check_csharp_sdk() {
    local sdk_path="$WORKSPACE_DIR/sdk-csharp"
    echo -e "${BLUE}Checking sdk-csharp...${NC}"
    
    if [ ! -d "$sdk_path" ]; then
        echo -e "${RED}  sdk-csharp not found${NC}"
        ((ERRORS++))
        return
    fi
    
    for method in "${REQUIRED_METHODS[@]}"; do
        # C# uses PascalCase
        local csharp_method=$(echo "$method" | sed 's/^\(.\)/\U\1/')
        
        if grep -rq "$csharp_method\|public.*$csharp_method" "$sdk_path" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $csharp_method"
        else
            echo -e "  ${YELLOW}⚠${NC} $csharp_method - not found"
        fi
    done
}

# Version consistency check
echo "📊 Checking version consistency..."
echo ""

RUST_VERSION=$(grep -m1 'version = "' "$WORKSPACE_DIR/sdk-rust/Cargo.toml" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "N/A")
TS_VERSION=$(grep -m1 '"version":' "$WORKSPACE_DIR/sdk-typescript/package.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "N/A")
PY_VERSION=$(grep -m1 'version=' "$WORKSPACE_DIR/sdk-python/setup.py" 2>/dev/null | sed 's/.*= *"\([^"]*\)".*/\1/' || echo "N/A")

echo "SDK Versions:"
echo "  Rust:       $RUST_VERSION"
echo "  TypeScript: $TS_VERSION"
echo "  Python:     $PY_VERSION"
echo ""

if [ "$RUST_VERSION" != "$TS_VERSION" ] || [ "$TS_VERSION" != "$PY_VERSION" ]; then
    echo -e "${YELLOW}⚠ Version mismatch detected - SDKs should be versioned together${NC}"
fi
echo ""

# Run all checks
check_rust_sdk
echo ""
check_typescript_sdk
echo ""
check_python_sdk
echo ""
check_go_sdk
echo ""
check_csharp_sdk
echo ""

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}$ERRORS SDK directories missing${NC}"
    exit 1
else
    echo -e "${GREEN}All SDK directories found${NC}"
fi

echo ""
echo "Note: Yellow warnings indicate methods not found - may need implementation"
echo "See docs/SDK_CONSISTENCY.md for the full API specification"
