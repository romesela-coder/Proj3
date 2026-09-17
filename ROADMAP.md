# Maslul product roadmap

Updated September 18, 2026.

This is the canonical forward-looking product plan. `HANDOFF.md` records the
implemented state and regression details; this file records what is next and
why. When a future session starts with "let's begin", start at the first
unfinished item under **Immediate next project** rather than reopening the
roadmap discussion.

## Product thesis

Maslul is a private, local-first career journal. Its differentiating loop is:

1. Capture what happened with as little friction as possible.
2. Organize and retrieve entries through Boxes, Tags, search, and reminders.
3. Connect meaningful entries to living Goals.
4. Turn the accumulated week into a guided Weekly Review.
5. Carry decisions and next actions into the following week.

Goals and Weekly Review are product pillars, not legacy side features. They are
what should make Maslul more focused on career, values, and reflection than a
generic note-taking app.

## Implemented baseline

- Keyboard-first typed and dictated capture.
- Rich entry editing, inline mentions, attachments, privacy, and dates.
- Generalized Tags and one durable Box assignment per entry.
- Calendar, Boxes board, global local search, Journal, Trash, and export.
- Per-entry Notification and Alarm reminders, editing, removal, deep links,
  and archived reminder history.
- On-device Foundation Models assistance where available, with deterministic
  fallbacks. This is the current implementation, not the desired final model
  strategy.

## Settled product and technical decisions

### Local intelligence

- Do not make Apple Intelligence availability a product requirement.
- Move all small generative tasks to one app-owned, on-device model that works
  in English and Hebrew on every supported device.
- Start with the simplest packaged path: `mlx-swift-lm` and the ready-made
  `mlx-community/Qwen3-0.6B-4bit` model (roughly 351 MB).
- Do not fine-tune initially. Use short task-specific prompts, low-variance
  generation, constrained/structured outputs, validation, and deterministic
  fallbacks.
- Initial tasks are deliberately narrow: title generation, emoji choice,
  short rewriting, simple summarization, and choosing among supplied options.
- Benchmark real Hebrew and English examples on a physical iPhone before
  replacing the current Foundation Models path. If quality is inadequate,
  evaluate another ready-made model rather than beginning a training project.
- The model must never block saving, navigation, retrieval, or access to the
  user's original text.
- For TestFlight/App Store distribution, prefer an Apple-hosted Background
  Asset pack so the model can be downloaded and updated separately from the
  main app binary.

Useful references:

- https://github.com/ml-explore/mlx-swift-lm
- https://huggingface.co/mlx-community/Qwen3-0.6B-4bit
- https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs

### Goals rebuild

- Retire the existing quarterly Goals product and design the replacement from
  first principles in a dedicated product session.
- A Goal may reuse Box/Tag primitives, but it must not be only another category
  or Box. It should become a living career object with related entries, a
  timeline, movement, friction, decisions, and a next action.
- Do not extend or legitimize the legacy Goal UI while the rebuild is pending.
- Exact behavior, information architecture, data model, and migration require
  the dedicated Goals session before implementation.

### Weekly Review rebuild

- Weekly Review is one of the core retention and differentiation mechanisms.
- Retire and reassess the legacy ritual/allocation flow rather than treating it
  as the desired product.
- Design it in a dedicated session after the Goals direction is settled.
- The review should prepare evidence from real entries and Goals, help the user
  identify progress, friction, neglected goals, recurring themes, and next
  actions, and save an editable result back into the journal.
- Deterministic code should select and calculate facts. The local model should
  organize and phrase those facts, not invent progress.
- The design must include a useful sparse-week state and must not use streaks,
  guilt, or daily nagging.

### Empty journal guidance

- Empty states are an activation surface, not decorative placeholders.
- The empty Journal/Calendar should offer a small rotating set of useful prompt
  CTAs, such as a decision, learning, win, blocker, follow-up, or something the
  user does not want to forget.
- Tapping a prompt should open or focus the normal composer with light guidance;
  it must not create content automatically or force a rigid questionnaire.
- Later personalization may use Goals and local history, but MVP prompts should
  be hand-authored and fully local.

### Analytics

- Analytics is intentionally added after the Goals and Weekly Review flows are
  coherent, but before the external alpha. Do not wait until after alpha.
- Use an internal analytics abstraction so the product is not coupled to one
  vendor.
- Current provider recommendation: Mixpanel for explicit event analytics.
- Disable session replay and autocapture. Do not add FullStory for the alpha.
- Never transmit entry titles or bodies, prompts, search queries, attachment
  data, or the names of Boxes, Tags, Goals, or people.
- Use an anonymous installation identifier and provide a visible opt-out in
  Settings. Keep development/test and production data separable.
- Initial dashboards should cover activation, capture, retrieval, Goal usage,
  Weekly Review completion, reminders, retention, and failures—not vanity tap
  counts.

### Distribution and alpha

- The user will enroll in the Apple Developer Program as an individual indie
  developer. No organization or D-U-N-S workflow is planned.
- Enrollment should begin in parallel with product work because identity
  verification, App Store Connect setup, build processing, and the first
  external TestFlight beta review are externally timed.
- Individual enrollment means the user's legal personal name will be the
  seller name on the App Store.
- The external alpha is a trusted WhatsApp group of roughly 10–20 people for
  one to two weeks, distributed through TestFlight.
- Collect explicit qualitative feedback alongside event analytics and
  TestFlight crash/screenshot feedback.
- Follow the alpha with a focused one-to-two-week feedback sprint. Prioritize
  crashes/data loss, repeated blockers, and evidence about the core loop; do
  not implement every isolated feature request.

## Immediate next project

### 1. Local model integration spike

This is the exact starting point for the next implementation session.

1. Add `mlx-swift-lm` through Swift Package Manager.
2. Load `mlx-community/Qwen3-0.6B-4bit` in an isolated local-intelligence
   service without changing user-facing behavior yet.
3. Implement prompt contracts for title generation, one emoji, short rewrite,
   and simple summary/choice tasks.
4. Assemble a small fixed evaluation set of real-shaped English and Hebrew
   inputs. Do not include private production journal content in the repository.
5. Run the model on the connected iPhone and record model load time, generation
   latency, memory stability, output validity, and subjective quality.
6. Compare results with the current Foundation Models/deterministic paths.
7. If the model is good enough, make it the single preferred implementation
   behind the existing local-intelligence interfaces; preserve deterministic
   fallbacks. If not, evaluate one other packaged model before reconsidering
   scope. Do not fine-tune during this project.
8. Build, install, and launch every completed slice on the connected iPhone.

Definition of done: one packaged bilingual model reliably performs the narrow
tasks on device, no workflow depends on Apple Intelligence, failure leaves the
app usable, and performance is acceptable on a real supported iPhone.

## Roadmap after the model spike

### 2. Goals product session and rebuild

- Dedicated product session first.
- Explicitly define the Goal object, entry relationship, lifecycle, timeline,
  progress/movement language, and connection to Boxes/Tags.
- Then remove or hide the old product and implement the new model in tested
  slices with a migration plan.

### 3. Weekly Review product session and rebuild

- Dedicated end-to-end flow design after Goals.
- Implement evidence gathering, guided questions, editable generated draft,
  next actions, scheduling, and review history.

### 4. Empty states and activation

- Empty Journal/Calendar prompt CTAs.
- First Box, Goal, reminder, search, model-download, permission-denied, and
  sparse-week states.
- Update onboarding to teach the capture-to-review loop rather than enumerate
  features.

### 5. Alpha readiness

- Complete basic Box lifecycle management such as rename and safe deletion.
- Add the analytics abstraction, Mixpanel integration, privacy disclosure,
  Settings opt-out, event validation, and initial dashboards.
- Add or strengthen tests around SwiftData migrations, capture, reminders,
  Goals, Weekly Review, export, and model failure.
- Run the full physical-device regression checklist.
- Remove or hide stale legacy product surfaces and update the in-app roadmap.
- Complete Apple Developer enrollment, App Store Connect setup, privacy policy,
  support URL, build metadata, TestFlight upload, and external beta review.

### 6. External alpha

- Distribute to the trusted 10–20-person WhatsApp group for one to two weeks.
- Give testers a concise mission and feedback format without coaching them
  through ordinary use.
- Review product events, crashes, TestFlight feedback, WhatsApp feedback, and
  end-of-period interviews together.

### 7. Feedback sprint

- One to two weeks of prioritized fixes and focused iteration.
- Re-test the core activation and weekly loop with a refreshed TestFlight build.

### 8. App Store launch

- Final privacy disclosures, screenshots, description, support materials,
  review notes, and App Review submission.
- Marketing, social content, and launch work begin from the validated product
  story and alpha evidence, not before it.

## Explicitly deferred unless alpha evidence changes the order

- Accounts, a custom application backend, and cross-device sync.
- Fine-tuning or training a language model.
- Session replay.
- A/B experimentation and feature-flag infrastructure.
- Semantic search, monthly summaries, widgets/App Intents, résumé drafting,
  public social features, and a full Goals metrics dashboard.
- Encrypted automatic backup and Face ID lock remain important public-release
  considerations, but they do not precede the current model/Goals/Review work.
