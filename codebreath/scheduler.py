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
from html import escape as _html_escape
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


def _detail_html_page(title: str, body_content: str) -> str:
    """Wrap body_content in a styled HTML page shell."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{_html_escape(title)} — CodeBreath</title>
<style>
  :root {{
    --bg: #0c0e14;
    --surface: #161a24;
    --card: #1c2130;
    --card-hover: #222838;
    --border: rgba(255,255,255,0.06);
    --text: #e8ecf4;
    --text-secondary: #8b95a8;
    --accent: #6c9cff;
    --accent-glow: rgba(108,156,255,0.15);
    --green: #5ee4a0;
    --green-bg: rgba(94,228,160,0.08);
    --red: #ff6b7a;
    --red-bg: rgba(255,107,122,0.08);
    --orange: #ffb06c;
    --radius: 16px;
    --radius-sm: 10px;
  }}
  @media (prefers-color-scheme: light) {{
    :root {{
      --bg: #f5f5f7;
      --surface: #ffffff;
      --card: #ffffff;
      --card-hover: #f9f9fb;
      --border: rgba(0,0,0,0.06);
      --text: #1d1d1f;
      --text-secondary: #86868b;
      --accent: #0071e3;
      --accent-glow: rgba(0,113,227,0.08);
      --green: #28a745;
      --green-bg: rgba(40,167,69,0.06);
      --red: #d73a49;
      --red-bg: rgba(215,58,73,0.06);
      --orange: #e36209;
    }}
  }}

  * {{ margin: 0; padding: 0; box-sizing: border-box; }}

  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', system-ui, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.65;
    padding: 0;
    -webkit-font-smoothing: antialiased;
  }}

  .page-wrap {{
    max-width: 520px;
    margin: 0 auto;
    padding: 3rem 1.5rem 2rem;
  }}

  /* ── Header ── */
  .page-header {{
    text-align: center;
    margin-bottom: 2rem;
  }}
  .page-header .icon {{
    font-size: 2.5rem;
    margin-bottom: 0.5rem;
    display: block;
  }}
  .page-header h1 {{
    font-size: 1.35rem;
    font-weight: 700;
    letter-spacing: -0.02em;
  }}
  .page-header .subtitle {{
    font-size: 0.85rem;
    color: var(--text-secondary);
    margin-top: 0.25rem;
  }}

  /* ── Section ── */
  .section {{
    margin-bottom: 1.75rem;
  }}
  .section-title {{
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--accent);
    margin-bottom: 0.75rem;
    padding-left: 0.25rem;
  }}

  /* ── Card ── */
  .card {{
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.25rem 1.4rem;
    margin-bottom: 0.75rem;
    transition: background 0.15s;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
  }}
  .card:hover {{ background: var(--card-hover); }}

  .card-name {{
    font-size: 1.05rem;
    font-weight: 650;
    margin-bottom: 0.85rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }}
  .card-name .badge {{
    font-size: 0.65rem;
    font-weight: 500;
    background: var(--accent-glow);
    color: var(--accent);
    padding: 0.15rem 0.55rem;
    border-radius: 20px;
    letter-spacing: 0.02em;
  }}

  /* ── Instruction block ── */
  .instruction {{
    background: var(--accent-glow);
    border-radius: var(--radius-sm);
    padding: 0.85rem 1rem;
    margin-bottom: 0.85rem;
    font-size: 0.92rem;
    line-height: 1.6;
    border-left: 3px solid var(--accent);
  }}

  /* ── Info rows ── */
  .info-row {{
    display: flex;
    gap: 0.5rem;
    padding: 0.6rem 0;
    font-size: 0.88rem;
    align-items: flex-start;
  }}
  .info-row + .info-row {{
    border-top: 1px solid var(--border);
  }}
  .info-icon {{
    flex-shrink: 0;
    width: 1.3rem;
    text-align: center;
    font-size: 0.85rem;
    padding-top: 0.1rem;
  }}
  .info-content {{
    flex: 1;
  }}
  .info-label {{
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-secondary);
    margin-bottom: 0.1rem;
  }}
  .info-text {{ color: var(--text); }}
  .info-row.benefit .info-text {{ color: var(--green); }}
  .info-row.consequence .info-text {{ color: var(--red); }}

  /* ── ASCII art ── */
  .ascii-wrap {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.7rem 1rem;
    margin-bottom: 0.85rem;
    overflow-x: auto;
  }}
  .ascii-wrap pre {{
    font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
    font-size: 0.7rem;
    line-height: 1.45;
    color: var(--text-secondary);
    margin: 0;
    white-space: pre;
  }}

  /* ── Duration pill ── */
  .duration {{
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.75rem;
    color: var(--text-secondary);
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 0.2rem 0.7rem;
    margin-top: 0.5rem;
  }}

  /* ── Stats (report page) ── */
  .stats-hero {{
    text-align: center;
    padding: 2rem 0 1.5rem;
  }}
  .stats-hero .big-number {{
    font-size: 4rem;
    font-weight: 800;
    letter-spacing: -0.04em;
    background: linear-gradient(135deg, var(--accent), var(--green));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }}
  .stats-hero .big-unit {{
    font-size: 1.8rem;
    font-weight: 600;
  }}
  .stats-hero .label {{
    color: var(--text-secondary);
    font-size: 0.85rem;
    margin-top: 0.25rem;
  }}
  .stat-pair {{
    display: flex;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }}
  .stat-box {{
    flex: 1;
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.85rem 1rem;
    text-align: center;
  }}
  .stat-box .num {{
    font-size: 1.5rem;
    font-weight: 700;
  }}
  .stat-box .lbl {{
    font-size: 0.75rem;
    color: var(--text-secondary);
  }}
  .stat-box.good .num {{ color: var(--green); }}
  .stat-box.bad .num {{ color: var(--red); }}

  .progress-row {{
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.7rem 0;
    font-size: 0.88rem;
  }}
  .progress-row + .progress-row {{
    border-top: 1px solid var(--border);
  }}
  .progress-row .cat-name {{
    width: 5rem;
    font-weight: 500;
    flex-shrink: 0;
  }}
  .progress-bar-track {{
    flex: 1;
    height: 6px;
    background: var(--border);
    border-radius: 3px;
    overflow: hidden;
  }}
  .progress-bar-fill {{
    height: 100%;
    border-radius: 3px;
    background: var(--accent);
    transition: width 0.3s;
  }}
  .progress-row .pct {{
    width: 3.5rem;
    text-align: right;
    font-weight: 600;
    font-size: 0.8rem;
    color: var(--text-secondary);
  }}

  .focus-card {{
    background: var(--red-bg);
    border: 1px solid var(--border);
    border-left: 3px solid var(--orange);
    border-radius: var(--radius-sm);
    padding: 0.85rem 1rem;
    font-size: 0.9rem;
  }}
  .focus-card strong {{ color: var(--orange); }}

  /* ── Footer ── */
  .page-footer {{
    text-align: center;
    color: var(--text-secondary);
    font-size: 0.7rem;
    margin-top: 2.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid var(--border);
    letter-spacing: 0.05em;
  }}
</style>
</head>
<body>
<div class="page-wrap">
  {body_content}
  <div class="page-footer">CODEBREATH</div>
</div>
</body>
</html>"""


class Scheduler:
    """Main scheduling engine.

    Manages two independent reminder timers:
    - Eye+Neck combined (default: every 30 min)
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
        self._next_eyeneck: Optional[float] = None
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
        self._next_eyeneck = now + self.config.eyeneck_interval_min * 60
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
            if self._next_eyeneck and now >= self._next_eyeneck:
                self._fire_combined_eye_neck_reminder()
                self._next_eyeneck = now + self.config.eyeneck_interval_min * 60

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

        detail_html = self._build_combo_detail_html(eye_tip, neck_combo)
        panel_path = create_detail_panel("eye_neck_combo", detail_html)
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

    def _fire_sedentary_reminder(self):
        """Fire a sedentary break reminder."""
        from .i18n import get_language

        current_hour = datetime.now().hour
        tip = self.rotator.next_sedentary_tip(current_hour)

        icons = {"sedentary": "🚶"}
        icon = icons.get("sedentary", "🚶")
        label = t("cat.sedentary")
        title = f"{icon} {label}: {tip.name}"
        subtitle = tip.instruction[:100]
        body = tip.benefit[:150]

        detail_html = self._build_single_tip_html(tip, "sedentary")
        panel_path = create_detail_panel("sedentary", detail_html)

        resp_file = send_notification_trackable(
            title=title, subtitle=subtitle, body=body, category="sedentary"
        )
        if resp_file:
            self._response_meta[resp_file] = {
                "category": "sedentary",
                "tip_name": tip.name,
                "panel_path": panel_path,
            }
        self.log.add_event("sedentary", tip.name, "notified")

    def _fire_noon_reminder(self):
        """Fire the noon outdoor reminder."""
        extra = self.rotator.next_noon_message()
        noon_tip = self.rotator.get_noon_outdoor()

        title = f"☀️ {t('notify.noon_title')}"
        subtitle = t("notify.noon_subtitle")
        body = extra or t("notify.noon_default")

        detail_html = self._build_single_tip_html(noon_tip, "outdoor")
        panel_path = create_detail_panel("noon_outdoor", detail_html)

        resp_file = send_notification_trackable(
            title=title, subtitle=subtitle, body=body,
            sound="Blow", category="outdoor",
        )
        if resp_file:
            self._response_meta[resp_file] = {
                "category": "outdoor",
                "tip_name": noon_tip.name,
                "panel_path": panel_path,
            }
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

        detail_html = self._build_daily_report_html(stats, rate, weakest)
        panel_path = create_detail_panel("daily_report", detail_html)
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

            if action in ("details", "dismissed") and meta.get("panel_path"):
                panel_path = meta["panel_path"]
                opened = open_detail_panel(panel_path)
                self._debug_log(
                    f"open details action={action} opened={opened} panel_path={panel_path}"
                )
                # Send a follow-up notification so user can still mark done/skip
                self._send_followup_notification(meta)
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

    def _send_followup_notification(self, meta: dict):
        """Send a follow-up notification after opening details, so user can still mark done/skip."""
        from .i18n import get_language

        lang = get_language()
        category = meta.get("category", "unknown")

        if lang == "zh":
            title = "✅ 做完了吗？"
            if category == "eye+neck":
                subtitle = "护眼 + 颈肩"
            elif category == "sedentary":
                subtitle = "起来动动"
            elif category == "outdoor":
                subtitle = "户外时间"
            else:
                subtitle = ""
            body = "看完详情后，记得标记完成状态"
        else:
            title = "✅ Did you do it?"
            if category == "eye+neck":
                subtitle = "Eye + Neck"
            elif category == "sedentary":
                subtitle = "Move Break"
            elif category == "outdoor":
                subtitle = "Go Outside"
            else:
                subtitle = ""
            body = "Mark your completion after reviewing details"

        resp_file = send_notification_trackable(
            title=title,
            subtitle=subtitle,
            body=body,
            category=f"{category}_followup",
        )
        if resp_file:
            # Copy meta but remove panel_path so clicking this one
            # won't loop into opening details again
            followup_meta = {k: v for k, v in meta.items() if k != "panel_path"}
            self._response_meta[resp_file] = followup_meta
            self._debug_log(f"followup sent resp_file={resp_file} category={category}")

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

    def _build_combo_detail_html(self, eye_tip, neck_combo) -> str:
        """Build HTML detail page for combined eye+neck reminder."""
        from .i18n import get_language

        lang = get_language()

        if lang == "zh":
            page_title = "护眼 + 颈肩"
            page_sub = "先护眼，再做颈肩——1 分钟搞定"
            eye_section = "👁  先做护眼"
            neck_section = "🦴  再做颈肩"
            lbl_how = "怎么做"
            lbl_why = "好处"
            lbl_skip = "不做的后果"
            lbl_sec = "秒"
        else:
            page_title = "Eye + Neck"
            page_sub = "Eye reset first, then neck set — 1 minute total"
            eye_section = "👁  Eye Reset"
            neck_section = "🦴  Neck Set"
            lbl_how = "How to do it"
            lbl_why = "Why it helps"
            lbl_skip = "If you skip"
            lbl_sec = "sec"

        def _tip_card(tip) -> str:
            ascii_html = ""
            if tip.ascii_art and tip.ascii_art.strip():
                ascii_html = f'<div class="ascii-wrap"><pre>{_html_escape(tip.ascii_art.strip())}</pre></div>'
            return f"""
            <div class="card">
              <div class="card-name">{_html_escape(tip.name)} <span class="badge">{tip.duration_seconds}{lbl_sec}</span></div>
              {ascii_html}
              <div class="instruction">{_html_escape(tip.instruction)}</div>
              <div class="info-row benefit">
                <div class="info-icon">✦</div>
                <div class="info-content"><div class="info-label">{lbl_why}</div><div class="info-text">{_html_escape(tip.benefit)}</div></div>
              </div>
              <div class="info-row consequence">
                <div class="info-icon">⚠</div>
                <div class="info-content"><div class="info-label">{lbl_skip}</div><div class="info-text">{_html_escape(tip.consequence)}</div></div>
              </div>
            </div>"""

        eye_card = _tip_card(eye_tip)
        neck_cards = "\n".join(_tip_card(t) for t in neck_combo)

        return _detail_html_page(page_title, f"""
        <div class="page-header">
          <span class="icon">🧠</span>
          <h1>{_html_escape(page_title)}</h1>
          <div class="subtitle">{_html_escape(page_sub)}</div>
        </div>
        <div class="section">
          <div class="section-title">{eye_section}</div>
          {eye_card}
        </div>
        <div class="section">
          <div class="section-title">{neck_section}</div>
          {neck_cards}
        </div>
        """)

    def _build_single_tip_html(self, tip, category: str) -> str:
        """Build HTML detail page for a single tip (sedentary/outdoor)."""
        from .i18n import get_language

        lang = get_language()
        cat_icons = {"sedentary": "🚶", "outdoor": "☀️"}
        icon = cat_icons.get(category, "💡")

        if lang == "zh":
            lbl_how = "怎么做"
            lbl_why = "好处"
            lbl_skip = "不做的后果"
            lbl_sec = "秒"
            cat_labels = {"sedentary": "起来动动", "outdoor": "户外时间"}
            page_sub = "休息一下，身体会感谢你"
        else:
            lbl_how = "How to do it"
            lbl_why = "Why it helps"
            lbl_skip = "If you skip"
            lbl_sec = "sec"
            cat_labels = {"sedentary": "Move Break", "outdoor": "Go Outside"}
            page_sub = "A short break goes a long way"

        cat_label = cat_labels.get(category, "Health")
        ascii_html = ""
        if tip.ascii_art and tip.ascii_art.strip():
            ascii_html = f'<div class="ascii-wrap"><pre>{_html_escape(tip.ascii_art.strip())}</pre></div>'

        return _detail_html_page(tip.name, f"""
        <div class="page-header">
          <span class="icon">{icon}</span>
          <h1>{_html_escape(tip.name)}</h1>
          <div class="subtitle">{_html_escape(page_sub)}</div>
        </div>
        <div class="section">
          <div class="section-title">{_html_escape(cat_label)}</div>
          <div class="card">
            <div class="card-name">{_html_escape(tip.name)} <span class="badge">{tip.duration_seconds}{lbl_sec}</span></div>
            {ascii_html}
            <div class="instruction">{_html_escape(tip.instruction)}</div>
            <div class="info-row benefit">
              <div class="info-icon">✦</div>
              <div class="info-content"><div class="info-label">{lbl_why}</div><div class="info-text">{_html_escape(tip.benefit)}</div></div>
            </div>
            <div class="info-row consequence">
              <div class="info-icon">⚠</div>
              <div class="info-content"><div class="info-label">{lbl_skip}</div><div class="info-text">{_html_escape(tip.consequence)}</div></div>
            </div>
          </div>
        </div>
        """)

    def _build_daily_report_html(self, stats: dict, rate: int, weakest: str) -> str:
        """Build HTML detail page for the daily report card."""
        from .i18n import get_language

        lang = get_language()

        if lang == "zh":
            page_title = "今日健康日报"
            page_sub = "你今天的表现"
            lbl_rate = "完成率"
            lbl_done = "已完成"
            lbl_skip = "已跳过"
            lbl_breakdown = "分类表现"
            lbl_focus = "明日重点"
            lbl_focus_text = "优先补齐"
        else:
            page_title = "Daily Health Card"
            page_sub = "Your health summary for today"
            lbl_rate = "Completion rate"
            lbl_done = "Completed"
            lbl_skip = "Skipped"
            lbl_breakdown = "Category Breakdown"
            lbl_focus = "Tomorrow's Focus"
            lbl_focus_text = "Prioritize"

        completed = stats.get('completed', 0)
        skipped = stats.get('skipped', 0)

        cat_rows = ""
        for cat in ("eye", "neck", "sedentary", "outdoor"):
            done = stats.get(f"{cat}_completed", 0)
            total = stats.get(f"{cat}_total", 0)
            if total > 0:
                pct = int(100 * done / total)
                cat_rows += f"""
                <div class="progress-row">
                  <span class="cat-name">{t(f"cat.{cat}")}</span>
                  <div class="progress-bar-track"><div class="progress-bar-fill" style="width:{pct}%"></div></div>
                  <span class="pct">{done}/{total}</span>
                </div>"""

        focus_html = ""
        if weakest:
            focus_html = f"""
            <div class="section">
              <div class="section-title">{lbl_focus}</div>
              <div class="focus-card">{lbl_focus_text}: <strong>{t(f"cat.{weakest}")}</strong></div>
            </div>"""

        return _detail_html_page(page_title, f"""
        <div class="page-header">
          <span class="icon">📊</span>
          <h1>{_html_escape(page_title)}</h1>
          <div class="subtitle">{_html_escape(page_sub)}</div>
        </div>
        <div class="stats-hero">
          <div class="big-number">{rate}<span class="big-unit">%</span></div>
          <div class="label">{lbl_rate}</div>
        </div>
        <div class="stat-pair">
          <div class="stat-box good"><div class="num">{completed}</div><div class="lbl">{lbl_done}</div></div>
          <div class="stat-box bad"><div class="num">{skipped}</div><div class="lbl">{lbl_skip}</div></div>
        </div>
        <div class="section">
          <div class="section-title">{lbl_breakdown}</div>
          <div class="card">
            {cat_rows}
          </div>
        </div>
        {focus_html}
        """)

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
        print(f"  🧠  {_t('cat.eyeneck')}: every {self.config.eyeneck_interval_min} min")
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
        if self._next_eyeneck:
            remaining = max(0, int(self._next_eyeneck - now))
            result["eyeneck"] = f"in {remaining // 60}m {remaining % 60}s"
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
