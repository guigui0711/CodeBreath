# CodeBreath v2 — Swift macOS Menu Bar App Redesign

**Date:** 2026-04-16
**Status:** Approved

## Summary

Rewrite CodeBreath from Python daemon + Swift notification helper into a native macOS Menu Bar app built entirely in Swift/SwiftUI. Replace system notifications with a custom floating window featuring embedded countdown timers that guide users through exercises in real-time.

## Problems Being Solved

1. **Too many notifications** — eye+neck and sedentary timers fire simultaneously, producing 2 notifications at once
2. **Dismissing = silent disappear** — closing a notification records nothing; the reminder vanishes without consequence
3. **Ugly notifications** — constrained by macOS system notification styling (plain text, identical appearance to every other app)
4. **No guidance to complete** — notifications remind but don't help you actually do the exercise

## Architecture

```
CodeBreath.app (SwiftUI, macOS 13+)
├── App Entry (MenuBarExtra)
│   ├── Menu Bar Icon — 🫁 + completion count (e.g. 3/8)
│   └── Popover Panel — today's stats, next reminder, pause/exercise buttons
│
├── Scheduler Engine
│   ├── Timer management (eye+neck combined, sedentary, noon outdoor)
│   ├── Working hours enforcement
│   ├── Notification merging — when multiple timers fire within 60s window, combine into single floating window
│   └── Pause/resume support
│
├── Floating Reminder Window
│   ├── Frosted glass card (NSPanel, .floating level)
│   ├── Exercise instructions + benefit text
│   ├── Circular countdown timer (animated ring)
│   ├── Actions: "做完了" / "跳过"
│   ├── Close (✕) = skip (explicitly logged)
│   └── Multi-step: when merged, step through exercises sequentially
│
├── Content Library
│   ├── Eye tips (5 rotating)
│   ├── Neck exercises (6 rotating, core + auxiliary combos)
│   ├── Sedentary breaks (7 time-aware)
│   ├── Noon outdoor reminder
│   └── i18n: English + Chinese
│
├── Storage Manager
│   ├── Config: ~/Library/Application Support/CodeBreath/config.json
│   ├── Daily logs: ~/Library/Application Support/CodeBreath/logs/YYYY-MM-DD.json
│   └── Settings via SwiftUI Settings scene
│
└── Daily Report
    ├── Popover shows live stats
    └── Optional summary notification at configurable time
```

## Components

### 1. Menu Bar Icon

- Permanent `MenuBarExtra` with SF Symbol or emoji (🫁)
- Displays today's completion ratio: `3/8`
- Click opens popover panel

### 2. Popover Panel

- **Header:** Large completion count (3/8) with label "今日完成"
- **Category cards:** Eye 👁 (2/4), Neck 🦴 (1/4), Sedentary 🚶 (0/2) — each with progress
- **Next reminder:** Countdown to next trigger with category label
- **Actions:** "暂停 30 分钟" and "现在练习" buttons
- **Settings access:** Gear icon opens Settings window

### 3. Floating Reminder Window (Core)

An `NSPanel` at `.floating` window level with:

- **Visual style:** Rounded corners (16pt), frosted glass (`NSVisualEffectView`), subtle border, drop shadow
- **Header:** Category icon + label, ✕ close button (close = skip)
- **Content:** Exercise name (17pt bold), step-by-step instructions (13pt)
- **Countdown ring:** Centered circular progress ring with seconds display. Auto-starts when window appears.
- **Benefit bar:** Colored info box explaining why this exercise helps
- **Action buttons:** "跳过" (secondary) and "✓ 做完了" (primary, gradient purple)

**Interaction flow:**
1. Timer fires → floating window appears (centered or top-right, configurable)
2. Countdown auto-starts (duration from exercise definition)
3. User does exercise while watching countdown
4. Countdown completes → buttons become prominent
5. User taps "做完了" → logged as completed, window closes
6. User taps "跳过" or ✕ → logged as skipped, window closes
7. If window remains untouched for 5 minutes → logged as skipped, window closes

**Notification merging:**
- When eye+neck and sedentary fire within 60 seconds of each other, show a single window
- Window steps through exercises: "1/2 护眼+颈肩" → "2/2 起来动动"
- Each step has its own countdown
- User can skip individual steps or skip all

### 4. Scheduler Engine

- Uses Swift `Timer` or `DispatchSourceTimer`
- Three independent tracks with configurable intervals:
  - Eye+Neck combined: default 30 min
  - Sedentary: default 60 min
  - Noon outdoor: fixed time (default 12:00)
- Working hours enforcement (default 9:00–19:00)
- Merging window: if another timer fires within 60s of current window being open, append to current window
- Pause/resume with optional duration

### 5. Content Library

Port all existing content from Python `content.py`:
- 5 eye tips with rotation
- 6 neck exercises (core + auxiliary combos)
- 7 time-aware sedentary activities
- Noon outdoor with rotating motivational messages
- All bilingual (en/zh)

### 6. Storage

- **Location:** `~/Library/Application Support/CodeBreath/`
- **Config:** `config.json` — same keys as current Python version
- **Daily logs:** `logs/YYYY-MM-DD.json` — same event format `{timestamp, category, tip_name, action}`
- **Actions logged:** `notified`, `completed`, `skipped` (no more `dismissed` — it's now `skipped`)
- Migrate from `~/.codebreath/` on first launch if old data exists

### 7. Settings Window

SwiftUI Settings scene:
- Intervals (eye+neck, sedentary)
- Working hours (start/end)
- Noon reminder toggle + time
- Daily report toggle + time
- Language (English/Chinese)
- Launch at login toggle
- Notification sound selection
- Floating window position (center/top-right)

### 8. Daily Report

- Integrated into popover (always visible)
- Optional push notification at configured time with day summary
- Shows: completed/skipped/total per category, streak count

## Data Flow

```
Timer fires
  → Scheduler checks merge window
  → If window already open: append step
  → If not: create FloatingReminderWindow
  → Log "notified" event

User completes exercise
  → Log "completed" event
  → Update menu bar count
  → Close window (or advance to next step)

User skips / closes window
  → Log "skipped" event
  → Update menu bar count
  → Close window (or advance to next step)

5-minute timeout
  → Log "skipped" event
  → Auto-close window
```

## What's NOT Included

- No smart frequency adjustment based on response rate
- No focus/DND mode detection
- No CLI interface (pure GUI app)
- No web dashboard or cloud sync
- No iOS companion app

## Tech Requirements

- macOS 13+ (Ventura) for MenuBarExtra API
- SwiftUI + AppKit (NSPanel for floating window)
- Xcode 15+
- No external dependencies
- Single .app bundle, distributable via DMG or direct download

## Migration

- On first launch, check for `~/.codebreath/config.json`
- If found, import settings and historical logs to new location
- Show one-time migration notice
