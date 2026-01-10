# claude-super-dispatch

> Context-optimized agent dispatch for Claude Code - run parallel agents in isolated tmux sessions

## Why?

When running multiple Claude Code agents, their outputs consume significant context tokens, degrading the orchestrator's ability to manage complex workflows. This tool isolates agent execution in tmux sessions, returning only completion signals to the main context.

**Result:** 90%+ context savings vs inline agent execution.

## Features

- **`/super` command** - Fast dispatch to specialized agents
- **Max 5 concurrent sessions** - Automatic queuing when at capacity
- **Priority system** - High-priority tasks preempt lower ones
- **Inter-agent messaging** - Agents can communicate without orchestrator
- **Auto-cleanup** - Sessions cleaned up on completion, crash, or 10-min timeout
- **Persistent state** - Survives `/compact` and restarts

## Quick Start

```bash
# Clone
git clone https://github.com/pookNast/claude-super-dispatch.git
cd claude-super-dispatch

# Install
./install.sh

# Restart shell or source
source ~/.bashrc
```

## Usage

### Dispatch a task

```bash
# With explicit agent type
/super be Add rate limiting to API endpoints
/super py Refactor the data pipeline

# Auto-detect agent from task
/super Fix the login bug in auth.py

# Multiple tasks
/super be Add caching; py Write tests; db Debug failures
```

### Agent Types

| Alias | Agent | Use For |
|-------|-------|---------|  
| `be` | backend-developer | APIs, server code, databases |
| `fe` | frontend-developer | UI, React, CSS |
| `py` | python-pro | Python code, scripts |
| `db` | debugger | Bug investigation |
| `dev` | devops-engineer | Deploy, infra, docker |
| `sec` | security-engineer | Security audit |
| `test` | test-automator | Tests, coverage |
| `api` | api-designer | API design |

### Check Status

```bash
/tmux-orchestrator:status
```

### Peek at Agent Output

```bash
# Last 20 lines
/tmux-orchestrator:peek agent-task-123

# With grep filter
/tmux-orchestrator:peek agent-task-123 --grep "error"
```

### Inter-Agent Messaging

```bash
/tmux-orchestrator:message send agent-1 agent-2 request "Need help" "Details..."
/tmux-orchestrator:message receive agent-2
```

## Requirements

- **Claude Code CLI** with MCP tmux tools enabled
- **Python 3.8+**
- **tmux 3.0+**
- **jq** (for hooks)

## Configuration

Set these environment variables (optional):

```bash
export SUPER_DISPATCH_HOME="$HOME/.super-dispatch"  # Default
export CLAUDE_HOME="$HOME/.claude"                   # Default
```

## License

MIT
