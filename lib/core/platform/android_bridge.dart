import 'package:flutter/services.dart';

import '../../domain/workout.dart';

class AndroidBridge {
  static const channel = MethodChannel('ye.hadeed/local');
  Future<bool> permission() async =>
      await channel.invokeMethod<bool>('notificationPermission') ?? false;
  Future<void> syncTimer(DbRow? timer, WorkoutSettings settings) async {
    if (timer == null ||
        timer['status'] != 'running' ||
        remainingSeconds(timer, DateTime.now()) == 0) {
      await channel.invokeMethod<void>('cancelAlarm');
      return;
    }
    await channel.invokeMethod<void>('scheduleAlarm', {
      'deadline': timer['deadline'],
      'sound': settings.sound,
      'vibration': settings.vibration,
    });
  }

  Future<void> finished(WorkoutSettings settings) => channel.invokeMethod<void>(
    'notifyNow',
    {'sound': settings.sound, 'vibration': settings.vibration},
  );
  Future<bool> exportFile(Uint8List bytes) async =>
      await channel.invokeMethod<bool>('exportFile', {
        'bytes': bytes,
        'name': 'Hadeed-${localDate(DateTime.now())}.hadeed',
      }) ??
      false;
  Future<Uint8List?> importFile() =>
      channel.invokeMethod<Uint8List>('importFile');
}
