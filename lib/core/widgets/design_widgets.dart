import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

// Exact exports of Figma's clipped icon slots, including their root dimensions.
class DesignIcon extends StatelessWidget {
  const DesignIcon(this.node, {super.key});
  final String node;
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icons/${node.replaceAll(':', '_')}.svg');
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, this.subtitle, {super.key, this.back = false});
  final String title, subtitle;
  final bool back;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        if (back) ...[
          IconButton(
            tooltip: 'رجوع',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.maybePop(context),
            icon: const DesignIcon('2:1224'),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.node,
    this.secondary = false,
  });
  final String label;
  final String? node;
  final VoidCallback? onPressed;
  final bool secondary;
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (node != null) ...[DesignIcon(node!), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: secondary
          ? OutlinedButton(onPressed: onPressed, child: child)
          : FilledButton(onPressed: onPressed, child: child),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ) ??
    false;
