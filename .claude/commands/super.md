---
description: "Dispatch tasks to engineer_team agents in isolated tmux sessions"
allowed-tools: ["Task", "Read", "Bash", "mcp__tmux__create-session", "mcp__tmux__execute-command", "mcp__tmux__list-sessions", "mcp__tmux__capture-pane"]
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
|-------|------|---------|  
| be | backend-developer | APIs, server code, databases |
| fe | frontend-developer | UI, React, CSS |
| py | python-pro | Python code, scripts |
| db | debugger | Bug investigation |
| dev | devops-engineer | Deploy, infra, docker |
| sec | security-engineer | Security audit, vulnerabilities |
| test | test-automator | Tests, coverage |
| api | api-designer | API design, endpoints |

## Dev Feedback Loop (Always Enabled)

Each agent runs a **verify-fix loop** before signaling DONE:

```
+-----------------------------------------+
| DEV LOOP (default: 7 iterations max)    |
|                                         |
|  1. IMPLEMENT the task                  |
|  2. VERIFY with dev-verify.sh           |
|  3. If FAIL: FIX and go to step 2       |
|  4. If PASS: Signal DONE                |
|  5. If max iterations: Signal DONE      |
|     with partial status                 |
+-----------------------------------------+
```

**Verification auto-detects project type:**
- Python: ruff/flake8, mypy/pyright, pytest
- Node.js: lint, tsc, test, build
- Go: go vet, go build, go test
- Rust: clippy, cargo build, cargo test

## Dispatch Flow

1. Parse task(s) from argument
2. For each task:
   - Check orchestrator capacity (max 5 concurrent)
   - Create tmux session via MCP tools
   - Register in orchestrator state
   - Spawn bash subagent with DEV LOOP prompt
3. Return dispatch summary only (not full output)

## Implementation

When user invokes `/super`:

1. Parse the argument to extract agent type, task description, and optional `--max-iter N`
2. Generate a unique task_id (e.g., timestamp or short hash)
3. Run the dispatch script:

```bash
$SUPER_DISPATCH_HOME/scripts/super-dispatch.sh \
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
$SUPER_DISPATCH_HOME/scripts/super-dispatch.sh \
    "$(date +%s)" "backend-developer" "$(pwd)" "7" "Fix the auth bug in api/auth.py"
```

## Agent Prompt Template (with Dev Feedback Loop)

The prompt written to `/tmp/agent-{task_id}-prompt.txt`:

```
You are a {agent_type} agent running in an isolated tmux session.

TASK: {task_description}

WORKING DIRECTORY: {cwd}

===============================================================
DEV FEEDBACK LOOP - MANDATORY BEFORE COMPLETION
===============================================================

You MUST follow this verify-fix loop before signaling DONE.
MAX ITERATIONS: {max_iter} (default: 7)

LOOP:
  iteration = 1
  while iteration <= {max_iter}:
      1. IMPLEMENT/FIX the task (or continue from previous iteration)

      2. VERIFY - Run the verification script:
         $SUPER_DISPATCH_HOME/scripts/dev-verify.sh .

      3. CHECK RESULTS:
         - If "STATUS: ALL CHECKS PASSED" -> Exit loop, signal DONE
         - If "STATUS: VERIFICATION FAILED" -> Note failures, increment iteration

      4. If iteration > {max_iter}: Exit loop with partial completion

      iteration++

===============================================================

IMPORTANT RULES:
1. Run dev-verify.sh AFTER EVERY significant change
2. Do NOT signal DONE until verification passes (or max iterations)
3. Each iteration should fix issues found in verification
4. If stuck after 3 iterations on same error, try a different approach

When complete (verification passed OR max iterations reached), output:

---ORCHESTRATOR-SIGNAL---
STATUS: {DONE|PARTIAL}
ITERATIONS: {n}/{max_iter}
VERIFICATION: {PASSED|FAILED}
SUMMARY: {1-3 sentence summary of what was accomplished}
FILES_CHANGED: {paths}
REMAINING_ISSUES: {any unfixed issues, or "none"}
---END-SIGNAL---

Keep your work focused. Your full output stays here in tmux.
Only the DONE signal returns to the orchestrator.
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
