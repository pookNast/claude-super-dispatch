#!/bin/bash
# install.sh - Install claude-super-dispatch

set -euo pipefail

INSTALL_DIR="${SUPER_DISPATCH_HOME:-$HOME/.super-dispatch}"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing claude-super-dispatch..."
echo "  Install dir: $INSTALL_DIR"
echo "  Claude dir:  $CLAUDE_DIR"

# Create directories
mkdir -p "$INSTALL_DIR"/{sessions,messages/inbox,messages/outbox}
mkdir -p "$CLAUDE_DIR"/{commands/tmux-orchestrator,hooks}

# Copy library files
cp "$SCRIPT_DIR"/lib/*.py "$INSTALL_DIR/"
echo "  Copied library files"

# Copy skills
cp "$SCRIPT_DIR"/.claude/commands/super.md "$CLAUDE_DIR/commands/"
cp "$SCRIPT_DIR"/.claude/commands/tmux-orchestrator/*.md "$CLAUDE_DIR/commands/tmux-orchestrator/"
echo "  Copied skill definitions"

# Copy hooks
cp "$SCRIPT_DIR"/.claude/hooks/*.sh "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh
echo "  Copied hooks"

# Copy helper scripts
mkdir -p "$INSTALL_DIR/scripts"
if ls "$SCRIPT_DIR"/scripts/*.sh 1> /dev/null 2>&1; then
    cp "$SCRIPT_DIR"/scripts/*.sh "$INSTALL_DIR/scripts/"
    chmod +x "$INSTALL_DIR/scripts/"*.sh
    echo "  Copied scripts"
fi

# Check if env vars already set
if ! grep -q 'SUPER_DISPATCH_HOME' ~/.bashrc 2>/dev/null; then
    echo "" >> ~/.bashrc
    echo "# claude-super-dispatch" >> ~/.bashrc
    echo "export SUPER_DISPATCH_HOME=\"$INSTALL_DIR\"" >> ~/.bashrc
    echo "export PYTHONPATH=\"\${PYTHONPATH:-}:\$SUPER_DISPATCH_HOME\"" >> ~/.bashrc
    echo "  Added environment variables to ~/.bashrc"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run: source ~/.bashrc"
echo "  2. Restart Claude Code or open new terminal"
echo "  3. Try: /super py Write a hello world script"
echo ""
echo "Requirements:"
echo "  - Claude Code with MCP tmux tools enabled"
echo "  - tmux 3.0+"
echo "  - jq (for hooks)"
