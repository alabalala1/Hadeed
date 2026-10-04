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

const _sessionBackground = Color(0xFFEEF3F1);
const _sessionDark = Color(0xFF123A32);
const _sessionInk = Color(0xFF132B2A);
const _sessionGreen = Color(0xFF2A7552);
const _sessionLime = Color(0xFFBDF56A);
const _sessionSoft = Color(0xFFF0F7EB);
const _sessionMuted = Color(0xFF6C807D);


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
  Map<String, dynamic> exerciseClock = {'elapsed': <String, dynamic>{}};
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final repo = context.read<WorkoutController>().repository;
      final s = await repo.session(widget.id);
      var clock = await repo.exerciseClock(widget.id);
      if (cached == null && s.exercises.isNotEmpty) {
        final remembered = clock['current'] as String?;
        expandedExerciseId = s.exercises.any((e) => e['id'] == remembered)
            ? remembered : s.exercises.first['id'] as String;
        if (s.active) clock = await repo.selectExercise(s.id, expandedExerciseId);
      }
      for (final e in s.exercises) {
        previous[e['id'] as String] = await repo.previous(
          e,
          s.row['day_id'] as String,
        );
      }
      if (mounted) {
        setState(() {
          cached = s;
          exerciseClock = clock;
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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _sessionGreen, onPrimary: Colors.white),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: _sessionInk, displayColor: _sessionInk),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFFF8FBF6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF98BC79), width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF98BC79), width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _sessionGreen, width: 1.5)),
          labelStyle: const TextStyle(color: _sessionMuted, fontSize: 11),
        ),
      ),
      child: Scaffold(
        backgroundColor: _sessionBackground,
        bottomNavigationBar: s.active ? _sessionActions(context, s, w) : null,
        body: SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              IconButton(tooltip: 'رجوع', onPressed: () => Navigator.pop(context), icon: const DesignIcon('30:725')),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.row['day_name'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _sessionInk)),
                Text(s.active ? 'تمرينك الآن • واصل بقوة' : 'سجل التمرين • ${s.row['date_local']}', style: const TextStyle(fontSize: 11, color: _sessionMuted)),
              ])),
              PopupMenuButton<String>(
                tooltip: 'خيارات الجلسة',
                icon: const DesignIcon('30:719'),
                onSelected: (value) {
                  if (value == 'rest') showRest(context);
                  if (value == 'abandon') abandon(context, s);
                },
                itemBuilder: (_) => [
                  if (s.active) const PopupMenuItem(value: 'rest', child: Text('مؤقت الراحة')),
                  if (s.active) const PopupMenuItem(value: 'abandon', child: Text('ترك الجلسة وحفظ الجولات')),
                ],
              ),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            key: const ValueKey('session-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _overview(s),
              if (w.error != null) Text(w.error!, style: const TextStyle(color: AppColors.danger)),
              if (error != null) Text(error!, style: const TextStyle(color: AppColors.danger)),
              if (s.active && w.timer != null && w.timer!['session_id'] == s.id)
                TextButton(onPressed: () => showRest(context), child: Text(remainingSeconds(w.timer!, DateTime.now()) == 0 ? 'انتهت الراحة' : 'الراحة: ${clockText(remainingSeconds(w.timer!, DateTime.now()))}')),
              for (final e in s.exercises) _exerciseCard(context, s, e, w),
              const SizedBox(height: 16),
            ]),
          )),
        ])),
      ),
    );
  }

  Widget _overview(SessionRecord s) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _sessionDark, borderRadius: BorderRadius.circular(24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الوقت الإجمالي للتمرين', style: TextStyle(fontSize: 12, color: Color(0xFFA8C5B9))),
          Text(clockText(s.elapsed(DateTime.now())), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 38, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
        ])),
        Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (s.active) const DesignIcon('30:733'),
              const SizedBox(width: 5),
              Text(s.active ? 'جلسة مباشرة' : s.row['status'] == 'completed' ? 'مكتملة' : 'متروكة', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _sessionLime)),
            ])),
          const SizedBox(height: 14),
          const DesignIcon('30:734'),
        ]),
      ]),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.spaceBetween, children: [
        const Text('خطوة أقرب لهدفك', style: TextStyle(fontSize: 11, color: Colors.white)),
        Text('${s.setCount} جولات مسجلة', style: const TextStyle(fontSize: 11, color: _sessionLime)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (final e in s.exercises) Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
            minHeight: 5, color: _sessionLime, backgroundColor: Colors.white.withValues(alpha: .15),
            value: (jsonDecode(e['plan_json'] as String) as List).isEmpty ? 0
              : (s.sets[e['id']]!.length / (jsonDecode(e['plan_json'] as String) as List).length).clamp(0.0, 1.0),
          )),
        )),
      ]),
    ]),
  );

  Widget _sessionActions(BuildContext context, SessionRecord s, WorkoutController w) => Material(
    color: _sessionBackground,
    child: SafeArea(top: false, minimum: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: FilledButton(
        key: const ValueKey('finish-session'),
        style: FilledButton.styleFrom(backgroundColor: _sessionDark, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: w.busy ? null : () => finish(context, s),
        child: const Text('إنهاء التمرين', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      )),
  );

  Future<void> selectExercise(SessionRecord s, String? id) async {
    try {
      final clock = s.active ? await context.read<WorkoutController>().repository.selectExercise(s.id, id) : exerciseClock;
      if (mounted) setState(() { expandedExerciseId = id ?? ''; exerciseClock = clock; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ وقت التمرين');
    }
  }

  int exerciseSeconds(String id) {
    final elapsed = ((exerciseClock['elapsed'] as Map<String, dynamic>)[id] as num?)?.toInt() ?? 0;
    final started = exerciseClock['started'] as int?;
    final extra = exerciseClock['current'] == id && started != null ? DateTime.now().millisecondsSinceEpoch - started : 0;
    return (elapsed + (extra > 0 ? extra : 0)) ~/ 1000;
  }

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
    final number = (e['sort_order'] as int) + 1;
    final complete = plans.isNotEmpty && sets.length >= plans.length;
    final header = InkWell(
      key: ValueKey('exercise-header-$id'),
      borderRadius: BorderRadius.circular(14),
      onTap: w.busy ? null : () => selectExercise(s, open ? null : id),
      child: Row(children: [
        if (!open && complete) ...[const DesignIcon('30:755'), const SizedBox(width: 8)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (open) const Text('التمرين الحالي', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _sessionGreen)),
          Text('$number. ${e['name']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: open ? 16 : 12, color: _sessionInk)),
          if (!open && (complete || skipped)) Text(skipped ? 'متخطى' : 'مكتمل', style: const TextStyle(fontSize: 10, color: _sessionGreen)),
        ])),
        if (!open) Text('${sets.length} جولات', style: const TextStyle(fontSize: 11, color: _sessionGreen)),
        if (open) ...[
          const SizedBox(width: 12),
          Container(width: 88, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(color: _sessionSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              const DesignIcon('30:824'),
              FittedBox(fit: BoxFit.scaleDown, child: Text(clockText(exerciseSeconds(id)), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: _sessionInk))),
              const Text('وقت هذا التمرين', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: _sessionGreen)),
            ])),
        ],
      ]),
    );
    return Container(
      key: ValueKey('exercise-card-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(open ? 16 : 12),
      decoration: BoxDecoration(
        color: open ? Colors.white : const Color(0xFFE2ECE5),
        border: open ? Border.all(color: const Color(0xFFC6DDB7)) : null,
        borderRadius: BorderRadius.circular(open ? 24 : 14),
        boxShadow: open ? [BoxShadow(color: const Color(0xFF1D4935).withValues(alpha: .08), offset: const Offset(0, 7), blurRadius: 24)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        if (open) ...[
          const SizedBox(height: 10),
          Text('الخطة المستهدفة: ${plans.length} جولات · ${plans.map((p) => PlannedSet.fromRow(Map<String, Object?>.from(p as Map)).describe(e['measurement_type'] == 'reps' ? MeasurementType.reps : MeasurementType.duration)).toSet().join(' / ')}${e['per_leg'] == 1 ? ' لكل رجل' : ''}${e['group_id'] == null ? '' : ' · سوبر سيت'}',
            style: const TextStyle(fontSize: 11, color: _sessionMuted)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _sessionSoft, borderRadius: BorderRadius.circular(8)),
            child: Text(previous[id] == null ? 'آخر أداء: لا يوجد أداء سابق مسجل'
              : 'آخر أداء (${previous[id]!['date_local']} · ${previous[id]!['day_name']}): ${(previous[id]!['sets'] as List<DbRow>).asMap().entries.map((p) => 'جولة ${p.key + 1}: ${setText(p.value, unit: w.settings.unit)}').join(' | ')}',
              style: const TextStyle(fontSize: 10, color: _sessionGreen))),
          for (var i = 0; i < sets.length; i++) _setRow(context, s, e, sets[i], i + 1),
          if (skipped) Text('سبب التخطي: ${e['skip_reason']}'),
          if (s.active && !skipped)
            SetEntry(key: ValueKey(id), exercise: e, previous: previous[id], onSaved: reload, onSkip: () => toggleSkip(context, e)),
          Wrap(spacing: 8, children: [
            if ((e['notes'] as String).isNotEmpty || e['image_file'] != null)
              TextButton(onPressed: () => setState(() { if (!explained.add(id)) explained.remove(id); }),
                child: Text(explained.contains(id) ? 'إخفاء الشرح' : 'شرح التمرين', style: const TextStyle(fontSize: 11))),
            if (s.active) TextButton(onPressed: w.busy ? null : () async {
              if (await workoutChange(context, () => w.repository.startTimer(id)) && context.mounted) await showRest(context);
            }, child: Text('راحة ${e['rest_seconds']} ثانية', style: const TextStyle(fontSize: 11))),
            if (s.active && skipped) TextButton(onPressed: w.busy ? null : () => toggleSkip(context, e), child: const Text('إلغاء التخطي')),
          ]),
          if (explained.contains(id)) ...[
            if (e['image_file'] != null) Image.file(File(context.read<ExerciseImageStore>().resolve(e['image_file'] as String)),
              height: 180, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Text('تعذر عرض الصورة')),
            Text(e['notes'] as String),
          ],
        ],
      ]),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text('✓ جولة $number: ${setText(set, unit: w.settings.unit)}', style: const TextStyle(fontSize: 11, color: _sessionInk)),
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
            icon: const DesignIcon('30:779'),
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
            icon: const DesignIcon('30:777'),
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
    this.onSkip,
  });
  final DbRow exercise;
  final DbRow? initial, previous;
  final bool correction;
  final VoidCallback? onSkip;
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
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _sessionInk),
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textDirection: TextDirection.ltr, validator: validWeight, onChanged: (_) => persist(),
    decoration: InputDecoration(labelText: 'الوزن (${unit == 'lb' ? 'باوند' : 'كجم'})',
        helperText: 'اختياري', hintText: '—', hintStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.muted), floatingLabelBehavior: FloatingLabelBehavior.always),
  );

  Widget _repsField() => TextFormField(
    key: const ValueKey('reps-input'), controller: reps, enabled: !saving,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _sessionInk),
    textAlign: TextAlign.center,
    keyboardType: TextInputType.number, textDirection: TextDirection.ltr,
    validator: positiveInt, onChanged: (_) => persist(),
    decoration: const InputDecoration(labelText: 'العدات', hintText: '—', hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.muted),
        floatingLabelBehavior: FloatingLabelBehavior.always),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Every form has a finite width, including forms opened after scrolling
      // and correction dialogs. No flex child receives an unbounded axis.
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.sizeOf(context).width - 80;
      final sideBySide = width >= 260 && MediaQuery.textScalerOf(context).scale(16) <= 22;
      return SizedBox(
        width: width,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(alignment: WrapAlignment.spaceBetween, children: [
                  Text(widget.initial == null ? 'الجولة ${(context.watch<WorkoutController>().active?.sets[widget.exercise['id']]?.length ?? 0) + 1} (التالية):' : 'تصحيح الأداء',
                    key: const ValueKey('next-set-heading'), style: const TextStyle(fontWeight: FontWeight.w800, color: _sessionInk, fontSize: 13)),
                  if (widget.initial == null) Text('${context.watch<WorkoutController>().active?.sets[widget.exercise['id']]?.length ?? 0} / ${(jsonDecode(widget.exercise['plan_json'] as String) as List).length} محفوظة', style: const TextStyle(fontSize: 10, color: _sessionGreen)),
                ]),
                if (draftError != null) Text(draftError!, style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 12),
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
                ExpansionTile(
                  tilePadding: EdgeInsets.zero, dense: true,
                  title: const Text('ملاحظة الجولة (اختياري)', style: TextStyle(fontSize: 11, color: _sessionMuted)),
                  children: [TextFormField(controller: notes, enabled: !saving, onChanged: (_) => persist(),
                    decoration: const InputDecoration(labelText: 'ملاحظة الجولة'))],
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
                Row(children: [
                  Expanded(child: FilledButton(
                    key: const ValueKey('save-set'),
                    style: FilledButton.styleFrom(backgroundColor: _sessionLime, foregroundColor: const Color(0xFF21470F),
                      minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'جارٍ الحفظ…' : widget.initial != null ? 'حفظ التعديل' : 'حفظ جولة ${(context.watch<WorkoutController>().active?.sets[widget.exercise['id']]?.length ?? 0) + 1} ✓', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  )),
                  if (widget.onSkip != null) ...[
                    const SizedBox(width: 10),
                    SizedBox(width: 86, child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: _sessionMuted, minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Color(0xFFDDE8E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: saving ? null : widget.onSkip, child: const Text('تخطي'))),
                  ],
                ]),
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
