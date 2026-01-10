---
description: "Dispatch tasks to engineer_team agents in isolated tmux sessions"
allowed-tools: ["Task", "Read", "Bash", "mcp__tmux__create-session", "mcp__tmux__execute-command", "mcp__tmux__list-sessions", "mcp__tmux__capture-pane"]
argument-hint: "[agent-type] task description OR list of tasks"
---

# Super - Fast Agent Dispatch

Dispatch tasks to engineer_team agents running in isolated tmux sessions. Full output stays in tmux, only DONE signals return here.

## Usage

```
/super [agent-type] task description
/super list of tasks (auto-selects agent types)
```

## Agent Types

| Short | Full | Use For |
|-------|------|---------||
| be | backend-developer | APIs, server code, databases |
| fe | frontend-developer | UI, React, CSS |
| py | python-pro | Python code, scripts |
| db | debugger | Bug investigation |
| dev | devops-engineer | Deploy, infra, docker |
| sec | security-engineer | Security audit, vulnerabilities |
| test | test-automator | Tests, coverage |
| api | api-designer | API design, endpoints |

## Dispatch Flow

1. Parse task(s) from argument
2. For each task:
   - Check orchestrator capacity (max 5 concurrent)
   - Create tmux session via MCP tools
   - Register in orchestrator state
   - Spawn bash subagent to run claude in the session
3. Return dispatch summary only (not full output)

## Implementation

When user invokes `/super`:

1. Parse the argument to extract agent type and task description
2. Use bash subagent to dispatch:

```python
Task(
    subagent_type="bash-agent",
    model="haiku",
    prompt=f"""
Dispatch task to tmux session:

1. Check capacity:
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from tmux_orchestrator import TmuxOrchestrator
o = TmuxOrchestrator()
print('CAN_SPAWN' if o.can_spawn() else 'QUEUE')
"

2. If CAN_SPAWN, create session and dispatch:
- Use mcp__tmux__create-session with name "agent-{{task_id}}"
- Register: python3 -c "import sys, os; sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch'))); from tmux_orchestrator import TmuxOrchestrator; o = TmuxOrchestrator(); o.add_session('{{task_id}}', '{{agent_type}}')"
- Execute claude in session with the task prompt

3. If QUEUE, add to queue:
python3 -c "import sys, os; sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch'))); from tmux_orchestrator import TmuxOrchestrator; o = TmuxOrchestrator(); o.queue_task('{{task_id}}', '{{agent_type}}', prompt='{{task}}')"

OUTPUT REQUIREMENTS (MANDATORY):
- Session ID created or queued
- Status: dispatched/queued
- 1 sentence summary
"""
)
```

## Agent Prompt Template

When spawning claude in tmux session, use this prompt structure:

```
You are a {agent_type} agent running in an isolated tmux session.

TASK: {task_description}

WORKING DIRECTORY: {cwd}

When complete, output this signal:
---ORCHESTRATOR-SIGNAL---
STATUS: DONE
SUMMARY: {1-3 sentence summary}
FILES_CHANGED: {paths}
COMMIT_TYPE: feat|fix|refactor|docs|test|chore
---END-SIGNAL---

Keep your work focused. Your full output stays here in tmux.
Only the DONE signal returns to the orchestrator.
```

## Examples

```bash
# Single task with explicit agent
/super be Add rate limiting to the API endpoints

# Single task with short alias
/super py Refactor the data processing pipeline

# Auto-detect agent from task
/super Fix the login bug in auth.py

# Multiple tasks (newline or semicolon separated)
/super be Add caching; py Write tests for cache; db Debug cache misses
```

## Quick Status

After dispatching, check status with:
- `/tmux-orchestrator:status` - See active/queued counts
- `tmux list-sessions` - See raw tmux sessions
- `/tmux-orchestrator:peek agent-{id}` - View specific agent output
