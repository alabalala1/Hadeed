import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/workout_controller.dart';
import '../../core/widgets/design_widgets.dart';
import '../../domain/workout.dart';
import 'session_screen.dart';
import 'workout_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '', filter = 'all';
  String? date, day;
  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutController>();
    final names = {
      for (final e in w.history)
        if (e['day_id'] != null) e['day_id'] as String: e['day_name'] as String,
    };
    final rows = w.history
        .where(
          (e) =>
              (filter == 'all' ||
                  e['kind'] == filter ||
                  e['status'] == filter) &&
              (date == null || e['date_local'] == date) &&
              (day == null || e['day_id'] == day) &&
              '${e['day_name']} ${e['exercise_names'] ?? ''} ${e['reason']}'
                  .toLowerCase()
                  .contains(query.toLowerCase().trim()),
        )
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ScreenHeader('سجل التمارين', 'تتبع جلساتك الرياضية وأداءك'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم اليوم أو التمرين أو سبب الراحة',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in {
                      'all': 'الكل',
                      'completed': 'مكتملة',
                      'abandoned': 'متروكة',
                      'rest': 'راحة',
                    }.entries)
                      ChoiceChip(
                        label: Text(f.value),
                        selected: filter == f.key,
                        onSelected: (_) => setState(() => filter = f.key),
                      ),
                  ],
                ),
                DropdownButton<String>(
                  value: names.containsKey(day) ? day : null,
                  isExpanded: true,
                  hint: const Text('كل أيام التدريب'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('كل أيام التدريب'),
                    ),
                    for (final entry in names.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => day = v),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (d != null && mounted) {
                          setState(() => date = localDate(d));
                        }
                      },
                      child: Text(date ?? 'تصفية بالتاريخ'),
                    ),
                    if (date != null)
                      TextButton(
                        onPressed: () => setState(() => date = null),
                        child: const Text('كل التواريخ'),
                      ),
                  ],
                ),
                if (w.error != null) Text(w.error!),
                if (rows.isEmpty)
                  const WorkoutCard(
                    child: Text(
                      'لا توجد سجلات مطابقة. تظهر جلساتك وأيام راحتك هنا بعد تسجيلها.',
                    ),
                  ),
                for (final row in rows)
                  WorkoutCard(
                    highlight: row['status'] == 'completed',
                    child: InkWell(
                      onTap: () => open(context, row),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row['date_local'] as String),
                          Text(
                            row['kind'] == 'rest'
                                ? 'يوم راحة'
                                : row['day_name'] as String,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            row['kind'] == 'rest'
                                ? 'الراحة · التدريب المستحق: ${row['day_name']}'
                                : row['status'] == 'completed'
                                ? 'مكتملة'
                                : row['status'] == 'active'
                                ? 'جارية'
                                : 'متروكة',
                          ),
                          if (row['kind'] == 'rest')
                            Text('السبب: ${row['reason']}')
                          else
                            Text(
                              '${row['set_count']} جولات · ${row['ended_at'] == null ? 'قيد التنفيذ' : clockText(((row['ended_at'] as int) - (row['started_at'] as int)) ~/ 1000)}',
                            ),
                          if (row['exercise_names'] != null)
                            Text(row['exercise_names'] as String),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> open(BuildContext context, DbRow row) async {
    if (row['kind'] == 'rest') {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('راحة ${row['date_local']}'),
          content: Text(
            'التدريب المستحق حين التسجيل: ${row['day_name']}\n${row['reason']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('عودة'),
            ),
          ],
        ),
      );
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(id: row['session_id'] as String),
        ),
      );
    }
  }
}
