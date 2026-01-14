#!/bin/bash
# super-dispatch.sh - Dispatch agent to tmux session with dev feedback loop
# Usage: super-dispatch.sh <task_id> <agent_type> <cwd> <max_iter> "<task_description>"

set -euo pipefail

TASK_ID="${1:?Task ID required}"
AGENT_TYPE="${2:?Agent type required}"
CWD="${3:?Working directory required}"
MAX_ITER="${4:-7}"
TASK_DESC="${5:?Task description required}"

BEADS_DIR="/home/pook/engineer-team/.beads"
SESSION_NAME="agent-${TASK_ID}"
PROMPT_FILE="/tmp/${SESSION_NAME}-prompt.txt"

# Check orchestrator capacity
CAN_SPAWN=$(python3 -c "
import sys; sys.path.insert(0, '$BEADS_DIR')
from tmux_orchestrator import TmuxOrchestrator
o = TmuxOrchestrator()
print('yes' if o.can_spawn() else 'no')
" 2>/dev/null || echo "yes")

if [[ "$CAN_SPAWN" == "no" ]]; then
    # Queue the task
    python3 -c "
import sys; sys.path.insert(0, '$BEADS_DIR')
from tmux_orchestrator import TmuxOrchestrator
TmuxOrchestrator().queue_task('$TASK_ID', '$AGENT_TYPE', prompt='''$TASK_DESC''')
"
    echo "QUEUED: $SESSION_NAME ($AGENT_TYPE)"
    echo "Queue position: $(python3 -c "
import sys; sys.path.insert(0, '$BEADS_DIR')
from tmux_orchestrator import TmuxOrchestrator
print(len(TmuxOrchestrator().queue))
")"
    exit 0
fi

# Generate prompt file with dev feedback loop
cat > "$PROMPT_FILE" << 'PROMPT_HEADER'
You are a specialized agent running in an isolated tmux session.

PROMPT_HEADER

cat >> "$PROMPT_FILE" << PROMPT_TASK
AGENT TYPE: $AGENT_TYPE
TASK: $TASK_DESC
WORKING DIRECTORY: $CWD

PROMPT_TASK

cat >> "$PROMPT_FILE" << 'PROMPT_TLDR'
════════════════════════════════════════════════════════════════════════════════
TLDR EXPLORATION - USE BEFORE CODING
════════════════════════════════════════════════════════════════════════════════

The `tldr` CLI is available for efficient codebase analysis. Use it BEFORE writing code:

EXPLORATION COMMANDS:
  tldr structure . --lang python    # See code structure (functions, classes)
  tldr search "pattern" .           # Find relevant code
  tldr context entry_func --depth 2 # Get LLM-ready context for a function
  tldr impact func_name .           # See what calls this function (before refactoring)
  tldr imports file.py              # See what a file imports
  tldr importers module .           # Find all files importing a module

WORKFLOW:
  1. Run `tldr structure .` to understand the codebase layout
  2. Run `tldr search "keyword"` to find relevant files
  3. Run `tldr impact` before modifying any function
  4. THEN implement your changes
  5. Run dev-verify.sh to validate

PROMPT_TLDR

cat >> "$PROMPT_FILE" << 'PROMPT_DEVLOOP'
════════════════════════════════════════════════════════════════════════════════
DEV FEEDBACK LOOP - MANDATORY BEFORE COMPLETION
════════════════════════════════════════════════════════════════════════════════

You MUST follow this verify-fix loop before signaling completion.

PROMPT_DEVLOOP

cat >> "$PROMPT_FILE" << PROMPT_ITER
MAX ITERATIONS: $MAX_ITER

PROMPT_ITER

cat >> "$PROMPT_FILE" << 'PROMPT_LOOP'
THE LOOP:

```
iteration = 1
while iteration <= MAX_ITERATIONS:

    # Step 1: IMPLEMENT or FIX
    - First iteration: Implement the task
    - Subsequent iterations: Fix issues from previous verification

    # Step 2: VERIFY
    Run: /home/pook/engineer-team/.beads/scripts/dev-verify.sh .

    # Step 3: CHECK RESULTS
    - If output shows "STATUS: ALL CHECKS PASSED":
        → Break loop, signal DONE with VERIFICATION: PASSED
    - If output shows "STATUS: VERIFICATION FAILED":
        → Read the failures, increment iteration, continue loop

    # Step 4: MAX ITERATIONS CHECK
    If iteration > MAX_ITERATIONS:
        → Break loop, signal DONE with VERIFICATION: PARTIAL

    iteration++
```

════════════════════════════════════════════════════════════════════════════════

CRITICAL RULES:

1. Run dev-verify.sh AFTER EVERY code change
2. Do NOT signal completion until verification passes OR max iterations reached
3. Each iteration should specifically address failures from verification
4. If stuck on the same error for 3+ iterations, try a completely different approach
5. Read verification output carefully - it tells you exactly what failed

════════════════════════════════════════════════════════════════════════════════

COMPLETION SIGNAL FORMAT (output this when done):

---ORCHESTRATOR-SIGNAL---
STATUS: DONE
ITERATIONS: {n}/{max}
VERIFICATION: {PASSED|PARTIAL|FAILED}
SUMMARY: {1-3 sentences describing what was accomplished}
FILES_CHANGED: {comma-separated list of file paths}
REMAINING_ISSUES: {any unfixed issues, or "none"}
---END-SIGNAL---

════════════════════════════════════════════════════════════════════════════════

Your full output stays in this tmux session.
Only the completion signal matters to the orchestrator.
Focus on quality - the feedback loop exists to help you get it right.

Now begin working on the task.
PROMPT_LOOP

# Create tmux session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
fi
tmux new-session -d -s "$SESSION_NAME" -c "$CWD"

# Register with orchestrator
python3 -c "
import sys; sys.path.insert(0, '$BEADS_DIR')
from tmux_orchestrator import TmuxOrchestrator
TmuxOrchestrator().add_session('$TASK_ID', '$AGENT_TYPE')
" 2>/dev/null || true

# Launch claude in the session
tmux send-keys -t "$SESSION_NAME" "claude --dangerously-skip-permissions < '$PROMPT_FILE'" Enter

echo "DISPATCHED: $SESSION_NAME"
echo "Agent: $AGENT_TYPE"
echo "Max iterations: $MAX_ITER"
echo "Dev loop: ENABLED"
echo "Monitor: tmux attach -t $SESSION_NAME"
