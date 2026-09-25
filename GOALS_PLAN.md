# Goals and journal: checkpoint experiment

## Product model

- An **Entry** is a dated journal record. The global + always starts an Entry. It may have no Goal, a Goal, or a Goal plus a Checkpoint. It remains one record in the daily journal and can also appear in the Goal timeline and a Checkpoint shelf.
- A **Goal** is the home for a specific intention. Its roadmap is primarily made of Checkpoints, with occasional individual Entries that are not linked to one. Each Checkpoint opens its own chronological Entry timeline; an unlinked Entry opens directly.
- A **Checkpoint** is a manually created plan step. It can be a small task with zero Entries or a larger milestone with many. The Goal roadmap can be reordered across both Checkpoints and standalone Entries; their target/creation dates are metadata and never change when an item is moved. Completion is explicit.
- **Boxes** remain intact during this experiment. They are not automatically equivalent to Checkpoints: names such as Inbox and Done describe workflow states, while some other Boxes may describe work areas rather than finishable milestones.

## Implemented in this slice

- Create, edit, delete, complete/reopen, and reorder Checkpoints inside a Goal. The focused Checkpoint screen exposes Edit and Delete directly under Manage; deletion asks for confirmation and leaves its Entries in the Goal and journal.
- Create an Entry from a Checkpoint with its Goal and Checkpoint links preselected, or add/change its Checkpoint later in Entry details. A Goal Entry does not require a Checkpoint.
- Show compact Checkpoint previews and standalone Goal Entries on the same vertical roadmap. Initially, an Entry's creation day places it before the first Checkpoint whose target day is the same or later; Entries on a target day come before that Checkpoint. Entries with no later dated Checkpoint appear after the planned steps. The roadmap menu enables dragging any visible Checkpoint or standalone Entry across the others. That manual order persists without editing `createdAt` or `dueAt`; new items join near their date-based neighbors while manually positioned items keep their order. Changing an Entry's Goal clears its old Goal-specific position. Tapping a Checkpoint opens a chronological, one-column timeline of its linked Entries; tapping an Entry opens its normal detail sheet. The Checkpoint view owns its contextual + action, while the + on the Goal itself writes an unassigned Goal Entry. The daily journal remains the global chronological view.
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
