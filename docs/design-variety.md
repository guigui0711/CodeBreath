# Design: Variety Algorithm + Combined Eye+Neck Integration

**Status:** design proposal (no code yet)
**Author:** designer@codebreath-variety
**Depends on:** `docs/research-variety.md`
**Consumers:** content-impl (task #3 → Content.swift), wiring-impl (task #4 → Scheduler.swift / FloatingReminderWindow.swift / PopoverView / MenuBarView / Storage.swift)

---

## 0. TL;DR

1. Introduce a first-class **combo** category that represents a *single* compound eye+neck move (not a concatenation of 3 separate tips).
2. Expand the library: **eye 5 → 9**, **neck core 3 + aux 3 → neck 10**, **combo 0 → 10**. Noon & sedentary unchanged.
3. Replace `Array.randomElement()!` with a **weighted sampler** layered with:
   - a **recency buffer** (last N tip IDs per category, exclusion filter),
   - **time-of-day bias** extended to eye/neck/combo,
   - a **daily theme seed** (date-deterministic, biases weights),
   - a small **novelty boost** (few-shot boost for rarely-seen tips),
   - a **dismiss-decay** (tips a user repeatedly skips get down-weighted).
4. Change `combinedEyeAndNeck()` so it returns **a single combo tip** (preferred) and falls back to the legacy eye + neck-core + neck-aux 3-step sequence only when combo pool is excluded by filters or user config disables combo.
5. UI: combo tips render as a single-page step (no slide), with a small "A + B simultaneously" callout; the countdown ring behavior is unchanged.
6. Storage: add `category = "combo"` to the log vocabulary. Keep existing `"eye_neck"` primary category on Scheduler logs for backwards compat. Config version bump 1 → 2 with safe defaults. No breaking change to existing log files.

---

## 1. Data-structure changes

### 1.1 `TipCategory` — add `combo`

```
enum TipCategory: String, Codable, CaseIterable {
    case eye
    case neck
    case combo        // NEW — compound eye+neck move
    case sedentary
    case noon
}
```

Rationale: combo is a genuine third thing (it trains cervico-ocular coupling — see research §2.1). Treating it as a separate category lets the Selector reason about it directly, lets the UI color/label it differently, and lets the logs attribute completions to "combo" for analytics. **Does not break** any existing decoder: old `TipCategory` values still decode (we only add a case), and old log files carry strings which are already stored as `String`, not as the enum.

### 1.2 `Tip` — add `difficulty` and `kind` (optional, additive)

```
enum TipDifficulty: String, Codable { case easy, medium, hard }
enum TipKind: String, Codable { case single, compound }   // compound = combo simultaneous

struct Tip {
    …existing fields…
    var difficulty: TipDifficulty = .easy   // optional, defaults to easy
    var kind: TipKind = .single             // combo tips set this to .compound
    var tags: [String] = []                 // e.g. ["vestibular", "FHP", "saccade"]
}
```

All new fields have defaults → existing `Tip` literals don't need to change if content-impl chooses to let Swift fill defaults. `difficulty` is used by progressive-unlock; `kind` drives a single UI branch in the floating window; `tags` is used by daily-theme biasing (optional but cheap).

### 1.3 Keep "sequential fallback" alive, but demote it

`combinedEyeAndNeck()` stays, but semantically becomes:

- **Primary path:** return `[comboTip]` — a single compound move.
- **Fallback path:** return `[eyeTip, neckCore, neckAux]` (today's behavior) when:
  - the combo pool after recency/safety filtering is empty, **or**
  - user has opted out of combo moves (onboarding vertigo flag, §3.7), **or**
  - scheduler is told to force a "classic" session (power-session or debug).

The caller (Scheduler) does not need to know which path ran — it just calls `ContentLibrary.combinedEyeAndNeck()` and gets back `[Tip]` of length 1 (combo) or 3 (legacy). The existing FloatingReminderWindow already handles both `tips.count == 1` and `tips.count > 1` (progress label, step advance). So no wiring change is strictly required for this fallback to keep working.

### 1.4 Recency buffer — where it lives

New type in Content.swift (pure value type, no persistence required for MVP):

```
final class RecencyBuffer {
    private var perCategory: [TipCategory: [String]] = [:]    // ring of last-N tip IDs
    private let capacity: Int
    init(capacity: Int = 4) { self.capacity = capacity }
    func record(_ id: String, in cat: TipCategory) { … }
    func contains(_ id: String, in cat: TipCategory) -> Bool { … }
    func decay()  // called daily to slowly forget
}
```

**MVP policy: in-memory only.** A buffer of 4 per category is enough to prevent immediate repeats across a workday. Persisting it is a nice-to-have (§5.3) but not required; on app restart the buffer just resets, which at worst reintroduces one repeat, a non-issue.

### 1.5 New `Selector` facade (lives in Content.swift, called by Scheduler)

```
enum TipSelector {
    static let shared = SelectorEngine()

    static func nextEye(now: Date = Date()) -> Tip
    static func nextNeck(now: Date = Date()) -> Tip
    static func nextCombo(now: Date = Date()) -> Tip?           // may return nil on safety-exclude
    static func nextSedentary(now: Date = Date()) -> Tip        // takes over sedentaryBreak(forHour:)
    static func nextNoon() -> Tip
    static func nextEyeNeckSession(now: Date = Date()) -> [Tip] // combo-first, fallback to 3-step
}
```

The existing call sites (`randomEyeTip`, `randomNeckExercise`, `neckCombo`, `combinedEyeAndNeck`, `sedentaryBreak(forHour:)`) stay as **thin wrappers** that forward into `TipSelector` — this keeps wiring-impl's diff in Scheduler.swift near-zero.

---

## 2. Anti-repetition algorithm

### 2.1 Weighted sampling formula (single formula, four factors)

For each candidate tip `t` in the target category pool:

```
weight(t) = baseWeight(t)                                // 1.0 default; see §2.6 unlock
          × timeContextMultiplier(t, hour)               // 0.5 – 2.0, §2.3
          × themeMultiplier(t, todayTheme)               // 0.8 – 1.6, §2.4
          × noveltyBoost(t, usageCount)                  // 1.0 – 1.4, §2.5
          × (inRecencyBuffer(t) ? 0 : 1)                 // hard exclude, §2.2
          × dismissDecay(t, recentSkips)                 // 0.3 – 1.0, §2.7
```

Then sample proportional to `weight`. If all weights become 0 (pathological case — tiny pool entirely in buffer), fall back to **pure uniform random** over the category, ignoring the buffer.

This single formula subsumes every lever; each factor can be disabled independently by returning 1.0 for cheap A/B or debugging.

### 2.2 Recency buffer (hard exclusion)

- **Size N = 4 per category** (eye, neck, combo). Sedentary uses 3. Rationale: eye has 9, neck 10, combo 10; excluding 4 still leaves ≥ 5 candidates. If a category has ≤ 4 tips (e.g. sedentary with time-pref narrowed to 3 indices), cap buffer at `pool.count - 1` to guarantee at least one candidate.
- Record on **notified**, not on completed — we want to avoid showing the same tip back-to-back regardless of whether the user completed or skipped it.
- **Persistence:** in-memory only for MVP. See §5.3.

### 2.3 Time-of-day multiplier (extended to all categories)

Research §1.5 item 6 prescribes this layout. Mechanism: a `TimeContext` enum maps hour → which tag families get boosted.

| Hour range | Context | Eye boost | Neck boost | Combo boost |
|---|---|---|---|---|
| 09–11 | morning dry-eye | tag:`dryeye` ×1.5 | — | tag:`dryeye` ×1.5 |
| 11–12 | pre-lunch posture | — | tag:`FHP` ×1.3 | tag:`FHP` ×1.5 |
| 13–15 | post-lunch drowsiness | — | — | tag:`vestibular`/`activating` ×1.6, sedentary already covers |
| 15–17 | afternoon stiffness | — | tag:`ROM` ×1.5 | tag:`ROM` ×1.3 |
| 17–20 | EOD fatigue | tag:`relaxation` ×1.5 | — | tag:`relaxation` ×1.2 |

Outside 09–20 (before workday or weekend evenings) → all multipliers = 1.0.

### 2.4 Daily theme (seeded once per local date)

```
enum DailyTheme: String { case eyeDay, neckDay, comboDay, mobilityDay, postureDay }
static func todayTheme() -> DailyTheme {
    let ymd = StorageManager.ymd(Date())        // e.g. "2026-04-20"
    let seed = abs(ymd.hashValue)
    return DailyTheme.allCases[seed % DailyTheme.allCases.count]
}
```

Seeded from the local YMD string → deterministic per-day, changes at midnight, no state to persist. Theme effect on weight:

| Theme | Eye ×| Neck × | Combo × | UI surface |
|---|---|---|---|---|
| eyeDay | 1.6 | 0.9 | 1.1 | "Today: Dry-Eye Day" in popover |
| neckDay | 0.9 | 1.6 | 1.1 | "Today: Posture Reset Day" |
| comboDay | 1.0 | 1.0 | 1.8 | "Today: Eye+Neck Combo Day" |
| mobilityDay | 1.0 | 1.2 (ROM-tagged) | 1.2 (ROM-tagged) | "Today: Mobility Day" |
| postureDay | 0.9 | 1.2 (FHP-tagged) | 1.3 (FHP-tagged) | "Today: Posture Day" |

Theme is a **bias, not a filter** — off-theme tips still appear ~30–40% of the time, which is important so users don't feel they're being railroaded.

### 2.5 Novelty boost

For each tip, track lifetime `notifiedCount` in-memory (derived from logs on startup — `StorageManager.countNotifiedByTipId()`, new helper). If a tip has been notified `< 3` times: weight ×1.4. If `< 10`: weight ×1.15. Else ×1.0. This ensures newly-added tips surface more often in the first week without hard-coding a "new" flag.

### 2.6 Progressive unlock (difficulty gate)

At launch:
- Tips with `difficulty == .hard` are hidden (weight = 0) until the user has **20 total completions** lifetime.
- Tips with `difficulty == .medium` are hidden until **5 total completions**.

Rationale: first-day overwhelm is real for a micro-break app; we want the user's first sessions to be things like close-eyes-and-breathe and chin-tuck, not VOR×1. Once unlocked, a popover toast announces the new tip ("New move available: Gaze-Follow Neck Rotation").

Designation (see §4 content list):
- **easy:** close-eyes/breathe, palming, distance focus, blink, eye rolls, chin tuck, scapular retraction, shoulder shrug, lateral neck stretch, neck rotation, thoracic extension, noon outdoor, all sedentary.
- **medium:** figure-8 + lateral stretch combo, chin-tuck+distance focus, scapular squeeze + 20ft focus, 20-20-20, palming + DCF, thoracic extension + ceiling sweep.
- **hard:** VOR×1 horizontal+vertical, eye-led neck rotation, gaze-direction recognition, wall-stand saccades.

### 2.7 Dismiss-decay (per-user adaptive weighting)

Count `skipped` actions per tip ID in the last 14 days. Apply:
- `skipped ≥ 5` in window: weight ×0.3
- `skipped 2–4` in window: weight ×0.6
- else ×1.0

A `completed` event within the window cancels the decay (resets the skip count for that tip). This is research §1.5 item 9 (Mehrotra 2016, notification habituation at individual level).

### 2.8 "Surprise" slot (~10%)

On every fire, with probability 0.10, override the category selection:
- From Eye/Neck/Combo track: surface a combo tip (even if today is eyeDay) **or** a "fun-fact" card (see §6.2) from a tiny pool.
- Never overrides Noon (user is going outside).
- Never overrides Sedentary (user is leaving the desk).

Rationale: Schultz 2015 — variable-ratio reward keeps engagement. Implementation is one `Double.random(in: 0..<1) < 0.1` branch in `nextEyeNeckSession`.

### 2.9 Does variety gain justify the complexity?

**Yes, provably.** Research §1.1 shows two RCTs (Glaros 2001, Sylvester 2016) with adherence effect sizes ranging from `F(1,116) = 5.55, p = .02` to "significantly lower dropout". The recency buffer and weighted sampler together cost ~60 lines of Swift. Theme & surprise slots are each < 10 lines. This is the highest-leverage change in the roadmap.

---

## 3. New content (what content-impl writes)

Full copy (en/zh, benefit, consequence, source) is already in the research report §2.2 — content-impl should adapt those, not re-invent them. Summary of the new Tip IDs:

### 3.1 Eye (9 total: 5 existing + 4 new)

Keep all 5 existing. Add:
- `eye.figure8` — Figure-8 / infinity-loop tracking, 30 s, easy, tags [`saccade`,`ROM`]. Stand-alone version of combo #3's eye component. Source: Scheiman & Wick 2019.
- `eye.2020` — The 20-20-20 rule card (look 20 ft away for 20 s every 20 min), 20 s, easy, tag [`dryeye`,`AAO`]. Source: AAO.
- `eye.convergence` — Pencil push-up / convergence drill, 40 s, medium, tag [`binocular`]. Near-far thumb tracking. Source: Scheiman & Wick 2019.
- `eye.saccades` — Horizontal two-target saccades, 30 s, medium, tag [`saccade`].

### 3.2 Neck (10 total: 6 existing + 4 new)

Keep all 3 core + 3 aux (collapse `neckCore` and `neckAux` into a single `neckTips` array; the "core vs aux" distinction was an artifact of the old 3-step composition and no longer earns its keep once combo is the primary path). Add:
- `neck.deep_flexor_hold` — Isolated 20 s chin-tuck hold (the DCF component of combo #7 as a stand-alone), easy, tag [`FHP`,`DCF`]. Source: Jull et al. 2008.
- `neck.levator_stretch` — Look-down-armpit lateral stretch (levator scapulae target), 45 s, easy, tag [`ROM`].
- `neck.wall_angel` — Wall angels against a wall, 60 s, medium, tag [`FHP`,`ROM`]. Complements the existing wall-stand.
- `neck.doorway_pec_stretch` — Doorway chest-opener (passive stretch for rounded shoulders), 45 s, easy, tag [`FHP`].

### 3.3 Combo (10 total: 0 existing + 10 new — from research §2.2)

| ID | Name (zh) | Difficulty | Tags | Duration |
|---|---|---|---|---|
| `combo.gaze_rotation` | 转头远眺跟随 | medium | vestibular, ROM, dryeye | 45 |
| `combo.chintuck_focus` | 收下巴远眺 | easy | FHP, dryeye, relaxation | 40 |
| `combo.figure8_lateral` | 8字眼球+侧颈拉伸 | medium | ROM, saccade | 50 |
| `combo.vor_x1` | 水平凝视稳定 VOR×1 | **hard** | vestibular, activating | 30 |
| `combo.scapular_2020` | 肩胛内收+20秒远眺 | easy | FHP, dryeye | 45 |
| `combo.eye_led_rotation` | 眼先动颈跟随 | **hard** | vestibular, ROM | 50 |
| `combo.palming_dcf` | 掌心敷眼+深层颈屈肌 | medium | relaxation, FHP, DCF | 45 |
| `combo.gaze_recognition` | 眼指方向+头回正 | **hard** | proprioception, FHP | 60 |
| `combo.thoracic_sweep` | 胸椎伸展+上下扫视 | medium | FHP, ROM, saccade | 50 |
| `combo.wall_saccades` | 靠墙站+水平扫视 | **hard** | saccade, posture, activating | 50 |

Every combo tip has `kind = .compound`. Every one has a populated `source` LocalizedText pointing to the citation in research §2.2. The UI copy for combo tips must make the *simultaneity* explicit in the `instruction` field — e.g., "**While holding** the lateral neck stretch, trace a figure-8 with your eyes".

### 3.4 Safety exclusion flag

Config gets `avoidHeadMotion: Bool = false`. When `true`, Selector filters out any combo/neck tip with tag `vestibular` or `ROM` **on rotation drills** (i.e. combo.vor_x1, combo.eye_led_rotation, combo.gaze_recognition, neck.rotation, combo.gaze_rotation). First-run onboarding asks one yes/no: "Any history of vertigo, recent whiplash, or motion sickness?" — if yes, set flag. Setting is visible and togglable in SettingsView.

---

## 4. UI changes — FloatingReminderWindow

### 4.1 Combo rendering

When `tips.count == 1 && tips[0].kind == .compound`:

- `progressLabel` is hidden (no 1/N pill; it's one integrated move).
- Above the title, show a small two-chip row: `[👁 Eye]  [＋]  [🧍 Neck]` — using the same `DS.categoryColor(.eye)` and `DS.categoryColor(.neck)` colors, separated by a plus sign. Visually signals "you're doing both at once".
- Category strip (`categoryLabel`) becomes "眼+颈联动 / Eye + Neck Combo" with a new category color `DS.categoryColor(.combo)` (proposed: a blend — teal/violet accent distinct from the existing eye/neck/sedentary/noon palette).
- The `instruction` block should render as a short **numbered list** when the combo has internal steps (split on newlines — content-impl writes the instruction as "1. …\n2. …\n3. …"), but it's still **one countdown**, **one tip**, **one page**. No slide transition.
- `benefitBox` unchanged. Mention "trains cervico-ocular coupling (VOR)" in benefit copy where applicable.

### 4.2 Multi-step rendering (unchanged)

Fallback 3-step path (`tips.count == 3`) uses the existing `progressLabel "1/3" → "2/3" → "3/3"` slide behavior with no changes. This path is increasingly rare post-launch (~10–15% of eye+neck fires, mostly safety-exclude users or legacy-session debug mode).

### 4.3 Symbol map + category color

Add to `FloatingReminderView.symbol(for:)`:
```
case .combo: return "eye.trianglebadge.exclamationmark"  // or "figure.mind.and.body"
```
Add to `DS.categoryColor(_:)`: a new distinct color. Designer-recommended: `Color(red: 0.45, green: 0.35, blue: 0.85)` (violet) — not used elsewhere, and contrasts both the blue-ish eye and the green-ish neck.

Add to `categoryLabel`: `(.combo, .zh) → "眼+颈联动"`, `(.combo, .en) → "Eye + Neck Combo"`.

### 4.4 MenuBarView / PopoverView

- PopoverView: show "Today's theme: X" as a small subtitle under the streak/stats row. One line, muted, clickable → scrolls to settings toggle.
- MenuBarView: the menu-bar title/icon does not change. The popover adds a new "Unlocks" section only when new difficulty tier just became available (shows once, dismissable).

### 4.5 SettingsView

Add new toggles/fields:
- `Avoid head-motion exercises` (bool, default false).
- `Daily theme` (read-only label showing today's theme; optional "reroll" button for debug builds only).
- `Enable combo moves` (bool, default true) — power switch for fallback-only mode.

No scheduler-timing changes. Existing interval/working-hours/noon settings untouched.

---

## 5. Compatibility & migration

### 5.1 Config file

Bump `AppConfig` with three new fields, all defaulted → decoder of older JSON still works (Swift's default-value decoding via `init(from:)` synthesized with defaults). No migration code needed beyond touching the sentinel.

```
var avoidHeadMotion: Bool = false
var comboEnabled: Bool = true
var configVersion: Int = 2        // was implicitly 1 before
```

The legacy migration in `StorageManager.migrateFromLegacy` does not need to change — combo fields simply default in since legacy config never had them.

### 5.2 Log file schema

**No breaking change.** `LogEvent.category` is already `String`, not `TipCategory`. Existing log files have categories like `"eye"`, `"neck"`, `"sedentary"`, `"noon"`, `"eye_neck"`. New writes will include:
- `"combo"` — when Scheduler fires a combo tip and logs it. The `primaryCategory` passed to `present(tips:primaryCategory:)` should become `"combo"` when `tips.first?.kind == .compound`, else `"eye_neck"` as today.
- `"eye_neck"` stays as a Scheduler-level track label (scheduled deferrals still log `category = "eye_neck"` with `tipName = "__deferred__"`). This is intentional: `eye_neck` labels the *track*, `combo`/`eye`/`neck` label the *tip*. DailyReport and stats code that buckets by category should treat `combo` as a new bucket next to eye/neck; existing eye/neck/sedentary/noon buckets are unaffected.

DailyReport update required: add `combo` bucket to whatever summary it renders (content-impl scope is Content.swift; DailyReport change is wiring-impl).

### 5.3 Recency buffer persistence (nice-to-have, not blocking)

If we want the buffer to survive app restart, StorageManager gets a trivial `recencyState.json` with `[TipCategory: [String]]`. MVP skips this; restart behavior is graceful (at worst one extra repeat).

### 5.4 Tip ID stability

Existing IDs (`eye.close_breathe`, `neck.chin_tuck`, …) must remain stable. All new IDs use the same dot-namespace convention. DailyReport / analytics that key on tip IDs continue to work.

### 5.5 Onboarding

First-run detection is new — gate on "config file was just created with defaults". Show a single-question sheet before the first reminder fires. If user already has a non-default config file on upgrade, skip onboarding and default `avoidHeadMotion = false` (consistent with "never asked = allow all"). Users who want to opt into the safety flag post-upgrade use SettingsView.

---

## 6. Implementation Plan (per file)

### 6.1 `Content.swift` (task #3 — content-impl)

1. Extend `TipCategory` with `combo`.
2. Extend `Tip` with `difficulty`, `kind`, `tags` (all defaulted).
3. Add new eye tips (4), new neck tips (4), all 10 combo tips with full bilingual copy + citations.
4. Collapse `neckCore` + `neckAux` into a single `neckTips` array; keep `neckCombo()` as a wrapper that returns `[nextNeck(), nextNeckDifferent()]` for the 3-step fallback path only.
5. Add `RecencyBuffer` (4-per-category ring) and `NoveltyTracker` (usage count, supplied from Storage on startup).
6. Add `TipSelector` (or `SelectorEngine` singleton) implementing the weighted sampler in §2.1. Expose: `nextEye`, `nextNeck`, `nextCombo`, `nextSedentary`, `nextEyeNeckSession(now:)`, `nextNoon`.
7. Add `DailyTheme.todayTheme()` and `TimeContext.forHour(_:)` helpers.
8. Refactor `combinedEyeAndNeck()` → `TipSelector.nextEyeNeckSession(now:)` with combo-first, 3-step fallback (§1.3).
9. Refactor `sedentaryBreak(forHour:)` to route through `TipSelector.nextSedentary` (preserves existing time-pref table, now sits inside the unified weight formula).
10. Add safety filtering: when `avoidHeadMotion = true` in config, filter pool before weighting. Selector receives config as a dependency or reads it via a `ConfigProvider` closure.
11. Preserve all existing function signatures (`randomEyeTip`, `randomNeckExercise`, `neckCombo`, `combinedEyeAndNeck`, `sedentaryBreak(forHour:)`, `noonReminder`) as thin forwarders so Scheduler.swift doesn't need to change in task #3.
12. Populate new `source` fields with citations from research §2.2 and §1.

**Expected diff size:** +550/-50 lines; single file.

### 6.2 `Scheduler.swift` (task #4 — wiring-impl)

1. In `fireEyeNeck()`: keep calling `ContentLibrary.combinedEyeAndNeck()`; thanks to §6.1 item 11, no call-site change is required. Add a tiny enhancement: compute `primaryCategory` from `tips.first?.kind` — `"combo"` if compound, `"eye_neck"` otherwise. Pass into `present(tips:primaryCategory:)`.
2. In `fireSedentary()`: replace direct call with `TipSelector.nextSedentary(now:)`. Behaviorally equivalent but participates in the unified weight formula.
3. In `present(tips:primaryCategory:)`: the `for t in tips` loop logs `LogEvent(category: t.category.rawValue, …)` — this already uses tip-level category. Only change: when combo, we want the **tip-level** category `"combo"` to show up in logs, and the **track-level** still labeled via the Scheduler-internal `primaryCategory` string (currently not persisted in the log). **No log-schema change needed.**
4. Surprise-slot hook: the 10% override lives inside `TipSelector`, not Scheduler — Scheduler stays agnostic. The only Scheduler concern is that if Selector returns a "fun-fact" card (a Tip with `kind = .compound` but `durationSeconds = 10` and `category = .combo`, tagged `funfact`), Scheduler should not treat it specially — it just presents, user reads, taps Done.

**Expected diff size:** +30/-15 lines.

### 6.3 `FloatingReminderWindow.swift` (task #4)

1. Add `.combo` case to `symbol(for:)` and `categoryLabel(_:locale:)`.
2. In `FloatingReminderView.body`, detect combo case: `vm.tips.count == 1 && vm.currentTip.kind == .compound`. Render the `[👁]+[🧍]` chip row above the title. Suppress `progressLabel` is already automatic (`tips.count > 1` check).
3. If `instruction` contains newlines, render as a `VStack` of numbered lines instead of a single `Text`. Additive; non-combo tips with no newlines keep the existing look.
4. No ViewModel / countdown changes.

**Expected diff size:** +70/-10 lines.

### 6.4 `Storage.swift` (task #4)

1. Add 3 new `AppConfig` fields with defaults (§5.1). Bump `configVersion` (informational only).
2. Add helper `countNotifiedByTipId(withinDays: Int) -> [String: Int]` that scans recent log files — used by `NoveltyTracker` and `dismiss-decay`. Read-only; no write-path change.
3. No change to log schema. No change to migration.

**Expected diff size:** +60/-0 lines.

### 6.5 `DesignSystem.swift` (task #4)

1. Add combo category color.
2. Add combo symbol constant if centralized.

**Expected diff size:** +5 lines.

### 6.6 `PopoverView.swift` / `MenuBarView.swift` / `SettingsView.swift` (task #4)

1. PopoverView: render "Today's theme: X" line + combo bucket in the per-category stats row.
2. SettingsView: three new controls (§4.5).
3. MenuBarView: no functional change; optionally surface unlock toast.
4. DailyReport.swift: extend category breakdown to include `"combo"`.

**Expected diff size:** +80/-5 lines across these files.

### 6.7 Out of scope (explicitly deferred)

- Persisting recency buffer to disk.
- First-run onboarding sheet (we'll default `avoidHeadMotion = false` and let users toggle it in Settings).
- A/B infrastructure for `recencyBuffer on/off`.
- Localizing the daily-theme name beyond zh/en.
- "Challenge" bonus cards (leave a stub for §2.8 surprise-slot using the same Tip struct + tag `funfact`).

---

## 7. Open questions for team-lead

1. **Combo color token** — is violet OK, or do we want to stick to the eye-blue/neck-green palette and just use a gradient? (I'll default to violet unless overridden.)
2. **Unlock thresholds** (5 / 20 lifetime completions) — are these user-visible progress, or silent? (I'll default to silent + one-time unlock toast.)
3. **Fallback frequency** — should the Scheduler randomly choose the 3-step "classic" session occasionally (say 15%) to preserve the novelty of the combo format itself? (Prevents combo from becoming the new habituated format.) (I'll default to: yes, 15% classic fallback rolled inside `nextEyeNeckSession`.)

These are non-blocking — content-impl and wiring-impl can proceed with defaults above and we can tweak constants later.

---

## 8. Verification checklist (what "done" looks like)

- [ ] Content library has 9 eye + 10 neck + 10 combo tips, all with non-nil `source`.
- [ ] Calling `TipSelector.nextEyeNeckSession` 200× in a row never returns the same tip ID twice within any 4-fire window.
- [ ] With `avoidHeadMotion = true`, none of the filtered tip IDs appear in 200 samples.
- [ ] Today's theme is stable for a calendar day and changes at local midnight.
- [ ] Old log files decode without error; new log files contain `"combo"` entries.
- [ ] FloatingReminderWindow renders combo (kind=compound) as single-page with the combined chips.
- [ ] `swift build` via `CodeBreathApp/build.sh` succeeds.
- [ ] Existing `randomEyeTip`, `neckCombo`, `sedentaryBreak(forHour:)`, `combinedEyeAndNeck()` entry points still compile.
