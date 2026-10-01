enum MeasurementType { reps, duration }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.measurementType,
    this.imageFile,
    this.notes = '',
    this.archived = false,
  });

  final String id, name, category, notes;
  final MeasurementType measurementType;
  // Relative to the application's documents directory.
  final String? imageFile;
  final bool archived;

  factory Exercise.fromRow(Map<String, Object?> row) => Exercise(
    id: row['id'] as String,
    name: row['name'] as String,
    category: row['category'] as String,
    measurementType: MeasurementType.values.byName(
      row['measurement_type'] as String,
    ),
    imageFile: row['image_file'] as String?,
    notes: row['notes'] as String,
    archived: row['archived'] == 1,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name.trim(),
    'category': category.trim(),
    'measurement_type': measurementType.name,
    'image_file': imageFile,
    'notes': notes.trim(),
    'archived': archived ? 1 : 0,
  };

  void validate() {
    if (id.isEmpty || name.trim().isEmpty || category.trim().isEmpty) {
      throw ArgumentError('اسم التمرين وتصنيفه مطلوبان');
    }
  }
}
