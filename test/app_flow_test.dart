import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hadeed/app/app.dart';
import 'package:hadeed/app/workout_controller.dart';
import 'package:hadeed/core/database/app_database.dart';
import 'package:hadeed/data/backup_repository.dart';
import 'package:hadeed/data/exercise_image_store.dart';
import 'package:hadeed/data/exercise_repository.dart';
import 'package:hadeed/data/training_repository.dart';
import 'package:hadeed/data/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Arabic app registers a set and opens history and settings without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('ye.hadeed/local'),
        (call) async => call.method == 'notificationPermission' ? false : null,
      );
      final setup = (await tester.runAsync(() async {
        final font = FontLoader('Cairo');
        for (final weight in [400, 500, 700, 800]) {
          font.addFont(rootBundle.load('assets/fonts/Cairo-$weight.ttf'));
        }
        await font.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        sqfliteFfiInit();
        final temp = await Directory.systemTemp.createTemp('hadeed_ui_');
        final factory = databaseFactoryFfiNoIsolate;
        final db = await AppDatabase.open(factory, '${temp.path}/db');
        return (temp, db);
      }))!;
      final temp = setup.$1;
      final db = setup.$2;
      final factory = databaseFactoryFfiNoIsolate;
      final repository = WorkoutRepository(db);
      await tester.runAsync(() async {
        final program =
            jsonDecode(
                  await File(
                    'assets/templates/user_program_v1.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        await TrainingRepository(db).installTemplate(program);
        await repository.onboarding(useTemplate: true);
      });
      final images = ExerciseImageStore('${temp.path}/documents');
      final boundary = GlobalKey();
      final app = HadeedApp(
        repository: ExerciseRepository(db),
        images: images,
        backup: BackupRepository(db, images, factory),
      );
      try {
        await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
        Future<void> settle() async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> capture(String name) async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = File('build/ui-previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        }

        await settle();
        await settle();
        expect(find.text('الحصة التدريبية اليوم'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => capture('today'));
        final start = find.text('بدء التمرين الآن');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await settle();
        await settle();
        await tester.runAsync(() => capture('session-open'));
        expect(find.text('الجولة القادمة'), findsOneWidget);
        final state = Provider.of<WorkoutController>(
          tester.element(find.text('الجولة القادمة')),
          listen: false,
        );
        final weight = find.byKey(const ValueKey('weight-input'));
        final reps = find.byKey(const ValueKey('reps-input'));
        await tester.ensureVisible(weight);
        await tester.enterText(weight, '٧٫٥');
        await tester.ensureVisible(reps);
        await tester.enterText(reps, '١٠');
        await settle();
        tester.testTextInput.hide();
        await tester.pump();
        final heading = find.text('1. بنش صدر مستوي');
        await tester.ensureVisible(heading);
        await tester.pump();
        await tester.tap(heading);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(heading);
        await tester.pump();
        await tester.tap(heading);
        await settle();
        expect(tester.widget<TextFormField>(weight).controller!.text, '٧٫٥');
        expect(tester.widget<TextFormField>(reps).controller!.text, '١٠');
        tester.testTextInput.hide();
        await tester.pump();
        final save = find.text('حفظ الجولة');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await settle();
        expect(state.active!.setCount, 1);
        expect(
          state.active!.sets.values.expand((s) => s).single['weight'],
          7.5,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(heading);
        await tester.pump();
        await tester.runAsync(() => capture('session'));
        final exercises = state.active!.exercises;
        for (var i = 1; i < exercises.length; i++) {
          final header = find.byKey(ValueKey('exercise-header-${exercises[i]['id']}'));
          await tester.ensureVisible(header);
          await tester.pump();
          await tester.tap(header);
          await settle();
          expect(tester.takeException(), isNull, reason: 'Exercise ${i + 1} must render after opening');
          expect(find.byType(ErrorWidget), findsNothing);
          final entryForm = find.byType(Form);
          expect(tester.getSize(entryForm).height, lessThan(700));
          if (i == 1) {
            await tester.ensureVisible(weight);
            await tester.enterText(weight, '12.5');
            await tester.ensureVisible(reps);
            await tester.enterText(reps, '12');
            tester.testTextInput.hide();
            await settle();
            await tester.ensureVisible(save);
            await tester.tap(save);
            await settle();
            expect(state.active!.sets[exercises[i]['id']]!.single['weight'], 12.5);
            await tester.ensureVisible(header);
            await tester.pump();
            await tester.runAsync(() => capture('session-second-exercise'));
          }
          final finish = find.byKey(const ValueKey('finish-session'));
          expect(finish.hitTestable(), findsOneWidget, reason: 'Finish must stay visible while scrolling');
        }
        // Reopen the second card with large text on a compact display.
        final second = find.byKey(ValueKey('exercise-header-${exercises[1]['id']}'));
        tester.view.physicalSize = const Size(320, 740);
        tester.binding.platformDispatcher.textScaleFactorTestValue = 1.8;
        await tester.pump();
        await tester.ensureVisible(second);
        await tester.tap(second);
        await settle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.getSize(find.byType(Form)).height, lessThan(1000));
        await tester.ensureVisible(second);
        await tester.pump();
        await tester.runAsync(() => capture('session-small-large-text'));
        tester.view.physicalSize = const Size(402, 874);
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('finish-session')));
        await settle();
        await settle();
        expect(find.text('ملخص الجلسة'), findsOneWidget);
        await tester.tap(find.text('حفظ وإنهاء الجلسة'));
        await settle();
        await settle();
        expect(state.active, isNull);
        await settle();
        await tester.pumpAndSettle();
        expect(find.text('السجل').last.hitTestable(), findsOneWidget);
        await tester.tap(find.text('السجل').last);
        await settle();
        expect(find.text('مكتملة'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => capture('history'));
        await tester.tap(find.text('اليوم').last);
        await settle();
        await tester.tap(find.byTooltip('الإعدادات'));
        await settle();
        await settle();
        expect(find.text('تفضيلات التمرين'), findsOneWidget);
        await tester.runAsync(() => capture('settings'));
        tester.view.physicalSize = const Size(320, 640);
        tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() => capture('settings-small-text-2x'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        await tester.runAsync(() async {
          await db.close();
          await temp.delete(recursive: true);
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
