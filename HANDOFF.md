# Maslul handoff

Updated September 28, 2026.

## Current baseline

The project is an actively tested iPhone app, not an uncompiled prototype. The
generalized tags, rich inline mentions, native rich-text editor, global search,
Boxes board, compact entry sheet, Trash, dictation, entry reminders, and the
first Goal/Checkpoint roadmap iteration have all been built and exercised on a
physical iPhone with Xcode 26.4 / iOS 26.

The current product loop is:

1. Capture a note from the Today screen by typing or dictating.
2. Add existing tags inline with `@`, create a missing tag in place, or choose
   from locally ranked suggestions.
3. File it into one Box (Inbox by default); the Box icon identifies the entry
   in Today and Journal.
4. Optionally link the Entry to a Goal and a Checkpoint within that Goal.
5. Edit the entry in a compact sheet and optionally change its Box, Goal,
   Checkpoint, date, privacy, title, tags, reminder, or attachments.
6. Retrieve entries by day in Calendar, by filing context in Boxes, through
   global search, or in the roadmap/timeline of a Goal.

Goals are now an active product direction, not a legacy surface. The working
navigation model is Goals plus the on-the-go Journal/Calendar. Boxes remain
available as a useful filing/workflow view, but are not automatically Goals or
Checkpoints. `GOALS_PLAN.md` is the detailed product record for this experiment.

## Current Goal model

- A **Goal** is a user-created intention and the home for its context, roadmap,
  and reflection. Its name is the only required creation field.
- A **Checkpoint** is a planned step or milestone inside one Goal. It may stand
  alone as a task or contain its own ordered Entry timeline. Checkpoints have
  optional descriptions and target dates; their roadmap order is independent
  of those dates.
- An **Entry** remains the single journal record. It may have no Goal, one Goal,
  or one Goal plus one Checkpoint. Linking it never removes it from Journal or
  its Box.
- The Goal roadmap interleaves Checkpoints and occasional Goal Entries. The
  user can reorder both. Entries inside a Checkpoint have a separate persisted
  manual order.
- Completing a Checkpoint is explicit and drives the Goal progress bar.
- Goal context is stored as three optional prompts but displayed as an
  unlabeled sequence of short paragraphs. The first paragraph previews below
  the Goal title; expansion pushes only the content below it down.
- Goal and Checkpoint detail pages share `EditableDetailHeader`: tapping the
  entity title enters inline editing with the same Save/Cancel convention.
- Goal/Checkpoint sheets intentionally have no generic navigation title or
  Done button. The Checkpoint Manage menu lives beside its title.
- The global floating `+` always creates an Entry. Goal creation has its own
  explicit action; the Goal roadmap header uses a single icon-only `+` to add a
  Checkpoint.
- Reflection questions are hard-coded, curated prompts. “Need a direction?” is
  available in normal, Goal, and Checkpoint capture; choosing a prompt inserts
  it into the Entry composer as context.

### Next product decisions

1. Decide the final names and navigation prominence of Goals, Journal/Calendar,
   and the legacy Boxes view.
2. Decide whether Goal creation should support batch planning of several
   Checkpoints or stay name-first and defer roadmap building.
3. Decide whether completing a Checkpoint should create a dated journal event.
4. Continue visual refinement of Goal/Checkpoint density and test the current
   context disclosure/editing interaction with real goals.
5. Define the first external-model contract before adding networking: provider,
   backend and key custody, explicit user consent, retained data, cost limits,
   failure behavior, and privacy copy. The first narrow model job should rank
   4–6 prompt IDs from the curated bank using bounded Goal context and approved
   recent Entries. No external-model networking exists yet.

## Build and device check

```bash
xcodebuild \
  -project Maslul.xcodeproj \
  -scheme Maslul \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

For physical-device work, build with the connected Xcode destination, install
the resulting `Maslul.app`, and launch bundle identifier
`com.romesela.maslul`. The user's standing preference is to refresh the build
on the connected iPhone after every completed implementation change.

The currently connected development phone uses these commands:

```bash
xcodebuild \
  -project Maslul.xcodeproj \
  -scheme Maslul \
  -configuration Debug \
  -destination 'platform=iOS,id=2911A2B1-6D4F-5301-B2C9-AB36DA5AAEC6' \
  -derivedDataPath /private/tmp/maslul-device-build \
  -allowProvisioningUpdates \
  build -quiet

xcrun devicectl device install app \
  --device 2911A2B1-6D4F-5301-B2C9-AB36DA5AAEC6 \
  /private/tmp/maslul-device-build/Build/Products/Debug-iphoneos/Maslul.app

xcrun devicectl device process launch \
  --device 2911A2B1-6D4F-5301-B2C9-AB36DA5AAEC6 \
  --terminate-existing com.romesela.maslul
```

If install or launch cannot acquire the device tunnel, confirm that the phone
is connected and unlocked, then retry. CoreDevice may print a harmless
"No provider was found" warning before succeeding.

## Architecture that matters now

- `Model/Tag.swift` owns tag validation, the `TagGroup`/`EntryTag` schema, and
  bootstrap of legacy entry types and projects.
- `Model/EntryBox.swift` owns Inbox bootstrap, Box validation, and the
  one-box-per-entry relationship.
- `Design/EntryBoxViews.swift` owns Box identity, selection, creation, and
  Box-level icon editing.
- `Design/InlineMentionEditor.swift` bridges `UITextView` for compact plain-text
  capture and mention previews.
- `Design/NativeRichTextEditor.swift` owns full-entry editing through the iOS 26
  SwiftUI `TextEditor` and `AttributedString`; selection, keyboard behavior and
  formatting controls remain system-owned.
- `Design/TagMentions.swift` owns `@` query parsing, selection, inline tag
  creation, and mention visuals.
- `Features/Home/HomeView.swift` owns the Calendar/Boxes mode switch, ranked tag
  suggestions, compact composer, day swipes, save coordination, and dictation
  entry point.
- `Features/Home/BoxesBoardView.swift` owns Box shelves, focused Box boards,
  persistent ordering, manage/delete states, and compact entry cards.
- `Services/SpeechDictationController.swift` owns both iOS 26
  `SpeechAnalyzer` dictation and the legacy recognizer fallback.
- `Services/LocalMetadataGenerator.swift` owns title/icon generation and
  deterministic fallbacks.
- `Features/Tags/TagsView.swift` owns tag-group navigation, editing, colors,
  uniqueness guardrails, and deletion.
- `Features/Tracks/GoalsOverviewView.swift` owns the Goals home, mixed Goal
  roadmap, Goal progress/context, roadmap ordering, and focused Goal capture.
- `Features/Tracks/GoalEntryCollectionSheet.swift` owns one Checkpoint's Entry
  timeline, Entry ordering, completion, deletion, and contextual capture.
- `Features/Tracks/GoalQuestions.swift` owns the curated question bank and
  name-first Goal creation flow.
- `Features/Tracks/GoalDirectionsView.swift` owns the compact prompt browser
  used above the Entry composer.
- `Model/GoalCheckpoint.swift` and the Goal/Checkpoint fields on `Entry` own the
  current roadmap relationships and persisted manual positions.
- `Design/Components.swift` owns `EditableDetailHeader`, the shared inline-edit
  convention for Goal-like entity detail pages.

## Important invariants

- The root environment is LTR with an English locale. Do not reintroduce a
  forced RTL root because the device or developer conversation is Hebrew.
- Tag names are globally unique after trimming, case folding, and diacritic
  folding. Empty names and names longer than 50 characters are invalid.
- Mention identity lives in `Entry.tags`; the body stores readable `@Name`
  text. Keep both in sync when changing the editor.
- Sending an entry during dictation must await `stopAndWait()` so the final
  volatile phrase is committed before save and title generation.
- Entry deletion is soft for 48 hours. Tag/group deletion must not delete
  entries.
- A Calendar day swipe is valid only when it begins outside an entry row. Rows
  retain their own native trailing swipe action.
- Quick capture combines the selected date with the current clock time. Do not
  regress new entries to `12:00 AM`; old midnight entries cannot be repaired
  because their original time was never stored.
- The app has no account, CloudKit container, analytics, third-party SDK, or
  application networking layer. An external model is planned but must not be
  connected until its privacy, consent, backend/key-custody, and failure model
  are explicitly defined.
- Foundation Models and Speech failures must leave a usable deterministic or
  system fallback.

## Regression checklist

1. Start quick capture; the editor focuses and follows the keyboard smoothly.
2. Dictate with Hebrew and English keyboards, pause, resume, stop, and send.
   Previously finalized text must not disappear.
3. Type `@`, choose a tag, and verify the full editor inserts a tinted `@Name`
   mention while saved-entry previews continue to render the compact token.
4. Edit or remove a full-editor mention and verify its tag relationship is
   removed only when no complete `@Name` occurrence remains.
5. Create a tag while writing and verify duplicate/empty/overlong names are
   rejected globally.
6. Open Tags, swipe back, edit a tag color, and delete a custom tag/group.
7. Swipe an entry to Trash, restore it, and verify permanent deletion.
8. Open an entry with attachments; date and Private remain tappable.
9. Confirm title generation does not block save and falls back cleanly when the
   local model rejects the language.
10. Change an entry from Inbox to another Box and verify the Box icon updates
    in the entry sheet, Today, and Journal.
11. Toggle between Calendar and Boxes from the title row. Verify every Box is a
    shelf, counts exclude trashed entries, and tapping a card opens the entry.
12. Swipe left-to-right on empty Calendar space to move to the previous day and
    right-to-left to move to the next day. Repeat on an entry row and verify the
    day does not change while the row's delete action still works.
13. Save a new quick entry and verify its timestamp is the current time rather
    than midnight. Existing historical `12:00 AM` entries are expected to stay
    unchanged.
14. Verify the Calendar/Boxes toggle is top-aligned with the title and the
    Journal/Me control is bottom-aligned with the floating `+` button.
15. Open Manage in Calendar, Boxes, and a focused Box. Verify each menu offers
    `Reorder & delete`, `Newest first`, and `Oldest first`; manual mode keeps
    content at full opacity and exposes the appropriate native or card delete
    affordance.
16. Reorder Box shelves, leave manual mode, enter it again, and verify the native
    handles stay next to the Box headings rather than returning to the trailing
    edge over the cards.
17. Open a focused Box, tap `+`, and verify the compact composer follows the
    keyboard with that Box selected rather than opening the legacy capture sheet.
18. Create a Goal with only a name, then add/edit its optional context by
    tapping the Goal title. Verify context renders as unlabeled paragraphs and
    expanding it does not move the Goal title upward.
19. Add, edit, reorder, complete/reopen, and delete a Checkpoint. Deleting it
    must leave linked Entries in the Goal and Journal.
20. Add Entries inside a Checkpoint, reorder them, reopen the Checkpoint, and
    verify the order persists without changing Entry dates.
21. Add a standalone Entry to a Goal roadmap, reorder it relative to
    Checkpoints, and verify both the manual order and original dates persist.
22. Verify Goal progress changes only from completed Checkpoints. Confirm Goal
    cards and roadmap rows do not show Entry-count clutter.
23. Tap Goal and Checkpoint titles and verify both use the shared inline editor,
    preserve long wrapping titles, and save/cancel without a generic top bar.

## Product roadmap

This roadmap captures the product decisions made from the ideas stored in the
`Fixes` and `Add to the app` Boxes. Each numbered item is its own project. Ship
and test it in small slices rather than combining the roadmap into one large
change. After every completed implementation slice, build, install, and launch
the refreshed app on the connected iPhone.

### 1. Reliability and long-form text

Status: completed September 13, 2026.

This is the immediate next project because it fixes trust and readability in
the existing product before adding new surfaces.

- [x] Fix capture-date drift: quick capture always uses the day and time that
  are current when it is submitted, and returns Calendar to today. Merely
  viewing a past day must not backdate a new quick entry.
- [x] In Calendar rows, show a deliberate preview made of complete lines with a
  clean ellipsis. Inline mention attachments must participate in line-height
  measurement so the preview is never vertically cropped.
- [x] In entry detail, give the body most of the available space and keep tags and
  metadata compact. The body must grow dynamically for longer text and the
  outer sheet should scroll when needed; do not clip after three lines or add a
  competing nested text scroll prematurely.

### 2. Complete Boxes as the durable organization view

Status: completed September 13, 2026.

- [x] Tapping a Box title opens a focused full-board view for that Box.
- [x] Box shelf order is manual and persists. Boxes can be reordered with drag and
  drop; creation date is not a useful default sort for Box shelves.
- [x] Entries can be reordered manually within a Box. Manual order persists.
- [x] `Newest` and `Oldest` are explicit sort actions for entries. Applying either
  action replaces the current manual entry order; the user can then make and
  persist further manual adjustments. Applying a sort again resets those
  adjustments to the selected chronological order.
- [x] Use one Manage convention in Calendar, Box shelves, and focused Box boards:
  `Reorder & delete`, `Newest first`, and `Oldest first`. Manual mode exposes
  deletion without dimming content, and focused-Box capture uses the shared
  keyboard-attached composer with the current Box preselected.

Manual ordering uses native iOS reordering behavior: Calendar and Box shelves
use `List.onMove`, while the focused two-column Box board uses interactive
collection-view movement so the cards keep their established proportions.

This requires stable persisted ordering fields and a tested SwiftData
migration. Do not derive manual order only from transient view indices.

### 3. Global search

Status: completed September 13, 2026.

Search is global rather than limited to the Journal list. It should open as a
focused full-screen search surface with the keyboard active and recent
Tags/Boxes visible before a query is entered.

- [x] Search entry titles and bodies, Tag names, Box names, and dates.
- [x] Group direct Tag and Box matches separately from matching entries. Selecting
  a Tag opens its entries; selecting a Box opens its board.
- [x] Support filters for Box, Tag, date or date range, attachments, privacy, and
  `Newest`/`Oldest` ordering.
- [x] Normalize case and diacritics, support partial matches, and tolerate modest
  spelling errors in both English and Hebrew input.
- [x] Start with fast deterministic local search. Natural-language and semantic
  retrieval belong to the later AI project and must not block this version.

### 4. Full entry editor

Status: completed September 14, 2026.

- [x] Keep quick capture minimal. Expanding the sheet is the full editor; there
  is no second full-screen surface or redundant expand button.
- [x] Preserve text, selection, mentions, and keyboard state while the sheet
  moves between detents.
- [x] Support long notes with natural dynamic growth and outer-sheet scrolling.
- [x] Replace the unstable custom TextKit formatting engine with the iOS 26
  native attributed `TextEditor` and system formatting controls.
- [x] Keep mentions, Box, date, privacy, and attachments part of the same entry.
- [x] Persist formatting separately from the canonical plain body in a versioned,
  migration-safe representation. Markdown and JSON exports preserve formatting,
  and older entries remain valid without conversion.

### 5. Per-entry reminders

Allow an entry to schedule a local notification using either a small set of
useful preset times or a custom date and time. This is separate from the Weekly
Interview feature. Reminder creation, editing, deletion, notification
permission, and behavior after an entry is trashed all need explicit handling.

### 6. Sensory design

Add this as a coherent pass after the core interactions above have stabilized,
not as unrelated feedback calls scattered through feature code.

- Use very subtle haptics for meaningful state changes such as committing a
  selection or completing a save.
- Reserve clearer feedback for destructive or irreversible actions.
- Use sound only for rare, high-value moments such as a successful entry save;
  never add sound to routine taps.
- Respect the device's Silent Mode and accessibility/system preferences.

The goal is quiet richness: users should feel polish without consciously
noticing repeated effects.

### 7. Weekly Interview

Treat Weekly Interview as a separate future feature, not as recurring entry
reminders. It may eventually support configurable questions, scheduling,
custom prompts, recurrence, and snooze. The existing weekly reminder/ritual
code is not automatically the desired product and must be reassessed before
reuse.

### 8. Goals rebuild

Goals is a large future feature and is deliberately out of the current scope.
Remove the legacy Goals product when this project begins and design it again
from first principles: define a goal, track its state or progress, and build a
timeline of entries and smaller events related to it. A Goal may eventually be
implemented on top of Box-like primitives, but that is an architectural option
rather than a settled user-facing model.

### 9. AI and Hebrew intelligence

AI is explicitly deferred and must not be treated as the next product step. It
is a separate project that can later cover Hebrew-aware metadata, post-capture
tag snapping, suggestions for new tags, and semantic search. Preserve the
current deterministic fallbacks and do not make capture, save, or retrieval
depend on model availability.

## Continuing debt

The generalized tag model currently coexists with legacy `Project` and
`EntryType` fields. Journal filters, tidy suggestions, reports, and legacy goals
still depend on those fields. Do not remove them until those consumers have
been migrated and historical data has a tested conversion path. The Goals
rebuild above should not accidentally legitimize or extend the old Goals model.

Some older screens still contain Hebrew copy despite the current LTR English
direction. Treat that as explicit localization/design debt, not a reason to
change layout direction.
