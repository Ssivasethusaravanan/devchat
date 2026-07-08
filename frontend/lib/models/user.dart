class UserModel {
  final String id;
  final String username;
  final String email;
  final String avatarUrl;
  final String status;
  final DateTime? lastSeen;
  final bool hideLastSeen;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl = '',
    this.status = 'offline',
    this.lastSeen,
    this.hideLastSeen = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      status: json['status'] ?? 'offline',
      lastSeen: json['last_seen'] != null ? DateTime.tryParse(json['last_seen'])?.toLocal() : null,
      hideLastSeen: json['hide_last_seen'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'status': status,
        'last_seen': lastSeen?.toUtc().toIso8601String(),
        'hide_last_seen': hideLastSeen,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  bool get isOnline => status == 'online';

  String get initials {
    if (username.isEmpty) return '?';
    final parts = username.split(RegExp(r'[\s._-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, username.length >= 2 ? 2 : 1).toUpperCase();
  }

  UserModel copyWith({
    String? status,
    String? avatarUrl,
    DateTime? lastSeen,
    bool? hideLastSeen,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      hideLastSeen: hideLastSeen ?? this.hideLastSeen,
      createdAt: createdAt,
    );
  }
}
