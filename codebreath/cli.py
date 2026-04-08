"""
CLI entry point for CodeBreath.
Usage: python -m codebreath <command> [options]

Commands:
    start       Start the reminder daemon
    stop        Stop the daemon
    pause [min] Pause reminders for N minutes (default: 30)
    resume      Resume paused reminders
    status      Show daemon status and today's stats
    exercise    Start an immediate exercise session
    report      Show today's health report
    config      Show/edit configuration
"""

import sys
from datetime import datetime
from typing import List

from . import __version__


USAGE = f"""\
CodeBreath v{__version__} — A breath between your code.
Science-backed health guardian for developers.

Usage: codebreath <command> [options]

Commands:
    start [-f]      Start the reminder daemon (-f for foreground)
    stop            Stop the daemon
    pause [minutes] Pause reminders (default: 30 min)
    resume          Resume paused reminders
    status          Show current status
    exercise [type] Start an exercise now (eye/neck/sedentary/outdoor)
    report          Show today's health report
    config          Show current configuration
    config set <key> <value>  Change a setting

Examples:
    codebreath start            # Start daemon in background
    codebreath start -f         # Start in foreground (see logs)
    codebreath pause 15         # Pause for 15 minutes
    codebreath exercise eye     # Do an eye exercise now
    codebreath exercise neck    # Do neck exercises now
    codebreath report           # See today's stats
"""


def main(argv: List[str] = None):
    """Main CLI entry point."""
    args = argv if argv is not None else sys.argv[1:]

    if not args or args[0] in ("-h", "--help", "help"):
        print(USAGE)
        return 0

    command = args[0]

    if command == "--version":
        print(f"CodeBreath v{__version__}")
        return 0

    if command == "start":
        return cmd_start(args[1:])
    elif command == "stop":
        return cmd_stop()
    elif command == "pause":
        return cmd_pause(args[1:])
    elif command == "resume":
        return cmd_resume()
    elif command == "status":
        return cmd_status()
    elif command == "exercise":
        return cmd_exercise(args[1:])
    elif command == "report":
        return cmd_report()
    elif command == "config":
        return cmd_config(args[1:])
    else:
        print(f"Unknown command: {command}")
        print(f"Run 'codebreath --help' for usage.")
        return 1


def cmd_start(args: List[str]) -> int:
    """Start the daemon."""
    from .scheduler import Scheduler

    foreground = "-f" in args or "--foreground" in args
    scheduler = Scheduler()
    scheduler.start(foreground=foreground)
    return 0


def cmd_stop() -> int:
    """Stop the daemon."""
    from .scheduler import stop_daemon

    stop_daemon()
    return 0


def cmd_pause(args: List[str]) -> int:
    """Pause reminders."""
    from .scheduler import pause_daemon

    minutes = 30
    if args:
        try:
            minutes = int(args[0])
        except ValueError:
            print(f"Invalid minutes: {args[0]}")
            return 1

    pause_daemon(minutes)
    return 0


def cmd_resume() -> int:
    """Resume reminders."""
    from .scheduler import resume_daemon

    resume_daemon()
    return 0


def cmd_status() -> int:
    """Show daemon status."""
    from .storage import read_pid, load_state, DailyLog
    from .terminal_ui import display_status

    pid = read_pid()
    is_running = pid is not None
    state = load_state()
    is_paused = state.get("paused", False)

    stats = None
    if is_running:
        log = DailyLog.today()
        stats = log.get_stats()
        # Format stats for display
        formatted_stats = {}
        for cat, icon in [
            ("eye", "👁 "),
            ("neck", "🦴"),
            ("sedentary", "🚶"),
            ("outdoor", "☀️"),
        ]:
            done = stats.get(f"{cat}_completed", 0)
            notified = stats.get(f"{cat}_total", 0)
            if notified > 0:
                formatted_stats[f"{icon} {cat.capitalize()}"] = (
                    f"{done}/{notified} completed"
                )
            else:
                formatted_stats[f"{icon} {cat.capitalize()}"] = "No reminders yet"
        stats = formatted_stats

    display_status(
        is_running=is_running,
        is_paused=is_paused,
        stats=stats,
    )

    if is_running:
        print(f"  PID: {pid}")

    return 0


def cmd_exercise(args: List[str]) -> int:
    """Run an immediate exercise session."""
    from .content import ContentRotator, NOON_OUTDOOR
    from .terminal_ui import run_exercise_session, run_quick_exercise
    from .storage import DailyLog

    rotator = ContentRotator()
    log = DailyLog.today()

    # Determine exercise type
    if not args:
        # Auto-select based on time of day
        hour = datetime.now().hour
        if hour == 12:
            exercise_type = "outdoor"
        elif hour % 2 == 0:
            exercise_type = "eye"
        else:
            exercise_type = "neck"
        print(
            f"Auto-selected: {exercise_type} (use 'codebreath exercise eye/neck/sedentary/outdoor' to choose)"
        )
    else:
        exercise_type = args[0].lower()

    if exercise_type == "eye":
        tip, extra_b, extra_c = rotator.next_eye_tip()
        run_quick_exercise("eye", tip, extra_benefit=extra_b, extra_consequence=extra_c)
        log.add_event("eye", tip.name, "completed")

    elif exercise_type == "neck":
        combo = rotator.next_neck_combo()
        run_exercise_session("neck", combo)
        names = " + ".join(t.name for t in combo)
        log.add_event("neck", names, "completed")

    elif exercise_type == "sedentary":
        hour = datetime.now().hour
        tip = rotator.next_sedentary_tip(hour)
        run_quick_exercise("sedentary", tip)
        log.add_event("sedentary", tip.name, "completed")

    elif exercise_type == "outdoor":
        run_quick_exercise("outdoor", NOON_OUTDOOR)
        log.add_event("outdoor", NOON_OUTDOOR.name, "completed")

    else:
        print(f"Unknown exercise type: {exercise_type}")
        print("Available: eye, neck, sedentary, outdoor")
        return 1

    return 0


def cmd_report() -> int:
    """Show today's health report."""
    from .storage import DailyLog
    from .terminal_ui import display_daily_report

    log = DailyLog.today()
    stats = log.get_stats()
    stats["streak_days"] = log.get_streak()
    display_daily_report(stats)
    return 0


def cmd_config(args: List[str]) -> int:
    """Show or modify configuration."""
    from .storage import Config

    config = Config.load()

    if not args:
        # Show current config
        print("\nCodeBreath Configuration")
        print("─" * 40)
        for key, val in config.to_display().items():
            print(f"  {key}: {val}")
        print("─" * 40)
        print(f"\nConfig file: ~/.codebreath/config.json")
        print(f"Edit with: codebreath config set <key> <value>")
        print()
        print("Available keys:")
        print("  eye_interval_min      (default: 30)")
        print("  neck_interval_min     (default: 45)")
        print("  sedentary_interval_min (default: 60)")
        print("  work_start_hour       (default: 9)")
        print("  work_end_hour         (default: 19)")
        print("  noon_reminder_enabled (default: true)")
        print("  terminal_ui_enabled   (default: true)")
        print()
        return 0

    if args[0] == "set" and len(args) >= 3:
        key = args[1]
        value = args[2]

        if key not in Config.__dataclass_fields__:
            print(f"Unknown config key: {key}")
            return 1

        # Type conversion
        field_type = Config.__dataclass_fields__[key].type
        try:
            if field_type == "bool":
                typed_value = value.lower() in ("true", "1", "yes")
            elif field_type == "int":
                typed_value = int(value)
            else:
                typed_value = value
        except ValueError:
            print(f"Invalid value for {key}: {value}")
            return 1

        setattr(config, key, typed_value)
        config.save()
        print(f"Set {key} = {typed_value}")
        print("Restart CodeBreath for changes to take effect.")
        return 0

    print(f"Unknown config command: {' '.join(args)}")
    return 1
