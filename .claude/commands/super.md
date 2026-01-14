---
description: "Dispatch tasks to engineer_team agents in isolated tmux sessions"
allowed-tools: ["Read", "Bash", "mcp__tmux__create-session", "mcp__tmux__execute-command", "mcp__tmux__list-sessions", "mcp__tmux__capture-pane"]
argument-hint: "[agent-type] task description [--max-iter N]"
---

# Super - Fast Agent Dispatch with Dev Feedback Loop

Dispatch tasks to engineer_team agents running in isolated tmux sessions. **Built-in feedback loop** ensures agents verify their work before signaling DONE. All iteration stays in the tmux session (no parent context bloat).

## Usage

```
/super [agent-type] task description
/super be Fix the auth bug --max-iter 10
/super list of tasks (auto-selects agent types)
```

## Agent Types

| Short | Full | Use For |
|-------|------|---------|}
| be | backend-developer | APIs, server code, databases |
| fe | frontend-developer | UI, React, CSS |
| py | python-pro | Python code, scripts |
| db | debugger | Bug investigation |
| dev | devops-engineer | Deploy, infra, docker |
| sec | security-engineer | Security audit, vulnerabilities |
| test | test-automator | Tests, coverage |
| api | api-designer | API design, endpoints |

## tldr Integration (Exploration + Verification)

Agents use the `tldr` CLI for both **exploration** and **verification**:

### Exploration (Before Coding)
```bash
tldr structure . --lang python    # See code structure
tldr search "pattern" .           # Find relevant code
tldr impact func_name .           # Impact analysis before refactoring
tldr context entry_func --depth 2 # Get LLM-ready context
```

### Verification (dev-verify.sh - tldr powered)
```
┌─────────────────────────────────────────┐
│ DEV LOOP (default: 7 iterations max)    │
│                                         │
│  1. EXPLORE with tldr commands          │
│  2. IMPLEMENT the task                  │
│  3. VERIFY with dev-verify.sh           │
│  4. If FAIL: FIX and go to step 3       │
│  5. If PASS: Signal DONE                │
└─────────────────────────────────────────┘
```

**Verification checks (via tldr):**
- `tldr diagnostics` - Type checking + linting (pyright/ruff)
- `tldr dead` - Dead code detection (warnings)
- `tldr change-impact --run` - Selective test execution
- Build/syntax checks per language

## Dispatch Flow

1. Parse task(s) from argument
2. For each task:
   - Check orchestrator capacity (max 5 concurrent)
   - Create tmux session via MCP tools
   - Register in orchestrator state
   - Spawn bash subagent with DEV LOOP prompt
3. Return dispatch summary only (not full output)

## Queue Handling (MANDATORY)

When a task returns **QUEUED** status, do NOT bypass the queue by doing work directly. Instead:

1. **Clear stale sessions** from the orchestrator:
   ```bash
   /home/pook/engineer-team/.beads/scripts/orchestrator-cleanup.sh
   ```

2. **Re-dispatch** the task through `/super` again

3. **Wait for completion** - monitor with `/tmux-orchestrator:status`

**Why this matters:**
- Doing work directly in parent context costs **1000-5000 tokens** of context bloat
- Agent sessions isolate all iteration and exploration to tmux (zero parent cost)
- The queue exists to prevent overload, not to be bypassed

**If queue persists after cleanup:**
- Check for zombie sessions: `tmux list-sessions | grep agent-`
- Kill stale sessions: `tmux kill-session -t agent-{id}`
- Verify orchestrator state: `cat /tmp/orchestrator-state.json`

## Implementation

When user invokes `/super`:

1. Parse the argument to extract agent type, task description, and optional `--max-iter N`
2. Generate a unique task_id (e.g., timestamp or short hash)
3. Run the dispatch script:

```bash
/home/pook/engineer-team/.beads/scripts/super-dispatch.sh \
    "{task_id}" "{agent_type}" "{cwd}" "{max_iter}" "{task_description}"
```

The script handles:
- Orchestrator capacity check (queue if at max)
- Prompt file generation with DEV LOOP built-in
- Tmux session creation
- Claude launch with the prompt

**Quick dispatch example:**
```bash
# Direct bash call
/home/pook/engineer-team/.beads/scripts/super-dispatch.sh \
    "$(date +%s)" "backend-developer" "$(pwd)" "7" "Fix the auth bug in api/auth.py"
```

## Examples

```bash
# Single task with explicit agent
/super be Add rate limiting to the API endpoints

# With custom max iterations
/super py Refactor the data processing pipeline --max-iter 10

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

## Monitoring Agent Iterations

```bash
# See current iteration in agent's tmux session
tmux capture-pane -t agent-{id} -p | grep -E "(iteration|VERIFY|STATUS)"

# View full agent output
tmux capture-pane -t agent-{id} -p -S -1000
```

## Ralph Integration

After agent signals DONE, optionally review with Ralph:
```bash
ralph review code --spec spec.md --files changed_files
/ralph-loop  # Interactive review loop
```
See `/help` for full Ralph documentation.
