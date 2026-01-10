#!/bin/bash
# Tmux Orchestrator Completion Hook
# Triggered by SubagentStop - detects completion signals and cleans up

set -euo pipefail

INPUT=$(cat)
AGENT_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null || echo "$INPUT")

# Check for orchestrator signal
if echo "$AGENT_OUTPUT" | grep -q "ORCHESTRATOR-SIGNAL"; then
    # Extract session ID from output
    SESSION_ID=$(echo "$AGENT_OUTPUT" | grep -oP 'agent-[a-zA-Z0-9-]+' | head -1 || true)
    
    if [[ -n "$SESSION_ID" ]]; then
        # Extract summary
        SUMMARY=$(echo "$AGENT_OUTPUT" | grep -oP 'SUMMARY:\s*\K.+' | head -1 || echo "Task completed")
        STATUS=$(echo "$AGENT_OUTPUT" | grep -oP 'STATUS:\s*\K\w+' | head -1 || echo "DONE")
        
        # Determine base path
        BASE_PATH="${SUPER_DISPATCH_HOME:-$HOME/.super-dispatch}"
        
        # Remove from orchestrator state
        python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
orch.remove_session('$SESSION_ID')
" 2>/dev/null || true
        
        # Kill tmux session
        tmux kill-session -t "$SESSION_ID" 2>/dev/null || true
        
        # Log completion (if kg-update-light.sh exists)
        if command -v kg-update-light.sh &> /dev/null; then
            kg-update-light.sh task_completion "$SUMMARY" --tags "orchestrator" 2>/dev/null || true
        fi
        
        # Check queue for next task
        python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
import json
orch = TmuxOrchestrator()
print(json.dumps(orch.get_queue_status()))
" 2>/dev/null || true
    fi
fi

exit 0
