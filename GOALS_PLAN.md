# Goals: first iteration and next decisions

## Core loop

1. Create a goal. Only the name is required; motivation, desired change, and current challenge are optional context.
2. Open the goal to see its entries as a timeline.
3. Write directly, choose a prompt, or start a “Nothing moved” check-in. All three save the same ordinary Entry linked to that goal. Silence is never interpreted as no progress.
4. A spontaneous entry can also be linked to an existing goal from the composer. Its box remains its location; its goal is an additional relationship. Tags remain available through @mention without an always-visible preview.

The Goals overview shows each goal's latest entry, including an honest no-progress check-in. Questions are visible only inside a specific goal and automatically inherit its link.

## Included in iteration 1

- Goal-first overview and creation flow.
- Optional goal context fields.
- Goal detail with 4 curated prompts, direct writing, explicit no-progress check-in, and clickable Entry timeline.
- Goal selection while capturing or editing an Entry.

Questions are currently selected from the hard-coded bank. No Entry is generated automatically, and no journal content is sent to a server in this iteration.

## Next slice: external model

The first model job should be narrow: rank 4–6 question IDs from the curated bank for one goal. Inputs should be limited to the goal's user-written context and a bounded, user-approved set of recent entries. The response should contain IDs and optional short rationale, not generated journal entries. Keep a local fallback if offline, unavailable, or declined.

Before connecting an API, decide on provider, backend/key custody, data-retention policy, opt-in scope, cost limits, failure behavior, and replacement copy for the app's current “nothing leaves the device” privacy promise. Never embed a shared API secret in the iOS app.

## Later slices

- Goal-specific recurring check-ins: a separate schedule opens the goal's composer or chosen prompt; it never silently creates an Entry.
- Agent/chat: start read-only, then propose typed actions such as draft an Entry, link an Entry, or configure a check-in. Show a preview and require explicit confirmation before each write. Preserve a clear record of what was proposed and what the user approved.

Open product questions: whether prompts should be fully visible or collapsed below the timeline; how users edit goal context after creation; and whether older quarterly Goals should appear alongside ongoing Goals or be presented as a separate legacy concept.
