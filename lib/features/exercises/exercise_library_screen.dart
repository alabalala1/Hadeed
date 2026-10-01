import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/exercise_controller.dart';
import '../../app/training_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../data/exercise_image_store.dart';
import '../../domain/exercise.dart';
import '../schedule/plan_editor_screen.dart';
import 'exercise_editor_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String query = '';
  bool archived = false;

  String usage(TrainingController training, Exercise exercise) {
    final names = training.days
        .where(
          (day) => (training.entries[day.id] ?? []).any(
            (link) => link.exercise.id == exercise.id,
          ),
        )
        .map((d) => d.name)
        .toList();
    return names.isEmpty
        ? 'المجموعة: غير مستخدم حاليًا'
        : 'المجموعة: ${names.join('، ')}';
  }

  Future<void> edit([Exercise? exercise]) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExerciseController>();
    final training = context.watch<TrainingController>();
    final available = state.exercises
        .where((e) => e.archived == archived)
        .toList();
    final entries = available
        .where(
          (e) => '${e.name} ${e.category}'.toLowerCase().contains(
            query.trim().toLowerCase(),
          ),
        )
        .toList();
    final groups = <String, List<Exercise>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.category, () => []).add(e);
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader('مكتبة التمارين', 'قاعدة تمارينك الرياضية'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'ابحث عن تمرين...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(15),
                    child: DesignIcon('2:1055'),
                  ),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            if (archived || state.exercises.any((e) => e.archived))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('التمارين النشطة'),
                      selected: !archived,
                      onSelected: (_) => setState(() => archived = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('المؤرشفة'),
                      selected: archived,
                      onSelected: (_) => setState(() => archived = true),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
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
                  : entries.isEmpty
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(child: DesignIcon('2:1060')),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              query.isNotEmpty
                                  ? 'لا توجد نتائج'
                                  : archived
                                  ? 'لا توجد تمارين مؤرشفة'
                                  : 'مكتبة التمارين فارغة',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              query.isNotEmpty
                                  ? 'جرّب اسمًا أو تصنيفًا آخر.'
                                  : 'أضف أول تمرين لبدء بناء مكتبتك التدريبية وتخصيص حصصك.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final group in groups.entries) ...[
                          Text(
                            group.key,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final e in group.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: state.busy ? null : () => edit(e),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: e.imageFile == null
                                              ? const Center(
                                                  child: DesignIcon('2:1120'),
                                                )
                                              : ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(
                                                      context
                                                          .read<
                                                            ExerciseImageStore
                                                          >()
                                                          .resolve(
                                                            e.imageFile!,
                                                          ),
                                                    ),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, error, stack) =>
                                                            const Center(
                                                              child: DesignIcon(
                                                                '2:1120',
                                                              ),
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
                                                e.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                usage(training, e),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!e.archived)
                                          TextButton(
                                            onPressed: training.busy
                                                ? null
                                                : () => linkToDay(e),
                                            child: const Text('ربط'),
                                          ),
                                        // Figma's chevron layer is empty; preserve its 18px slot.
                                        const SizedBox(width: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: ActionButton(
                'إضافة تمرين جديد للمكتبة',
                node: '2:1068',
                onPressed: state.loading || state.busy || state.error != null
                    ? null
                    : () => edit(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> linkToDay(Exercise exercise) async {
    final t = context.read<TrainingController>();
    final day = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('ربط التمرين بيوم'),
        children: [
          if (t.days.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('أضف يومًا من الجدول أولًا.'),
            ),
          for (final d in t.days)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, d.id),
              child: Text(d.name),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    final id = t.repository.newId();
    final ok = await t.change(() => t.repository.link(day, exercise.id, id));
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.error ?? 'تعذر الربط')));
      return;
    }
    final link = t.entries[day]!.firstWhere((e) => e.id == id);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PlanEditorScreen(link: link)),
    );
  }
}
