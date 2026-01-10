#!/bin/bash
# orchestrator-cleanup.sh - Clean up stale sessions and reset state

set -euo pipefail

BASE_PATH="${SUPER_DISPATCH_HOME:-$HOME/.super-dispatch}"

echo "Orchestrator Cleanup"
echo "==================="
echo ""

# Health check
echo "Checking session health..."
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
import json
orch = TmuxOrchestrator()
health = orch.health_check()
print(f'Healthy: {len(health["healthy"])}')
print(f'Dead: {len(health["dead"])}')
for dead in health['dead']:
    print(f'  - Cleaning up: {dead}')
    orch.cleanup_session(dead)
"

echo ""

# Check for timed out sessions
echo "Checking for timed out sessions..."
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
timed_out = orch.get_timed_out_sessions()
for s in timed_out:
    print(f'  - Timed out: {s.session_id} ({s.agent_type})')
    orch.cleanup_session(s.session_id)
if not timed_out:
    print('  None')
"

echo ""
echo "Current status:"
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
import json
orch = TmuxOrchestrator()
print(json.dumps(orch.get_queue_status(), indent=2))
"
