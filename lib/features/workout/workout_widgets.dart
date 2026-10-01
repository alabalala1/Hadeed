import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/workout_controller.dart';
import '../../core/theme/app_theme.dart';

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.child,
    this.highlight = false,
    this.tint,
  });
  final Widget child;
  final bool highlight;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlight ? AppColors.primary : AppColors.border,
        width: highlight ? 1.5 : 1,
      ),
    ),
    child: child,
  );
}

Future<bool> workoutChange(
  BuildContext context,
  Future<void> Function() action,
) async {
  final state = context.read<WorkoutController>();
  final ok = await state.change(action);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.error ?? 'انتظر اكتمال الحفظ')),
    );
  }
  return ok;
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    ),
  );
}
