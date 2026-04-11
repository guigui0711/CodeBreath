"""
macOS notification sender for CodeBreath.

Two backends:
1. Native (preferred) — Swift helper app with UNUserNotificationCenter,
   alert-style notifications that stay on screen, and Done/Skip action
   buttons.  User responses are written to a JSON file so the scheduler
   can log completions.
2. Fallback — osascript `display notification` (no action buttons, banners
   auto-dismiss after ~5 s).

The Swift helper lives at ~/.codebreath/CodeBreathNotify.app.  Build it
with `./swift/build.sh`.  If the helper is not found, the fallback is
used automatically.
"""

import json
import os
import subprocess
import time
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_CODEBREATH_DIR = Path.home() / ".codebreath"
_NATIVE_APP = _CODEBREATH_DIR / "CodeBreathNotify.app"
_NATIVE_BIN = _NATIVE_APP / "Contents" / "MacOS" / "CodeBreathNotify"
_RESPONSE_DIR = _CODEBREATH_DIR / "responses"


def _native_available() -> bool:
    """Check if the native Swift notification helper is built."""
    return _NATIVE_BIN.is_file()


def _ensure_response_dir() -> Path:
    """Create the response directory if needed."""
    _RESPONSE_DIR.mkdir(parents=True, exist_ok=True)
    return _RESPONSE_DIR


# ---------------------------------------------------------------------------
# Native notification (preferred)
# ---------------------------------------------------------------------------


def _send_native(
    title: str,
    subtitle: str = "",
    body: str = "",
    sound: str = "default",
    category: str = "",
    timeout: int = 300,
) -> Optional[str]:
    """Send notification via native Swift helper (non-blocking).

    Returns the response file path (caller can poll it later),
    or None if the native helper is not available.
    """
    if not _native_available():
        return None

    from .i18n import get_language

    # Determine button labels
    lang = get_language()
    if lang == "zh":
        done_label = "做了 ✓"
        skip_label = "跳过"
    else:
        done_label = "Done ✓"
        skip_label = "Skip"

    # Create response file
    resp_dir = _ensure_response_dir()
    resp_file = resp_dir / f"{category}_{os.getpid()}_{id(title)}.json"

    try:
        cmd = [
            "open",
            "-n",
            "-g",  # -g = don't bring to foreground
            str(_NATIVE_APP),
            "--args",
            "--title",
            title,
            "--subtitle",
            subtitle,
            "--body",
            body,
            "--done-label",
            done_label,
            "--skip-label",
            skip_label,
            "--response-file",
            str(resp_file),
            "--sound",
            sound,
            "--timeout",
            str(timeout),
        ]

        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return str(resp_file)
    except OSError:
        return None


# ---------------------------------------------------------------------------
# Fallback: osascript notification
# ---------------------------------------------------------------------------


def _send_osascript(
    title: str,
    subtitle: str = "",
    body: str = "",
    sound: str = "default",
) -> bool:
    """Send a macOS system notification via osascript (fallback)."""
    title = title.replace('"', '\\"')
    subtitle = subtitle.replace('"', '\\"')
    body = body.replace('"', '\\"')

    script = (
        f'display notification "{body}" '
        f'with title "{title}" '
        f'subtitle "{subtitle}" '
        f'sound name "{sound}"'
    )

    try:
        subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            timeout=5,
        )
        return True
    except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
        return False


# ---------------------------------------------------------------------------
# Unified send (tries native first, falls back to osascript)
# ---------------------------------------------------------------------------


def send_notification(
    title: str,
    subtitle: str = "",
    body: str = "",
    sound: str = "default",
    category: str = "",
    timeout: int = 300,
) -> bool:
    """Send a macOS notification.

    Tries native Swift helper first (with action buttons), falls back
    to osascript if the helper is not built.

    Returns True if the notification was sent (by either backend).
    """
    resp = _send_native(
        title,
        subtitle,
        body,
        sound,
        category,
        timeout,
    )
    if resp is not None:
        return True
    return _send_osascript(title, subtitle, body, sound)


def send_notification_trackable(
    title: str,
    subtitle: str = "",
    body: str = "",
    sound: str = "default",
    category: str = "",
    timeout: int = 300,
) -> Optional[str]:
    """Send notification and return response file path when native backend is used.

    If native helper is unavailable, sends via fallback and returns None.
    """
    resp = _send_native(
        title,
        subtitle,
        body,
        sound,
        category,
        timeout,
    )
    if resp is not None:
        return resp
    _send_osascript(title, subtitle, body, sound)
    return None


def create_detail_panel(filename_prefix: str, html_content: str) -> Optional[str]:
    """Persist an HTML detail panel and return its path."""
    details_dir = _CODEBREATH_DIR / "details"
    details_dir.mkdir(parents=True, exist_ok=True)
    safe_prefix = "".join(
        c if c.isalnum() or c in "-_" else "_" for c in filename_prefix
    )
    stamp = str(int(time.time() * 1000))
    path = details_dir / f"{safe_prefix}_{stamp}.html"
    try:
        path.write_text(html_content, encoding="utf-8")
        return str(path)
    except OSError:
        return None


def open_detail_panel(panel_path: str) -> bool:
    """Open a markdown detail panel with system default app."""
    if not panel_path:
        return False
    try:
        subprocess.Popen(
            ["open", panel_path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except OSError:
        return False


# ---------------------------------------------------------------------------
# Response file utilities
# ---------------------------------------------------------------------------


def read_response(resp_file: str) -> Optional[str]:
    """Read and consume a notification response file.

    Returns the action string ("done", "skip", "dismissed", "timeout")
    or None if file doesn't exist yet or is invalid.
    """
    path = Path(resp_file)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text())
        path.unlink(missing_ok=True)
        return data.get("action")
    except (json.JSONDecodeError, OSError):
        return None


def cleanup_old_responses(max_age_seconds: int = 600):
    """Remove response files older than max_age_seconds."""
    if not _RESPONSE_DIR.is_dir():
        return
    import time

    now = time.time()
    for f in _RESPONSE_DIR.iterdir():
        if f.suffix == ".json":
            try:
                if now - f.stat().st_mtime > max_age_seconds:
                    f.unlink(missing_ok=True)
            except OSError:
                pass


# ---------------------------------------------------------------------------
# High-level senders (used by scheduler)
# ---------------------------------------------------------------------------


def send_health_reminder(
    category: str,
    tip_name: str,
    instruction: str,
    benefit: str,
    consequence: str,
    extra_benefit: str = "",
) -> bool:
    """Send a formatted health reminder notification.

    The notification shows:
      - Title: category icon + category name + tip name
      - Subtitle: what to do
      - Body: why it helps

    Returns True if sent successfully.
    """
    icons = {
        "eye": "👁",
        "neck": "🦴",
        "sedentary": "🚶",
        "outdoor": "☀️",
    }

    from .i18n import t

    icon = icons.get(category, "💡")
    label = t(f"cat.{category}") if category in icons else t("cat.health_break")

    title = f"{icon} {label}: {tip_name}"

    # Subtitle: instruction (truncated if too long)
    subtitle = instruction
    if len(subtitle) > 100:
        subtitle = subtitle[:97] + "..."

    # Body: benefit (use rotating extra message for variety)
    body = benefit
    if extra_benefit:
        body = extra_benefit
    if len(body) > 150:
        body = body[:147] + "..."

    return send_notification(title, subtitle, body, category=category)


def send_noon_reminder(extra_message: str = "") -> bool:
    """Send the critical noon outdoor reminder with emphasis."""
    from .i18n import t

    title = f"☀️ {t('notify.noon_title')}"
    subtitle = t("notify.noon_subtitle")
    body = extra_message or t("notify.noon_default")
    return send_notification(title, subtitle, body, sound="Blow", category="outdoor")
