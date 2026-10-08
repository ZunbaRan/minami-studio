#!/bin/sh
# Register agent-computer-use with the local Codex CLI.
#   ./scripts/install-codex.sh           # add
#   ./scripts/install-codex.sh remove    # remove
set -e
cd "$(dirname "$0")/.."
NAME="agent_computer_use"
ROOT="$(pwd)"

if [ "${1:-}" = "remove" ]; then
  codex mcp remove "$NAME" || true
  echo "removed $NAME"
  exit 0
fi

[ -x "$ROOT/bin/agent-computer-use" ] || ./scripts/build.sh
chmod +x "$ROOT/bin/agent-computer-use-mcp"

# Idempotent: remove any existing registration first.
codex mcp remove "$NAME" 2>/dev/null || true
codex mcp add "$NAME" -- "$ROOT/bin/agent-computer-use-mcp"
echo "registered: codex mcp list | grep $NAME"
codex mcp list 2>/dev/null | grep -A2 "$NAME" || true
