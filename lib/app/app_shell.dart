import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/design_widgets.dart';
import '../features/exercises/exercise_library_screen.dart';
import '../features/schedule/schedule_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: selected,
      children: const [ScheduleScreen(), ExerciseLibraryScreen()],
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
              for (var i = 0; i < 2; i++)
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
                                  ? (selected == 0 ? '2:900' : '2:1078')
                                  : (selected == 1 ? '2:1082' : '2:904'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              i == 0 ? 'الجدول' : 'التمارين',
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
}
