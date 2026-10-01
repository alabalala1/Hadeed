import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'data/exercise_image_store.dart';
import 'data/exercise_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<HadeedApp> startup;
  @override
  void initState() {
    super.initState();
    startup = initialize();
  }

  Future<HadeedApp> initialize() async {
    final documents = await getApplicationDocumentsDirectory();
    final db = await AppDatabase.open(
      databaseFactory,
      p.join(await getDatabasesPath(), 'hadeed.db'),
    );
    return HadeedApp(
      repository: ExerciseRepository(db),
      images: ExerciseImageStore(documents.path),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HadeedApp>(
    future: startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        theme: appTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('تعذر فتح البيانات المحلية.'),
                          TextButton(
                            onPressed: () =>
                                setState(() => startup = initialize()),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}
