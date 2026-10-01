import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/exercise_controller.dart';
import '../../app/training_controller.dart';
import '../../app/workout_controller.dart';
import '../../core/widgets/design_widgets.dart';
import '../../data/backup_repository.dart';
import '../../domain/training_plan.dart';
import '../../domain/workout.dart';
import 'workout_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final form = GlobalKey<FormState>();
  final rest = TextEditingController();
  late bool auto, sound, vibration;
  late String unit;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final s = context.read<WorkoutController>().settings;
    rest.text = '${s.restSeconds}';
    auto = s.autoRest;
    sound = s.sound;
    vibration = s.vibration;
    unit = s.unit;
  }

  Future<void> fileAction(bool restore) async {
    if (busy) return;
    setState(() => busy = true);
    final w = context.read<WorkoutController>();
    final backup = context.read<BackupRepository>();
    try {
      if (restore) {
        final bytes = await w.bridge.importFile();
        if (bytes == null) return;
        final preview = await backup.preview(bytes);
        if (!mounted ||
            !await confirm(
              context,
              'استعادة النسخة — ${preview.summary}',
              'سيتم استبدال البيانات الحالية والصور. الجلسة الجارية في النسخة تُستعاد قابلة للاستكمال وتحتسب الوقت من بدايتها الأصلية؛ مؤقت الراحة والتنبيه لا يُستعادان. هل تؤكد؟',
            )) {
          return;
        }
        await backup.restore(preview);
        await w.load();
        if (!mounted) return;
        await context.read<TrainingController>().load();
        if (!mounted) return;
        await context.read<ExerciseController>().load();
        if (!mounted) return;
        final s = w.settings;
        rest.text = '${s.restSeconds}';
        auto = s.autoRest;
        sound = s.sound;
        vibration = s.vibration;
        unit = s.unit;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تمت الاستعادة بنجاح')));
      } else {
        final bytes = await backup.export();
        final saved = await w.bridge.exportFile(bytes);
        if (saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تصدير البيانات والصور إلى الملف المختار'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restore
                  ? 'تعذرت الاستعادة. البيانات الحالية محفوظة؛ تأكد من نسخة حديد سليمة.'
                  : 'تعذر تصدير النسخة. تحقق من الصور ومساحة التخزين.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WorkoutController>();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(
                'الإعدادات',
                'تخصيص التطبيق والبيانات المحلية',
                back: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    WorkoutCard(
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'تفضيلات التمرين',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            DropdownButton<String>(
                              value: unit,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'kg',
                                  child: Text('كجم'),
                                ),
                                DropdownMenuItem(
                                  value: 'lb',
                                  child: Text('باوند'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => unit = v!),
                            ),
                            const Text(
                              'الأوزان محفوظة بالكيلوجرام؛ تغيير الوحدة يغير العرض والإدخال فقط.',
                            ),
                            TextFormField(
                              controller: rest,
                              enabled: !busy,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse(
                                  normalizeNumber(v ?? ''),
                                );
                                return n != null && n > 0 && n <= 86400
                                    ? null
                                    : 'ثوانٍ بين 1 و86400';
                              },
                              decoration: const InputDecoration(
                                labelText: 'الراحة الافتراضية (ثانية)',
                              ),
                            ),
                            const Text(
                              'تُطبق على الروابط الجديدة؛ الراحة الخاصة بكل خطة تبقى كما ضبطتها.',
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('راحة تلقائية بعد حفظ الجولة'),
                              subtitle: const Text(
                                'في السوبر سيت بعد التمرين الأخير في المجموعة',
                              ),
                              value: auto,
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => auto = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('صوت التنبيه'),
                              value: sound,
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => sound = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('اهتزاز التنبيه'),
                              value: vibration,
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => vibration = v),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final allowed = await w.bridge
                                          .permission();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              allowed
                                                  ? 'تنبيهات الراحة متاحة وفق إعدادات Android'
                                                  : 'رفض الإذن لا يمنع المؤقت أو حفظ الجولات',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('تفعيل إذن إشعارات الراحة'),
                            ),
                            const Text(
                              'قد يؤخر Android التنبيه في الخلفية لتوفير الطاقة. المنع الإجباري يوقف التنبيهات؛ بعد العودة يظهر الوقت المحفوظ.',
                            ),
                            ActionButton(
                              'حفظ الإعدادات',
                              onPressed: busy || w.busy
                                  ? null
                                  : () async {
                                      if (!form.currentState!.validate()) {
                                        return;
                                      }
                                      final ok = await workoutChange(
                                        context,
                                        () => w.repository.saveSettings(
                                          WorkoutSettings(
                                            restSeconds: int.parse(
                                              normalizeNumber(rest.text),
                                            ),
                                            autoRest: auto,
                                            sound: sound,
                                            vibration: vibration,
                                            unit: unit,
                                          ),
                                        ),
                                      );
                                      if (ok && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم حفظ الإعدادات'),
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    WorkoutCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'النسخ الاحتياطي والبيانات',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          ActionButton(
                            'تصدير البيانات والصور',
                            secondary: true,
                            onPressed: busy ? null : () => fileAction(false),
                          ),
                          const SizedBox(height: 12),
                          ActionButton(
                            'استعادة نسخة احتياطية',
                            secondary: true,
                            onPressed: busy ? null : () => fileAction(true),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'اختر مكان الملف بنفسك. استعادة النسخة تستبدل البيانات الحالية بعد المعاينة والتأكيد. حذف التطبيق قد يحذف بياناته؛ احتفظ بنسخة خارج مجلده.',
                          ),
                        ],
                      ),
                    ),
                    WorkoutCard(
                      tint: const Color(0xFFFEE2E2),
                      child: ActionButton(
                        'إعادة ضبط الدورة إلى أول يوم',
                        secondary: true,
                        onPressed: busy || w.busy
                            ? null
                            : () async {
                                if (!await confirm(
                                  context,
                                  'إعادة ضبط مؤشر الدورة',
                                  'العودة لأول يوم نشط دون حذف السجل؟',
                                )) {
                                  return;
                                }
                                if (context.mounted &&
                                    await workoutChange(
                                      context,
                                      w.repository.resetCycle,
                                    ) &&
                                    context.mounted) {
                                  await context
                                      .read<TrainingController>()
                                      .load();
                                }
                              },
                      ),
                    ),
                    if (busy) const LinearProgressIndicator(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    rest.dispose();
    super.dispose();
  }
}
