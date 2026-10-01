# Hadeed

Read docs/GYM_APP_SPEC.md and docs/STEP_03.md before changes.
Steps 1–3 implement the Android foundation, exercise library, training days and per-day plans.
Work incrementally; every new screen must use local SQLite for its saved data.

- Flutter/Dart, Android only, Arabic RTL and bundled Cairo.
- No server, authentication, runtime asset URLs or fabricated workout history.
- Seed only assets/templates/user_program_v1.json, received from the user on 2026-10-01.
- Latest user list overrides conflicting example names/counts in the spec or Figma.
- Install the template once in a transaction; reopening must preserve user edits.
- Exercise definitions and per-day plans are separate. Use stable IDs.
- Archive definitions; preserve session snapshots in future features.
- SQLite is authoritative. UI → controllers → repositories. Schema version 2 preserves version 1 data.
- Resolve images relative to the app documents directory and copy picker files.
- Include migrations for every future schema version; never silently reset a database.
- Do not claim builds, rendered UI parity or device checks without successful results.
- Run source analysis and tools/check_repository.dart and tools/check_training.dart; build Android when available.
