import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

// Exact exports of Figma's clipped icon slots, including their root dimensions.
class DesignIcon extends StatelessWidget {
  const DesignIcon(this.node, {super.key, this.color});
  final String node;
  final Color? color;
  static const _primaryNodes = {'2:649', '2:1528', '2:529', '2:900',
    '2:643', '2:1082', '2:661', '2:622', '2:1243', '2:574',
    '2:970', '2:664', '2:1120', '2:1060', '2:646'};
  @override
  Widget build(BuildContext context) {
    final tint = color ?? (_primaryNodes.contains(node) ? AppColors.primary : null);
    return SvgPicture.asset('assets/icons/${node.replaceAll(':', '_')}.svg',
      colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn));
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(
    this.title,
    this.subtitle, {
    super.key,
    this.back = false,
    this.backNode = '2:1224',
    this.trailing,
  });
  final String title, subtitle;
  final bool back;
  final String backNode;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(20),
      ),
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
            icon: DesignIcon(backNode),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 28, height: 3, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.onDarkMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
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
        if (node != null) ...[DesignIcon(node!, color: secondary ? AppColors.primary : AppColors.onAccent), const SizedBox(width: 8)],
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
