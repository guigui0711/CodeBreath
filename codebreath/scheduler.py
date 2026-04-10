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
    send_notification_trackable,
    read_response,
    cleanup_old_responses,
    create_detail_panel,
    open_detail_panel,
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
        self._daily_report_sent_today = False

        # Track next fire times
        self._next_eye: Optional[float] = None
        self._next_neck: Optional[float] = None
        self._next_sedentary: Optional[float] = None

        # Pending notification responses: list of (resp_file, category, name)
        self._response_meta: dict = {}

    def _debug_log(self, message: str):
        """Append debug messages for notification response tracing."""
        from pathlib import Path

        log_path = Path.home() / ".codebreath" / "debug.log"
        try:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            with open(log_path, "a", encoding="utf-8") as f:
                f.write(f"{datetime.now().isoformat()} {message}\n")
        except OSError:
            pass

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

            # Daily report card (once per day). Runs regardless of working hours.
            if (
                self.config.daily_report_enabled
                and not self._daily_report_sent_today
                and current_hour == self.config.daily_report_hour
                and current_minute >= self.config.daily_report_minute
            ):
                self._fire_daily_report_card()

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
            eye_due = self._next_eye and now >= self._next_eye
            neck_due = self._next_neck and now >= self._next_neck

            # Combine eye + neck into one compact reminder when due together.
            if eye_due and neck_due:
                self._fire_combined_eye_neck_reminder()
                self._next_eye = now + self.config.eye_interval_min * 60
                self._next_neck = now + self.config.neck_interval_min * 60
            else:
                if eye_due:
                    self._fire_eye_reminder()
                    self._next_eye = now + self.config.eye_interval_min * 60

                if neck_due:
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

    def _fire_combined_eye_neck_reminder(self):
        """Fire one compact reminder for eye + neck together."""
        from .i18n import get_language

        eye_tip, _, _ = self.rotator.next_eye_tip()
        neck_combo = self.rotator.next_neck_combo()
        neck_names = " + ".join(tip.name for tip in neck_combo)

        lang = get_language()
        if lang == "zh":
            title = "🧠 联合提醒：护眼 + 颈肩"
            subtitle = "先护眼 20 秒，再做 1 组颈肩动作"
            body = "1 分钟搞定，减少今晚眼酸和肩颈僵硬。"
        else:
            title = "🧠 Combo: Eye + Neck"
            subtitle = "20s eye reset, then one neck set"
            body = "One minute now prevents sore eyes and neck stiffness later."

        detail_markdown = self._build_combo_detail_markdown(eye_tip, neck_combo)
        panel_path = create_detail_panel("eye_neck_combo", detail_markdown)
        resp_file = send_notification_trackable(
            title=title,
            subtitle=subtitle,
            body=body,
            category="eyeneck",
        )

        if resp_file:
            self._response_meta[resp_file] = {
                "category": "eye+neck",
                "eye_tip": eye_tip.name,
                "neck_tip": neck_names,
                "panel_path": panel_path,
            }
            self._debug_log(f"combo sent resp_file={resp_file} panel_path={panel_path}")

        self.log.add_event("eye", eye_tip.name, "notified")
        self.log.add_event("neck", neck_names, "notified")

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

    def _fire_daily_report_card(self):
        """Send one compact daily report card notification."""
        from .i18n import get_language

        stats = self.log.get_stats()
        completed = stats.get("completed", 0)
        skipped = stats.get("skipped", 0)
        total = max(1, completed + skipped)
        rate = int(100 * completed / total)

        weakest = self._weakest_category(stats)
        weak_label = t(f"cat.{weakest}") if weakest else "-"

        lang = get_language()
        if lang == "zh":
            title = "📊 今日健康日报"
            subtitle = f"完成率 {rate}% | 完成 {completed} 次 | 跳过 {skipped} 次"
            body = f"最薄弱项：{weak_label}。明天优先补这个。"
        else:
            title = "📊 Daily Health Card"
            subtitle = f"{rate}% done | {completed} completed | {skipped} skipped"
            body = f"Weakest area: {weak_label}. Prioritize this tomorrow."

        detail_markdown = self._build_daily_report_markdown(stats, rate, weakest)
        panel_path = create_detail_panel("daily_report", detail_markdown)
        resp_file = send_notification_trackable(
            title=title,
            subtitle=subtitle,
            body=body,
            category="dailyreport",
        )
        if resp_file:
            self._response_meta[resp_file] = {
                "category": "dailyreport",
                "tip_name": "daily_report",
                "panel_path": panel_path,
            }
            self._debug_log(f"daily sent resp_file={resp_file} panel_path={panel_path}")
        self._daily_report_sent_today = True

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
            meta = self._response_meta.pop(str(f), {})
            self._debug_log(
                f"response file={str(f)} action={action} panel_path={meta.get('panel_path', '')} category={meta.get('category', 'unknown')}"
            )

            if not meta:
                # Backward-compatible fallback: infer category from filename
                parts = f.stem.split("_", 1)
                meta = {"category": parts[0] if parts else "unknown", "tip_name": ""}

            if action == "details":
                panel_path = meta.get("panel_path", "")
                opened = open_detail_panel(panel_path)
                self._debug_log(
                    f"open details action=details opened={opened} panel_path={panel_path}"
                )
                continue

            # On macOS, clicking notification body may be reported as
            # default action ("details") or dismissal depending on timing/style.
            # For notifications with detail panels, treat dismiss as details.
            if action == "dismissed" and meta.get("panel_path"):
                panel_path = meta.get("panel_path", "")
                opened = open_detail_panel(panel_path)
                self._debug_log(
                    f"open details action=dismissed opened={opened} panel_path={panel_path}"
                )
                continue

            category = meta.get("category", "unknown")

            if action == "done":
                if category == "eye+neck":
                    self.log.add_event("eye", meta.get("eye_tip", ""), "completed")
                    self.log.add_event("neck", meta.get("neck_tip", ""), "completed")
                elif category in ("dailyreport", "unknown"):
                    pass
                else:
                    self.log.add_event(category, meta.get("tip_name", ""), "completed")
            elif action == "skip":
                if category == "eye+neck":
                    self.log.add_event("eye", meta.get("eye_tip", ""), "skipped")
                    self.log.add_event("neck", meta.get("neck_tip", ""), "skipped")
                elif category in ("dailyreport", "unknown"):
                    pass
                else:
                    self.log.add_event(category, meta.get("tip_name", ""), "skipped")

    def _in_working_hours(self, hour: int) -> bool:
        """Check if current hour is within working hours."""
        return self.config.work_start_hour <= hour < self.config.work_end_hour

    def _daily_reset(self, today: date):
        """Reset daily state."""
        self._current_date = today
        self._noon_sent_today = False
        self._daily_report_sent_today = False
        self.rotator.reset_daily()
        self.log = DailyLog.today()

    def _weakest_category(self, stats: dict) -> str:
        """Return category key with lowest completion ratio among active tracks."""
        candidates = []
        for cat in ("eye", "neck", "sedentary", "outdoor"):
            total = stats.get(f"{cat}_total", 0)
            if total <= 0:
                continue
            done = stats.get(f"{cat}_completed", 0)
            candidates.append((done / total, cat))
        if not candidates:
            return ""
        candidates.sort(key=lambda x: x[0])
        return candidates[0][1]

    def _build_combo_detail_markdown(self, eye_tip, neck_combo) -> str:
        """Build markdown panel for combined eye+neck reminder."""
        from .i18n import get_language

        lang = get_language()
        neck_names = " + ".join(tip.name for tip in neck_combo)
        neck_instruction = " -> ".join(tip.instruction for tip in neck_combo)
        if lang == "zh":
            return (
                "# 护眼 + 颈肩 详情\n\n"
                "## 先做护眼\n"
                f"- 动作: {eye_tip.name}\n"
                f"- 指引: {eye_tip.instruction}\n"
                f"- 好处: {eye_tip.benefit}\n"
                f"- 不做后果: {eye_tip.consequence}\n\n"
                "## 再做颈肩\n"
                f"- 动作: {neck_names}\n"
                f"- 指引: {neck_instruction}\n"
                f"- 好处: {neck_combo[0].benefit}\n"
                f"- 不做后果: {neck_combo[0].consequence}\n"
            )
        return (
            "# Eye + Neck Details\n\n"
            "## Eye reset first\n"
            f"- Exercise: {eye_tip.name}\n"
            f"- Guide: {eye_tip.instruction}\n"
            f"- Benefit: {eye_tip.benefit}\n"
            f"- If skipped: {eye_tip.consequence}\n\n"
            "## Then neck set\n"
            f"- Exercise: {neck_names}\n"
            f"- Guide: {neck_instruction}\n"
            f"- Benefit: {neck_combo[0].benefit}\n"
            f"- If skipped: {neck_combo[0].consequence}\n"
        )

    def _build_daily_report_markdown(self, stats: dict, rate: int, weakest: str) -> str:
        """Build markdown panel for the daily report card."""
        from .i18n import get_language

        lang = get_language()
        lines = []
        if lang == "zh":
            lines.append("# 今日健康日报")
            lines.append("")
            lines.append(f"- 完成率: {rate}%")
            lines.append(f"- 总完成: {stats.get('completed', 0)}")
            lines.append(f"- 总跳过: {stats.get('skipped', 0)}")
            lines.append("")
            lines.append("## 分类表现")
            for cat in ("eye", "neck", "sedentary", "outdoor"):
                done = stats.get(f"{cat}_completed", 0)
                total = stats.get(f"{cat}_total", 0)
                if total > 0:
                    lines.append(f"- {t(f'cat.{cat}')}: {done}/{total}")
            if weakest:
                lines.append("")
                lines.append(f"## 明日重点\n- 优先补齐: {t(f'cat.{weakest}')}")
        else:
            lines.append("# Daily Health Card")
            lines.append("")
            lines.append(f"- Completion rate: {rate}%")
            lines.append(f"- Total completed: {stats.get('completed', 0)}")
            lines.append(f"- Total skipped: {stats.get('skipped', 0)}")
            lines.append("")
            lines.append("## Category breakdown")
            for cat in ("eye", "neck", "sedentary", "outdoor"):
                done = stats.get(f"{cat}_completed", 0)
                total = stats.get(f"{cat}_total", 0)
                if total > 0:
                    lines.append(f"- {t(f'cat.{cat}')}: {done}/{total}")
            if weakest:
                lines.append("")
                lines.append(f"## Tomorrow focus\n- Prioritize: {t(f'cat.{weakest}')}")
        return "\n".join(lines) + "\n"

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
