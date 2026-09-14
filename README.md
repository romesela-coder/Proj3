# מסלול · Maslul

Maslul is a private, iPhone-first journal for capturing work, decisions,
learning, friction, people, projects, and recurring themes. The current build
is organized around a fast keyboard-first capture flow, reusable tags, inline
mentions, and on-device assistance.

The app has no account, server, analytics, CloudKit container, third-party SDK,
or application networking code. Journal data and attachments are stored in the
app container. Export only happens when the user explicitly opens the system
share sheet.

## Run the app

Open `Maslul.xcodeproj`, select the `Maslul` scheme, and run on an iPhone or
simulator.

```bash
xcodebuild \
  -project Maslul.xcodeproj \
  -scheme Maslul \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

- Xcode 26.x is required.
- Deployment target: iOS 26.0. The full editor uses SwiftUI's native
  `AttributedString` editing and system formatting controls.
- iPhone only, portrait only, light appearance.
- No Swift Package Manager, CocoaPods, or other external dependencies.
- Simulator builds do not need signing. A physical device needs a valid local
  development team and provisioning profile.
- The project uses a file-system synchronized `Maslul/` group, so new Swift
  files do not need to be added to the target manually.

Microphone and speech-recognition permissions are requested only when the user
starts dictation.

## What is implemented

### Capture and entry editing

- A Calendar home view with a seven-day strip and per-day entries.
- A parallel Boxes board that groups entries by their durable Box assignment
  and presents each Box as a shelf of entry cards.
- A large Calendar/Boxes toggle in the title row.
- A compact composer attached to the keyboard instead of a blank creation
  screen.
- An adaptive multiline editor that grows to three lines and then scrolls.
- Dictation from the same composer, using the active keyboard language.
- Locally generated entry titles with a deterministic fallback.
- A reading-first entry sheet with editable title and text, date, privacy,
  tags, and local photo attachments.
- A single Box assignment for every entry. The Box icon is the entry's leading
  visual identity in Calendar and Journal.
- New entries preserve the selected day while storing the real capture time;
  they are no longer created at midnight.
- Interactive keyboard dismissal and native-feeling sheet/navigation gestures.
- Horizontal swipes on empty Calendar space move between days. Entry rows keep
  their own native swipe-to-delete interaction.

### Tags and mentions

- Reusable `TagGroup` and `EntryTag` models for projects, people, entry types,
  or any other user-defined category.
- Default groups bootstrapped from the existing entry types and projects.
- Minimal group/tag creation from a keyboard-height composer.
- Globally unique, case- and diacritic-insensitive tag names, with a maximum of
  50 characters.
- Optional per-tag colors. Neutral tags share one soft lemon default tint.
- Tag cards inherit one emoji from their group; the separate Box icon remains
  the entry-level identity.
- Type `@` while writing to find an existing tag or create a new one inside a
  group.
- Mentions render inline as colored tokens while their plain-text form remains
  `@Tag name` in storage.
- The first backspace detaches an inline mention but keeps its text; the next
  backspace edits the characters normally.
- The quick composer suggests up to five tags using text match, frequency, and
  recency.

### Retrieval and reflection

- Journal search, date range, entry-type, and project filters.
- A Box-based board alongside the date-based Calendar view.
- Global local search across entry titles and bodies, tags, Boxes, and dates,
  with Box, tag, date, attachment, privacy, and chronological filters.
- A consistent Manage menu in Calendar, Box shelves, and focused Box boards for
  persisted manual ordering, chronological ordering, and recoverable deletion.
- Weekly tidy and time-allocation flows.
- Time-allocation reports and goals-versus-reality views.
- Markdown and JSON export, with sensitive entries excluded by default.
- Weekly local reminders and sample data for testing.

### Deletion

- Entries use recoverable deletion: a swipe moves them to Trash for 48 hours.
- Manual Manage mode exposes native row deletion in Calendar and card deletion
  in Boxes without dimming entry content.
- Trash supports restore and permanent deletion; expired entries are purged on
  launch.
- Tags, custom tag groups, projects, and attachments have direct delete
  actions. Deleting a tag removes the relationship from entries, not the entry.

## Speech and local intelligence

Dictation has two runtime paths:

- On iOS 26, `SpeechAnalyzer` and `DictationTranscriber` use progressive
  long-form dictation and finalize the last phrase before an entry is saved.
- The older `SFSpeechRecognizer` implementation remains isolated in the
  service, but the shipping target now runs the iOS 26 `SpeechAnalyzer` path.

The locale follows the current keyboard (`he-IL`, `en-US`, or the reported
keyboard language). The app requests Speech assets through the system when a
supported language is not already installed.

The AI layer is optional and failure-safe:

- `FoundationModelsSuggester` uses Apple's on-device model for tidy
  classification when the device and OS support it.
- `HeuristicSuggester` keeps the same workflow usable everywhere else.
- `LocalMetadataGenerator` attempts on-device titles and group icons, then
  falls back to deterministic extraction/mapping.

Foundation Models language support is controlled by the OS. In particular,
long Hebrew entries may use the deterministic title fallback even when Apple
Intelligence is otherwise available.

## Data model and migration state

The SwiftData container currently includes:

- `Entry`, `EntryBox`, `TagGroup`, `EntryTag`
- `Project`, `Goal`
- `WeeklyAllocation`, `AllocationSlice`

`TagGroup`/`EntryTag` are the new general classification model. The older
`Project` relationship and `EntryType` raw field deliberately remain during a
staged migration because reports, tidy suggestions, goals, and historical data
still use them. `TagBootstrap` mirrors valid legacy projects and entry types
into system tag groups without creating duplicate tags.

Before clearing a development install after a schema problem, export any data
you want to keep. There is no automatic backup.

## Project layout

```text
Maslul/
  MaslulApp.swift          SwiftData container and application environment
  Navigation/              Router, root stacks, sheets, floating dock
  Design/                  Theme, shared components, inline mention editor
  Model/                   Entries, tags, projects, goals, allocations
  Data/                    Settings, attachments, sample data, allocation math
  Services/                Dictation, local AI, export, reminders
  Features/
    Home/                  Calendar, Boxes board, and quick capture
    Capture/               Full capture and entry detail
    Tags/                  Tag groups, tags, colors, deletion
    Journal/               Search and filters
    Ritual/                Weekly tidy and allocation
    Reports/               Time-allocation reporting
    Goals/                 Quarterly goals and close flow
    Projects/              Legacy project management
    Me/                    Settings, privacy, export, trash
    Onboarding/            First-run flow
```

## Known gaps

- AI-assisted tag snapping after typing or dictation is not implemented yet;
  the current mention flow is explicit and the suggestion row is ranked
  locally.
- Tags and legacy project/type fields are not yet one unified reporting model.
- Box creation and icon selection are available from filing flows, but broader
  Box lifecycle management such as renaming or deleting a Box is not implemented.
- Semantic search, monthly summaries, résumé-line drafting, widgets/App
  Intents, Face ID lock, and encrypted backup are not implemented.
- The app shell and new capture/tag surfaces are LTR English. Some older
  settings, reports, ritual, and onboarding copy is still Hebrew and should be
  migrated separately.
