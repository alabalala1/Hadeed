import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/training_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../domain/training_plan.dart';
import 'day_detail_screen.dart';

Future<String?> editDayName(BuildContext context, {String initial = ''}) async {
  final input = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial.isEmpty ? 'إضافة يوم تدريب' : 'تعديل اسم اليوم'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم اليوم'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'أدخل اسم اليوم' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, input.text.trim());
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  // Let the dialog's reverse transition finish before releasing its controller.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(milliseconds: 300), input.dispose);
  });
  return result;
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool archived = false;
  Future<void> add() async {
    final state = context.read<TrainingController>();
    final id = state.repository.newId();
    final name = await editDayName(context);
    if (name == null || !mounted) return;
    final ok = await state.change(() => state.repository.saveDay(id, name));
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  Future<void> reorder(
    List<TrainingDay> days,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem already supplies the final insertion index.
    final ids = days.map((d) => d.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    final state = context.read<TrainingController>();
    final ok = await state.change(() => state.repository.reorderDays(ids));
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingController>();
    final days = archived ? state.archivedDays : state.days;
    Widget card(TrainingDay day, int index) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: day.id == state.currentDayId
              ? AppColors.primary
              : AppColors.border,
          width: day.id == state.currentDayId ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state.busy
            ? null
            : () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DayDetailScreen(dayId: day.id),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: day.id == state.currentDayId
                      ? AppColors.primarySoft
                      : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(
                          '${day.exerciseCount} تمارين',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (day.id == state.currentDayId)
                          const Text(
                            'اليوم المستحق',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader('جدول التدريب', 'أيام الدورة التدريبية'),
            if (archived || state.archivedDays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('الأيام النشطة'),
                      selected: !archived,
                      onSelected: (_) => setState(() => archived = false),
                    ),
                    ChoiceChip(
                      label: const Text('المؤرشفة'),
                      selected: archived,
                      onSelected: (_) => setState(() => archived = true),
                    ),
                  ],
                ),
              ),
            if (!archived && days.length > 1)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'اضغط مطولًا على اليوم واسحبه لتغيير الترتيب.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: state.load,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : days.isEmpty
                  ? const Center(child: Text('لا توجد أيام في هذه القائمة.'))
                  : archived
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < days.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card(days[i], i),
                          ),
                      ],
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      buildDefaultDragHandles: false,
                      itemCount: days.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (!state.busy) reorder(days, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) => Padding(
                        key: ValueKey(days[index].id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          enabled: !state.busy,
                          child: card(days[index], index),
                        ),
                      ),
                    ),
            ),
            if (state.generalNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'ملاحظات البرنامج',
                    style: TextStyle(fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(state.generalNote),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: ActionButton(
                'إضافة يوم تدريب مخصص',
                node: '2:890',
                onPressed: state.busy || state.loading ? null : add,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
