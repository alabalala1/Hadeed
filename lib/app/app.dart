import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../data/exercise_image_store.dart';
import '../data/exercise_repository.dart';
import '../features/exercises/exercise_library_screen.dart';
import 'exercise_controller.dart';

class HadeedApp extends StatelessWidget {
  const HadeedApp({super.key, required this.repository, required this.images});
  final ExerciseRepository repository;
  final ExerciseImageStore images;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: images),
        ChangeNotifierProvider(
          create: (_) => ExerciseController(repository)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'حديد',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: appTheme(),
        home: const ExerciseLibraryScreen(),
      ),
    );
  }
}
