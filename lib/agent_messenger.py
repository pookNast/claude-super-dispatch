#!/usr/bin/env python3
"""
Agent Messenger - Inter-agent communication system for tmux orchestrator.
Allows agents in isolated tmux sessions to communicate without orchestrator context bloat.
"""

import json
import os
import uuid
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from enum import Enum

# Configurable base directory
BASE_DIR = Path(os.environ.get("SUPER_DISPATCH_HOME", os.path.expanduser("~/.super-dispatch")))


class MessageType(Enum):
    REQUEST = "request"      # Ask another agent to do something
    RESPONSE = "response"    # Reply to a request
    BROADCAST = "broadcast"  # Message to all agents
    HANDOFF = "handoff"      # Transfer task ownership
    STATUS = "status"        # Status update
    DATA = "data"            # Share data/results


@dataclass
class Message:
    """Inter-agent message."""
    id: str
    from_agent: str
    to_agent: str  # "all" for broadcast
    msg_type: str
    subject: str
    content: str
    timestamp: str
    reply_to: Optional[str] = None  # ID of message being replied to
    read: bool = False


class AgentMessenger:
    """Manages inter-agent communication."""

    def __init__(self, base_path: str = None):
        if base_path is None:
            base_path = str(BASE_DIR / "messages")
        self.base_path = Path(base_path)
        self.inbox_path = self.base_path / "inbox"
        self.outbox_path = self.base_path / "outbox"
        self._ensure_dirs()

    def _ensure_dirs(self):
        """Ensure message directories exist."""
        self.inbox_path.mkdir(parents=True, exist_ok=True)
        self.outbox_path.mkdir(parents=True, exist_ok=True)

    def _get_agent_inbox(self, agent_id: str) -> Path:
        """Get path to agent's inbox."""
        inbox = self.inbox_path / agent_id
        inbox.mkdir(exist_ok=True)
        return inbox

    def send(self, from_agent: str, to_agent: str, msg_type: str, 
             subject: str, content: str, reply_to: Optional[str] = None) -> Message:
        """
        Send a message to another agent.
        
        Args:
            from_agent: Sender agent ID (e.g., "agent-task-123")
            to_agent: Recipient agent ID or "all" for broadcast
            msg_type: Message type (request, response, broadcast, handoff, status, data)
            subject: Brief subject line
            content: Message content
            reply_to: Optional ID of message being replied to
        
        Returns:
            Message: The sent message
        """
        msg = Message(
            id=f"msg-{uuid.uuid4().hex[:8]}",
            from_agent=from_agent,
            to_agent=to_agent,
            msg_type=msg_type,
            subject=subject,
            content=content,
            timestamp=datetime.now().isoformat(),
            reply_to=reply_to
        )

        if to_agent == "all":
            # Broadcast to all agent inboxes
            for inbox in self.inbox_path.iterdir():
                if inbox.is_dir():
                    self._write_message(inbox, msg)
        else:
            # Send to specific agent
            inbox = self._get_agent_inbox(to_agent)
            self._write_message(inbox, msg)

        # Also save to outbox for sender's reference
        outbox = self.outbox_path / from_agent
        outbox.mkdir(exist_ok=True)
        self._write_message(outbox, msg)

        return msg

    def _write_message(self, folder: Path, msg: Message):
        """Write message to folder."""
        msg_file = folder / f"{msg.id}.json"
        with open(msg_file, "w") as f:
            json.dump(asdict(msg), f, indent=2)

    def receive(self, agent_id: str, unread_only: bool = True) -> List[Message]:
        """
        Get messages for an agent.
        
        Args:
            agent_id: Agent ID to check inbox for
            unread_only: Only return unread messages
        
        Returns:
            List[Message]: Messages in inbox
        """
        inbox = self._get_agent_inbox(agent_id)
        messages = []

        for msg_file in sorted(inbox.glob("*.json")):
            with open(msg_file) as f:
                data = json.load(f)
                msg = Message(**data)
                if unread_only and msg.read:
                    continue
                messages.append(msg)

        return messages

    def mark_read(self, agent_id: str, msg_id: str) -> bool:
        """Mark a message as read."""
        inbox = self._get_agent_inbox(agent_id)
        msg_file = inbox / f"{msg_id}.json"

        if msg_file.exists():
            with open(msg_file) as f:
                data = json.load(f)
            data["read"] = True
            with open(msg_file, "w") as f:
                json.dump(data, f, indent=2)
            return True
        return False

    def get_conversation(self, msg_id: str) -> List[Message]:
        """Get all messages in a conversation thread."""
        messages = []
        # Search all inboxes and outboxes
        for folder in [self.inbox_path, self.outbox_path]:
            for agent_folder in folder.iterdir():
                if agent_folder.is_dir():
                    for msg_file in agent_folder.glob("*.json"):
                        with open(msg_file) as f:
                            data = json.load(f)
                            if data["id"] == msg_id or data.get("reply_to") == msg_id:
                                messages.append(Message(**data))
        
        # Sort by timestamp
        messages.sort(key=lambda m: m.timestamp)
        return messages

    def request_help(self, from_agent: str, to_agent: str, task: str) -> Message:
        """Shortcut to request help from another agent."""
        return self.send(
            from_agent=from_agent,
            to_agent=to_agent,
            msg_type="request",
            subject=f"Help needed: {task[:50]}",
            content=task
        )

    def handoff_task(self, from_agent: str, to_agent: str, task: str, context: str) -> Message:
        """Handoff a task to another agent."""
        return self.send(
            from_agent=from_agent,
            to_agent=to_agent,
            msg_type="handoff",
            subject=f"Task handoff: {task[:50]}",
            content=f"TASK: {task}\n\nCONTEXT:\n{context}"
        )

    def share_data(self, from_agent: str, to_agent: str, data_name: str, data: str) -> Message:
        """Share data/results with another agent."""
        return self.send(
            from_agent=from_agent,
            to_agent=to_agent,
            msg_type="data",
            subject=f"Data: {data_name}",
            content=data
        )

    def broadcast_status(self, from_agent: str, status: str) -> Message:
        """Broadcast status update to all agents."""
        return self.send(
            from_agent=from_agent,
            to_agent="all",
            msg_type="status",
            subject="Status update",
            content=status
        )

    def get_stats(self) -> dict:
        """Get messaging statistics."""
        total_messages = 0
        unread_messages = 0
        agents_with_inbox = 0

        for inbox in self.inbox_path.iterdir():
            if inbox.is_dir():
                agents_with_inbox += 1
                for msg_file in inbox.glob("*.json"):
                    total_messages += 1
                    with open(msg_file) as f:
                        if not json.load(f).get("read", False):
                            unread_messages += 1

        return {
            "total_messages": total_messages,
            "unread_messages": unread_messages,
            "agents_with_inbox": agents_with_inbox
        }


def main():
    """CLI interface."""
    import sys

    messenger = AgentMessenger()

    if len(sys.argv) < 2:
        print(json.dumps(messenger.get_stats(), indent=2))
        return

    cmd = sys.argv[1]

    if cmd == "stats":
        print(json.dumps(messenger.get_stats(), indent=2))

    elif cmd == "send" and len(sys.argv) >= 6:
        # send <from> <to> <type> <subject> <content>
        msg = messenger.send(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], " ".join(sys.argv[6:]))
        print(f"Sent: {msg.id}")

    elif cmd == "receive" and len(sys.argv) >= 3:
        # receive <agent_id>
        messages = messenger.receive(sys.argv[2])
        for msg in messages:
            print(f"[{msg.id}] {msg.msg_type}: {msg.subject} (from {msg.from_agent})")

    elif cmd == "read" and len(sys.argv) >= 4:
        # read <agent_id> <msg_id>
        inbox = messenger._get_agent_inbox(sys.argv[2])
        msg_file = inbox / f"{sys.argv[3]}.json"
        if msg_file.exists():
            with open(msg_file) as f:
                msg = json.load(f)
            print(f"From: {msg['from_agent']}")
            print(f"Type: {msg['msg_type']}")
            print(f"Subject: {msg['subject']}")
            print(f"---")
            print(msg['content'])
            messenger.mark_read(sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()
