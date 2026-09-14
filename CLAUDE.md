# Maslul project context

Maslul is a private, single-user career and memory journal for iPhone. It is a
local-first SwiftUI/SwiftData app with fast capture, reusable tags, inline
mentions, dictation, weekly reflection, reports, goals, and export.

Read `README.md` for the product and build overview, and `HANDOFF.md` for the
current implementation state and regression checklist. Follow the repository's
applicable `AGENTS.md` instructions for GitHub account separation and workflow.

## Product constraints

Do not relax these without asking the user:

1. No account, server, analytics, CloudKit model container, third-party SDK, or
   application networking code.
2. Journal data and attachments stay in the app container. Export is an
   explicit user action through the system share sheet.
3. AI must be on device and optional. Every AI-assisted path needs a useful
   deterministic or heuristic fallback.
4. Entries use recoverable deletion: Trash for 48 hours, then purge. Directly
   deleting a tag or group must never delete an entry.
5. No streaks, guilt states, or daily nagging. The product has one weekly
   reminder flow.
6. Future widgets must never expose entry text—only counters, tag/project names,
   and non-sensitive labels.
7. The application root is LTR and uses an English locale. Hebrew input is
   supported, but must not flip the application chrome or placeholder layout.

## Build

- Xcode 26.x required; iOS 26.0 deployment target.
- One iPhone-only, portrait-only target and scheme: `Maslul`.
- SwiftUI + SwiftData, no package dependencies.
- File-system synchronized Xcode group: adding a Swift file under `Maslul/` is
  enough.
- Physical-device builds require microphone and speech-recognition usage
  descriptions, which are already configured in the project.

```bash
xcodebuild \
  -project Maslul.xcodeproj \
  -scheme Maslul \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## Data model

`Entry` is the central record. Its only required user input is body text. It
also stores an editable title, timestamps, optional legacy type/project/effort,
privacy, attachments, an optional goal, Trash state, and a many-to-many tag
relationship. Every entry also belongs to one `EntryBox`; Inbox is assigned to
new and migrated entries by default.

`EntryBox` is the durable filing axis used by the Boxes board. Its icon belongs
to the Box, not to each entry. Calendar and Journal show that Box icon as the
entry's leading visual identity. `EntryBoxBootstrap` creates Inbox and assigns
it to migrated entries that do not yet have a Box.

`TagGroup` is a user-defined namespace such as Projects, People, or Entry type.
`EntryTag` is the selectable item inside a group. Important rules:

- names are trimmed and limited to 50 characters;
- names are globally unique using case- and diacritic-insensitive comparison;
- groups may be single- or multiple-selection;
- tags may have an optional color;
- deleting a group cascades to its tags, while tag-to-entry relationships use
  nullification so entries survive.

`TagBootstrap` creates system groups from the legacy `EntryType` cases and
`Project` records. This is a staged migration. Do not remove `Entry.type`,
`Entry.project`, or `Project` until Journal, tidy, reports, goals, sample data,
and export have all moved to tags and a historical-data migration is tested.

SwiftData views generally fetch a small sorted set with `@Query` and filter in
memory. Keep relationship mutation on the main actor and normally set one side
of a relationship, allowing SwiftData's inverse to maintain the other.

## Mentions

`InlineMentionEditor` is the focused `UITextView` bridge used by compact plain
capture and inline previews. The full entry editor uses SwiftUI's iOS 26
`TextEditor` with an `AttributedString`, so selection, keyboard integration and
rich-text formatting stay system-owned. The persisted body remains readable
plain text: `@Tag name`.

The contract is:

- `Entry.tags` is the source of mention identity;
- the body is the portable/exportable text representation;
- mention matching requires a valid boundary and prefers longer tag names;
- the first deletion converts a token to ordinary name text and removes its tag
  relationship; a subsequent deletion edits text normally;
- `@` opens local search and may create a missing tag inside a selected group;
- duplicate prevention is global, not per group.

Keep the editor, tag relationship, export format, and rename behavior aligned
when modifying mentions.

## Dictation

`SpeechDictationController` selects a locale from the active keyboard.

- iOS 26 uses `SpeechAnalyzer` + `DictationTranscriber` with
  `.progressiveLongDictation`, installed Speech assets, continuous final and
  volatile transcripts, and audio-format conversion when needed.
- The older `SFSpeechRecognizer` implementation is retained as isolated legacy
  code, but the iOS 26 deployment target uses `SpeechAnalyzer` in production.

Finalized transcript text must only grow. Volatile text may be revised by the
recognizer, but it must not replace prior finalized phrases. Saving while
recording must await `stopAndWait()` before reading the final body or starting
title generation.

## Local intelligence

There are two related but separate paths:

- `Suggesting` classifies entries for the tidy flow. It uses
  `FoundationModelsSuggester` when Apple's on-device model is available and
  `HeuristicSuggester` otherwise.
- `LocalMetadataGenerator` creates titles and group icons opportunistically,
  then falls back to deterministic extraction/mapping.

Never make save, navigation, tagging, or retrieval wait on model availability.
Foundation Models language support is OS-controlled; Hebrew title generation
can legitimately fall back even on an otherwise eligible device.

AI tag snapping is not implemented yet. Current tag suggestions are local,
deterministic rankings based on text match, usage count, and recency.

## UI and interaction conventions

- Root layout direction is LTR, regardless of keyboard language.
- New-item flows should use the compact keyboard-height composer rather than a
  mostly empty full-screen form.
- The compact composer is also the creation surface inside a focused Box; seed
  it with the current Box instead of routing to the legacy capture sheet.
- Calendar and Boxes are sibling modes in `HomeView`, selected by the large
  toggle top-aligned with the title. Calendar is date-oriented; Boxes groups
  the same entries into Box shelves.
- Horizontal day navigation starts only on empty Calendar space. Never attach
  a day-changing gesture to an entry row because rows use native trailing
  swipe actions for deletion.
- Quick capture must preserve the selected calendar day while applying the
  current clock time. Do not construct new quick entries from a start-of-day
  value directly.
- Entry detail is a draggable partial sheet that can expand to full height.
- Use the shared tokens in `Design/Theme.swift`; do not hardcode colors or
  motion curves.
- Tags without a chosen color use one consistent default mention tint. Custom
  colors must look the same in suggestion cards and inline mentions.
- Box icons and tag-group emoji have separate jobs: one editable SF Symbol
  represents the entry's Box, while each tag card inherits the single emoji of
  its group.
- Lists use native trailing swipe actions for destructive actions. A revealed
  destructive action is the confirmation unless the operation is materially
  broader than the row.
- Calendar, Box shelves, and focused Box boards share one `Manage` menu with
  `Reorder & delete`, `Newest first`, and `Oldest first`. Manual mode uses the
  platform-appropriate delete affordance and must not dim row or card content.
- Prefer native interactive dismissal and synchronized keyboard movement.
- The desired application language is English. Some legacy Hebrew strings
  remain and should be converted deliberately without changing the direction.

## Privacy and deletion details

- `PhotosPicker` imports images, re-encodes them, and stores them locally.
- Dictation uses Apple's system Speech frameworks and explicit microphone and
  speech permissions; the app has no speech server of its own.
- Sensitive entries are excluded from export and summaries by default.
- Entry swipe deletion sets `trashedAt`; `RootView` purges entries older than
  48 hours. Trash can restore or permanently delete them earlier.
- Sample-data clearing is a test-only destructive affordance.

## Project layout

```text
Maslul/
  Navigation/  root tabs, routes, sheets, floating dock
  Design/      theme, components, mention editor and visuals
  Model/       entry, tags, projects, goals, allocations
  Data/        settings, attachments, sample data, allocation math
  Services/    dictation, local intelligence, export, reminders
  Features/    Home (Calendar, Boxes board, quick capture), Capture, Tags,
               Journal, Ritual, Reports, Goals, Projects, Me, Onboarding
```

## Git

Do not hardcode a long-lived working branch or historical co-author footer in
this file. Inspect the current branch and follow the active `AGENTS.md` GitHub
authentication rules before repository or GitHub work.
