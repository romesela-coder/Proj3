# Handoff

Written by the cloud session that produced every commit in this repo. That
session runs on Linux with **no Swift toolchain and no access to the user's
Mac**, so most of this code has never been near a compiler. You have Xcode.
That is the whole reason you are here.

## The task

**Get a clean build, then keep it clean.** Nothing else is queued.

```bash
xcodebuild -scheme Maslul -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The user's environment is confirmed: **Xcode 26.4, iOS SDK 26.4**,
`FoundationModels.framework` present in the SDK, and an **iPhone 17 Pro Max on
iOS 26** for on-device testing.

## What is and isn't verified

| Commit | Contents | State |
| --- | --- | --- |
| `b82cc56` | 0.1 — onboarding, capture, entry detail, journal, projects, export, reminder, stats | ✅ built and ran on the user's Mac |
| `8a6e5f4` | 0.2 core — tidy (F2), weekly allocation (F3), time report, goals vs reality, quarter close | ❌ **never compiled** |
| `51a72ec` | `FoundationModelsSuggester` behind `#if canImport` | ❌ **never compiled, and could not be** on the Xcode 16 the user had at the time |

So roughly 2,800 lines across 14 new files have never been type-checked. Expect
a batch of errors on first build. That is the expected state, not a symptom of
something rotten.

## Most likely failures, in order

1. **`Services/FoundationModelsSuggester.swift`** — the only file written
   against an SDK that could not be checked at all. Suspect, in order:
   - `LanguageModelSession(instructions: Self.instructions)` — `instructions`
     may take an `Instructions` value built by a result builder rather than a
     plain `String` variable. A string *literal* may convert where a `String`
     constant does not.
   - the `@Generable` / `@Guide(description:)` declarations.
   - the `SystemLanguageModel.default.availability` switch and the
     `UnavailableReason` case names (`deviceNotEligible`,
     `appleIntelligenceNotEnabled`, `modelNotReady`).

   Fix these against the real SDK. **Do not** delete the file or disable the
   feature to get green — the user specifically wants the on-device model, and
   their hardware supports it.

2. **`Features/Ritual/AllocationView.swift`** — `PercentSlider` computes
   geometry by hand because the app forces RTL and `position(x:)` is not
   mirrored. If the fill or thumb ends up on the wrong side, the fix is the
   arithmetic inside `PercentSlider`, not adding a layout-direction override.

3. **SwiftData relationships** — `WeeklyAllocation` ↔ `AllocationSlice`
   (cascade, with the inverse declared on the allocation side) and
   `AllocationSlice.project`, which is intentionally unidirectional.

4. **`Design/Components.swift`** — `SettingRow` relies on the `@ViewBuilder`
   attribute propagating to the synthesized memberwise init, plus a constrained
   `where Trailing == Chevron` init. An ambiguity here lights up many call
   sites at once, which looks worse than it is.

## Before running

**The schema changed in `8a6e5f4`** — `Goal`, `WeeklyAllocation` and
`AllocationSlice` are new, and `Entry` gained an optional `goal` relationship.
SwiftData should migrate automatically, but a store created by the 0.1 build
may crash on launch. If it does: delete the app from the simulator or device
and run again. Do not add migration code before confirming that is the cause.

## Once it builds, verify in this order

1. App launches into onboarding; stepping through or skipping reaches the home
   screen.
2. **אני ← נתוני דוגמה** → on. Loads ~37 entries, 6 projects, 11 weekly
   allocations (2 deliberately skipped) and 3 goals.
3. **אני ← סידור שבועי** — cards advance, swipe and buttons both work, the
   closing screen shows a summary and one question.
4. **הקצאת זמן** — sliders always sum to 100, the lock holds a project still,
   the remainder line reads 0%.
5. **אני ← דוח הקצאת זמן** — bands render, origin split renders, the footer
   states the skipped-week count.
6. **אני ← מטרות מול מציאות** — declared next to recorded.
7. **On the device only: אני ← מודל מקומי** should read "המודל המקומי פעיל".
   In the simulator it will not — Apple Intelligence does not exist there, and
   falling back to the keyword suggester is correct behaviour, not a bug.

## Ground rules

- **Do not redesign anything.** The wireframes and §05 are binding. If
  something looks wrong, it is a layout bug, not an invitation.
- **Do not add features** without the user asking. There is a deliberate
  not-yet-built list surfaced in-app under *אני ← מה עוד לא נבנה*: review pack,
  voice dictation, résumé lines, semantic search, Face ID, encrypted backup,
  and the entire widget family. Widgets were explicitly deferred by the user
  because they need a second target and an App Group.
- **Do not weaken the hard constraints in `CLAUDE.md`** to make something
  easier. If one of them is genuinely blocking, say so and ask.
- Report honestly what compiled, what ran, and what you could not check. The
  user has been told plainly at every step which code was unverified; keep
  that going.

## Open product question

The user's own spec (§15) says not to start 0.2 before running 0.1 for six
weeks. They overrode that deliberately — building turned out to cost a fraction
of what the spec assumed — and chose to keep implementing. That decision stands;
don't relitigate it. What is still genuinely unanswered is whether the habit
holds in real use, and only the user can answer that.
