import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';

class HadeedApp extends StatelessWidget {
  const HadeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حديد',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: Text('حديد'))),
    );
  }
}
