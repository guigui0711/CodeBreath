"""
Terminal interactive exercise UI.
Displays countdown timers, ASCII art guides, and exercise instructions
in a clean terminal interface. Zero external dependencies.
"""

import os
import sys
import time
from typing import List, Optional

from .content import Tip

# ANSI color codes
RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
MAGENTA = "\033[35m"
RED = "\033[31m"
BG_GREEN = "\033[42m"
BG_CYAN = "\033[46m"


def clear_screen():
    """Clear terminal screen."""
    os.system("clear" if os.name != "nt" else "cls")


def get_terminal_width() -> int:
    """Get terminal width, default to 60."""
    try:
        return os.get_terminal_size().columns
    except OSError:
        return 60


def center(text: str, width: int = 0) -> str:
    """Center text in terminal."""
    if not width:
        width = get_terminal_width()
    return text.center(width)


def hr(char: str = "─", width: int = 0) -> str:
    """Horizontal rule."""
    if not width:
        width = min(get_terminal_width(), 60)
    return char * width


def format_time(seconds: int) -> str:
    """Format seconds as M:SS or just SS."""
    if seconds >= 60:
        return f"{seconds // 60}:{seconds % 60:02d}"
    return f"{seconds}s"


def progress_bar(current: int, total: int, width: int = 30) -> str:
    """Create a progress bar string."""
    filled = int(width * current / total) if total > 0 else 0
    bar = "█" * filled + "░" * (width - filled)
    pct = int(100 * current / total) if total > 0 else 0
    return f"[{bar}] {pct}%"


def countdown_timer(seconds: int, label: str = ""):
    """Display an interactive countdown timer.

    Shows a live countdown with progress bar.
    User can press Ctrl+C to skip.
    """
    from .i18n import t

    total = seconds
    try:
        for remaining in range(seconds, 0, -1):
            bar = progress_bar(total - remaining, total)
            time_str = format_time(remaining)
            line = f"\r  {CYAN}{label}{RESET} {bar} {BOLD}{time_str}{RESET} {t('ui.remaining')}  "
            sys.stdout.write(line)
            sys.stdout.flush()
            time.sleep(1)

        # Complete
        bar = progress_bar(total, total)
        line = f"\r  {GREEN}{label}{RESET} {bar} {GREEN}{t('ui.done')}{RESET}              "
        sys.stdout.write(line)
        sys.stdout.flush()
        print()
        return True
    except KeyboardInterrupt:
        print(f"\n  {DIM}{t('ui.skipped')}{RESET}")
        return False


def display_tip_header(category: str, tip: Tip):
    """Display a tip header with category and name."""
    from .i18n import t

    icons = {
        "eye": f"👁  {t('cat.eye')}",
        "neck": f"🦴  {t('cat.neck')}",
        "sedentary": f"🚶  {t('cat.sedentary')}",
        "outdoor": f"☀️  {t('cat.outdoor')}",
    }

    header = icons.get(category, f"💡  {t('cat.health_break')}")
    w = min(get_terminal_width(), 60)

    print()
    print(f"  {BOLD}{CYAN}{hr('═', w)}{RESET}")
    print(f"  {BOLD}{header}: {tip.name}{RESET}")
    print(f"  {CYAN}{hr('─', w)}{RESET}")


def display_tip_body(tip: Tip, extra_benefit: str = "", extra_consequence: str = ""):
    """Display tip instruction, benefit, consequence, and ASCII art."""
    from .i18n import t

    w = min(get_terminal_width(), 60)

    # Instruction
    print()
    print(f"  {BOLD}{t('ui.what_to_do')}{RESET}")
    _print_wrapped(f"  {tip.instruction}", w)
    print()

    # ASCII art
    if tip.ascii_art:
        print(f"  {DIM}{tip.ascii_art.strip()}{RESET}")
        print()

    # Benefit
    print(f"  {GREEN}✓ {t('ui.why_helps')}{RESET}")
    benefit = tip.benefit
    if extra_benefit:
        benefit += f" {extra_benefit}"
    _print_wrapped(f"  {benefit}", w)
    print()

    # Consequence
    print(f"  {YELLOW}✗ {t('ui.if_skip')}{RESET}")
    consequence = tip.consequence
    if extra_consequence:
        consequence += f" {extra_consequence}"
    _print_wrapped(f"  {consequence}", w)
    print()

    # Source
    if tip.source:
        print(f"  {DIM}📚 {tip.source}{RESET}")
        print()


def _print_wrapped(text: str, width: int):
    """Simple word-wrap for terminal display."""
    words = text.split()
    line = ""
    indent = "  "
    for word in words:
        if len(line) + len(word) + 1 > width:
            print(line)
            line = indent + word
        else:
            line = line + " " + word if line else indent + word
    if line:
        print(line)


def run_exercise_session(
    category: str,
    tips: List[Tip],
    extra_benefit: str = "",
    extra_consequence: str = "",
):
    """Run an interactive exercise session in the terminal.

    Displays exercise info and runs countdown timers for each tip.

    Args:
        category: "eye", "neck", "sedentary", "outdoor"
        tips: List of tips to guide through
        extra_benefit: Rotating extra benefit message
        extra_consequence: Rotating extra consequence message
    """
    from .i18n import t

    clear_screen()
    w = min(get_terminal_width(), 60)

    total_exercises = len(tips)

    for i, tip in enumerate(tips, 1):
        if total_exercises > 1:
            print(
                f"\n  {DIM}{t('ui.exercise_n').format(i=i, total=total_exercises)}{RESET}"
            )

        display_tip_header(category, tip)
        display_tip_body(
            tip,
            extra_benefit=extra_benefit if i == 1 else "",
            extra_consequence=extra_consequence if i == 1 else "",
        )

        # Countdown
        print(f"  {CYAN}{hr('─', w)}{RESET}")
        print(f"  {DIM}{t('ui.skip_hint')}{RESET}")
        print()

        completed = countdown_timer(tip.duration_seconds, tip.name)

        if completed:
            print(f"\n  {GREEN}{BOLD}{t('ui.great_job')} ✓{RESET}")
        print()

        # Pause between exercises in a combo
        if i < total_exercises:
            print(f"  {DIM}{t('ui.next_exercise')}{RESET}")
            try:
                time.sleep(3)
            except KeyboardInterrupt:
                pass

    # Session complete
    print(f"  {CYAN}{hr('═', w)}{RESET}")
    print(f"  {GREEN}{BOLD}{t('ui.session_complete')}{RESET}")
    print(f"  {DIM}{t('ui.back_to_coding')}{RESET}")
    print(f"  {CYAN}{hr('═', w)}{RESET}")
    print()


def run_quick_exercise(category: str, tip: Tip, **kwargs):
    """Convenience wrapper for single-tip sessions."""
    run_exercise_session(category, [tip], **kwargs)


def display_status(
    is_running: bool,
    is_paused: bool,
    next_eye: Optional[str] = None,
    next_neck: Optional[str] = None,
    next_sedentary: Optional[str] = None,
    stats: Optional[dict] = None,
):
    """Display CodeBreath daemon status."""
    from .i18n import t

    w = min(get_terminal_width(), 60)

    print()
    print(f"  {BOLD}{CYAN}{t('status.title')}{RESET}")
    print(f"  {hr('─', w)}")

    if not is_running:
        print(f"  {RED}● {t('status.not_running')}{RESET}")
        print(f"  {DIM}{t('status.start_hint')}{RESET}")
    elif is_paused:
        print(f"  {YELLOW}● {t('status.paused')}{RESET}")
        print(f"  {DIM}{t('status.resume_hint')}{RESET}")
    else:
        print(f"  {GREEN}● {t('status.running')}{RESET}")

    if is_running:
        print()
        if next_eye:
            print(f"  👁  {t('status.next_eye')}     {next_eye}")
        if next_neck:
            print(f"  🦴  {t('status.next_neck')} {next_neck}")
        if next_sedentary:
            print(f"  🚶  {t('status.next_sedentary')}   {next_sedentary}")

    if stats:
        print()
        print(f"  {BOLD}{t('status.today_stats')}{RESET}")
        print(f"  {DIM}{hr('─', w)}{RESET}")
        for key, val in stats.items():
            print(f"  {key}: {val}")

    print(f"  {hr('─', w)}")
    print()


def display_daily_report(stats: dict):
    """Display end-of-day health report."""
    from .i18n import t

    w = min(get_terminal_width(), 60)

    clear_screen()
    print()
    print(f"  {BOLD}{CYAN}{'═' * w}{RESET}")
    print(f"  {BOLD}📊 {t('report.title')}{RESET}")
    print(f"  {CYAN}{'═' * w}{RESET}")
    print()

    completed = stats.get("completed", 0)
    skipped = stats.get("skipped", 0)
    total = completed + skipped

    if total > 0:
        rate = int(100 * completed / total)
        bar = progress_bar(completed, total, width=20)
        print(f"  {t('report.completion')} {bar}")
        print()

    # Category breakdown
    for cat, icon in [
        ("eye", "👁 "),
        ("neck", "🦴"),
        ("sedentary", "🚶"),
        ("outdoor", "☀️"),
    ]:
        done = stats.get(f"{cat}_completed", 0)
        total_cat = stats.get(f"{cat}_total", 0)
        if total_cat > 0:
            cat_label = t(f"cat.{cat}")
            print(
                f"  {icon} {cat_label:12s} {done}/{total_cat} {t('status.completed')}"
            )

    # Streaks and encouragement
    streak = stats.get("streak_days", 0)
    if streak > 1:
        print()
        print(f"  🔥 {t('report.streak').format(n=streak)}")

    print()
    print(f"  {CYAN}{'═' * w}{RESET}")
    print()
