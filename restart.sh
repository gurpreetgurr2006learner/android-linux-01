#!/usr/bin/env bash
# =============================================================================
# restart.sh — First-time verification script
# =============================================================================
# Run this the first time to ensure everything is installed properly and
# services can successfully start and stop gracefully.
#
# HOW TO RUN: bash restart.sh
# =============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trap 'echo ""; echo "[restart.sh] ERROR — verification aborted."; exit 1' ERR

echo ""
echo "================================================="
echo "  [restart.sh] Testing Environment Startup"
echo "================================================="
echo ""

# ── 1. Start everything in the background ─────────────────────────────────
echo "▶ [1/4] Starting the environment (asynchronous)..."
"${SCRIPT_DIR}/start.sh" &
START_PID=$!

# Give start.sh a moment to launch Xvnc and xrdp
sleep 5

# ── 2. Wait properly for key processes and port ────────────────────────────
echo "▶ [2/4] Waiting for services to fully initialize..."
WAIT_TIMEOUT=60
WAITED=0
SERVICES_READY=false

while [ $WAITED -lt $WAIT_TIMEOUT ]; do
    if pgrep -f "xrdp" >/dev/null && pgrep -f "Xvnc" >/dev/null; then
        SERVICES_READY=true
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ "$SERVICES_READY" = true ]; then
    echo "  -> Services are up after ${WAITED}s."
    # Wait a bit more for the DE to settle before checking tools
    sleep 5
else
    echo "  -> [WARN] Timed out waiting for Xvnc/xrdp after ${WAIT_TIMEOUT}s."
    echo "  -> Continuing to verification anyway..."
fi

# ── 3. Tool verification ───────────────────────────────────────────────────
echo "▶ [3/4] Verifying CLI tools and OpenCode..."
ALL_GOOD=true
TOOLS_TO_CHECK=("opencode-ai" "openclaw" "node" "npm")

for tool in "${TOOLS_TO_CHECK[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        # Just grab the first line if the version output is noisy
        VER=$("$tool" --version 2>/dev/null | head -n 1 || echo "installed")
        echo "  -> [OK] ${tool} is available (version/status: ${VER})"
    else
        echo "  -> [FAIL] ${tool} is missing from PATH or not installed."
        ALL_GOOD=false
    fi
done

echo ""
if [ "$ALL_GOOD" = true ]; then
    echo "  ✅ All essential tools verified!"
else
    echo "  ❌ Some tools were not found. Please review the output of setup.sh."
fi
echo ""

# ── 4. Graceful stop ───────────────────────────────────────────────────────
echo "▶ [4/4] Stopping the environment gracefully..."
"${SCRIPT_DIR}/stop.sh"

# Make sure we don't return an error exit code just because of background script killing
kill "$START_PID" 2>/dev/null || true
wait "$START_PID" 2>/dev/null || true

echo ""
echo "================================================="
echo "  [restart.sh] First-time verification complete."
echo "================================================="
echo ""
