#!/bin/bash
# Push dependabot configurations to all repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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
    "infrastructure"
    "ops"
)

echo "========================================"
echo "Push Dependabot Configs to All Repos"
echo "========================================"
echo ""

for repo in "${REPOS[@]}"; do
    repo_path="$WORKSPACE_DIR/$repo"
    
    if [ ! -d "$repo_path" ]; then
        echo -e "${YELLOW}⚠ $repo - not found, skipping${NC}"
        continue
    fi
    
    if [ ! -f "$repo_path/.github/dependabot.yml" ]; then
        echo -e "${YELLOW}⚠ $repo - no dependabot.yml, skipping${NC}"
        continue
    fi
    
    echo -e "📦 ${GREEN}$repo${NC}"
    
    cd "$repo_path"
    
    # Check if there are changes
    if git diff --quiet .github/dependabot.yml 2>/dev/null; then
        # File might be new (untracked)
        if git ls-files --error-unmatch .github/dependabot.yml >/dev/null 2>&1; then
            echo "   Already committed"
            continue
        fi
    fi
    
    # Stage and commit
    git add .github/dependabot.yml
    git commit -m "ci: add Dependabot configuration for automated dependency updates

- Weekly dependency update PRs on Mondays
- Grouped updates for crypto, async, testing packages
- Security and CI labels for proper review routing
- Coordinated with ops/config for version management" || echo "   Nothing to commit"
    
    # Push (uncomment when ready)
    # git push origin main
    
    echo "   ✓ Committed (push manually or uncomment in script)"
done

echo ""
echo "========================================"
echo "Next: Push all repos"
echo "========================================"
echo ""
echo "Run this to push all changes:"
echo ""
echo "for repo in ${REPOS[*]}; do"
echo "    cd \$WORKSPACE_DIR/\$repo && git push origin main"
echo "done"
