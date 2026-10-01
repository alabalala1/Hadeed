import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../data/exercise_image_store.dart';
import '../data/exercise_repository.dart';
import '../data/training_repository.dart';
import '../data/workout_repository.dart';
import '../data/backup_repository.dart';
import '../core/platform/android_bridge.dart';
import 'app_shell.dart';
import 'exercise_controller.dart';
import 'training_controller.dart';
import 'workout_controller.dart';

class HadeedApp extends StatelessWidget {
  const HadeedApp({
    super.key,
    required this.repository,
    required this.images,
    required this.backup,
  });
  final ExerciseRepository repository;
  final ExerciseImageStore images;
  final BackupRepository backup;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: images),
        Provider.value(value: backup),
        ChangeNotifierProvider(
          create: (_) => WorkoutController(
            WorkoutRepository(repository.database),
            AndroidBridge(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TrainingController(TrainingRepository(repository.database))
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => ExerciseController(
            repository,
            onChanged: context.read<TrainingController>().load,
          )..load(),
        ),
      ],
      child: MaterialApp(
        title: 'حديد',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: appTheme(),
        home: const AppShell(),
      ),
    );
  }
}
