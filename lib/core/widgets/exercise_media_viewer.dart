import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/exercise_image_store.dart';
import '../theme/app_theme.dart';

Future<void> showExerciseMedia(
  BuildContext context, {
  required String name,
  required String imageFile,
}) async {
  final file = File(context.read<ExerciseImageStore>().resolve(imageFile));
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        key: const ValueKey('exercise-media-viewer'),
        appBar: AppBar(
          backgroundColor: AppColors.dark,
          foregroundColor: Colors.white,
          title: Text(name),
          leading: IconButton(
            tooltip: 'إغلاق الصورة',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 4,
                  child: SizedBox.expand(
                    child: Image.file(
                      file,
                      key: const ValueKey('exercise-media-image'),
                      fit: BoxFit.contain,
                      semanticLabel: 'صورة تمرين $name',
                      errorBuilder: (_, error, _) {
                        assert(() { debugPrint('Exercise media read failed: $error'); return true; }());
                        return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'تعذر عرض الصورة المرفقة. يمكنك إعادة إضافتها من مكتبة التمارين.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('كبّر الصورة بإصبعين واسحب لعرض التفاصيل'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
