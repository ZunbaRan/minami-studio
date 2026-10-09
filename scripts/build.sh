#!/bin/sh
# Build the native daemon and stage it where the MCP wrapper looks for it
# (mcp/../bin/minami-studio — same relative layout Alma uses).
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
mkdir -p bin
cp ".build/$CONFIG/minami-studio" bin/minami-studio
chmod +x bin/minami-studio
echo "staged bin/minami-studio ($CONFIG)"
