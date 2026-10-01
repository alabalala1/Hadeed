import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'workout_controller.dart';
import 'training_controller.dart';
import '../features/workout/workout_widgets.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/design_widgets.dart';
import '../features/exercises/exercise_library_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/workout/today_screen.dart';
import '../features/workout/history_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: context.watch<WorkoutController>().onboarding
        ? _welcome(context)
        : IndexedStack(
            index: selected,
            children: const [
              TodayScreen(),
              ScheduleScreen(),
              ExerciseLibraryScreen(),
              HistoryScreen(),
            ],
          ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Semantics(
                    selected: selected == i,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => selected = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DesignIcon(
                              i == 0
                                  ? (selected == 0 ? '2:529' : '2:1516')
                                  : i == 1
                                  ? (selected == 1 ? '2:900' : '2:1078')
                                  : i == 2
                                  ? (selected == 2 ? '2:1082' : '2:904')
                                  : (selected == 3 ? '2:1528' : '2:538'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ['اليوم', 'الجدول', 'التمارين', 'السجل'][i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected == i
                                    ? AppColors.primary
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _welcome(BuildContext context) {
    final w = context.watch<WorkoutController>();
    final t = context.watch<TrainingController>();
    Future<void> choose(bool ready) async {
      if (await workoutChange(
            context,
            () => w.repository.onboarding(useTemplate: ready),
          ) &&
          context.mounted) {
        await t.load();
        if (mounted) setState(() => selected = ready ? 0 : 1);
      }
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ScreenHeader(
            'مرحبًا بك في حديد',
            'ابدأ بالقائمة التي قدمتها أو أنشئ جدولًا مخصصًا',
          ),
          WorkoutCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'جدول الأيام الستة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                for (final day in t.days)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${day.order + 1}. ${day.name}'),
                  ),
                const Text(
                  'الأسماء والخطط قابلة للتعديل. تعريفات التمارين تبقى في المكتبة حتى لو بدأت جدولًا مخصصًا.',
                ),
              ],
            ),
          ),
          ActionButton(
            'استخدام الجدول الجاهز',
            onPressed: w.busy ? null : () => choose(true),
          ),
          const SizedBox(height: 12),
          ActionButton(
            'بدء جدول مخصص',
            secondary: true,
            onPressed: w.busy ? null : () => choose(false),
          ),
        ],
      ),
    );
  }
}
