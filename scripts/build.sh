#!/bin/sh
# Build the native daemon and stage it where the MCP wrapper looks for it
# (mcp/../bin/minami-computer-use — same relative layout Alma uses).
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
mkdir -p bin
cp ".build/$CONFIG/minami-computer-use" bin/minami-computer-use
chmod +x bin/minami-computer-use
echo "staged bin/minami-computer-use ($CONFIG)"
