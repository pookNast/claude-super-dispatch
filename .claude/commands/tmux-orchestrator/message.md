---
description: "Send/receive messages between agents"
allowed-tools: ["Bash", "Read"]
argument-hint: "[send|receive|broadcast] [args]"
---

# Agent Messaging

Inter-agent communication for tmux orchestrator sessions.

## Commands

### Send a message
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
m = AgentMessenger()
m.send('agent-sender', 'agent-recipient', 'request', 'Subject', 'Message content')
"
```

### Receive messages
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
m = AgentMessenger()
for msg in m.receive('agent-id'):
    print(f'[{msg.id}] {msg.msg_type}: {msg.subject}')
"
```

### Broadcast to all agents
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
m = AgentMessenger()
m.broadcast_status('agent-sender', 'Status message here')
"
```

## Message Types

| Type | Use For |
|------|---------||
| `request` | Ask another agent to do something |
| `response` | Reply to a request |
| `broadcast` | Message to all agents |
| `handoff` | Transfer task ownership |
| `status` | Status update |
| `data` | Share data/results |

## Agent Instructions

Agents running in tmux sessions can use these patterns:

### Check for messages (poll)
```bash
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
m = AgentMessenger()
for msg in m.receive('$SESSION_NAME'):
    print(f'[{msg.id}] {msg.subject}')
"
```

### Request help from another agent
```python
from agent_messenger import AgentMessenger
m = AgentMessenger()
m.request_help("agent-me", "agent-helper", "I need help with X")
```

### Share results with another agent
```python
m.share_data("agent-me", "agent-recipient", "analysis_results", "data here...")
```

### Handoff task
```python
m.handoff_task("agent-me", "agent-recipient", "Complete the auth module", "Context: we use JWT...")
```

## Integration with Orchestrator

Agents should check for messages periodically when working on collaborative tasks.
