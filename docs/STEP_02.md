# Step 2 — Exercise library and editor

Source: Figma file 2KedKAx8jYTcAjkMMzpKRl, nodes 2:1037, 2:1092, 2:1210.

Implemented: Arabic RTL library (empty/data/search states), grouping by category,
add/edit, repetitions-or-duration measurement, local images, archive and restore.
SQLite is authoritative; controllers reload after committed writes.
New exercises receive a stable UUID before saving; save buttons are locked during writes.
Image references are relative to the app documents directory. Copies are made before
committing; originals are removed only after the database commit succeeds.

## Decisions

- User chose to send the exercise list later. No initial exercise definitions or
  fabricated performance records are inserted.
- The guide lists six day names, not detailed exercises. Day setup is the next step.
- Planned sets/reps/rest belong to the exercise-day link, not the exercise definition.
  Figma's plan fields are therefore reserved for the future day-plan editor.
- Library rows show their real measurement type until day links are implemented.
- Other navigation tabs are deferred until their screens have working actions.
- Native Android system bars replace the static iOS status/navigation mockups.
- Original clipped icon-slot SVGs were exported unchanged. Figma's chevron layers
  2:1125 and 2:1238 are empty; no replacement icon is fabricated.

## Verification

- Direct Dart source analysis: no issues.
- 14 checks against real host SQLite through sqflite_common_ffi: empty initialization,
  repeated/concurrent saving, stable IDs, reopening the database, edits, archive/restore,
  duplicate names, invalid writes, foreign keys, schema version, local image copy and cleanup.
- Icon root dimensions and local non-empty files checked against the original slots.
- Flutter pub dependency resolution, APK builds, rendered UI comparison, Android image
  picker/device behavior and small-screen/text-scale QA have not been executed here.
  Local analysis used existing cached packages and an SDK library map.

Run on a Flutter-equipped machine:

```sh
flutter pub get
flutter analyze
# Runs repository checks using native SQLite hook resolution:
dart run tools/check_repository.dart
flutter build apk --debug
```

Before accepting visual parity, inspect empty/data/editor states at 402px and on a
small device with enlarged text and keyboard open. Test gallery/camera, cancelling,
editing, archiving/restoring the last archived item, and reopening the application.
