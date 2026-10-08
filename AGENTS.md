# Hadeed

Read docs/GYM_APP_SPEC.md, docs/STEP_04.md and docs/STEP_05.md before changes.
Steps 1–4 implement the offline Android application, sessions, timers, history and backup.
Work incrementally; every new screen must use local SQLite for its saved data.

- Flutter/Dart, Android only, Arabic RTL and bundled Cairo.
- No server, authentication, runtime asset URLs or fabricated workout history.
- Seed only assets/templates/user_program_v1.json, received from the user on 2026-10-01.
- Latest user list overrides conflicting example names/counts in the spec or Figma.
- Install the template once in a transaction; reopening must preserve user edits.
- Exercise definitions and per-day plans are separate. Use stable IDs.
- Archive definitions; preserve session snapshots in future features.
- SQLite is authoritative. UI → controllers → repositories. Schema version 3 preserves earlier data.
- Resolve images relative to the app documents directory and copy picker files.
- Include migrations for every future schema version; never silently reset a database.
- Do not claim builds, rendered UI parity or device checks without successful results.
- Run source analysis and tools/check_repository.dart and tools/check_training.dart, tools/check_workout.dart and flutter test; build Android in GitHub Actions.

- Session snapshots are independent of mutable plans and definitions; do not delete referenced images.
- One event per local date and one active session. Only confirmed completion advances the cycle, once.
- Store weights in kg; lb is an input/display conversion. Blank weight is null, never implicit zero.
- Validate backups in an isolated database before confirmation. Stage images before transactional replacement.
- Native alarm payload is a mirror; SQLite deadlines and status remain authoritative.

- Latest visual direction: dark green/lime across all pages per STEP_07, based on session Figma 30:711; keep forms width-bounded and session completion pinned outside scrolling.
- Regression tests must open later exercise cards, not just the initially expanded first card.
