# מסלול · Maslul

A career journal for iPhone. Local-only, no account, no network code.

This repository covers the **0.1 milestone plus the core of 0.2** of the product
spec (`אפיון מסלול`, v0.3): capture, the weekly ritual (tidy + time allocation),
the time-allocation report, goals versus reality, journal, and export.

---

## Running it

```
open Maslul.xcodeproj
```

Pick any iPhone simulator and press ⌘R. Nothing else is required — no
CocoaPods, no SPM packages, no signing team for the simulator.

- **Xcode 16** (project format `objectVersion = 77`, file-system synchronized groups)
- **Deployment target: iOS 17.0**, so it runs on whatever simulator you already
  have installed. Built against the iOS 18 SDK.
- iPhone only, portrait only.
- The target uses automatic signing with no team. Simulator builds are fine as
  is; select a team in *Signing & Capabilities* only if you want to run on a
  physical device.

Adding Swift files is just adding files — the target references the `Maslul/`
folder itself, so nothing needs to be registered in the project.

## What's in this build

**Stage 1 — capture**

| Screen | Spec | |
| --- | --- | --- |
| Onboarding, 5 steps | F7 | ✅ |
| Home — greeting, four tiles, search, pending counter | §05 | ✅ |
| Quick capture, one required field, draft kept on exit | F1, US-A1/A3/A4 | ✅ |
| Entry details — type, project, origin, effort, date, sensitivity, evidence | US-B2/B3 | ✅ |

**Stage 2 — the weekly ritual**

| Screen | Spec | |
| --- | --- | --- |
| Tidy, card at a time, swipe or buttons, batches of 10 | F2, US-B1 | ✅ |
| Closing summary and one data-derived question | F2 | ✅ |
| Weekly allocation — sliders that hold 100, lock, note, skip | F3, US-G2 | ✅ |
| Two-week backfill window, then closed permanently | §07 | ✅ |
| Suggestions during tidy | §13 | ⚠️ keyword heuristic, not a model — see below |

**Stage 3 — retrieval**

| Screen | Spec | |
| --- | --- | --- |
| Journal — full-text search, filters, month grouping | US-C3 | ✅ |
| Time-allocation report — bands, origin split, notes, skipped weeks | §11, US-G4 | ✅ |
| Goals versus reality, quarter open/close, carry a goal forward | §12, F6, US-D1/D2 | ✅ |
| Markdown / JSON export, sensitive entries excluded by default | US-E3 | ✅ |
| Time-report export with the self-report disclaimer | US-G4 | ✅ |

**Supporting:** projects as an entity with the 8-active ceiling (US-G1), weekly
reminder with no streaks (US-F1/F2), local stats (§16), sample-data toggle.

Still missing, and listed in-app under *אני → מה עוד לא נבנה*: the review pack,
voice dictation, résumé lines, semantic search, Face ID, encrypted backup, and
the widget family.

## Notable implementation decisions

**No widgets in this drop.** §10 argues the widget family is why 0.1 might work
at all, and I agree — but it needs a second target and an App Group with a
shared SwiftData store, which is the most likely thing to fail to build on a
machine I can't test on. The store layer is structured so they drop in without
a rewrite. *אני → ווידג׳טים ונקודות כניסה* says this in the app rather than
pretending the family exists.

**No network code.** There is no `URLSession` call, no third-party SDK, and no
analytics anywhere in the target, and no CloudKit configuration on the model
container. §14 asks for a claim that can be verified: grepping `Maslul/` for
`URLSession`, `https?://` or `CloudKit` matches only comments and one SF Symbol
name (`network.slash`) — no networking API is called.

**RTL is forced at the root** (`.environment(\.layoutDirection, .rightToLeft)`)
rather than driven by the device language, so the layout matches the wireframes
in a simulator set to English.

**Light only.** The spec defines one palette on a white ground and no dark
variant, so the app pins `.preferredColorScheme(.light)` instead of inventing
a dark palette.

**Filtering happens in memory,** not through `#Predicate`. The dataset is one
person's journal, and SwiftData predicates over optional relationships cost
more in bugs than they save here.

**Tidy suggestions are keyword matching, not a language model.** §13 puts
classification on Apple's on-device `SystemLanguageModel`, which needs iOS 26
with Apple Intelligence and is absent from the simulator. What ships is the
fallback the spec already requires — the screen opens either way and every
suggestion is one tap from being corrected — behind a `Suggesting` protocol so
a `FoundationModelsSuggester` drops in without touching the flow. The UI labels
the source honestly rather than claiming a model it doesn't have.

**Report bands use a neutral grey ramp, not the pastels.** The six tints in §05
are bound to entry *types*; reusing them for projects would make the same colour
mean two different things. The wireframe's greyscale is correct here for a
reason the wireframe didn't intend.

**Goals show share of records, not share of effort.** The wireframe says
"31% מהמאמץ", but §07 makes the weekly allocation the only source of truth about
time, and goals link to entries rather than projects. The label says
"מהרשומות" so the number doesn't claim more than it knows.

**Nothing is deleted.** Per §03.04 there is no delete action on an entry —
entries are editable instead. The one exception is the sample-data toggle,
which wipes everything; it is labelled as a test affordance.

**Attachments** use `PhotosPicker`, so the app needs no permission strings at
all. Camera capture would require `NSCameraUsageDescription` and is left out.
Files are re-encoded to JPEG and copied into the app container.

**Colour comes from the spec, not the wireframes.** The wireframes are
deliberately greyscale; §05 defines the six pastel tints and the single
orange-red accent, which is what the tiles and the pending badge use.

## Layout

```
Maslul/
  MaslulApp.swift          model container, RTL root, reminder sync
  Navigation/              Router, RootView, floating dock
  Design/                  colour tokens, metrics, type, Hebrew formatting, components
  Model/                   Entry, Project, and the enums behind them
  Data/                    settings keys, attachment store, sample data
  Services/                exporter, reminder scheduler
  Features/                Onboarding, Home, Capture, Journal, Projects, Me
```

## Known caveats

Written without a Mac in the loop — the 0.1 milestone was verified to build and
run by hand, but the 0.2 work in this pass has not been compiled. The API
surface is kept conservative on purpose (SwiftUI + SwiftData, no exotic
modifiers).

**The schema changed** in this pass: `Goal`, `WeeklyAllocation` and
`AllocationSlice` are new, and `Entry` gained an optional `goal` relationship.
SwiftData should migrate this automatically, but if the app crashes on launch
against a store created by the previous build, delete the app from the
simulator and run again.
