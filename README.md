# מסלול · Maslul

A career journal for iPhone. Local-only, no account, no network code.

This repository is the **0.1 milestone** of the product spec (`אפיון מסלול`, v0.3, §15):
capture, projects, journal with search and filters, sensitivity, and export.

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

| Screen | Spec | Status |
| --- | --- | --- |
| Onboarding, 5 steps | F7 | ✅ |
| Home — greeting, four tiles, search, pending counter | §05 | ✅ |
| Quick capture, one required field, draft kept on exit | F1, US-A1/A3/A4 | ✅ |
| Entry details — type, project, origin, effort, date, sensitivity, evidence | US-B2/B3 | ✅ |
| Journal — full-text search, filter by type / project / range, grouped by month | US-C3 | ✅ |
| Projects as an entity, 8 active ceiling, closing keeps history | US-G1 | ✅ |
| Sensitivity flag, excluded from export with the count stated | US-B3, US-E3 | ✅ |
| Markdown / JSON export via the system share sheet | US-E3 | ✅ |
| Weekly reminder, no streaks | US-F1/F2 | ✅ |
| Local stats (entry count, this month, friction share) | §16 | ✅ |
| Sample data toggle | — | ✅ (off by default, in "אני") |

Deliberately **not** here, and visible as such inside the app under
*אני → מה עוד לא נבנה*: the weekly tidy flow, weekly allocation and the time
report, quarterly goals, the review pack, voice dictation, résumé lines,
semantic search, Face ID, and encrypted backup.

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

This was written without a Mac in the loop — it has not been compiled or run.
The API surface was kept conservative on purpose (SwiftUI + SwiftData, no
exotic modifiers), but expect the first build to want small fixes rather than a
clean first try.
