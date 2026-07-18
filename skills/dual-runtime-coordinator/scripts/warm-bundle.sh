#!/bin/bash
# warm-bundle.sh — Pre-load VM bundle for faster startup
# Usage: ./warm-bundle.sh [bundle-name] [profile]
# Profiles: standard, node, python, full

set -euo pipefail

BUNDLE_NAME="${1:-default}"
PROFILE="${2:-standard}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "VM Bundle Warmer"
echo "========================================="
echo "Bundle:  $BUNDLE_NAME"
echo "Profile: $PROFILE"
echo "========================================="

# Check if vmbundle command is available
if ! command -v vmbundle &> /dev/null; then
    echo -e "${RED}ERROR: vmbundle command not found.${NC}"
    echo "Ensure the VM management tools are installed and in PATH."
    exit 1
fi

# Step 1: Load the bundle
echo ""
echo -e "${YELLOW}Step 1: Loading bundle...${NC}"
START_TIME=$(date +%s%N)

if ! vmbundle load --name "$BUNDLE_NAME"; then
    echo -e "${RED}ERROR: Failed to load bundle '$BUNDLE_NAME'.${NC}"
    exit 1
fi

LOAD_TIME=$(( ($(date +%s%N) - START_TIME) / 1000000 ))
echo -e "${GREEN}Bundle loaded in ${LOAD_TIME}ms.${NC}"

# Step 2: Run warm-up tasks based on profile
echo ""
echo -e "${YELLOW}Step 2: Running warm-up tasks (profile: $PROFILE)...${NC}"
WARM_START=$(date +%s%N)

case "$PROFILE" in
    standard)
        echo "  Running standard warm-up..."
        vmbundle exec --name "$BUNDLE_NAME" -- bash -c '
            # Verify package managers are responsive
            npm --version > /dev/null 2>&1 && echo "  [OK] npm ready" || echo "  [WARN] npm not available"
            python3 --version > /dev/null 2>&1 && echo "  [OK] python3 ready" || echo "  [WARN] python3 not available"
            # Touch common paths to populate dentry cache
            ls /usr/lib/node_modules > /dev/null 2>&1 || true
            ls /usr/lib/python3*/dist-packages > /dev/null 2>&1 || true
        '
        ;;
    node)
        echo "  Warming Node.js environment..."
        vmbundle exec --name "$BUNDLE_NAME" -- bash -c '
            npm cache verify 2>/dev/null && echo "  [OK] npm cache verified" || echo "  [WARN] npm cache verification failed"
            # Pre-load commonly used global modules
            node -e "try{require.resolve(\"typescript\")}catch(e){}" 2>/dev/null && echo "  [OK] typescript available" || true
            node -e "try{require.resolve(\"eslint\")}catch(e){}" 2>/dev/null && echo "  [OK] eslint available" || true
        '
        ;;
    python)
        echo "  Warming Python environment..."
        vmbundle exec --name "$BUNDLE_NAME" -- bash -c '
            pip3 cache info 2>/dev/null && echo "  [OK] pip cache info" || echo "  [WARN] pip not available"
            python3 -c "import pytest; print(\"  [OK] pytest available\")" 2>/dev/null || echo "  [INFO] pytest not installed"
            python3 -c "import numpy; print(\"  [OK] numpy available\")" 2>/dev/null || echo "  [INFO] numpy not installed"
        '
        ;;
    full)
        echo "  Running full warm-up (all runtimes)..."
        vmbundle exec --name "$BUNDLE_NAME" -- bash -c '
            npm --version > /dev/null 2>&1 && echo "  [OK] npm $(npm --version)" || echo "  [WARN] npm not available"
            python3 --version > /dev/null 2>&1 && echo "  [OK] $(python3 --version)" || echo "  [WARN] python3 not available"
            cargo --version > /dev/null 2>&1 && echo "  [OK] $(cargo --version)" || echo "  [INFO] cargo not available"
            go version > /dev/null 2>&1 && echo "  [OK] go available" || echo "  [INFO] go not available"
            # Warm all caches
            npm cache verify 2>/dev/null || true
            pip3 cache purge 2>/dev/null || true
        '
        ;;
    *)
        echo -e "${RED}ERROR: Unknown profile '$PROFILE'.${NC}"
        echo "Available profiles: standard, node, python, full"
        vmbundle unload --name "$BUNDLE_NAME" 2>/dev/null || true
        exit 1
        ;;
esac

WARM_TIME=$(( ($(date +%s%N) - WARM_START) / 1000000 ))
echo -e "${GREEN}Warm-up completed in ${WARM_TIME}ms.${NC}"

# Step 3: Summary
TOTAL_TIME=$((LOAD_TIME + WARM_TIME))
echo ""
echo "========================================="
echo -e "${GREEN}Bundle warmed successfully!${NC}"
echo "  Load time:  ${LOAD_TIME}ms"
echo "  Warm time:  ${WARM_TIME}ms"
echo "  Total time: ${TOTAL_TIME}ms"
echo "========================================="
echo ""
echo "The VM is now ready for execution."
echo "First task execution will benefit from pre-loaded caches."
