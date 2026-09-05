class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
  });

  final String id;
  final String email;
  final String username;
  final String? displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String?,
      );
}
