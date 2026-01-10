#!/bin/bash
# check-messages.sh - Check for inter-agent messages

set -euo pipefail

AGENT_ID="${1:-}"

if [[ -z "$AGENT_ID" ]]; then
    echo "Usage: check-messages.sh <agent-id>"
    echo ""
    echo "Stats:"
    python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
import json
m = AgentMessenger()
print(json.dumps(m.get_stats(), indent=2))
"
    exit 0
fi

echo "Messages for: $AGENT_ID"
echo "========================"
python3 -c "
import sys, os
sys.path.insert(0, os.environ.get('SUPER_DISPATCH_HOME', os.path.expanduser('~/.super-dispatch')))
from agent_messenger import AgentMessenger
m = AgentMessenger()
messages = m.receive('$AGENT_ID')
if not messages:
    print('No unread messages')
else:
    for msg in messages:
        print(f'[{msg.id}] {msg.msg_type}: {msg.subject}')
        print(f'  From: {msg.from_agent}')
        print(f'  Time: {msg.timestamp}')
        print()
"
