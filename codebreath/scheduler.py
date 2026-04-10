"""
Scheduling engine for CodeBreath.
Runs as a background daemon, scheduling reminders at configured intervals.
Uses only stdlib threading and time — no external scheduler dependency.
"""

import os
import signal
import sys
import threading
import time
from datetime import datetime, date
from typing import Optional

from .content import ContentRotator
from .i18n import set_language, t
from .notifier import (
    send_health_reminder,
    send_noon_reminder,
    read_response,
    cleanup_old_responses,
)
from .storage import (
    Config,
    DailyLog,
    load_state,
    save_state,
    write_pid,
    read_pid,
    remove_pid,
)


class Scheduler:
    """Main scheduling engine.

    Manages three independent reminder timers:
    - Eye care (default: every 30 min)
    - Neck exercises (default: every 45 min)
    - Sedentary breaks (default: every 60 min)

    Plus a fixed-time noon outdoor reminder.
    """

    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config.load()
        # Initialize language for the daemon process
        set_language(self.config.language)

        self.rotator = ContentRotator()
        self.log = DailyLog.today()

        self._running = False
        self._paused = False
        self._stop_event = threading.Event()
        self._current_date = date.today()
        self._noon_sent_today = False

        # Track next fire times
        self._next_eye: Optional[float] = None
        self._next_neck: Optional[float] = None
        self._next_sedentary: Optional[float] = None

        # Pending notification responses: list of (resp_file, category, name)
        self._pending_responses: list = []

    def start(self, foreground: bool = False):
        """Start the scheduler.

        Args:
            foreground: If True, run in foreground (blocking).
                       If False, daemonize.
        """
        existing_pid = read_pid()
        if existing_pid:
            print(t("sched.already_running").format(pid=existing_pid))
            print(t("sched.stop_first"))
            return False

        if not foreground:
            self._daemonize()

        write_pid()
        self._running = True

        # Set up signal handlers
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

        # Restore paused state if any
        state = load_state()
        if state.get("paused"):
            paused_until = state.get("paused_until")
            if paused_until and time.time() < paused_until:
                self._paused = True
            else:
                save_state(paused=False)

        # Initialize next fire times
        now = time.time()
        self._next_eye = now + self.config.eye_interval_min * 60
        self._next_neck = now + self.config.neck_interval_min * 60
        self._next_sedentary = now + self.config.sedentary_interval_min * 60

        if foreground:
            print(t("sched.fg_start"))
            self._print_schedule()

        self._run_loop()
        return True

    def _run_loop(self):
        """Main loop — checks timers and fires reminders."""
        while self._running and not self._stop_event.is_set():
            now = time.time()
            current_hour = datetime.now().hour
            current_minute = datetime.now().minute

            # Daily reset check
            today = date.today()
            if today != self._current_date:
                self._daily_reset(today)

            # Skip if outside working hours
            if not self._in_working_hours(current_hour):
                self._stop_event.wait(60)
                continue

            # Skip if paused
            if self._paused:
                state = load_state()
                paused_until = state.get("paused_until")
                if paused_until and time.time() >= paused_until:
                    self._paused = False
                    save_state(paused=False)
                else:
                    self._stop_event.wait(30)
                    continue

            # Check noon outdoor reminder
            if (
                self.config.noon_reminder_enabled
                and not self._noon_sent_today
                and current_hour == self.config.noon_reminder_hour
                and current_minute >= self.config.noon_reminder_minute
            ):
                self._fire_noon_reminder()

            # Check each timer
            if self._next_eye and now >= self._next_eye:
                self._fire_eye_reminder()
                self._next_eye = now + self.config.eye_interval_min * 60

            if self._next_neck and now >= self._next_neck:
                self._fire_neck_reminder()
                self._next_neck = now + self.config.neck_interval_min * 60

            if self._next_sedentary and now >= self._next_sedentary:
                self._fire_sedentary_reminder()
                self._next_sedentary = now + self.config.sedentary_interval_min * 60

            # Sleep in small increments so we can respond to stop quickly
            self._stop_event.wait(10)

            # Check for notification responses (Done/Skip from native notifications)
            self._check_responses()

            # Periodic cleanup of old response files
            if int(now) % 300 < 11:
                cleanup_old_responses()

    def _fire_eye_reminder(self):
        """Fire an eye care reminder."""
        tip, extra_b, extra_c = self.rotator.next_eye_tip()
        ok = send_health_reminder(
            category="eye",
            tip_name=tip.name,
            instruction=tip.instruction,
            benefit=tip.benefit,
            consequence=tip.consequence,
            extra_benefit=extra_b,
        )
        self.log.add_event("eye", tip.name, "notified")

    def _fire_neck_reminder(self):
        """Fire a neck exercise reminder."""
        combo = self.rotator.next_neck_combo()
        names = " + ".join(tip.name for tip in combo)
        instructions = " → ".join(tip.instruction for tip in combo)
        ok = send_health_reminder(
            category="neck",
            tip_name=names,
            instruction=instructions,
            benefit=combo[0].benefit,
            consequence=combo[0].consequence,
        )
        self.log.add_event("neck", names, "notified")

    def _fire_sedentary_reminder(self):
        """Fire a sedentary break reminder."""
        current_hour = datetime.now().hour
        tip = self.rotator.next_sedentary_tip(current_hour)
        ok = send_health_reminder(
            category="sedentary",
            tip_name=tip.name,
            instruction=tip.instruction,
            benefit=tip.benefit,
            consequence=tip.consequence,
        )
        self.log.add_event("sedentary", tip.name, "notified")

    def _fire_noon_reminder(self):
        """Fire the noon outdoor reminder."""
        extra = self.rotator.next_noon_message()
        send_noon_reminder(extra)
        noon_tip = self.rotator.get_noon_outdoor()
        self.log.add_event("outdoor", noon_tip.name, "notified")
        self._noon_sent_today = True

    def _check_responses(self):
        """Check response directory for notification action results."""
        from .notifier import _RESPONSE_DIR

        if not _RESPONSE_DIR.is_dir():
            return
        for f in list(_RESPONSE_DIR.iterdir()):
            if not f.suffix == ".json":
                continue
            action = read_response(str(f))
            if action is None:
                continue
            # Extract category from filename: {category}_{pid}_{id}.json
            parts = f.stem.split("_", 1)
            category = parts[0] if parts else "unknown"
            if action == "done":
                self.log.add_event(category, "", "completed")
            elif action == "skip":
                self.log.add_event(category, "", "skipped")

    def _in_working_hours(self, hour: int) -> bool:
        """Check if current hour is within working hours."""
        return self.config.work_start_hour <= hour < self.config.work_end_hour

    def _daily_reset(self, today: date):
        """Reset daily state."""
        self._current_date = today
        self._noon_sent_today = False
        self.rotator.reset_daily()
        self.log = DailyLog.today()

    def _daemonize(self):
        """Fork into a background daemon process (Unix double-fork)."""
        # First fork
        try:
            pid = os.fork()
            if pid > 0:
                # Parent: print PID and exit
                print(t("sched.started").format(pid=pid))
                print(t("sched.stop_hint"))
                sys.exit(0)
        except OSError as e:
            print(f"Fork failed: {e}", file=sys.stderr)
            sys.exit(1)

        # Decouple from parent
        os.setsid()

        # Second fork
        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError as e:
            sys.exit(1)

        # Redirect stdout/stderr to /dev/null
        sys.stdout.flush()
        sys.stderr.flush()
        devnull = open(os.devnull, "w")
        os.dup2(devnull.fileno(), sys.stdout.fileno())
        os.dup2(devnull.fileno(), sys.stderr.fileno())

    def _handle_signal(self, signum, frame):
        """Handle SIGTERM/SIGINT gracefully."""
        self._running = False
        self._stop_event.set()
        remove_pid()
        save_state(paused=False)

    def _print_schedule(self):
        """Print upcoming schedule (foreground mode only)."""
        from .i18n import t as _t

        print(
            f"\nSchedule ({self.config.work_start_hour}:00-{self.config.work_end_hour}:00):"
        )
        print(f"  👁  {_t('cat.eye')}:     every {self.config.eye_interval_min} min")
        print(f"  🦴  {_t('cat.neck')}: every {self.config.neck_interval_min} min")
        print(
            f"  🚶  {_t('cat.sedentary')}:   every {self.config.sedentary_interval_min} min"
        )
        if self.config.noon_reminder_enabled:
            print(
                f"  ☀️  {_t('cat.outdoor')}:  at {self.config.noon_reminder_hour}:{self.config.noon_reminder_minute:02d}"
            )
        print()

    def get_next_times(self) -> dict:
        """Return next scheduled reminder times (for status display)."""
        result = {}
        now = time.time()
        if self._next_eye:
            remaining = max(0, int(self._next_eye - now))
            result["eye"] = f"in {remaining // 60}m {remaining % 60}s"
        if self._next_neck:
            remaining = max(0, int(self._next_neck - now))
            result["neck"] = f"in {remaining // 60}m {remaining % 60}s"
        if self._next_sedentary:
            remaining = max(0, int(self._next_sedentary - now))
            result["sedentary"] = f"in {remaining // 60}m {remaining % 60}s"
        return result


def stop_daemon() -> bool:
    """Stop the running daemon."""
    pid = read_pid()
    if not pid:
        print(t("sched.not_running"))
        return False

    try:
        os.kill(pid, signal.SIGTERM)
        # Wait for process to exit
        for _ in range(10):
            try:
                os.kill(pid, 0)
                time.sleep(0.5)
            except ProcessLookupError:
                break
        remove_pid()
        print(t("sched.stopped"))
        return True
    except ProcessLookupError:
        remove_pid()
        print(t("sched.stale_pid"))
        return False
    except PermissionError:
        print(f"Permission denied to stop process {pid}.")
        return False


def pause_daemon(minutes: int = 30):
    """Pause the daemon for N minutes."""
    pid = read_pid()
    if not pid:
        print(t("sched.not_running"))
        return

    paused_until = time.time() + minutes * 60
    save_state(paused=True, paused_until=paused_until)
    print(t("sched.paused").format(min=minutes))
    print(t("sched.pause_hint"))


def resume_daemon():
    """Resume the daemon from pause."""
    pid = read_pid()
    if not pid:
        print(t("sched.not_running"))
        return

    save_state(paused=False)
    print(t("sched.resumed"))
