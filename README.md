# CodeBreath

**A breath between your code.** Science-backed health guardian for developers.

CodeBreath is an open-source CLI tool that sends rotating, evidence-based health reminders via macOS system notifications — covering eye care, neck exercises, and sedentary breaks. Every reminder tells you *what to do*, *why it helps*, and *what happens if you skip it*.

Zero external dependencies. Python 3 standard library only.

## Why

- **49%** of office workers develop neck pain within their first year (Hush 2009)
- **92%** of screen users report at least one Digital Eye Strain symptom
- Sitting **8+ hours/day** without exercise increases all-cause mortality by **59%**
- Indoor offices provide ~400 lux. Your eyes need **10,000+ lux** (outdoor light) to slow myopia progression

CodeBreath addresses all of these with science-backed micro-interventions that take 20-60 seconds.

## Features

- **Three reminder tracks** with independent intervals:
  - 👁 Eye care (every 30 min) — 5 rotating methods: close eyes, palming, distance focus, blink exercise, eye rolls
  - 🦴 Neck exercises (every 45 min) — 6 exercises (3 core + 3 auxiliary), randomly combined 2-3 per session
  - 🚶 Sedentary breaks (every 60 min) — 7 activities with time-of-day awareness
- **Noon outdoor reminder** — the single most impactful thing for high myopia control
- **Content rotation** — every reminder differs from the last. Benefits and consequences also rotate from message pools
- **macOS system notifications** — dual backend:
  - **Native (recommended)**: Swift helper with persistent alert-style notifications and Done/Skip action buttons for completion tracking
  - **Fallback**: `osascript` banners (auto-dismiss in ~5 seconds, no buttons)
- **Completion tracking** — click "Done" or "Skip" on notifications to log whether you did the exercise
- **Terminal interactive mode** — countdown timers with ASCII art exercise guides
- **Daily health report** with completion stats and streaks
- **Configurable** — intervals, working hours, all customizable

## Quick Start

```bash
# Clone the repo
git clone https://github.com/guigui0711/CodeBreath.git
cd CodeBreath

# Build native notification helper (recommended)
codebreath build-notifier

# Run setup guide
codebreath setup

# Start the daemon
python3 -m codebreath start

# Or run in foreground to see logs
python3 -m codebreath start -f
```

## Usage

```bash
codebreath start            # Start daemon in background
codebreath start -f         # Start in foreground (see logs)
codebreath stop             # Stop the daemon
codebreath pause 15         # Pause reminders for 15 minutes
codebreath resume           # Resume reminders
codebreath status           # Show current status
codebreath exercise eye     # Do an eye exercise now
codebreath exercise neck    # Do neck exercises now
codebreath exercise outdoor # Noon outdoor reminder
codebreath report           # Today's health report
codebreath config           # Show configuration
codebreath config set eye_interval_min 25  # Change setting
codebreath lang zh          # Switch to Chinese (中文)
codebreath lang en          # Switch back to English
codebreath build-notifier   # Build native notification helper
codebreath setup            # First-time setup guide
```

## Configuration

Settings are stored in `~/.codebreath/config.json`:

| Key | Default | Description |
|-----|---------|-------------|
| `eye_interval_min` | 30 | Minutes between eye care reminders |
| `neck_interval_min` | 45 | Minutes between neck exercise reminders |
| `sedentary_interval_min` | 60 | Minutes between sedentary break reminders |
| `work_start_hour` | 9 | Working hours start (24h) |
| `work_end_hour` | 19 | Working hours end (24h) |
| `noon_reminder_enabled` | true | Enable noon outdoor reminder |
| `language` | en | UI and content language (`en` or `zh`) |

## Language / 语言切换

CodeBreath supports English and Chinese. All notifications, terminal UI, exercise instructions, and motivational messages are fully translated.

```bash
# Switch to Chinese
codebreath lang zh

# Switch back to English
codebreath lang en
```

Restart the daemon after switching for the change to take effect.

## Native Notifications (Recommended)

By default, CodeBreath uses basic macOS `osascript` banners that auto-dismiss in ~5 seconds with no action buttons. For a better experience, build the native Swift notification helper:

```bash
# Build the helper (requires Xcode command-line tools)
codebreath build-notifier

# Or directly:
./swift/build.sh
```

This gives you:
- **Persistent notifications** that stay on screen until you interact with them
- **Done / Skip buttons** — click to log whether you completed the exercise
- **Completion tracking** in your daily health report

### macOS Setup

After building, configure macOS to use alert-style notifications:

1. Open **System Settings > Notifications > CodeBreath**
2. Set **Allow Notifications** = ON
3. Set **Alert style** = **Alerts** (not "Banners")

The "Alerts" style keeps notifications visible until you click a button. Without this, macOS will auto-dismiss them as banners.

### Requirements

- Xcode command-line tools (`xcode-select --install`)
- macOS 12.0+

## The Science

Every recommendation in CodeBreath is backed by peer-reviewed research:

- **20-20-20 rule**: Talens-Estarelles et al., *Contact Lens & Anterior Eye*, 2023 (PMID: 35963776). Closing eyes achieves accommodation = 0, even better than looking far.
- **Break frequency**: Redondo et al., 2025 (PMID: 40466853). Self-paced breaks work nearly as well as optimal-frequency breaks.
- **Chin tuck**: Rehabilitation medicine gold standard for Forward Head Posture correction.
- **Thoracic extension + scapular stabilization**: Kang et al., *Turk J Phys Med Rehabil*, 2021. RCT proving significant FHP improvement.
- **Outdoor light & myopia**: Multiple RCTs showing 10,000+ lux exposure triggers retinal dopamine release, the strongest factor for slowing myopia progression.
- **Sedentary behavior**: 2018 *Physical Activity Guidelines Advisory Committee Report*. Interrupting sitting improves cardiometabolic markers.

## Design Philosophy

1. **Non-blocking**: Notifications don't steal focus. You choose when to engage.
2. **Variety**: No one follows reminders that say the same thing every time. Content rotates.
3. **Motivation through understanding**: Every reminder explains *why* — both the benefit and the consequence of skipping.
4. **Context-aware**: Post-lunch drowsiness? Get squats. Morning? Hydration focus. Windowless office? Eye rest defaults to closing eyes, not "look far away."
5. **Zero friction**: No pip install, no dependencies, no config needed to start.

## Requirements

- macOS 12.0+
- Python 3.9+
- Xcode command-line tools (optional, for native notifications — `xcode-select --install`)

## License

MIT

---

*Your body writes the code too. Take a breath.*
