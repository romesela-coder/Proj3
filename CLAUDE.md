# מסלול · Maslul — project context

A career journal for iPhone, built from a Hebrew product spec (`אפיון מסלול`,
v0.3) and an 18-artboard wireframe canvas. Single user, single device.

**Read `HANDOFF.md` first** — it holds the point-in-time state, what has and
hasn't been compiled, and the current task. This file is the durable context.

## Hard constraints — do not relax these without asking

These come from the product spec and are not style preferences.

1. **No network code, ever.** No `URLSession`, no third-party SDK, no
   analytics, no CloudKit on the model container. §14 asks for a claim the user
   can verify by grepping. Keep it true.
2. **No account, no server, no sign-in.** Not now, not as a "future hook".
3. **Nothing is deleted.** There is deliberately no delete action on an entry
   (§03.04); entries are editable instead. The only exception is the
   sample-data toggle, which is labelled a test affordance.
4. **No streaks, no guilt.** A missed week is a missed week. No red states, no
   "you missed", no daily reminders — one weekly reminder, two maximum (§03.06).
5. **No entry text in any widget**, if widgets are ever added (§10). Counters,
   project names and labels only.
6. **On-device AI only.** No Private Cloud Compute, no external provider, even
   where the API allows it. This is a product decision, not a technical limit.

## Build

- **Xcode 26.4**, iOS SDK 26.4. Deployment target **iOS 17.0**, built against
  the newer SDK on purpose so it runs on older simulators.
- One target, one scheme, iPhone-only, portrait-only. No SPM packages, no
  CocoaPods. Simulator builds need no signing team.
- The target references the `Maslul/` folder via a file-system synchronized
  group (`objectVersion = 77`), so **adding a Swift file is just adding a file**
  — nothing to register in the project.

```bash
xcodebuild -scheme Maslul -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Layout

```
Maslul/
  MaslulApp.swift          model container, forced RTL root, reminder sync
  Navigation/              Router (@Observable), RootView, floating dock
  Design/                  colour tokens, metrics, type, Hebrew formatting, components
  Model/                   Entry, Project, Goal (+Quarter), WeeklyAllocation, enums
  Data/                    settings keys, attachment store, sample data, allocation math
  Services/                exporter, reminder scheduler, suggesters, weekly insight
  Features/                Onboarding, Home, Capture, Journal, Ritual, Reports, Goals, Me
```

The product is a three-stage loop, and the folder names follow it:
**לתפוס** (Capture) → **לסדר** (Ritual) → **לשלוף** (Journal, Reports, Goals).

## Conventions in this codebase

- **Filter in memory, not with `#Predicate`.** The dataset is one person's
  journal. SwiftData predicates over optional relationships cost more in bugs
  than they save here. `@Query` fetches sorted, views filter in Swift.
- **Enums are stored as raw `String`** on the models, with computed properties
  exposing the enum. Keeps predicates and migrations simple.
- **Set one side of a SwiftData relationship**, the to-one side, and let the
  inverse maintain itself. Setting both duplicates children.
- **Hebrew UI strings are inline in the views.** There is no localisation
  infrastructure and none is wanted — the product is Hebrew-only.
- **RTL is forced at the root** (`.environment(\.layoutDirection, .rightToLeft)`)
  rather than following device language, so layout matches the wireframes on
  any simulator. Consequence: `offset(x:)` and `position(x:)` are **not**
  mirrored by SwiftUI — hand-built sliders and bars compute geometry
  explicitly. See `PercentSlider` in `AllocationView.swift`.
- **Light only.** The spec defines one palette on a white ground and no dark
  variant, so the app pins `.preferredColorScheme(.light)`.

## Design language (spec §05)

- **Colour comes from the spec, not the wireframes.** The artboards are
  deliberately greyscale. The real palette is six low-saturation tints bound to
  the six **entry types**, plus one live accent `#FF5C3A` used *only* for state
  that needs attention. Never use a type tint to mean something else — the
  report bands use a neutral grey ramp for exactly this reason.
- Radii: tile 20, card 16, pills fully rounded. No sharp corners anywhere.
- 8pt base spacing, 20pt horizontal margins, 12pt between tiles.
- One spring for the whole app: `response 0.35, damping 0.85` (`Motion.spring`).
- Thin monoline SF Symbols against very heavy type — that contrast is the
  entire personality. No illustrations, no emoji.
- Navigation and the write button live in floating black pills at the bottom,
  not a tab bar.

All tokens are in `Design/Theme.swift`. Use them; do not hardcode colours.

## The AI layer

`Suggesting` (async, `@MainActor`) has two implementations:

- `FoundationModelsSuggester` — Apple's on-device `SystemLanguageModel`. The
  whole file is inside `#if canImport(FoundationModels)` **and**
  `@available(iOS 26, *)`. A fresh session per entry with a three-field
  structured output; the context window is small and feeding it more lowers
  quality rather than raising it.
- `HeuristicSuggester` — keyword matching. The fallback the spec requires.

`SuggesterFactory.make()` picks at runtime. **Every retrieval surface must stay
fully usable with no model at all** (§13) — that is a requirement, not a nicety.
A model failure must never be worse than no model.

## Git

Work on `claude/cloud-vs-local-9w7808`. It is also the repository's default
branch — the repo was empty when the project was first pushed, and the user
chose to leave it that way. There is no PR.

End commit messages with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JSq7MjaPdq3HArQYYcAXhs
```
