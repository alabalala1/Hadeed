import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/platform/android_bridge.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';

class WorkoutController extends ChangeNotifier with WidgetsBindingObserver {
  WorkoutController(this.repository, this.bridge) {
    WidgetsBinding.instance.addObserver(this);
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timer != null &&
          timer!['status'] == 'running' &&
          remainingSeconds(timer!, DateTime.now()) == 0 &&
          !busy) {
        _expire();
      } else {
        notifyListeners();
      }
    });
  }
  final WorkoutRepository repository;
  final AndroidBridge bridge;
  late final Timer tick;
  SessionRecord? active;
  DbRow? timer;
  List<DbRow> history = [];
  WorkoutSettings settings = const WorkoutSettings();
  bool busy = false, loading = true;
  bool onboarding = false;
  String? error, notificationError;
  Future<void> _expire() async {
    if (await change(() => repository.timerAction('expire'))) {
      try {
        await bridge.finished(settings);
      } catch (_) {
        notificationError = 'تعذر عرض تنبيه الراحة';
      }
    }
  }

  Future<void> load() async {
    try {
      active = await repository.active();
      onboarding = await repository.needsOnboarding();
      history = await repository.history();
      settings = await repository.settings();
      timer = await repository.timer();
      if (timer != null &&
          timer!['status'] == 'running' &&
          remainingSeconds(timer!, DateTime.now()) == 0) {
        await repository.timerAction('expire');
        timer = await repository.timer();
      }
      await syncAlarm();
      error = null;
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'تعذر قراءة بيانات الجلسات';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> syncAlarm() async {
    try {
      await bridge.syncTimer(timer, settings);
      notificationError = null;
    } catch (_) {
      notificationError =
          'تعذر جدولة التنبيه؛ المؤقت والتسجيل يعملان داخل التطبيق.';
    }
  }

  Future<bool> change(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await load();
      return true;
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : e is ArgumentError
          ? e.message.toString()
          : 'تعذر حفظ التغيير. حاول مجددًا.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  @override
  void dispose() {
    tick.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
