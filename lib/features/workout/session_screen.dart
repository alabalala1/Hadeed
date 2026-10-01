import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/training_controller.dart';
import '../../app/workout_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../data/exercise_image_store.dart';
import '../../domain/training_plan.dart';
import '../../domain/exercise.dart';
import '../../domain/workout.dart';
import 'workout_widgets.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.id});
  final String id;
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  SessionRecord? cached;
  final previous = <String, DbRow?>{};
  String? error;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final repo = context.read<WorkoutController>().repository;
      final s = await repo.session(widget.id);
      for (final e in s.exercises) {
        previous[e['id'] as String] = await repo.previous(
          e,
          s.row['day_id'] as String,
        );
      }
      if (mounted) {
        setState(() {
          cached = s;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل الجلسة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutController>();
    final s = w.active?.id == widget.id ? w.active : cached;
    if (s == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: error == null
                ? const CircularProgressIndicator()
                : TextButton(onPressed: reload, child: Text(error!)),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              s.row['day_name'] as String,
              '${s.row['date_local']} · المدة: ${clockText(s.elapsed(DateTime.now()))}',
              back: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (w.error != null)
                    Text(
                      w.error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  if (!s.active)
                    WorkoutCard(
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        children: [
                          Metric(
                            'الحالة',
                            s.row['status'] == 'completed'
                                ? 'مكتملة'
                                : 'متروكة',
                          ),
                          Metric('الجولات', '${s.setCount}'),
                          Metric(
                            'الحجم',
                            '${s.volume.toStringAsFixed(1)} كجم × عدة',
                          ),
                          Metric(
                            'الإنجاز',
                            s.plannedCount == 0
                                ? 'غير محدد'
                                : '${(100 * s.plannedDone / s.plannedCount).round()}٪',
                          ),
                        ],
                      ),
                    ),
                  if (s.active &&
                      w.timer != null &&
                      w.timer!['session_id'] == s.id)
                    ActionButton(
                      remainingSeconds(w.timer!, DateTime.now()) == 0
                          ? 'انتهت الراحة'
                          : 'الراحة: ${clockText(remainingSeconds(w.timer!, DateTime.now()))}',
                      secondary: true,
                      onPressed: () => showRest(context),
                    ),
                  for (final e in s.exercises)
                    WorkoutCard(
                      highlight: s.active,
                      child: ExpansionTile(
                        key: PageStorageKey(e['id']),
                        initiallyExpanded: !s.active || e == s.exercises.first,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          '${(e['sort_order'] as int) + 1}. ${e['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Text(
                          '${s.sets[e['id']]!.length} جولات مسجلة${e['skipped'] == 1 ? ' · متخطى' : ''}${e['group_id'] == null ? '' : ' · سوبر سيت'}',
                        ),
                        children: [
                          if (e['image_file'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Image.file(
                                File(
                                  context.read<ExerciseImageStore>().resolve(
                                    e['image_file'] as String,
                                  ),
                                ),
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const Text('تعذر عرض الصورة'),
                              ),
                            ),
                          if ((e['notes'] as String).isNotEmpty)
                            Text(e['notes'] as String),
                          if (e['per_leg'] == 1)
                            const Text('العدات المستهدفة لكل رجل'),
                          for (final p
                              in (jsonDecode(e['plan_json'] as String) as List))
                            Text(
                              'هدف جولة ${(p['sort_order'] as int) + 1}: ${PlannedSet.fromRow(Map<String, Object?>.from(p as Map)).describe(e['measurement_type'] == 'reps' ? MeasurementType.reps : MeasurementType.duration)}',
                            ),
                          if (previous[e['id']] != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const DesignIcon('2:574'),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'آخر مرة: ${previous[e['id']]!['date_local']} · ${previous[e['id']]!['day_name']}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  for (final p
                                      in previous[e['id']]!['sets']
                                          as List<DbRow>)
                                    Text(
                                      'جولة ${(p['sort_order'] as int) + 1}: ${setText(p, unit: w.settings.unit)}',
                                    ),
                                ],
                              ),
                            ),
                          for (var i = 0; i < s.sets[e['id']]!.length; i++)
                            _setRow(context, s, e, s.sets[e['id']]![i], i + 1),
                          if (e['skipped'] == 1)
                            Text('سبب التخطي: ${e['skip_reason']}'),
                          if (s.active) ...[
                            if (e['skipped'] == 0)
                              SetEntry(
                                key: ValueKey(e['id']),
                                exercise: e,
                                previous: previous[e['id']],
                                onSaved: reload,
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: w.busy
                                      ? null
                                      : () async {
                                          await workoutChange(
                                            context,
                                            () => w.repository.startTimer(
                                              e['id'] as String,
                                            ),
                                          );
                                          if (context.mounted) {
                                            await showRest(context);
                                          }
                                        },
                                  child: Text(
                                    'راحة ${e['rest_seconds']} ثانية',
                                  ),
                                ),
                                TextButton(
                                  onPressed: w.busy
                                      ? null
                                      : () => toggleSkip(context, e),
                                  child: Text(
                                    e['skipped'] == 1
                                        ? 'إلغاء التخطي'
                                        : 'تخطي التمرين',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (s.active) ...[
                    ActionButton(
                      'مراجعة وإنهاء الجلسة',
                      onPressed: w.busy ? null : () => finish(context, s),
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      'ترك الجلسة وحفظ الجولات',
                      secondary: true,
                      onPressed: w.busy
                          ? null
                          : () async {
                              if (!await confirm(
                                context,
                                'ترك الجلسة',
                                'ستحفظ الجولات السابقة دون نقل دور التدريب. يبقى هذا التاريخ مسجلًا بهذه الجلسة.',
                              )) {
                                return;
                              }
                              if (context.mounted &&
                                  await workoutChange(
                                    context,
                                    () => w.repository.finish(
                                      s.id,
                                      abandon: true,
                                    ),
                                  ) &&
                                  context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setRow(
    BuildContext context,
    SessionRecord s,
    DbRow e,
    DbRow set,
    int number,
  ) {
    final w = context.read<WorkoutController>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('جولة $number: ${setText(set, unit: w.settings.unit)}'),
          ),
          IconButton(
            tooltip: 'تعديل الجولة',
            onPressed: w.busy
                ? null
                : () async {
                    if (!s.active &&
                        !await confirm(
                          context,
                          'تصحيح السجل',
                          'سيُعدّل الأداء المحفوظ دون تغيير مؤشر الدورة.',
                        )) {
                      return;
                    }
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('تعديل جولة $number'),
                        content: SingleChildScrollView(
                          child: SetEntry(
                            exercise: e,
                            initial: set,
                            correction: !s.active,
                            onSaved: () async {
                              await reload();
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    );
                  },
            icon: const DesignIcon('2:580'),
          ),
          IconButton(
            tooltip: 'حذف الجولة',
            onPressed: w.busy
                ? null
                : () async {
                    if (!await confirm(
                      context,
                      'حذف الجولة',
                      'حذف الجولة المحفوظة؟ مؤشر الدورة لن يتغير.',
                    )) {
                      return;
                    }
                    if (context.mounted) {
                      await workoutChange(
                        context,
                        () => w.repository.deleteSet(
                          e['id'] as String,
                          set['id'] as String,
                          correction: !s.active,
                        ),
                      );
                      await reload();
                    }
                  },
            icon: const DesignIcon('2:583'),
          ),
        ],
      ),
    );
  }

  Future<void> toggleSkip(BuildContext context, DbRow e) async {
    final w = context.read<WorkoutController>();
    if (e['skipped'] == 1) {
      await workoutChange(
        context,
        () => w.repository.skip(e['id'] as String, '', skipped: false),
      );
      return;
    }
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تخطي التمرين'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تخطي'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await workoutChange(
        context,
        () => w.repository.skip(e['id'] as String, reason.text),
      );
    }
    Future<void>.delayed(const Duration(milliseconds: 300), reason.dispose);
  }

  Future<void> finish(BuildContext context, SessionRecord s) async {
    final missing = s.exercises
        .where(
          (e) =>
              e['skipped'] == 1 ||
              s.sets[e['id']]!.isEmpty ||
              s.sets[e['id']]!.length <
                  (jsonDecode(e['plan_json'] as String) as List).length,
        )
        .map((e) => e['name'])
        .join('\n');
    final confirmed =
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _SessionSummary(session: s, missing: missing),
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final w = context.read<WorkoutController>();
    if (await workoutChange(
          context,
          () => w.repository.finish(s.id, allowPartial: true),
        ) &&
        context.mounted) {
      await context.read<TrainingController>().load();
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class SetEntry extends StatefulWidget {
  const SetEntry({
    super.key,
    required this.exercise,
    required this.onSaved,
    this.initial,
    this.previous,
    this.correction = false,
  });
  final DbRow exercise;
  final DbRow? initial, previous;
  final bool correction;
  final Future<void> Function() onSaved;
  @override
  State<SetEntry> createState() => _SetEntryState();
}

class _SetEntryState extends State<SetEntry> {
  final form = GlobalKey<FormState>();
  final reps = TextEditingController(),
      weight = TextEditingController(),
      duration = TextEditingController(),
      notes = TextEditingController();
  late String id, unit;
  bool saving = false;
  String? draftError;
  Future<void> writes = Future<void>.value();
  bool get timed => widget.exercise['measurement_type'] == 'duration';
  @override
  void initState() {
    super.initState();
    final w = context.read<WorkoutController>();
    final draft =
        jsonDecode(widget.exercise['draft_json'] as String)
            as Map<String, dynamic>;
    unit = (draft['unit'] as String?) ?? w.settings.unit;
    id =
        widget.initial?['id'] as String? ??
        draft['id'] as String? ??
        w.repository.newId();
    if (widget.initial != null) {
      final s = widget.initial!;
      reps.text = '${s['reps'] ?? ''}';
      final kg = s['weight'] as num?;
      weight.text = kg == null
          ? ''
          : '${unit == 'lb' ? kg * 2.2046226218 : kg}';
      duration.text = s['duration_seconds'] == null
          ? ''
          : '${(s['duration_seconds'] as int) / 60}';
      notes.text = s['notes'] as String;
    } else {
      reps.text = draft['reps'] as String? ?? '';
      weight.text = draft['weight'] as String? ?? '';
      duration.text = draft['duration'] as String? ?? '';
      notes.text = draft['notes'] as String? ?? '';
    }
  }

  void persist() {
    if (widget.initial != null || widget.correction) return;
    final repo = context.read<WorkoutController>().repository;
    final value = {
      'id': id,
      'unit': unit,
      'reps': reps.text,
      'weight': weight.text,
      'duration': duration.text,
      'notes': notes.text,
    };
    writes = writes
        .then((_) => repo.draft(widget.exercise['id'] as String, value))
        .then((_) {
          draftError = null;
        })
        .catchError((Object _) {
          if (mounted) {
            setState(
              () => draftError =
                  'تعذر حفظ المسودة؛ حاول حفظ الجولة قبل المغادرة.',
            );
          }
        });
  }

  String? positiveInt(String? v) {
    final n = int.tryParse(normalizeNumber(v ?? ''));
    return n != null && n > 0 ? null : 'عدد صحيح موجب';
  }

  String? positiveDuration(String? v) {
    final n = double.tryParse(normalizeNumber(v ?? ''));
    return n != null && n.isFinite && n > 0 && (n * 60).round() > 0
        ? null
        : 'مدة موجبة بالدقائق';
  }

  String? validWeight(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = double.tryParse(normalizeNumber(v!));
    return n != null && n.isFinite && n >= 0 ? null : 'وزن غير سالب';
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    await writes;
    if (!mounted) return;
    final w = context.read<WorkoutController>();
    final value = weight.text.trim().isEmpty
        ? null
        : double.parse(normalizeNumber(weight.text)) /
              (unit == 'lb' ? 2.2046226218 : 1);
    final ok = await workoutChange(context, () async {
      await w.repository.saveSet(
        widget.exercise['id'] as String,
        id,
        reps: timed ? null : int.parse(normalizeNumber(reps.text)),
        weight: timed ? null : value,
        duration: timed
            ? (double.parse(normalizeNumber(duration.text)) * 60).round()
            : null,
        notes: notes.text,
        correction: widget.correction,
      );
      if (widget.initial == null && !widget.correction) {
        await w.repository.maybeAutoRest(widget.exercise);
      }
    });
    if (!mounted) return;
    if (ok) {
      if (widget.initial == null) {
        id = w.repository.newId();
        reps.clear();
        weight.clear();
        duration.clear();
        notes.clear();
      }
      await widget.onSaved();
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          widget.initial == null ? 'الجولة القادمة' : 'تصحيح الأداء',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (draftError != null)
          Text(draftError!, style: const TextStyle(color: AppColors.danger)),
        if (timed)
          TextFormField(
            controller: duration,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            validator: positiveDuration,
            onChanged: (_) => persist(),
            decoration: const InputDecoration(
              labelText: 'المدة الفعلية (دقيقة)',
            ),
          )
        else ...[
          TextFormField(
            controller: weight,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            validator: validWeight,
            onChanged: (_) => persist(),
            decoration: InputDecoration(
              labelText: 'الوزن (${unit == 'lb' ? 'باوند' : 'كجم'}) — اختياري',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: reps,
            enabled: !saving,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            validator: positiveInt,
            onChanged: (_) => persist(),
            decoration: const InputDecoration(labelText: 'التكرارات الفعلية'),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: notes,
          enabled: !saving,
          onChanged: (_) => persist(),
          decoration: const InputDecoration(
            labelText: 'ملاحظة الجولة (اختياري)',
          ),
        ),
        if (widget.previous != null && widget.initial == null)
          TextButton(
            onPressed: saving
                ? null
                : () {
                    final actual =
                        context
                            .read<WorkoutController>()
                            .active
                            ?.sets[widget.exercise['id']]
                            ?.length ??
                        0;
                    final old = widget.previous!['sets'] as List<DbRow>;
                    if (actual >= old.length) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا توجد جولة مناظرة في آخر أداء'),
                        ),
                      );
                      return;
                    }
                    final s = old[actual];
                    if (timed) {
                      duration.text = '${(s['duration_seconds'] as int) / 60}';
                    } else {
                      reps.text = '${s['reps']}';
                      final kg = s['weight'] as num?;
                      weight.text = kg == null
                          ? ''
                          : '${unit == 'lb' ? kg * 2.2046226218 : kg}';
                    }
                    persist();
                  },
            child: const Text(
              'تعبئة من الجولة المناظرة في آخر مرة (لم تُحفظ بعد)',
            ),
          ),
        const SizedBox(height: 12),
        ActionButton(
          saving ? 'جارٍ الحفظ…' : 'حفظ الجولة',
          node: '2:688',
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
  @override
  void dispose() {
    reps.dispose();
    weight.dispose();
    duration.dispose();
    notes.dispose();
    super.dispose();
  }
}

Future<void> showRest(BuildContext context) =>
    showDialog<void>(context: context, builder: (c) => const _RestDialog());

class _RestDialog extends StatelessWidget {
  const _RestDialog();
  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutController>();
    final t = w.timer;
    if (t == null) {
      return AlertDialog(
        title: const Text('لا توجد راحة جارية'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('عودة'),
          ),
        ],
      );
    }
    final left = remainingSeconds(t, DateTime.now());
    final ex = w.active?.exercises
        .where((e) => e['id'] == t['session_exercise_id'])
        .firstOrNull;
    Future<void> action(String a) async {
      await workoutChange(context, () => w.repository.timerAction(a));
    }

    return AlertDialog(
      title: const Text('مؤقت الراحة', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ex?['name'] as String? ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (left / (t['duration_seconds'] as int)).clamp(
                        0,
                        1,
                      ),
                      strokeWidth: 7,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                  Text(
                    left == 0 ? 'انتهت الراحة' : clockText(left),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (t['status'] == 'paused') const Text('متوقف مؤقتًا'),
            if (w.notificationError != null) Text(w.notificationError!),
            const SizedBox(height: 24),
            TextButton(
              onPressed: w.busy ? null : () => action('add'),
              child: const Text('+15 ثانية'),
            ),
            ActionButton(
              'تخطي الراحة',
              onPressed: w.busy
                  ? null
                  : () async {
                      await action('skip');
                      if (context.mounted) Navigator.pop(context);
                    },
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: w.busy
                      ? null
                      : () => action(
                          t['status'] == 'paused' ? 'resume' : 'pause',
                        ),
                  child: Text(
                    t['status'] == 'paused' ? 'استئناف' : 'إيقاف مؤقت',
                  ),
                ),
                TextButton(
                  onPressed: w.busy ? null : () => action('reset'),
                  child: const Text('إعادة'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('عودة للجلسة'),
        ),
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session, required this.missing});
  final SessionRecord session;
  final String missing;
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<WorkoutController>().settings;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ScreenHeader(
              'ملخص الجلسة',
              'راجع الأداء قبل حفظ وإنهاء الجلسة',
              back: true,
            ),
            WorkoutCard(
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const DesignIcon('2:643'),
                      Metric(
                        'الوقت الإجمالي',
                        clockText(session.elapsed(DateTime.now())),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const DesignIcon('2:646'),
                      Metric(
                        'تمارين مسجلة',
                        '${session.performedCount} من ${session.exercises.length}',
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const DesignIcon('2:649'),
                      Metric('الجولات', '${session.setCount}'),
                    ],
                  ),
                ],
              ),
            ),
            WorkoutCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'سجل الأداء بالجلسة:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  for (final e in session.exercises)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e['skipped'] == 1
                            ? const Color(0xFFFEF3C7)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            e['skipped'] == 1
                                ? 'تم التخطي: ${e['skip_reason']}'
                                : session.sets[e['id']]!.isEmpty
                                ? 'لم يُسجل أداء'
                                : '${session.sets[e['id']]!.length} جولات مسجلة',
                          ),
                          for (final actual in session.sets[e['id']]!)
                            Text(setText(actual, unit: settings.unit)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (missing.isNotEmpty)
              WorkoutCard(
                tint: const Color(0xFFFEF3C7),
                child: Text(
                  'جلسة جزئية — تمارين غير مكتملة أو متخطاة:\n$missing\nبالضغط على حفظ وإنهاء تؤكد إكمالها جزئيًا ونقل دورة التدريب.',
                ),
              ),
            ActionButton(
              'حفظ وإنهاء الجلسة',
              onPressed: session.setCount == 0
                  ? null
                  : () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
            ActionButton(
              'العودة لتعديل الجلسة',
              secondary: true,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
