import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/training_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../domain/exercise.dart';
import '../../domain/training_plan.dart';

String groupLabel(String id) => switch (id) {
  'day1_superset1' => 'دامبل مائل + رفرفة مائل',
  'day6_superset1' => 'السكوت + المطرقة',
  'day6_superset2' => 'مكينة تراي + ضغط ضيق',
  _ => id,
};

class _SetDraft {
  _SetDraft(PlannedSet set, bool duration)
    : id = set.id,
      low = TextEditingController(
        text: duration ? _minutes(set.durationMin) : set.repsMin?.toString(),
      ),
      high = TextEditingController(
        text: duration ? _minutes(set.durationMax) : set.repsMax?.toString(),
      ),
      weight = TextEditingController(text: set.weight?.toString());
  final String id;
  final TextEditingController low, high, weight;
  static String? _minutes(int? value) =>
      value == null ? null : (value / 60).toString();
  void dispose() {
    low.dispose();
    high.dispose();
    weight.dispose();
  }
}

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, required this.link});
  final DayExercise link;
  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController rest, group, notes;
  late final List<_SetDraft> drafts;
  late bool perLeg;
  bool saving = false;
  bool get duration =>
      widget.link.exercise.measurementType == MeasurementType.duration;
  @override
  void initState() {
    super.initState();
    rest = TextEditingController(text: '${widget.link.restSeconds}');
    group = TextEditingController(
      text: widget.link.groupId == null ? '' : groupLabel(widget.link.groupId!),
    );
    notes = TextEditingController(text: widget.link.notes);
    perLeg = widget.link.perLeg;
    drafts = widget.link.sets.map((s) => _SetDraft(s, duration)).toList();
  }

  @override
  void dispose() {
    rest.dispose();
    group.dispose();
    notes.dispose();
    for (final d in drafts) {
      d.dispose();
    }
    super.dispose();
  }

  int? target(String input) {
    if (input.trim().isEmpty) return null;
    final value = normalizeNumber(input);
    return duration ? (double.parse(value) * 60).round() : int.parse(value);
  }

  String? number(String? input, {bool optional = true, bool decimal = false}) {
    if (input == null || input.trim().isEmpty) {
      return optional ? null : 'أدخل القيمة';
    }
    final normalized = normalizeNumber(input);
    final value = decimal
        ? double.tryParse(normalized)
        : int.tryParse(normalized);
    return value == null || !value.isFinite || value <= 0
        ? 'أدخل رقمًا موجبًا'
        : null;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final state = context.read<TrainingController>();
    final sets = <PlannedSet>[];
    try {
      for (final d in drafts) {
        final lo = target(d.low.text), hi = target(d.high.text);
        final weight = d.weight.text.trim().isEmpty
            ? null
            : double.parse(normalizeNumber(d.weight.text));
        final s = PlannedSet(
          id: d.id,
          repsMin: duration ? null : lo,
          repsMax: duration ? null : hi,
          durationMin: duration ? lo : null,
          durationMax: duration ? hi : null,
          weight: duration ? null : weight,
        );
        s.validate(widget.link.exercise.measurementType);
        sets.add(s);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تحقق من الأهداف: الحد الأعلى لا يقل عن الأدنى، والوزن غير سالب.',
          ),
        ),
      );
      return;
    }
    final label = group.text.trim();
    String? groupId;
    if (label.isNotEmpty) {
      final existing = (state.entries[widget.link.dayId] ?? [])
          .map((l) => l.groupId)
          .whereType<String>()
          .where((id) => groupLabel(id) == label)
          .firstOrNull;
      groupId = existing ?? label;
    }
    setState(() => saving = true);
    final ok = await state.change(
      () => state.repository.savePlan(
        widget.link.id,
        sets: sets,
        restSeconds: int.parse(normalizeNumber(rest.text)),
        groupId: groupId,
        perLeg: perLeg,
        notes: notes.text,
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  Widget input(
    TextEditingController controller,
    String label, {
    bool weight = false,
  }) => TextFormField(
    controller: controller,
    enabled: !saving,
    keyboardType: TextInputType.numberWithOptions(decimal: duration || weight),
    decoration: InputDecoration(labelText: label),
    validator: weight
        ? (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = double.tryParse(normalizeNumber(v));
            return n == null || !n.isFinite || n < 0 ? 'وزن غير سالب' : null;
          }
        : (v) => number(v, decimal: duration),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              'خطة التمرين',
              widget.link.exercise.name,
              back: !saving,
            ),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const Text(
                      'أهداف كل جولة — يمكن تركها دون هدف',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < drafts.length; i++)
                      Padding(
                        key: ValueKey(drafts[i].id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'الجولة ${i + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: saving
                                        ? null
                                        : () {
                                            final removed = drafts[i];
                                            setState(() => drafts.removeAt(i));
                                            WidgetsBinding.instance
                                                .addPostFrameCallback(
                                                  (_) => removed.dispose(),
                                                );
                                          },
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: input(
                                      drafts[i].low,
                                      duration ? 'أقل مدة (دقيقة)' : 'أقل عدات',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: input(
                                      drafts[i].high,
                                      duration
                                          ? 'أقصى مدة (دقيقة)'
                                          : 'أقصى عدات',
                                    ),
                                  ),
                                ],
                              ),
                              if (!duration) ...[
                                const SizedBox(height: 12),
                                input(
                                  drafts[i].weight,
                                  'الوزن المستهدف (اختياري، كجم)',
                                  weight: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => setState(
                              () => drafts.add(
                                _SetDraft(
                                  PlannedSet(
                                    id: context
                                        .read<TrainingController>()
                                        .repository
                                        .newId(),
                                  ),
                                  duration,
                                ),
                              ),
                            ),
                      child: const Text('إضافة جولة مخططة'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: rest,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            'مدة الراحة بعد الجولة أو السوبر سيت (ثانية)',
                      ),
                      validator: (v) => number(v, optional: false),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: group,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'مجموعة سوبر سيت (اختياري)',
                        helperText:
                            'استخدم الاسم نفسه لتمرينين متتابعين في هذا اليوم.',
                      ),
                    ),
                    if (!duration)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('العدات لكل رجل'),
                        value: perLeg,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => perLeg = v),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notes,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات خاصة بهذه الخطة',
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ActionButton(
                saving ? 'جارٍ الحفظ...' : 'حفظ الخطة',
                node: '2:1265',
                onPressed: saving ? null : save,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
