import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/exercise_controller.dart';
import '../../app/training_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../domain/exercise.dart';
import '../../domain/training_plan.dart';
import '../exercises/exercise_editor_screen.dart';
import 'plan_editor_screen.dart';
import 'schedule_screen.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.dayId});
  final String dayId;
  Future<void> changed(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final state = context.read<TrainingController>();
    final ok = await state.change(action);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  Future<void> add(BuildContext context, {bool create = false}) async {
    final state = context.read<TrainingController>();
    final linkId = state.repository.newId();
    String? exerciseId;
    if (create) {
      exerciseId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ExerciseEditorScreen()),
      );
    } else {
      exerciseId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _ExercisePicker(),
      );
    }
    if (exerciseId == null || !context.mounted) return;
    final ok = await state.change(
      () => state.repository.link(dayId, exerciseId!, linkId),
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
      return;
    }
    final link = state.entries[dayId]!.firstWhere((e) => e.id == linkId);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PlanEditorScreen(link: link)),
    );
  }

  Future<void> archive(BuildContext context, TrainingDay day) async {
    final state = context.read<TrainingController>();
    if (day.archived) {
      await changed(context, () => state.repository.restoreDay(dayId));
      return;
    }
    String? replacement;
    if (state.currentDayId == dayId) {
      final alternatives = state.days.where((d) => d.id != dayId).toList();
      if (alternatives.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أضف يومًا بديلًا قبل أرشفة اليوم المستحق.'),
          ),
        );
        return;
      }
      replacement = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('اختر اليوم المستحق البديل'),
          children: [
            for (final d in alternatives)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, d.id),
                child: Text(d.name),
              ),
          ],
        ),
      );
      if (replacement == null || !context.mounted) return;
    }
    if (!context.mounted ||
        !await confirm(
          context,
          'أرشفة اليوم',
          'سيبقى اليوم وتمارينه محفوظين لاستعادتهما لاحقًا.',
        )) {
      return;
    }
    if (context.mounted) {
      await changed(
        context,
        () => state.repository.archiveDay(dayId, replacement: replacement),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingController>();
    final day = [
      ...state.days,
      ...state.archivedDays,
    ].where((d) => d.id == dayId).firstOrNull;
    if (day == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('اليوم غير موجود'))),
      );
    }
    final entries = state.entries[dayId] ?? [];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ScreenHeader(
                    day.name,
                    '${entries.length} تمارين مضافة${day.archived ? ' · مؤرشف' : ''}',
                    back: true,
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل اسم اليوم',
                  onPressed: state.busy
                      ? null
                      : () async {
                          final name = await editDayName(
                            context,
                            initial: day.name,
                          );
                          if (name != null && context.mounted) {
                            await changed(
                              context,
                              () => state.repository.saveDay(dayId, name),
                            );
                          }
                        },
                  icon: const DesignIcon('2:970'),
                ),
              ],
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DesignIcon('2:1060'),
                            SizedBox(height: 24),
                            Text(
                              'لم تُضف أي تمارين لهذا اليوم',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'اختر تمارين من المكتبة أو أنشئ تمرينًا جديدًا.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      buildDefaultDragHandles: false,
                      itemCount: entries.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (state.busy || day.archived) return;
                        final ids = entries.map((e) => e.id).toList();
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        changed(
                          context,
                          () => state.repository.reorderLinks(dayId, ids),
                        );
                      },
                      itemBuilder: (context, index) {
                        final link = entries[index];
                        return Padding(
                          key: ValueKey(link.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            enabled: !state.busy && !day.archived,
                            child: Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: state.busy || day.archived
                                    ? null
                                    : () => Navigator.push<void>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PlanEditorScreen(link: link),
                                        ),
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: AppColors.background,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  link.exercise.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  link.summary,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (link.groupId != null)
                                                  Text(
                                                    'سوبر سيت: ${groupLabel(link.groupId!)}',
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'إزالة الربط من اليوم',
                                            onPressed:
                                                state.busy || day.archived
                                                ? null
                                                : () async {
                                                    if (await confirm(
                                                      context,
                                                      'إزالة التمرين من اليوم',
                                                      'يبقى تعريف التمرين في المكتبة.',
                                                    )) {
                                                      if (context.mounted) {
                                                        await changed(
                                                          context,
                                                          () => state.repository
                                                              .unlink(link.id),
                                                        );
                                                      }
                                                    }
                                                  },
                                            icon: const DesignIcon('2:983'),
                                          ),
                                        ],
                                      ),
                                      if (link.exercise.notes.isNotEmpty ||
                                          link.notes.isNotEmpty)
                                        ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          title: const Text(
                                            'طريقة العمل والهدف',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          children: [
                                            Align(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: Text(
                                                [
                                                      link.exercise.notes,
                                                      link.notes,
                                                    ]
                                                    .where((s) => s.isNotEmpty)
                                                    .join('\n\n'),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            TextButton(
              onPressed: state.busy ? null : () => archive(context, day),
              child: Text(
                day.archived ? 'استعادة اليوم' : 'أرشفة اليوم',
                style: TextStyle(
                  color: day.archived ? AppColors.primary : AppColors.danger,
                ),
              ),
            ),
            if (!day.archived)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    ActionButton(
                      'إضافة تمرين من المكتبة',
                      node: '2:1031',
                      onPressed: state.busy ? null : () => add(context),
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      'إنشاء تمرين جديد مخصص',
                      secondary: true,
                      onPressed: state.busy
                          ? null
                          : () => add(context, create: true),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();
  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExerciseController>();
    final entries = state.exercises
        .where(
          (e) =>
              !e.archived &&
              '${e.name} ${e.category}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              const ScreenHeader(
                'اختر تمرينًا',
                'الربط يتيح خطة مختلفة لكل يوم',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن تمرين...',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('لا توجد تمارين مطابقة.'))
                    : ListView(
                        children: [
                          for (final Exercise ex in entries)
                            ListTile(
                              title: Text(ex.name),
                              subtitle: Text(ex.category),
                              onTap: () => Navigator.pop(context, ex.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
