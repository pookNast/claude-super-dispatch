---
description: "Peek at agent output on demand"
allowed-tools: ["Bash", "mcp__tmux__*"]
argument-hint: "[session-id] [--lines N] [--grep PATTERN]"
---

# Tmux Orchestrator Peek

Pull specific agent output into context ON DEMAND. Use sparingly - this WILL consume context tokens.

## Usage

```bash
# Last 20 lines (default)
/tmux-orchestrator:peek agent-task-123

# Last N lines
/tmux-orchestrator:peek agent-task-123 --lines 50

# Grep for pattern
/tmux-orchestrator:peek agent-task-123 --grep "error"
```

## Implementation

1. **Capture pane content:**
```bash
tmux capture-pane -t "$SESSION_ID" -p -S -$LINES
```

2. **Apply filters if specified:**
```bash
# With grep
tmux capture-pane -t "$SESSION_ID" -p -S -100 | grep -i "$PATTERN"
```

3. **Return filtered output**

## Warning

This command pulls output INTO your context. Only use when you specifically need to see agent progress or debug an issue.

For zero-cost monitoring, attach directly:
```bash
tmux attach -t $SESSION_ID
```
