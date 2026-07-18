# Re-adding StomperZ Mode — Implementation Plan

Restores the StomperZ game mode removed in `bdc9097e` ("remove StomperZ mode", 2020-03-30).

> **Status: implemented.** Corrections found while implementing are marked
> **[CORRECTION]** inline. The open questions at the bottom are all resolved.

## Why this is not a revert

`bdc9097e` is **2060 commits** behind `HEAD`. Of the 29 code/config files that commit
touched, **4 no longer exist at their old paths**, and only **1** (`Shared/Header.lua`)
is byte-identical to its 2020 state. Several are effectively rewritten:

| File | Churn since removal |
|---|---|
| `Scripts/SL-Helpers.lua` | +838 / −342 |
| `Scripts/SL-PlayerOptions.lua` | +626 / −64 |
| `metrics.ini` | +564 / −289 |
| `BGAnimations/ScreenSelectMusic overlay/SortMenu/default.lua` | +558 / −143 |
| `Scripts/SL_Init.lua` | +289 / −34 |
| `BGAnimations/.../TargetScore/default.lua` | +60 / −587 |

`git revert bdc9097e` will conflict on essentially every hunk. Every change below is a
**manual re-application**, using the old diff as a specification rather than a patch.

### Files that moved

| 2020 path | Current path |
|---|---|
| `ScreenEvaluation common/PerPlayer/Graphs.lua` | `ScreenEvaluation common/PerPlayer/Lower/Graphs.lua` |
| `ScreenEvaluation common/PerPlayer/LetterGrade.lua` | `ScreenEvaluation common/PerPlayer/Upper/LetterGrade.lua` |
| `ScreenEvaluation common/PerPlayer/Pane4/` | `ScreenEvaluation common/Panes/Pane4/` |
| `ScreenGameplay underlay/PerPlayer/ColumnFlashOnMiss.lua` | `ScreenGameplay underlay/PerPlayer/NoteField/ColumnFlashOnMiss.lua` |

---

## The central architectural change: FA+ is no longer a GameMode

This is the most consequential difference from 2020, and it shapes the whole task.

In 2020 there were four GameModes: `Casual`, `ITG`, `FA+`, `StomperZ`. Today
`metrics.ini` offers **only two**:

```ini
[ScreenSelectPlayMode]
ChoiceNames="Casual,ITG"
```

FA+ was demoted to a **per-player modifier** (`ShowFaPlusWindow`, `ShowExScore` in
`SL_Init.lua`). The string `"FA+"` survives only as a **data key** — `SL.Preferences["FA+"]`,
`SL.Metrics["FA+"]`, `SL.JudgmentColors["FA+"]` — which other code reads to derive the
tighter window and the white-Fantastic color while still running in `ITG` mode. For example:

- `SL-Helpers-GrooveStats.lua:537` — `if SL.Global.GameMode == "FA+" or (SL.Global.GameMode == "ITG" and SL[pn].ActiveModifiers.ShowFaPlusWindow)`
- `NoteField/ErrorBar/Text.lua:21` — `SL.Preferences["FA+"].TimingWindowSecondsW1`

**This plan restores StomperZ as a true third GameMode**, matching its original design
(it needs its own scoring weights, life rules, and receptor positions — none of which fit
the modifier model FA+ uses). The alternative — StomperZ as a modifier — is noted at the
end but is not what "re-add the StomperZ mode" implies.

Consequence: a large body of code written between 2020 and now assumes
`GameMode ∈ {Casual, ITG}` with `"FA+"` as a data-only key. Adding a third live value
means auditing that code, which is where most of the new work is.

---

## Phase 1 — Data model (`Scripts/SL_Init.lua`)

Three tables need a `StomperZ` key. Two are near-verbatim restorations; one has a new
required field.

**1a. `SL.JudgmentColors`** (currently ~line 271) — restore verbatim:

```lua
StomperZ = {
    color("#5b2b8e"),  -- purple
    color("#0073ff"),  -- dark blue
    color("#66c955"),  -- green
    color("#e29c18"),  -- gold
    color("#dddddd"),  -- grey
    color("#ff0000")   -- red
},
```

**1b. `SL.Preferences`** (~line 297) — restore the 2020 block verbatim. Note it
deliberately omits `MinTNSToScoreNotes`, which `ITG`/`FA+` gained later for
`RescoreEarlyHits`; StomperZ should keep the engine default.

**1c. `SL.Metrics`** (~line 369) — restore the 2020 weights, **plus two fields that did
not exist in 2020** and are now read unconditionally:

- `PercentScoreWeightCheckpointHit=0` and `GradeWeightCheckpointHit=0` — read by
  `metrics.ini:2335` / `:2346` for every mode. Omitting these yields `nil` and a
  metrics evaluation error in pump mode.
- `InitialValue=1` — `InitialValue` **moved out of `metrics.ini` into `SL.Metrics`**
  since 2020. This is a happy accident: StomperZ's full-life start is now expressible
  as data instead of the old inline `metrics.ini` conditional.

**1d. `PlayerDefaults.ActiveModifiers`** (~line 44) — restore
`ReceptorArrowsPosition = "StomperZ"`.

## Phase 2 — Mode plumbing

**2a. `Scripts/99 SL-ThemePrefs.lua:76`** — add StomperZ to `DefaultGameMode`
`Choices`/`Values`. (The 2020 diff also shows this list once held FA+; do **not**
re-add FA+.)

**2b. `Scripts/SL-Helpers.lua:379`** — `SetGameModePreferences` builds the Stats.xml
prefix table imperatively now, not as a literal. Add `prefix["StomperZ"] = "StomperZ-"`
so StomperZ scores go to `StomperZ-Stats.xml` and never pollute `Stats.xml`.

**2c. `Scripts/SL-Helpers.lua:~365`** — `GetComboThreshold`: restore StomperZ to the
`TapNoteScore_W4` combo-threshold branch alongside FA+.

**2d. `Scripts/SL-PlayerOptions.lua:~468`** — restore the `ReceptorArrowsPosition`
override (`Choices = { "StomperZ", "ITG" }`), and re-add the `GameplayExtras` filter that
strips `NPSGraphAtTop` in StomperZ.

**2e. `metrics.ini`** — restore per-mode conditionals that were flattened to constants:

| Line | Current | Restore to |
|---|---|---|
| 2310 | `MinStayAlive="TapNoteScore_W3"` | `(SL.Global.GameMode=="StomperZ" and "TapNoteScore_W4") or "TapNoteScore_W3"` |
| 2319 | `DangerThreshold=0.2` | `SL.Global.GameMode=="StomperZ" and 0.5 or 0.2` |
| 2364 | `HoldJudgmentYStandard=... or -90` | `... or (SL.Global.GameMode=="StomperZ" and -130 or -90)` |
| 2365 | `ReceptorArrowsYStandard=-125` | `SL.Global.GameMode=="StomperZ" and -170 or -125` |
| 2366 | `ReceptorArrowsYReverse=145` | `SL.Global.GameMode=="StomperZ" and 170 or 145` |

Line 2314 `InitialValue=0.5` is handled in Phase 1c instead — point it at
`SL.Metrics[SL.Global.GameMode]["InitialValue"]` for consistency with the other metrics,
or leave it and let StomperZ's value be applied where `SL.Metrics` is consumed. **Verify
which path the engine actually honors before choosing.**

**2f. `metrics.ini:~666+`** — `ScreenPlayerOptions2` `LineNames`. The 2020 conditional
(`gsub` out `ReceptorArrowsPosition` outside StomperZ; `gsub` out `TimingWindows` and
`LifeMeterType` inside it) must be rebuilt against the **current** line list, which has
grown considerably. Locate the correct `LineNames` block among the ~20 in the file — it
is the one under `[ScreenPlayerOptions2]`.

## Phase 3 — The new-surface audit (the real work)

Everything above is mechanical. This phase is not: it covers subsystems written
**after** StomperZ was removed, which have never seen a third GameMode.

**3a. Hard-crash risk — unguarded per-mode table lookups.** These index by
`SL.Global.GameMode` and will throw on a missing key. Phase 1 fixes all of them *if*
all three tables get a `StomperZ` entry; this is the verification checklist:

- `Panes/Pane1/JudgmentLabels.lua:80`, `Pane1/JudgmentNumbers.lua:44`
- `Panes/Pane2/JudgmentLabels.lua:163`, `Pane2/JudgmentNumbers.lua:146`, `Pane2/Percentage.lua:10,13`
- `ScreenGameplay underlay/PerPlayer/BackgroundFilter.lua:30` — reads
  `SL.Preferences[GameMode].MinTNSToHideNotes`
- `NoteField/SubtractiveScoring.lua:12` — reads `SL.Metrics[GameMode]`
- `metrics.ini:2324–2353` — ~25 `SL.Metrics[SL.Global.GameMode][...]` lookups

**3a-bis. Clamping mods is load-order sensitive — use `EnforceGameModeModifiers()`.**
Removing an OptionRow stops a *player* setting a modifier, but a **profile** can still
carry it in, and profiles load later than you'd expect:

```
ScreenSelectPlayMode
  -> Branch.AllowScreenSelectPlayMode2()   -- calls SetGameModePreferences()
     -> ScreenProfileLoad                  -- LoadProfileCustom() writes
                                           --   SL[pn].ActiveModifiers[k] = v
```

So anything forced off inside `SetGameModePreferences()` is silently overwritten by the
profile a screen later. `SetGameModePreferences()` is also a no-op for this purpose when
no players have joined yet, since it only loops `GAMESTATE:GetHumanPlayers()`.

`EnforceGameModeModifiers(player)` in `SL-Helpers.lua` holds the clamps and is called
from **both** `SetGameModePreferences()` and the end of `LoadProfileCustom()`. Add any
future per-mode modifier clamp there, not inline.

Symptom when this was missed: an ECFA player's profile kept `ShowFaPlusWindow = true`
into StomperZ, so `Pane5/Calculations.lua` painted `SL.JudgmentColors["FA+"][2]`
(`#ffffff`) over 13.5-21.5ms — a white band inside StomperZ's Gr window (12.5-25ms) in
the offset histogram. The same mods also feed `ScatterPlot.lua` and the `Pane3` labels.

**3b. Subsystems that must be explicitly gated off in StomperZ.** StomperZ's scoring
weights (W1=10, W2=9, W3=8, W4=5, no negative Miss weight) are incompatible with these,
and none of them existed in 2020:

- **EX Score** (`SL.ExWeights`, `TrackExScoreJudgments.lua`, `SL-CustomScores.lua`) —
  built on ITG/FA+ window semantics. Decide: disable, or define StomperZ EX weights.
- **ErrorBar** — `NoteField/ErrorBar/{Monochrome,Highlight,Average,Colorful}.lua`
  (8, 5, 5, 4 GameMode refs). These color-code by timing window; StomperZ's windows
  differ (W1=12.5ms, W2=25ms, W3=50ms, W4/W5=100ms).
- **OffsetDisplay** (`NoteField/OffsetDisplay.lua`, 5 refs)
- **Pane3/JudgmentLabels.lua** (13 refs) and **Pane5/default.lua** (8 refs)
- **ITL / RPG / GrooveStats** — `SL_ITL.lua`, `RpgRatemod.lua`, `ItlFile.lua`,
  `AutoSubmitScore.lua`. `SL-Helpers-GrooveStats.lua:351` already reads
  `valid[4] = SL.Global.GameMode == "ITG"`, which correctly excludes StomperZ with no
  change — **confirm** the ITL and RPG paths gate as tightly.
- **Ghost data** (`TrackGhostData.lua`, `SaveGhostData.lua`) — ensure StomperZ ghosts
  are stored separately or not at all.

**3c. `Graphics/MusicWheelItem Grades/GetLamp.lua`** (2 refs) — grade lamps on the music
wheel are per-mode; StomperZ scores live in a separate Stats.xml, so confirm the wheel
reads the right profile.

---

## UI changes

Every visible difference StomperZ introduces, grouped by screen.

### ScreenSelectPlayMode — mode picker

1. **Third choice.** `metrics.ini:172` → `ChoiceNames="Casual,ITG,StomperZ"`, and add
   `ChoiceStomperZ="name,StomperZ;"`. Match the current `ChoiceCasual`/`ChoiceITG` form —
   the 2020 version's `screen,ScreenSelectPlayMode2` fragment is obsolete; the current
   entries omit it and rely on `NextScreen=Branch.AllowScreenSelectPlayMode2()`.
2. **Icon position.** Replace the stale placeholder at `metrics.ini:193–194`:
   ```ini
   IconChoiceStomperZX=_screen.cx - 110
   IconChoiceStomperZY=_screen.cy + 25
   ```
   Note `+ 25`, **not** the 2020 value of `+ 75` — StomperZ now occupies the *third*
   slot (FA+ used to hold `+ 25`), so it slides up one row.
3. **Description text.** `Languages/en.ini [ScreenSelectPlayMode]` needs a
   `StomperZDescription` string. `en.ini` still has a stale `FA+=FA+` name entry at
   line 71 but no `FA+Description`; add `StomperZ=StomperZ` and a fresh description.
   The other eight `Languages/*.ini` files need the same pair, or they fall back to
   English.
4. **Animated LifeMeter preview.** Restore the `StomperZLifeMeter` `ActorFrame` in
   `BGAnimations/ScreenSelectPlayMode underlay/default.lua` — the masked
   `Triangles.png` with two magenta `diffuseshift` quads at `x=50` and `x=140`, shown
   only when the cursor is on StomperZ. Restore the companion tweak in the existing
   `LifeMeter` frame (~line 188) so the standard ITG meter fades **out** when StomperZ
   is highlighted. `Graphics/Triangles.png` still exists — no asset work needed.
5. **`BGAnimations/Thonk overlay/default.lua:869,910`** — re-add `"IconChoiceStomperZ"`
   to the `items` list and `GetChild("StomperZLifeMeter")` to `items2`, or the Thonk
   easter-egg animation will desync against the new three-choice screen.

### ScreenGameplay — the most visible differences

6. **Receptors sit higher.** `ReceptorArrowsYStandard` −170 (vs −125), reverse +170
   (vs +145). Restore `ScreenGameplay overlay/ReceptorArrowsPosition.lua` (deleted
   outright) and its `LoadActor` call in `ScreenGameplay overlay/default.lua:~31`. This
   actor lets the player pick StomperZ-style or ITG-style receptor height at runtime by
   shifting the whole `PlayerP1`/`PlayerP2` ActorFrame; the offsets are Standard `ITG=45 / StomperZ=0`,
   Reverse `ITG=-30 / StomperZ=0`.
7. **Purple surround LifeMeter.** Restore
   `ScreenGameplay underlay/PerPlayer/LifeMeter/StomperZ.lua` (130 lines, deleted). It
   is a three-layer stack of cropped quads flanking the notefield — green `#00c263`
   under-half, blue `#0073ff` over-half, purple `#6517e0` "hot" overlay with a red
   death flash. Then branch to it in `LifeMeter/default.lua:9`, whose comment currently
   reads "in ITG, we have the choice…" and must be reworded. **StomperZ forces this
   meter — the `LifeMeterType` option row does not apply** (see 2f).
8. **Half-height header.** `Shared/Header.lua` — 40px tall in StomperZ vs 80px. This is
   the one file untouched since 2020, so the old hunk applies cleanly.
9. **BPM display.** `Shared/BPMDisplay.lua` — zoom `1` instead of `1.33`, plus an extra
   black backing `Quad` (66×40 at `y=-20`, alpha 0.85) that exists only in StomperZ.
10. **Score readout repositioned.** `PerPlayer/Score.lua` — zoom `0.4` (vs `0.5`),
    positioned at `x=WideScale(160,214), y=20` for P1 and `_screen.w - WideScale(50,104)`
    for P2. Also restore the two early-return guards that exempt StomperZ from the
    `NPSGraphAtTop` hide logic. This file has churned heavily (+157/−24); re-derive the
    conditionals rather than pasting.
11. **Combo raised** 20px — `Graphics/Player combo.lua`, restore the `OnCommand` `y(-20)`.
12. **Difficulty meter lowered** 20px — `PerPlayer/DifficultyMeter.lua`.
13. **Column-flash offset** 40 instead of 80 —
    `PerPlayer/NoteField/ColumnFlashOnMiss.lua` (moved path).
14. **Step Statistics panel** shifts to `y=-40` —
    `PerPlayer/StepStatistics/BackgroundAndBanner.lua`.
15. **Pacemaker repositioned** — `PerPlayer/TargetScore/default.lua`. When StomperZ is
    active *and* `ReceptorArrowsPosition == "StomperZ"`, the pacemaker moves above the
    combo (`y = _screen.cy - 60`, zoom `0.35`, `x = width/NumColumns`, plus
    `shadowlength(1)`) to clear the raised receptors. This file lost 587 lines since
    2020 — treat the old hunk as a spec only.
16. **No upper NPS graph** — `PerPlayer/UpperNPSGraph.lua`, restore the StomperZ
    early-return.
17. **No danger/fail red flash** — `PerPlayer/Danger.lua`, restore StomperZ to the
    early-return alongside Casual. Reword the comment, which now explains only the
    Casual rationale.

### ScreenEvaluation

18. **No letter grade.** StomperZ's scoring produces no meaningful ITG grade. Restore
    the early-return in `PerPlayer/Upper/LetterGrade.lua` (moved path).
19. **Lifebar halfway marker.** Restore `LifeBarGraph_MidwayQuad` in
    `PerPlayer/Lower/Graphs.lua` (moved path) — a black 75%-alpha quad marking the 50%
    line, visible only in StomperZ, reflecting that StomperZ starts at full life with a
    0.5 danger threshold.
20. **Decorative triangles.** Restore `BGAnimations/Triangles.lua` (deleted) and its
    `LoadActor(THEME:GetPathB("", "Triangles.lua"))` call. **The old call site is gone** —
    `ScreenEvaluation common/default.lua` was restructured (+90/−101) into
    `Shared/` and `PerPlayer/` loaders. Pick a new insertion point among the
    `t[#t+1] = LoadActor(...)` calls at lines 49–109, before the panes are added.
21. **[CORRECTION] Judgment abbreviations are in Pane*5*, not Pane 4.** Pane 4 is now a
    HighScores list; the offset histogram — with both the `abbreviations` table and the
    centre divider quad — moved to `Panes/Pane5/default.lua`. Both changes land there:
    add `StomperZ = { "Perf", "Gr", "Good", "Hit", "" }`, and recolor the divider to
    `diffuse(0,0,0,0.666)` (black instead of white) in StomperZ.
22. **GrooveStats ineligibility.** Already correct — `SL-Helpers-GrooveStats.lua:351`
    reads `valid[4] = SL.Global.GameMode == "ITG"`, which excludes StomperZ.
    Only the explanatory comment needs updating to name StomperZ.

### ScreenEvaluationSummary

23. **No letter grades**, in two places: the per-player `ActorProxy` in
    `PlayerStageStats.lua` (~line 119) and the `LoadActor("./LetterGrades.lua")` call in
    `default.lua`. Both need their StomperZ guard restored.
24. **Decorative triangles** on the summary screen — same `Triangles.lua` actor.

### ScreenSelectMusic

25. **Header mode text.** `Graphics/ScreenSelectMusic header.lua` already renders
    `THEME:GetString("ScreenSelectPlayMode", SL.Global.GameMode)` generically, so it
    picks up StomperZ **for free** once the language string from item 3 exists. Only
    the comment needs updating.
26. **SortMenu mode switching.** `SortMenu/default.lua:417`. The menu was rewritten into
    a declarative `{ {"ChangeMode", "<Mode>"}, <condition> }` table and now offers only a
    Casual switch. Add StomperZ in the same style:
    ```lua
    { {"ChangeMode", "StomperZ"}, SL.Global.Stages.PlayedThisGame == 0 and SL.Global.GameMode ~= "StomperZ" },
    ```
    This is a rewrite, not a restoration — the 2020 `table.insert` form no longer exists.

### ScreenSelectProfile

27. **[CORRECTION] The three deleted StomperZ PNGs must be restored.** The original plan
    said to skip them on the grounds that the flat `_judgments/` folder already ships
    `Code 2x7`, `Miso 2x7`, and `Roboto 2x7`. **That was wrong.** Those are the *ITG*
    graphics: they render Fantastic/Excellent/Great/Decent/Way Off. The StomperZ 2x6
    sheets render StomperZ's own wording — Perfect/Great/Good/Hit — so they are distinct
    art, not redundant copies of the same fonts. Restore with:

    ```sh
    git checkout bdc9097e^ -- "Graphics/_judgments/StomperZ"
    ```

28. **Wiring them back up.** In 2020, `_judgments/` had one subfolder per mode and
    `GetJudgmentGraphics(mode)` read the matching one. Today the directory is **flat**
    and the function takes no argument, so the restored subfolder needs reconnecting:

    - `SL-Helpers.lua` gains `JudgmentGraphicDirectory()` (returns
      `_judgments/StomperZ` in StomperZ, `_judgments` otherwise) and
      `GetJudgmentGraphicPath(filename)`. `GetJudgmentGraphics()` reads the former.
    - Six load sites that hardcoded `"_judgments/"..filename` now call
      `GetJudgmentGraphicPath()`: `Player judgment.lua` (×2), `JudgmentBack.lua` (×2),
      `PerColumnJudgmentGraphics.lua`, and `OptionRowPreviews/JudgmentGraphic.lua`.
      The `"_judgments/Love"` ScreenEdit fallbacks stay hardcoded — `Love` exists only
      in the common folder.
    - **The two sets cannot be merged into one flat list.** `StripSpriteHints()` reduces
      both `Code 2x6 (doubleres).png` and `Code 2x7 (doubleres).png` to `Code`, so
      merging would show duplicate names in the options row. Separate directories are
      load-bearing, not incidental.
    - Consequence, matching 2020: StomperZ offers only its own three graphics. A profile
      whose saved graphic isn't in that set falls back to `available_judgments[1]` via
      the `FindInTable` guard already present at each site.

29. **`ScreenSelectProfile` judgment previews** — `JudgmentGraphicPreviews.lua` must
    check **both** directories. This screen runs before a GameMode is settled and
    previews whatever each profile last saved, so it cannot use
    `GetJudgmentGraphicPath()` (which follows the *current* mode).
    `PlayerProfileData.lua` needs no change — its `RecentMods()` just passes the raw
    filename through now, with no per-mode table.

### ScreenPlayerOptions

30. **`ReceptorArrowsPosition` row appears** (StomperZ only) — offering "StomperZ" and
    "ITG" receptor heights (item 6).
31. **`TimingWindows` and `LifeMeterType` rows disappear** — StomperZ has fixed windows
    and a forced purple meter. Both via the `LineNames` conditional in 2f.
32. **`NPSGraphAtTop` removed** from the `GameplayExtras` multi-select (item 2d).

### README

33. **[CORRECTION]** This fork's `README.md` has no game-mode list to restore a bullet
    to — it is a feature-list README for the Zmod fork, not upstream's. Added StomperZ
    to the fork's feature list instead.

### Screen flow

34. **[NOT IN THE ORIGINAL PLAN]** `Branch.AllowScreenSelectPlayMode2()`
    (`Scripts/SL-Branches.lua:153`) gates the Regular/Marathon chooser to
    `GameMode == "ITG"`. In 2020, StomperZ reached that screen via
    `ChoiceStomperZ="...; screen,ScreenSelectPlayMode2"`, which no longer exists —
    all choices now route through this branch. StomperZ must be added to the condition
    or it silently loses access to course mode.

---

## Suggested commit order

1. **Data** — Phase 1 (`SL_Init.lua`). Inert on its own; nothing reads `StomperZ` yet.
2. **Plumbing** — Phase 2. Mode becomes selectable and correctly scored, but looks like ITG.
3. **Gameplay UI** — items 6–17. The biggest and riskiest chunk; consider splitting the
   LifeMeter (7) and receptor positioning (6) into their own commits.
4. **Evaluation UI** — items 18–24.
5. **Menus & options** — items 1–5, 25–31.
6. **Docs** — item 32.

## Verification

There are no automated tests in this theme; verification is manual in ITGmania.

- Launch, pick StomperZ, confirm the third icon and the magenta triangle preview.
- Play a chart: receptors high, purple surround meter, 40px header, no NPS graph, no
  danger flash, score at top-left.
- Toggle `ReceptorArrowsPosition` to "ITG" mid-session and confirm arrows and pacemaker
  both move together.
- Reach evaluation: no letter grade, triangles visible, Pane 4 shows `Perf/Gr/Good/Hit`,
  GrooveStats shows as invalid.
- Confirm scores land in `StomperZ-Stats.xml` and **not** `Stats.xml`.
- Play a stage in ITG mode afterward to confirm nothing leaked — especially
  `ReceptorArrowsY*`, `InitialValue`, and `MinStayAlive`.
- Switch to StomperZ via the SortMenu (only offered before stage 1) and confirm
  preferences re-apply.

## Resolved questions

- **EX Score in StomperZ** (3b) — **disabled.** `ShowExScore`, `ShowFaPlusWindow`, and
  `ShowFaPlusPane` are forced off for StomperZ in `SetGameModePreferences()`, and the
  `FaPlus` option row is removed from `[ScreenPlayerOptions2]`. Consistent with
  StomperZ's GrooveStats ineligibility.
- **ErrorBar / OffsetDisplay** (3b) — **disabled.** Early-returns in
  `NoteField/ErrorBar/default.lua` and `NoteField/OffsetDisplay.lua`, plus removal of
  the three ErrorBar option rows. StomperZ's 12.5ms W1 would make the ITG-tuned colors
  actively misleading.
- **`InitialValue` authority** (2e) — **answered: `metrics.ini` is authoritative.**
  `SL.Metrics[mode].InitialValue` was dead data, read by nothing;
  `THEME:GetMetric("LifeMeterBar", "InitialValue")` is what the engine and
  `SL-Helpers-GrooveStats.lua:442` actually consult. Rather than add a fourth
  hardcoded conditional, `metrics.ini` now reads
  `SL.Metrics[SL.Global.GameMode]["InitialValue"]`, making the existing field live and
  single-sourced — the same pattern the surrounding Life/Grade weights already use.
- **Alternative design not taken:** StomperZ could follow FA+ and become a per-player
  modifier rather than a GameMode. This would avoid the entire Phase 3 audit, but it
  cannot express StomperZ's distinct life rules, receptor positions, or full-life start,
  so it was not pursued.

## Note for future edits: mixed line endings

`Languages/en.ini`, `metrics.ini`, `Graphics/Player combo.lua`, and
`ScreenSelectPlayMode underlay/default.lua` contain **mixed** line endings — mostly CRLF
with a few dozen LF-only lines — while `.gitattributes` declares `* text=auto eol=lf`
and `core.autocrlf` is `true` locally. Editors that rewrite a whole file will normalize
those stray lines and produce a diff full of invisible EOL-only changes (40 spurious
lines in `en.ini` alone). Check with:

```sh
git diff --shortstat && git diff --shortstat --ignore-cr-at-eol
```

If the two disagree, the difference is EOL churn, not real changes.
