---
description: "Show orchestrator status (minimal context cost)"
allowed-tools: ["Bash"]
---

# Tmux Orchestrator Status

Show current orchestrator state with minimal context usage.

## Output Format

```
=== Orchestrator Status ===
Active: 3/5 sessions
Queued: 2 tasks

Sessions:
- agent-task-001: backend (p=1) running 5m
- agent-task-002: debugger (p=2) running 2m
- agent-task-003: python (p=2) running 1m

Queue:
- task-004: devops (p=2)
- task-005: test (p=3)

Monitor: tmux attach -t orchestrator-status
```

## Implementation

```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
import json
orch = TmuxOrchestrator()
print(json.dumps(orch.get_queue_status(), indent=2))
"

python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
for s in orch.get_active_sessions():
    print(f'{s.session_id}: {s.agent_type} (p={s.priority})')
"

python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
for q in orch.queue:
    print(f'{q.task_id}: {q.agent_type} (p={q.priority})')
"
```

## Zero-Cost Streaming

To watch all agents without context cost:
```bash
tmux attach -t orchestrator-status
```

This shows live output from all agents in split panes.
