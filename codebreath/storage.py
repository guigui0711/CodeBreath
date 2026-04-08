"""
Configuration and data persistence for CodeBreath.
Stores config and daily logs in ~/.codebreath/
Uses only stdlib: json for data, no YAML dependency.
"""

import json
import os
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

DATA_DIR = Path.home() / ".codebreath"
CONFIG_FILE = DATA_DIR / "config.json"
LOG_DIR = DATA_DIR / "logs"
PID_FILE = DATA_DIR / "codebreath.pid"
STATE_FILE = DATA_DIR / "state.json"


def ensure_dirs():
    """Create data directories if they don't exist."""
    DATA_DIR.mkdir(exist_ok=True)
    LOG_DIR.mkdir(exist_ok=True)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------


@dataclass
class Config:
    """User-configurable settings."""

    # Reminder intervals (minutes)
    eye_interval_min: int = 30
    neck_interval_min: int = 45
    sedentary_interval_min: int = 60

    # Working hours (reminders only fire within this window)
    work_start_hour: int = 9
    work_end_hour: int = 19

    # Noon outdoor reminder
    noon_reminder_enabled: bool = True
    noon_reminder_hour: int = 12
    noon_reminder_minute: int = 0

    # Notification sound
    notification_sound: str = "default"

    # Whether to also open terminal UI on notification (vs notification only)
    terminal_ui_enabled: bool = True

    # Language: "en" or "zh"
    language: str = "en"

    @classmethod
    def load(cls) -> "Config":
        """Load config from file, or return defaults."""
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r") as f:
                    data = json.load(f)
                return cls(
                    **{k: v for k, v in data.items() if k in cls.__dataclass_fields__}
                )
            except (json.JSONDecodeError, TypeError, KeyError):
                pass
        return cls()

    def save(self):
        """Save config to file."""
        ensure_dirs()
        with open(CONFIG_FILE, "w") as f:
            json.dump(asdict(self), f, indent=2)

    def to_display(self) -> Dict[str, str]:
        """Return human-readable config for display."""
        if self.language == "zh":
            return {
                "护眼提醒间隔": f"每 {self.eye_interval_min} 分钟",
                "颈椎锻炼间隔": f"每 {self.neck_interval_min} 分钟",
                "久坐提醒间隔": f"每 {self.sedentary_interval_min} 分钟",
                "工作时间": f"{self.work_start_hour}:00 - {self.work_end_hour}:00",
                "午间户外提醒": "已开启" if self.noon_reminder_enabled else "已关闭",
                "提示音": self.notification_sound,
                "终端交互界面": "已开启" if self.terminal_ui_enabled else "已关闭",
                "语言": self.language,
            }
        return {
            "Eye care interval": f"Every {self.eye_interval_min} minutes",
            "Neck exercise interval": f"Every {self.neck_interval_min} minutes",
            "Sedentary break interval": f"Every {self.sedentary_interval_min} minutes",
            "Working hours": f"{self.work_start_hour}:00 - {self.work_end_hour}:00",
            "Noon outdoor reminder": "Enabled"
            if self.noon_reminder_enabled
            else "Disabled",
            "Notification sound": self.notification_sound,
            "Terminal UI": "Enabled" if self.terminal_ui_enabled else "Disabled",
            "Language": self.language,
        }


# ---------------------------------------------------------------------------
# Daily log / statistics
# ---------------------------------------------------------------------------


@dataclass
class ReminderEvent:
    """A single reminder event record."""

    timestamp: str
    category: str  # "eye", "neck", "sedentary", "outdoor"
    tip_name: str
    action: str  # "notified", "completed", "skipped", "dismissed"


@dataclass
class DailyLog:
    """Daily log of reminder events and statistics."""

    date: str  # ISO format YYYY-MM-DD
    events: List[Dict] = field(default_factory=list)

    @property
    def log_path(self) -> Path:
        return LOG_DIR / f"{self.date}.json"

    @classmethod
    def today(cls) -> "DailyLog":
        """Load or create today's log."""
        today_str = date.today().isoformat()
        log = cls(date=today_str)
        if log.log_path.exists():
            try:
                with open(log.log_path, "r") as f:
                    data = json.load(f)
                log.events = data.get("events", [])
            except (json.JSONDecodeError, KeyError):
                pass
        return log

    def add_event(self, category: str, tip_name: str, action: str):
        """Record a reminder event."""
        event = {
            "timestamp": datetime.now().isoformat(),
            "category": category,
            "tip_name": tip_name,
            "action": action,
        }
        self.events.append(event)
        self._save()

    def _save(self):
        """Persist log to disk."""
        ensure_dirs()
        with open(self.log_path, "w") as f:
            json.dump({"date": self.date, "events": self.events}, f, indent=2)

    def get_stats(self) -> Dict:
        """Compute daily statistics."""
        stats = {
            "completed": 0,
            "skipped": 0,
            "notified": 0,
            "eye_completed": 0,
            "eye_total": 0,
            "neck_completed": 0,
            "neck_total": 0,
            "sedentary_completed": 0,
            "sedentary_total": 0,
            "outdoor_completed": 0,
            "outdoor_total": 0,
        }

        for event in self.events:
            cat = event.get("category", "")
            action = event.get("action", "")

            if action == "notified":
                stats["notified"] += 1
                if f"{cat}_total" in stats:
                    stats[f"{cat}_total"] += 1

            elif action == "completed":
                stats["completed"] += 1
                if f"{cat}_completed" in stats:
                    stats[f"{cat}_completed"] += 1

            elif action == "skipped":
                stats["skipped"] += 1

        return stats

    def get_streak(self) -> int:
        """Calculate consecutive days with at least 1 completed exercise."""
        streak = 0
        check_date = date.today()

        while True:
            log_path = LOG_DIR / f"{check_date.isoformat()}.json"
            if not log_path.exists():
                break

            try:
                with open(log_path, "r") as f:
                    data = json.load(f)
                events = data.get("events", [])
                has_completion = any(e.get("action") == "completed" for e in events)
                if has_completion:
                    streak += 1
                else:
                    break
            except (json.JSONDecodeError, KeyError):
                break

            # Go back one day
            from datetime import timedelta

            check_date -= timedelta(days=1)

        return streak


# ---------------------------------------------------------------------------
# Daemon state (PID file management)
# ---------------------------------------------------------------------------


def write_pid():
    """Write current process PID to file."""
    ensure_dirs()
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def read_pid() -> Optional[int]:
    """Read daemon PID from file. Returns None if not running."""
    if not PID_FILE.exists():
        return None
    try:
        with open(PID_FILE, "r") as f:
            pid = int(f.read().strip())
        # Check if process is actually running
        os.kill(pid, 0)
        return pid
    except (ValueError, ProcessLookupError, PermissionError):
        # PID file exists but process is dead
        PID_FILE.unlink(missing_ok=True)
        return None


def remove_pid():
    """Remove PID file."""
    PID_FILE.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Daemon pause/resume state
# ---------------------------------------------------------------------------


def save_state(paused: bool = False, paused_until: Optional[float] = None):
    """Save daemon runtime state."""
    ensure_dirs()
    state = {
        "paused": paused,
        "paused_until": paused_until,
        "updated_at": datetime.now().isoformat(),
    }
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def load_state() -> Dict:
    """Load daemon runtime state."""
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, KeyError):
            pass
    return {"paused": False, "paused_until": None}
