import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/training_controller.dart';
import '../../app/workout_controller.dart';
import '../../core/widgets/design_widgets.dart';
import '../../domain/workout.dart';
import 'session_screen.dart';
import 'settings_screen.dart';
import 'workout_widgets.dart';
import '../schedule/day_detail_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});
  Future<void> start(BuildContext context) async {
    final w = context.read<WorkoutController>();
    String? id = w.active?.id;
    if (id == null &&
        !await workoutChange(context, () async {
          id = await w.repository.start();
        })) {
      return;
    }
    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => SessionScreen(id: id!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrainingController>();
    final w = context.watch<WorkoutController>();
    final day = t.days.where((d) => d.id == t.currentDayId).firstOrNull;
    final last = w.history
        .where((e) => e['day_id'] == day?.id && e['status'] == 'completed')
        .firstOrNull;
    final links = t.entries[day?.id] ?? [];
    final date = DateTime.now();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Row(
            children: [
              Expanded(
                child: ScreenHeader('الحصة التدريبية اليوم', localDate(date)),
              ),
              IconButton(
                tooltip: 'الإعدادات',
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (w.loading || t.loading) const LinearProgressIndicator(),
                if (w.error != null)
                  WorkoutCard(
                    child: Column(
                      children: [
                        Text(w.error!),
                        TextButton(
                          onPressed: w.load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                if (w.active != null)
                  WorkoutCard(
                    tint: const Color(0xFFFEF3C7),
                    child: Row(
                      children: [
                        const DesignIcon('2:526'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'لديك جلسة قيد التنفيذ\n${w.active!.row['day_name']} · ${w.active!.row['date_local']}',
                          ),
                        ),
                      ],
                    ),
                  ),
                WorkoutCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('التدريب التالي المستحق:'),
                      Text(
                        day?.name ?? 'جدولك فارغ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${links.length} تمارين · ${last == null ? 'لا يوجد أداء سابق' : 'آخر مرة: ${last['date_local']}'}',
                      ),
                      const Divider(height: 32),
                      for (
                        var i = 0;
                        i < (links.length < 3 ? links.length : 3);
                        i++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${i + 1}. ${links[i].exercise.name}\n${links[i].summary}',
                          ),
                        ),
                      if (links.length > 3)
                        TextButton(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DayDetailScreen(dayId: day!.id),
                            ),
                          ),
                          child: Text(
                            '+ ${links.length - 3} تمارين أخرى — تفاصيل اليوم',
                          ),
                        ),
                      if (links.isEmpty)
                        const Text('أضف يومًا وتمارين من تبويب الجدول.'),
                      const SizedBox(height: 16),
                      ActionButton(
                        w.active == null
                            ? 'بدء التمرين الآن'
                            : 'استكمال الجلسة الحالية',
                        node: '2:697',
                        onPressed: w.busy || (w.active == null && links.isEmpty)
                            ? null
                            : () => start(context),
                      ),
                      const SizedBox(height: 12),
                      ActionButton(
                        'تسجيل يوم راحة',
                        secondary: true,
                        node: '2:661',
                        onPressed: w.busy || w.active != null
                            ? null
                            : () => restDay(context),
                      ),
                    ],
                  ),
                ),
                WorkoutCard(
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    children: [
                      Metric(
                        'جلسات مكتملة',
                        '${w.history.where((h) => h['status'] == 'completed').length}',
                      ),
                      Metric(
                        'أيام راحة',
                        '${w.history.where((h) => h['kind'] == 'rest').length}',
                      ),
                      Metric(
                        'جولات مسجلة',
                        '${w.history.fold<int>(0, (s, e) => s + ((e['set_count'] as int?) ?? 0))}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> restDay(BuildContext context) async {
  final w = context.read<WorkoutController>();
  final t = context.read<TrainingController>();
  final due = t.days.where((d) => d.id == t.currentDayId).firstOrNull;
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  if (date == null || !context.mounted) return;
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('تأكيد يوم راحة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${localDate(date)}\nسيبقى التدريب المستحق: ${due?.name ?? 'غير محدد'}',
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('تسجيل الراحة'),
        ),
      ],
    ),
  );
  final text = reason.text;
  if (ok == true && context.mounted) {
    await workoutChange(context, () => w.repository.rest(date, text));
  }
  Future<void>.delayed(const Duration(milliseconds: 300), reason.dispose);
}
