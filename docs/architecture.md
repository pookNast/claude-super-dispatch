# Architecture

## Overview

claude-super-dispatch provides context-optimized agent dispatch for Claude Code by isolating agent execution in tmux sessions.

## Problem

When running multiple Claude Code agents inline, their outputs consume significant context tokens (2000-8000+ per agent), degrading the orchestrator's ability to manage complex workflows.

## Solution

Isolate agent execution in tmux sessions:
- Full agent output stays in tmux (zero context cost)
- Only completion signals (~100 tokens) return to orchestrator
- Result: 90%+ context savings

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                         │
│  (Main Claude Code session - context-optimized)         │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Task List   │→ │ Dispatcher  │→ │ State Mgr   │     │
│  └─────────────┘  └──────┬──────┘  └──────┬──────┘     │
│                          │                 │            │
│         ┌────────────────┼─────────────────┤            │
│         ▼                ▼                 ▼            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ DONE Signal │  │ Peek Cmd    │  │ Priority Q  │     │
│  │ (< 100 tok) │  │ (on demand) │  │ (waiting)   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Tmux Session │   │ Tmux Session │   │ Tmux Session │
│   agent-1    │   │   agent-2    │   │   agent-3    │
│              │   │              │   │              │
│ ┌──────────┐ │   │ ┌──────────┐ │   │ ┌──────────┐ │
│ │ Claude   │ │   │ │ Claude   │ │   │ │ Claude   │ │
│ │  Agent   │ │   │ │  Agent   │ │   │ │  Agent   │ │
│ └──────────┘ │   │ └──────────┘ │   │ └──────────┘ │
│              │   │              │   │              │
│ [Isolated]   │   │ [Isolated]   │   │ [Isolated]   │
└──────────────┘   └──────────────┘   └──────────────┘
        │                  │                  │
        └──────────────────┴──────────────────┘
                           │
                  ┌────────┴───────┐
                  │ Inter-Agent   │
                  │  Messaging    │
                  └────────────────┘
```

## Components

### 1. Orchestrator (Main Session)
- Receives task requests via `/super` command
- Dispatches to tmux sessions
- Tracks state in `sessions/active.json`
- Manages priority queue

### 2. Tmux Sessions
- Isolated Claude Code instances
- Full context per session
- Output stays local until completion
- Emits `ORCHESTRATOR-SIGNAL` when done

### 3. State Manager (`tmux_orchestrator.py`)
- Tracks active sessions (max 5)
- Priority queue for waiting tasks
- Health checks and timeouts
- Persistent across `/compact`

### 4. Agent Messenger (`agent_messenger.py`)
- File-based message passing
- Request/response patterns
- Task handoffs between agents
- Broadcast capabilities

### 5. Completion Hook
- Detects `ORCHESTRATOR-SIGNAL`
- Cleans up tmux session
- Updates state file
- Dequeues next task

## Data Flow

1. User invokes `/super py Fix the bug`
2. Orchestrator checks capacity (< 5 sessions?)
3. If yes: Create tmux session, spawn Claude agent
4. Agent works in isolation, full output in tmux
5. Agent completes, emits `ORCHESTRATOR-SIGNAL`
6. Hook detects signal, extracts summary (~100 tokens)
7. Hook cleans up session, updates state
8. Summary returns to orchestrator context

## File Locations

| Component | Default Path |
|-----------|-------------|
| State file | `~/.super-dispatch/sessions/active.json` |
| Messages | `~/.super-dispatch/messages/` |
| Skills | `~/.claude/commands/super.md` |
| Hooks | `~/.claude/hooks/tmux-orchestrator-completion.sh` |

## Constraints

| Constraint | Value |
|------------|-------|
| Max concurrent sessions | 5 |
| Agent timeout | 10 minutes |
| Session cleanup | Auto on completion/crash/timeout |
