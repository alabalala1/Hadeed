import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/exercise_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_widgets.dart';
import '../../data/exercise_image_store.dart';
import '../../domain/exercise.dart';

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({super.key, this.exercise});
  final Exercise? exercise;
  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  final form = GlobalKey<FormState>();
  late final String id;
  late final TextEditingController name, category, notes;
  late MeasurementType type;
  String? selectedPath;
  bool removeImage = false;
  bool saving = false;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    id = widget.exercise?.id ?? const Uuid().v4();
    name = TextEditingController(text: widget.exercise?.name);
    category = TextEditingController(text: widget.exercise?.category);
    notes = TextEditingController(text: widget.exercise?.notes);
    type = widget.exercise?.measurementType ?? MeasurementType.reps;
  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    if (picking || saving) return;
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(source: source);
      if (file != null && mounted) {
        setState(() {
          selectedPath = file.path;
          removeImage = false;
        });
      }
    } catch (_) {
      if (mounted) message('تعذر اختيار الصورة. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('اختيار من الصور'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await pickImage(source);
  }

  Future<void> save() async {
    if (saving || picking || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final state = context.read<ExerciseController>();
    final images = context.read<ExerciseImageStore>();
    String? copied;
    final old = widget.exercise?.imageFile;
    final ok = await state.change(() async {
      if (selectedPath != null) copied = await images.copy(selectedPath!);
      try {
        await state.repository.save(
          Exercise(
            id: id,
            name: name.text,
            category: category.text,
            notes: notes.text,
            measurementType: type,
            imageFile: copied ?? (removeImage ? null : old),
            archived: widget.exercise?.archived ?? false,
          ),
        );
      } catch (_) {
        if (copied != null) {
          try {
            await images.delete(copied!);
          } catch (_) {
            /* Keep the original database failure. */
          }
        }
        rethrow;
      }
    });
    if (ok && old != null && (copied != null || removeImage)) {
      // Cleanup follows the successful database commit; it must never undo it.
      try {
        await images.delete(old);
      } catch (_) {
        /* Orphan cleanup can retry later. */
      }
    }
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      message(state.error ?? 'تعذر الحفظ');
    }
  }

  Future<void> archive() async {
    final state = context.read<ExerciseController>();
    final archived = widget.exercise!.archived;
    if (!await confirm(
      context,
      archived ? 'استعادة التمرين' : 'أرشفة التمرين',
      archived
          ? 'إعادة التمرين إلى المكتبة النشطة؟'
          : 'سيختفي من المكتبة النشطة وتبقى بياناته محفوظة.',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await state.change(
      () => state.repository.setArchived(id, !archived),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      message(state.error!);
    }
  }

  Widget field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExerciseController>();
    final images = context.read<ExerciseImageStore>();
    final path =
        selectedPath ??
        (removeImage || widget.exercise?.imageFile == null
            ? null
            : images.resolve(widget.exercise!.imageFile!));
    final busy = saving || picking || state.busy;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                widget.exercise == null ? 'إضافة تمرين جديد' : 'تعديل التمرين',
                'أضف تمرينك المخصص مع أهدافك',
                back: !busy,
              ),
              Expanded(
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      field(
                        'اسم التمرين *',
                        TextFormField(
                          controller: name,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'أدخل اسم التمرين'
                              : null,
                        ),
                      ),
                      field(
                        'التصنيف وعضلة الاستهداف *',
                        TextFormField(
                          controller: category,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'مثل: صدر، ظهر، رجل، كارديو',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'أدخل تصنيف التمرين'
                              : null,
                        ),
                      ),
                      field(
                        'نوع القياس',
                        DropdownButtonFormField<MeasurementType>(
                          initialValue: type,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: MeasurementType.reps,
                              child: Text('تكرارات ووزن'),
                            ),
                            DropdownMenuItem(
                              value: MeasurementType.duration,
                              child: Text('مدة زمنية / كارديو'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(() => type = value!),
                          icon: const SizedBox(width: 18),
                        ),
                      ),
                      field(
                        'صورة توضيحية (اختياري)',
                        Column(
                          children: [
                            Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: InkWell(
                                onTap: busy ? null : chooseImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: path == null
                                        ? const Column(
                                            children: [
                                              DesignIcon('2:1243'),
                                              SizedBox(height: 8),
                                              Text(
                                                'اختر أو التقط صورة',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Image.file(
                                            File(path),
                                            height: 160,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, error, stack) =>
                                                const Text(
                                                  'تعذر فتح الصورة؛ يمكنك اختيار صورة بديلة.',
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (path != null)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                        selectedPath = null;
                                        removeImage = true;
                                      }),
                                child: const Text('إزالة الصورة'),
                              ),
                          ],
                        ),
                      ),
                      field(
                        'ملاحظات الأداء وتنبيهات الأمان',
                        TextFormField(
                          controller: notes,
                          enabled: !busy,
                          minLines: 2,
                          maxLines: 4,
                        ),
                      ),
                      const Text(
                        'تُحدد أهداف الجولات والتكرارات والراحة لكل يوم عند ربط التمرين به.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      if (widget.exercise != null)
                        TextButton(
                          onPressed: busy ? null : archive,
                          child: Text(
                            widget.exercise!.archived
                                ? 'استعادة التمرين'
                                : 'أرشفة التمرين',
                            style: TextStyle(
                              color: widget.exercise!.archived
                                  ? AppColors.primary
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    ActionButton(
                      saving ? 'جارٍ الحفظ...' : 'حفظ التمرين',
                      node: '2:1265',
                      onPressed: busy ? null : save,
                    ),
                    const SizedBox(height: 12),
                    ActionButton(
                      'إلغاء التعديلات',
                      secondary: true,
                      onPressed: busy ? null : () => Navigator.pop(context),
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
