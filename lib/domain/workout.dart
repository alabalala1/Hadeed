import 'dart:convert';

typedef DbRow = Map<String, Object?>;

String localDate(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

String clockText(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class SessionRecord {
  const SessionRecord(this.row, this.exercises, this.sets);
  final DbRow row;
  final List<DbRow> exercises;
  final Map<String, List<DbRow>> sets;
  String get id => row['id'] as String;
  bool get active => row['status'] == 'active';
  int get setCount => sets.values.fold(0, (a, b) => a + b.length);
  int get performedCount => sets.values.where((s) => s.isNotEmpty).length;
  int elapsed(DateTime now) =>
      (((row['ended_at'] as int?) ?? now.millisecondsSinceEpoch) -
          (row['started_at'] as int)) ~/
      1000;
  double get volume => sets.values
      .expand((x) => x)
      .fold(
        0.0,
        (sum, s) =>
            sum + ((s['weight'] as num?) ?? 0) * ((s['reps'] as int?) ?? 0),
      );
  int get plannedCount => exercises.fold(
    0,
    (sum, e) => sum + (jsonDecode(e['plan_json'] as String) as List).length,
  );
  int get plannedDone => exercises.fold(0, (sum, e) {
    final count = (jsonDecode(e['plan_json'] as String) as List).length;
    final actual = sets[e['id']]?.length ?? 0;
    return sum + (actual < count ? actual : count);
  });
}

class WorkoutSettings {
  const WorkoutSettings({
    this.restSeconds = 60,
    this.autoRest = false,
    this.sound = false,
    this.vibration = false,
    this.unit = 'kg',
  });
  final int restSeconds;
  final bool autoRest, sound, vibration;
  final String unit;
  factory WorkoutSettings.fromJson(Map<String, dynamic> j) {
    final seconds = j['rest_seconds'] as int? ?? 60;
    final unit = j['unit'] as String? ?? 'kg';
    if (seconds <= 0 || seconds > 86400 || !['kg', 'lb'].contains(unit)) {
      throw const FormatException('إعدادات غير صالحة');
    }
    return WorkoutSettings(
      restSeconds: seconds,
      autoRest: j['auto_rest'] as bool? ?? false,
      sound: j['sound'] as bool? ?? false,
      vibration: j['vibration'] as bool? ?? false,
      unit: unit,
    );
  }
  Map<String, dynamic> toJson() => {
    'rest_seconds': restSeconds,
    'auto_rest': autoRest,
    'sound': sound,
    'vibration': vibration,
    'unit': unit,
  };
}

int remainingSeconds(DbRow timer, DateTime now) {
  if (timer['status'] == 'paused') return timer['remaining_seconds'] as int;
  if (timer['status'] != 'running') return 0;
  final ms = (timer['deadline'] as int) - now.millisecondsSinceEpoch;
  return ms <= 0 ? 0 : (ms / 1000).ceil();
}

String setText(DbRow s, {String unit = 'kg'}) {
  if (s['duration_seconds'] != null) {
    return '${clockText(s['duration_seconds'] as int)} · ${s['notes'] ?? ''}';
  }
  final kg = s['weight'] as num?;
  final weight = kg == null
      ? 'وزن غير مسجل'
      : '${(unit == 'lb' ? kg * 2.2046226218 : kg).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} ${unit == 'lb' ? 'باوند' : 'كجم'}';
  return '${s['reps']} عدة · $weight';
}
