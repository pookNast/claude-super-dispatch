---
description: "Dispatch task to isolated tmux agent session"
allowed-tools: ["Bash", "mcp__tmux__*", "Read"]
argument-hint: "[task-description] [agent-type] [priority:1-3]"
---

# Tmux Orchestrator Dispatch

Dispatch a task to run in an isolated tmux session with fresh context.

## Process (Use MCP Tools - works from subagents)

### Step 1: Check capacity
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
print('yes' if orch.can_spawn() else 'no')
"
```

### Step 2: If "yes", create session via MCP

Use `mcp__tmux__create-session` with name `agent-{task-id}`:
```
mcp__tmux__create-session(name="agent-task-TIMESTAMP")
```

### Step 3: Register with orchestrator
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
orch.add_session('TASK_ID', 'AGENT_TYPE', PRIORITY)
"
```

### Step 4: Get pane ID

Use `mcp__tmux__list-windows` then `mcp__tmux__list-panes` to get pane ID.

### Step 5: Execute task via MCP

Use `mcp__tmux__execute-command` with the task prompt:
```
mcp__tmux__execute-command(
  paneId="%N",
  command="claude --dangerously-skip-permissions -p 'TASK: {description}

You are in an isolated tmux session. When complete, output:

---ORCHESTRATOR-SIGNAL---
STATUS: DONE
SUMMARY: {1-3 sentence summary}
FILES_CHANGED: {paths}
COMMIT_TYPE: feat|fix|refactor|docs|test|chore
---END-SIGNAL---

Be concise. No unnecessary exploration.'"
)
```

### Step 6: Return minimal confirmation
```
Dispatched: agent-{task-id}
Type: {agent-type}
Priority: {priority}
Monitor: tmux attach -t agent-{task-id}
```

## If at limit (5 sessions), queue instead:
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
orch = TmuxOrchestrator()
orch.queue_task('TASK_ID', 'AGENT_TYPE', PRIORITY, 'PROMPT')
print('Queued: TASK_ID (position N)')
"
```

## Priority Levels

| Priority | Use For |
|----------|---------||
| 1 (High) | Urgent fixes, blocking issues |
| 2 (Normal) | Standard tasks |
| 3 (Low) | Background work, nice-to-haves |

## Agent Types

Map to engineer-team agents:
- `backend` → backend-developer
- `debug` → debugger
- `python` → python-pro
- `devops` → devops-engineer
- `test` → test-automator
- `docs` → technical-writer

## Output

Return ONLY:
- Session name
- How to attach
- Queue position (if queued)

Do NOT return agent output - that stays in the tmux session.
