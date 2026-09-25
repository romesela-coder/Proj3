# Goals and journal: checkpoint experiment

## Product model

- An **Entry** is a dated journal record. The global + always starts an Entry. It may have no Goal, a Goal, or a Goal plus a Checkpoint. It remains one record in the daily journal and can also appear in the Goal timeline and a Checkpoint shelf.
- A **Goal** is the home for a specific intention. Its screen has one user-ordered roadmap, with Entries shown as cards inside their Checkpoint or in an "Along the way" shelf when they have no Checkpoint.
- A **Checkpoint** is a manually created plan step. It can be a small task with zero Entries or a larger milestone with many. Its order is manual; an optional target date is metadata and never changes silently when the step is moved. Completion is explicit.
- **Boxes** remain intact during this experiment. They are not automatically equivalent to Checkpoints: names such as Inbox and Done describe workflow states, while some other Boxes may describe work areas rather than finishable milestones.

## Implemented in this slice

- Create, edit, delete, complete/reopen, and reorder Checkpoints inside a Goal. Deleting a Checkpoint leaves its Entries in the Goal and journal.
- Create an Entry from a Checkpoint with its Goal and Checkpoint links preselected, or add/change its Checkpoint later in Entry details. A Goal Entry does not require a Checkpoint.
- Show linked Entries as the same small horizontal cards used on the Boxes board, with a vertical roadmap rail. The redundant second timeline was removed; the daily journal remains the chronological view.
- Optional **Use an existing Box** bridge: the user previews a Box, then creates a new Checkpoint with its name. Only Entries with no Goal or already in this Goal and no Checkpoint are linked. The Box, its membership, other Goals, and Entry content are preserved. Nothing is imported automatically.
- The old Boxes screen and composer classification remain accessible while this layout is evaluated.

The code state before this experiment is saved in commit `38b8e5f`. A copy of the on-device store and attachments was taken before adding the Checkpoint schema. A Git rollback does not itself roll back on-device data.

## Next product decisions

- Whether the two main destinations should be named Goals and Journal, and how the legacy Boxes view should remain accessible without overloading Entry capture.
- Whether a finished Checkpoint should also appear as a dated event in the daily journal. Currently it shows as completed in the roadmap only.
- Whether Goal creation should offer a batch planning flow for several Checkpoints.
- Whether a Box should be convertible into a Goal-level area or tag when it does not represent a finishable Checkpoint.

## Later: external model

The first model job should be narrow: rank 4–6 question IDs from the curated bank for one Goal. Inputs should be limited to the Goal's user-written context and a bounded, user-approved set of recent Entries. Keep a local fallback. Before connecting an API, decide on provider, backend/key custody, data-retention policy, opt-in scope, cost limits, failure behavior, and replacement copy for the current “nothing leaves the device” privacy promise. Never embed a shared API secret in the iOS app.
