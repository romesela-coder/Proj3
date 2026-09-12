# Maslul handoff

Updated September 12, 2026.

## Current baseline

The project is an actively tested iPhone app, not an uncompiled prototype. The
generalized tags, inline mentions, Boxes board, compact entry sheet, attachment
fixes, Trash, and dictation work have all been built and exercised on a physical
iPhone with Xcode 26.4 / iOS 26.

The current product loop is:

1. Capture a note from the Today screen by typing or dictating.
2. Add existing tags inline with `@`, create a missing tag in place, or choose
   from locally ranked suggestions.
3. File it into one Box (Inbox by default); the Box icon identifies the entry
   in Today and Journal.
4. Edit the entry in a compact sheet and optionally change its box, date,
   privacy, title, tags, or attachments.
5. Retrieve entries by day in Calendar, by filing context in Boxes, or through
   Journal search; use the weekly ritual, allocation, goals, reports, and export
   for reflection.

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
  -destination 'id=00008150-001125800205401C' \
  -allowProvisioningUpdates \
  build -quiet

xcrun devicectl device install app \
  --device 2911A2B1-6D4F-5301-B2C9-AB36DA5AAEC6 \
  /Users/rom/Library/Developer/Xcode/DerivedData/Maslul-cadwpieqdxlvwvbaoxvdzdlgpgih/Build/Products/Debug-iphoneos/Maslul.app

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
- `Design/InlineMentionEditor.swift` bridges `UITextView` so mentions can be
  real inline attachments while storage remains plain text.
- `Design/TagMentions.swift` owns `@` query parsing, selection, inline tag
  creation, and mention visuals.
- `Features/Home/HomeView.swift` owns the Calendar/Boxes mode switch, ranked tag
  suggestions, compact composer, day swipes, save coordination, and dictation
  entry point.
- `Features/Home/BoxesBoardView.swift` owns the Box shelves and compact entry
  cards used by the Boxes view.
- `Services/SpeechDictationController.swift` owns both iOS 26
  `SpeechAnalyzer` dictation and the legacy recognizer fallback.
- `Services/LocalMetadataGenerator.swift` owns title/icon generation and
  deterministic fallbacks.
- `Features/Tags/TagsView.swift` owns tag-group navigation, editing, colors,
  uniqueness guardrails, and deletion.

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
  application networking layer.
- Foundation Models and Speech failures must leave a usable deterministic or
  system fallback.

## Regression checklist

1. Start quick capture; the editor focuses and follows the keyboard smoothly.
2. Dictate with Hebrew and English keyboards, pause, resume, stop, and send.
   Previously finalized text must not disappear.
3. Type `@`, choose a tag, and verify both the editor and saved entry render a
   framed token with the group emoji and no visible `@`.
4. Backspace once over a mention: remove the token relationship but keep the
   tag name as editable text.
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

## Known debt and next product step

The next planned intelligence step is post-capture tag resolution: inspect
typed or dictated text, snap confident matches to existing tags, and propose
new tags without silently creating them.

The first Boxes board is implemented as vertically stacked Box shelves with
horizontally scrolling entry cards. Dates remain useful metadata and keep the
Calendar view, while Box is the durable organizing axis. Board search,
reordering, drag-and-drop filing, and richer Box actions remain open product
work; do not add them without confirming the intended interaction.

The generalized tag model currently coexists with legacy `Project` and
`EntryType` fields. Journal filters, tidy suggestions, reports, and goals still
depend on those legacy fields. Do not remove them until those consumers have
been migrated and historical data has a tested conversion path.

Some older screens still contain Hebrew copy despite the current LTR English
direction. Treat that as explicit localization/design debt, not a reason to
change layout direction.
