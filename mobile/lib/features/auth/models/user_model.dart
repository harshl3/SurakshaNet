class UserModel {
  final int? id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final int? policeStationId;
  final String? policeStationName;

  const UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.policeStationId,
    this.policeStationName,
  });

  bool get isAdmin => role == 'ROLE_ADMIN';
  bool get isOfficer => role == 'ROLE_POLICE_OFFICER';
  bool get isSurveyor => role == 'ROLE_SURVEY_PERSON';

  String get roleDisplay {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'System Administrator';
      case 'ROLE_POLICE_OFFICER':
        return 'Police Officer';
      case 'ROLE_SURVEY_PERSON':
        return 'Field Surveyor';
      default:
        return role.replaceAll('ROLE_', '');
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      policeStationId: json['policeStationId'] as int?,
      policeStationName: json['policeStationName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
      'policeStationId': policeStationId,
      'policeStationName': policeStationName,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? fullName,
    String? role,
    int? policeStationId,
    String? policeStationName,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      policeStationId: policeStationId ?? this.policeStationId,
      policeStationName: policeStationName ?? this.policeStationName,
    );
  }
}
