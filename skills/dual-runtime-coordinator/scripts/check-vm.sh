#!/bin/bash
# check-vm.sh — Verify VM is running and responsive
# Usage: ./check-vm.sh [vm-name] [timeout]

set -euo pipefail

VM_NAME="${1:-default}"
TIMEOUT="${2:-5}"
EXIT_CODE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if virsh is available
if ! command -v virsh &> /dev/null; then
    echo -e "${RED}ERROR: virsh not found. Install libvirt-client or equivalent.${NC}"
    exit 1
fi

# Check if VM process exists via virsh
VM_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null || echo "not-found")

if [ "$VM_STATE" = "not-found" ]; then
    echo -e "${RED}ERROR: VM '$VM_NAME' does not exist or is not managed by libvirt.${NC}"
    exit 1
fi

if [ "$VM_STATE" != "running" ]; then
    echo -e "${RED}ERROR: VM '$VM_NAME' is in state '$VM_STATE' (expected 'running').${NC}"
    exit 1
fi

echo -e "${GREEN}VM '$VM_NAME' is running.${NC}"

# Check if guest agent is responsive
echo "Testing guest agent responsiveness (timeout: ${TIMEOUT}s)..."

AGENT_RESPONSE=$(timeout "$TIMEOUT" virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' 2>/dev/null)

if [ $? -eq 0 ] && echo "$AGENT_RESPONSE" | grep -q '"return":{}'; then
    echo -e "${GREEN}Guest agent is responsive.${NC}"
else
    echo -e "${YELLOW}WARNING: VM is running but guest agent is unresponsive.${NC}"
    echo "This may indicate:"
    echo "  - Guest agent not installed or not running inside the VM"
    echo "  - VM is hung or experiencing high load"
    echo "  - Network/communication issue between host and guest"
    EXIT_CODE=2
fi

# Optional: Check resource usage if vmstat is available
if command -v virsh &> /dev/null; then
    echo ""
    echo "VM Resource Info:"
    virsh domstats "$VM_NAME" 2>/dev/null | grep -E "(cpu\.time|memory\.rss|block\..*\.rx|block\..*\.tx)" || true
fi

exit $EXIT_CODE
