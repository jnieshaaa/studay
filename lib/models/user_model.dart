class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  final List<String> createdExamIds;
  final List<String> savedSubjectIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.createdExamIds = const [],
    this.savedSubjectIds = const [],
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
    List<String>? createdExamIds,
    List<String>? savedSubjectIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      createdExamIds: createdExamIds ?? this.createdExamIds,
      savedSubjectIds: savedSubjectIds ?? this.savedSubjectIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'created_at': createdAt.toIso8601String(),
        'created_exam_ids': createdExamIds,
        'saved_subject_ids': savedSubjectIds,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        createdExamIds: (json['created_exam_ids'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        savedSubjectIds: (json['saved_subject_ids'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}
