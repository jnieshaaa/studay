class Subject {
  final String id;
  final String name;
  final String description;
  final String icon; // Icon identifier
  final int sortOrder;
  final bool isActive;

  const Subject({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? 'book',
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class Topic {
  final String id;
  final String subjectId;
  final String name;
  final String description;
  final int sortOrder;

  const Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.description,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'name': name,
        'description': description,
        'sort_order': sortOrder,
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        subjectId: json['subject_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
