# claude-super-dispatch

Context-optimized agent dispatch for Claude Code with built-in dev feedback loops.

## Key Feature: Dev Feedback Loop

Every agent includes a verify-fix loop (default 7 iterations):

1. IMPLEMENT the task
2. VERIFY with dev-verify.sh
3. If FAIL: FIX and repeat
4. If PASS: Signal DONE

Auto-detects: Python, Node.js, Go, Rust

## Quick Start

```bash
git clone https://github.com/pookNast/claude-super-dispatch.git
cd claude-super-dispatch
./install.sh
source ~/.bashrc
```

## Usage

```bash
/super be Add rate limiting to API
/super py Refactor pipeline --max-iter 10
/super Fix the login bug
```

## Agent Types

| Alias | Agent | Use For |
|-------|-------|---------|  
| be | backend-developer | APIs, databases |
| fe | frontend-developer | UI, React |
| py | python-pro | Python scripts |
| db | debugger | Bug investigation |
| dev | devops-engineer | Deploy, docker |
| sec | security-engineer | Security audit |
| test | test-automator | Tests |
| api | api-designer | API design |

## Status

```bash
/tmux-orchestrator:status
tmux capture-pane -t agent-{id} -p
```

## Requirements

- Claude Code CLI with MCP tmux tools
- Python 3.8+
- tmux 3.0+

## License

MIT
