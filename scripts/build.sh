#!/bin/sh
# Build the native daemon and stage it where the MCP wrapper looks for it
# (mcp/../bin/agent-computer-use — same relative layout Alma uses).
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
mkdir -p bin
cp ".build/$CONFIG/agent-computer-use" bin/agent-computer-use
chmod +x bin/agent-computer-use
echo "staged bin/agent-computer-use ($CONFIG)"
