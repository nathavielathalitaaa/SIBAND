class ChildModel {
  final int id;
  final int userId;
  final String nickname;
  final int birthYear;

  const ChildModel({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.birthYear,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      nickname: json['nickname']?.toString() ?? '',
      birthYear: json['birth_year'] is int ? json['birth_year'] as int : int.tryParse(json['birth_year']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      'birth_year': birthYear,
    };
  }
}
