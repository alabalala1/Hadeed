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
  String? expandedExerciseId;
  final explained = <String>{};
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
      bottomNavigationBar: s.active ? _sessionActions(context, s, w) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              s.row['day_name'] as String,
              '${s.row['date_local']} · المدة: ${clockText(s.elapsed(DateTime.now()))}',
              back: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('session-scroll'),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (w.error != null)
                    Text(w.error!, style: const TextStyle(color: AppColors.danger)),
                  if (!s.active)
                    WorkoutCard(
                      child: Wrap(
                        alignment: WrapAlignment.spaceAround,
                        children: [
                          Metric('الحالة', s.row['status'] == 'completed' ? 'مكتملة' : 'متروكة'),
                          Metric('الجولات', '${s.setCount}'),
                          Metric('الحجم', '${s.volume.toStringAsFixed(1)} كجم × عدة'),
                        ],
                      ),
                    ),
                  if (s.active && w.timer != null && w.timer!['session_id'] == s.id)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ActionButton(
                        remainingSeconds(w.timer!, DateTime.now()) == 0
                            ? 'انتهت الراحة'
                            : 'الراحة: ${clockText(remainingSeconds(w.timer!, DateTime.now()))}',
                        secondary: true,
                        onPressed: () => showRest(context),
                      ),
                    ),
                  for (final e in s.exercises) _exerciseCard(context, s, e, w),
                  const SizedBox(height: 16),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionActions(BuildContext context, SessionRecord s, WorkoutController w) =>
      Material(
        color: Colors.white,
        elevation: 0,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.setCount} جولة محفوظة · ${s.performedCount} من ${s.exercises.length} تمارين',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('finish-session'),
                      onPressed: w.busy ? null : () => finish(context, s),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('إنهاء الجلسة', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'ترك الجلسة وحفظ الجولات',
                    onPressed: w.busy ? null : () => abandon(context, s),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> abandon(BuildContext context, SessionRecord s) async {
    if (!await confirm(context, 'ترك الجلسة',
        'ستحفظ الجولات السابقة دون نقل دور التدريب. يبقى هذا التاريخ مسجلًا بهذه الجلسة.')) {
      return;
    }
    if (!context.mounted) return;
    final w = context.read<WorkoutController>();
    if (await workoutChange(context, () => w.repository.finish(s.id, abandon: true)) && context.mounted) {
      Navigator.pop(context);
    }
  }

  Widget _exerciseCard(BuildContext context, SessionRecord s, DbRow e, WorkoutController w) {
    final id = e['id'] as String;
    final open = expandedExerciseId == id ||
        (expandedExerciseId == null && e['id'] == s.exercises.first['id']);
    final sets = s.sets[id]!;
    final plans = jsonDecode(e['plan_json'] as String) as List;
    final skipped = e['skipped'] == 1;
    return WorkoutCard(
      key: ValueKey('exercise-card-$id'),
      highlight: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('exercise-header-$id'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => expandedExerciseId = open ? '' : id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${(e['sort_order'] as int) + 1}. ${e['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.text)),
                        const SizedBox(height: 6),
                        Text('${sets.length} جولات محفوظة · الهدف ${plans.length}${skipped ? ' · متخطى' : ''}${e['group_id'] == null ? '' : ' · سوبر سيت'}',
                            style: TextStyle(color: skipped ? AppColors.warning : AppColors.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.primary),
                ],
              ),
            ),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                for (final p in plans)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: Text('جولة ${(p['sort_order'] as int) + 1}: ${PlannedSet.fromRow(Map<String, Object?>.from(p as Map)).describe(e['measurement_type'] == 'reps' ? MeasurementType.reps : MeasurementType.duration)}',
                        style: const TextStyle(color: AppColors.primaryPressed, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
            if (e['per_leg'] == 1) const Text('العدات المستهدفة لكل رجل'),
            if ((e['notes'] as String).isNotEmpty || e['image_file'] != null)
              TextButton.icon(
                onPressed: () => setState(() {
                  if (!explained.add(id)) explained.remove(id);
                }),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(explained.contains(id) ? 'إخفاء شرح التمرين' : 'شرح التمرين'),
              ),
            if (explained.contains(id)) ...[
              if (e['image_file'] != null)
                Image.file(File(context.read<ExerciseImageStore>().resolve(e['image_file'] as String)),
                    height: 180, fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('تعذر عرض الصورة')),
              Text(e['notes'] as String),
              const SizedBox(height: 12),
            ],
            if (previous[id] != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.comparison, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('آخر مرة: ${previous[id]!['date_local']} · ${previous[id]!['day_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryPressed)),
                    for (final p in previous[id]!['sets'] as List<DbRow>)
                      Text('جولة ${(p['sort_order'] as int) + 1}: ${setText(p, unit: w.settings.unit)}'),
                  ],
                ),
              ),
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('الجولات المحفوظة', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
              for (var i = 0; i < sets.length; i++) _setRow(context, s, e, sets[i], i + 1),
            ],
            if (skipped) Text('سبب التخطي: ${e['skip_reason']}'),
            if (s.active) ...[
              if (!skipped)
                SetEntry(key: ValueKey(id), exercise: e, previous: previous[id], onSaved: reload),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: w.busy ? null : () async {
                      if (await workoutChange(context, () => w.repository.startTimer(id)) && context.mounted) {
                        await showRest(context);
                      }
                    },
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: Text('راحة ${e['rest_seconds']} ثانية'),
                  ),
                  TextButton(
                    onPressed: w.busy ? null : () => toggleSkip(context, e),
                    child: Text(skipped ? 'إلغاء التخطي' : 'تخطي التمرين'),
                  ),
                ],
              ),
            ],
          ],
        ],
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
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width - 96,
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
    final row = widget.exercise;
    writes = writes
        .then((_) => repo.draft(widget.exercise['id'] as String, value))
        .then((_) {
          row['draft_json'] = jsonEncode(value);
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

  Widget _weightField() => TextFormField(
    key: const ValueKey('weight-input'), controller: weight, enabled: !saving,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textDirection: TextDirection.ltr, validator: validWeight, onChanged: (_) => persist(),
    decoration: InputDecoration(labelText: 'الوزن (${unit == 'lb' ? 'باوند' : 'كجم'})',
        helperText: 'اختياري', hintText: '7.5', hintStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.muted), floatingLabelBehavior: FloatingLabelBehavior.always),
  );

  Widget _repsField() => TextFormField(
    key: const ValueKey('reps-input'), controller: reps, enabled: !saving,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
    keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
    validator: positiveInt, onChanged: (_) => persist(),
    decoration: const InputDecoration(labelText: 'العدات', helperText: 'عدد صحيح', hintText: '10', hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.muted),
        floatingLabelBehavior: FloatingLabelBehavior.always),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Every form has a finite width, including forms opened after scrolling
      // and correction dialogs. No flex child receives an unbounded axis.
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.sizeOf(context).width - 80;
      final sideBySide = width >= 300 && MediaQuery.textScalerOf(context).scale(16) <= 22;
      return SizedBox(
        width: width,
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inputPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.initial == null ? 'الجولة القادمة' : 'تصحيح الأداء',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 16)),
                const Text('أدخل أداءك الفعلي ثم احفظ الجولة', style: TextStyle(fontSize: 12)),
                if (draftError != null) Text(draftError!, style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 20),
                if (timed)
                  TextFormField(
                    key: const ValueKey('duration-input'),
                    controller: duration, enabled: !saving,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr, validator: positiveDuration, onChanged: (_) => persist(),
                    decoration: const InputDecoration(labelText: 'المدة الفعلية (دقيقة)',
                        floatingLabelBehavior: FloatingLabelBehavior.always),
                  )
                else if (sideBySide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _weightField()),
                    const SizedBox(width: 12),
                    Expanded(child: _repsField()),
                  ])
                else ...[
                  _weightField(), const SizedBox(height: 16), _repsField(),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes, enabled: !saving, onChanged: (_) => persist(),
                  decoration: const InputDecoration(labelText: 'ملاحظة الجولة (اختياري)'),
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
                    if ((timed && s['duration_seconds'] == null) ||
                        (!timed && s['reps'] == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'نوع القياس تغير منذ آخر أداء؛ أدخل القيمة الحالية يدويًا.',
                          ),
                        ),
                      );
                      return;
                    }
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
                const SizedBox(height: 16),
                ActionButton(saving ? 'جارٍ الحفظ…' : 'حفظ الجولة', node: '2:688', onPressed: saving ? null : save),
              ],
            ),
          ),
        ),
      );
    },
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
      bottomNavigationBar: Material(
        color: Colors.white, elevation: 0,
        child: SafeArea(top: false, minimum: const EdgeInsets.all(16),
          child: ActionButton('حفظ وإنهاء الجلسة',
            onPressed: session.setCount == 0 ? null : () => Navigator.pop(context, true)),
        ),
      ),
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
