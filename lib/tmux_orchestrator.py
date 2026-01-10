#!/usr/bin/env python3
"""
Tmux Agent Orchestrator - Session and queue management for context-optimized agent execution.
"""

import json
import os
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List

# Configurable base directory
BASE_DIR = Path(os.environ.get("SUPER_DISPATCH_HOME", os.path.expanduser("~/.super-dispatch")))
STATE_FILE = BASE_DIR / "sessions" / "active.json"


@dataclass
class Session:
    """Active tmux session."""
    session_id: str
    task_id: str
    agent_type: str
    priority: int
    started_at: str
    status: str = "running"


@dataclass
class QueuedTask:
    """Task waiting in queue."""
    task_id: str
    agent_type: str
    priority: int
    queued_at: str
    prompt: str = ""


class TmuxOrchestrator:
    """Manages tmux sessions and task queue for concurrent agent execution."""

    def __init__(self):
        self.state_file = STATE_FILE
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self._load_state()

    def _load_state(self) -> None:
        """Load state from file."""
        if self.state_file.exists():
            with open(self.state_file) as f:
                data = json.load(f)
                self.sessions = [Session(**s) for s in data.get("sessions", [])]
                self.queue = [QueuedTask(**q) for q in data.get("queue", [])]
                self.max_concurrent = data.get("max_concurrent", 5)
                self.timeout_minutes = data.get("timeout_minutes", 10)
        else:
            self.sessions = []
            self.queue = []
            self.max_concurrent = 5
            self.timeout_minutes = 10
            self._save_state()

    def _save_state(self) -> None:
        """Persist state to file."""
        data = {
            "sessions": [asdict(s) for s in self.sessions],
            "queue": [asdict(q) for q in self.queue],
            "max_concurrent": self.max_concurrent,
            "timeout_minutes": self.timeout_minutes
        }
        with open(self.state_file, "w") as f:
            json.dump(data, f, indent=2)

    def can_spawn(self) -> bool:
        """Check if we can spawn a new session."""
        return len(self.sessions) < self.max_concurrent

    def add_session(self, task_id: str, agent_type: str, priority: int = 2) -> Session:
        """Add a new active session."""
        session = Session(
            session_id=f"agent-{task_id}",
            task_id=task_id,
            agent_type=agent_type,
            priority=priority,
            started_at=datetime.now().isoformat()
        )
        self.sessions.append(session)
        self._save_state()
        return session

    def remove_session(self, session_id: str) -> bool:
        """Remove a session by ID."""
        before = len(self.sessions)
        self.sessions = [s for s in self.sessions if s.session_id != session_id]
        if len(self.sessions) < before:
            self._save_state()
            return True
        return False

    def get_active_sessions(self) -> List[Session]:
        """Get all active sessions."""
        return self.sessions.copy()

    def queue_task(self, task_id: str, agent_type: str, priority: int = 2, prompt: str = "") -> QueuedTask:
        """Add task to queue."""
        task = QueuedTask(
            task_id=task_id,
            agent_type=agent_type,
            priority=priority,
            queued_at=datetime.now().isoformat(),
            prompt=prompt
        )
        self.queue.append(task)
        self.sort_queue()
        self._save_state()
        return task

    def sort_queue(self) -> None:
        """Sort queue by priority (lower = higher priority), then by time."""
        self.queue.sort(key=lambda x: (x.priority, x.queued_at))

    def dequeue_next(self) -> Optional[QueuedTask]:
        """Get and remove highest priority task from queue."""
        if not self.queue:
            return None
        task = self.queue.pop(0)
        self._save_state()
        return task

    def preempt_queue(self, task_id: str, agent_type: str, prompt: str = "") -> QueuedTask:
        """Insert high-priority task at front of queue."""
        task = QueuedTask(
            task_id=task_id,
            agent_type=agent_type,
            priority=0,
            queued_at=datetime.now().isoformat(),
            prompt=prompt
        )
        self.queue.insert(0, task)
        self._save_state()
        return task

    def get_queue_status(self) -> dict:
        """Get queue summary."""
        return {
            "queued": len(self.queue),
            "active": len(self.sessions),
            "available_slots": self.max_concurrent - len(self.sessions),
            "next_task": self.queue[0].task_id if self.queue else None
        }

    def get_timed_out_sessions(self) -> List[Session]:
        """Get sessions that have exceeded timeout."""
        now = datetime.now()
        timed_out = []
        for session in self.sessions:
            started = datetime.fromisoformat(session.started_at)
            if now - started > timedelta(minutes=self.timeout_minutes):
                timed_out.append(session)
        return timed_out

    def cleanup_session(self, session_id: str) -> bool:
        """Kill tmux session and remove from state."""
        try:
            subprocess.run(["tmux", "kill-session", "-t", session_id], capture_output=True, timeout=5)
        except Exception:
            pass
        return self.remove_session(session_id)

    def health_check(self) -> dict:
        """Check health of all sessions."""
        healthy, dead = [], []
        for session in self.sessions:
            result = subprocess.run(["tmux", "has-session", "-t", session.session_id], capture_output=True)
            (healthy if result.returncode == 0 else dead).append(session.session_id)
        return {"healthy": healthy, "dead": dead}


def main():
    import sys
    orch = TmuxOrchestrator()
    if len(sys.argv) < 2:
        print(json.dumps(orch.get_queue_status(), indent=2))
        return
    cmd = sys.argv[1]
    if cmd == "status": print(json.dumps(orch.get_queue_status(), indent=2))
    elif cmd == "sessions":
        for s in orch.get_active_sessions(): print(f"{s.session_id}: {s.agent_type} (p={s.priority})")
    elif cmd == "queue":
        for q in orch.queue: print(f"{q.task_id}: {q.agent_type} (p={q.priority})")
    elif cmd == "can-spawn": print("yes" if orch.can_spawn() else "no")
    elif cmd == "health": print(json.dumps(orch.health_check(), indent=2))


if __name__ == "__main__":
    main()
