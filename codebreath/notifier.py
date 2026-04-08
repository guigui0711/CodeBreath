"""
macOS notification sender using osascript.
Zero external dependencies — uses only AppleScript via subprocess.
"""

import subprocess
from dataclasses import dataclass
from typing import Optional


@dataclass
class NotificationPayload:
    """Structured notification content."""

    title: str
    subtitle: str
    body: str
    sound: str = "default"


def send_notification(
    title: str,
    subtitle: str = "",
    body: str = "",
    sound: str = "default",
) -> bool:
    """Send a macOS system notification via osascript.

    Args:
        title: Main notification title (e.g., "Eye Care Time")
        subtitle: Secondary line (e.g., "Close Eyes & Breathe — 20s")
        body: Detail text (benefit/consequence)
        sound: Sound name (default, Basso, Blow, Bottle, Frog, etc.)

    Returns:
        True if notification was sent successfully, False otherwise.
    """
    # Escape double quotes for AppleScript string
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


def send_health_reminder(
    category: str,
    tip_name: str,
    instruction: str,
    benefit: str,
    consequence: str,
    extra_benefit: str = "",
) -> bool:
    """Send a formatted health reminder notification.

    This is the main entry point for sending reminders.
    The notification shows:
      - Title: category icon + category name
      - Subtitle: what to do
      - Body: why it helps (truncated to fit notification)

    Args:
        category: One of "eye", "neck", "sedentary", "outdoor"
        tip_name: Name of the tip/exercise
        instruction: What to do
        benefit: Why it helps
        consequence: What happens if skipped
        extra_benefit: Additional rotating benefit message

    Returns:
        True if sent successfully.
    """
    icons = {
        "eye": "👁",
        "neck": "🦴",
        "sedentary": "🚶",
        "outdoor": "☀️",
    }
    labels = {
        "eye": "Eye Care",
        "neck": "Neck Exercise",
        "sedentary": "Move Break",
        "outdoor": "Go Outside!",
    }

    icon = icons.get(category, "💡")
    label = labels.get(category, "Health Break")

    title = f"{icon} {label}: {tip_name}"

    # Subtitle: instruction (truncated if too long for notification)
    subtitle = instruction
    if len(subtitle) > 100:
        subtitle = subtitle[:97] + "..."

    # Body: benefit (short version for notification)
    body = benefit
    if extra_benefit:
        body = extra_benefit  # Use the rotating extra message for variety

    # macOS notifications truncate long body text, so keep it concise
    if len(body) > 150:
        body = body[:147] + "..."

    return send_notification(title, subtitle, body)


def send_noon_reminder(extra_message: str = "") -> bool:
    """Send the critical noon outdoor reminder with emphasis."""
    title = "☀️ NOON: Go Outside Now!"
    subtitle = "15 min outdoor walk — your eyes NEED real sunlight"
    body = extra_message or (
        "Indoor = 400 lux. Outdoor = 10,000+ lux. "
        "This is the #1 thing you can do for myopia control."
    )
    return send_notification(title, subtitle, body, sound="Blow")
