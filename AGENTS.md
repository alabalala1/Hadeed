# Hadeed

Read docs/GYM_APP_SPEC.md and docs/STEP_02.md before changes.
Steps 1 and 2 implement the Android foundation, exercise library and editor.
Work incrementally; every new screen must use local SQLite for its saved data.

- Flutter/Dart, Android only, Arabic RTL and bundled Cairo.
- No server, authentication, runtime asset URLs or fabricated workout history.
- User will send the exercise list; do not seed names from Figma examples.
- Exercise definitions and per-day plans are separate. Use stable IDs.
- Archive definitions; preserve session snapshots in future features.
- SQLite is authoritative. UI → ExerciseController → ExerciseRepository.
- Resolve images relative to the app documents directory and copy picker files.
- Include migrations for every future schema version; never silently reset a database.
- Do not claim builds, rendered UI parity or device checks without successful results.
- Run source analysis and tools/check_repository.dart; build Android when available.
