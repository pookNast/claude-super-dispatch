#!/bin/bash
# uninstall.sh - Remove claude-super-dispatch

set -euo pipefail

INSTALL_DIR="${SUPER_DISPATCH_HOME:-$HOME/.super-dispatch}"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

echo "Uninstalling claude-super-dispatch..."

# Remove skills
rm -f "$CLAUDE_DIR/commands/super.md"
rm -rf "$CLAUDE_DIR/commands/tmux-orchestrator"
echo "  Removed skills"

# Remove hooks
rm -f "$CLAUDE_DIR/hooks/tmux-orchestrator-completion.sh"
echo "  Removed hooks"

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    read -p "Remove $INSTALL_DIR and all data? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "  Removed $INSTALL_DIR"
    fi
fi

echo ""
echo "Uninstall complete!"
echo "Note: Environment variables in ~/.bashrc were not removed."
echo "You may want to manually remove SUPER_DISPATCH_HOME and PYTHONPATH entries."
