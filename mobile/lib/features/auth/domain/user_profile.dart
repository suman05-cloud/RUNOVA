class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.city,
    this.stateRegion,
    this.countryCode = 'IN',
    this.isPublic = false,
  });

  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? city;
  final String? stateRegion;
  final String countryCode;
  final bool isPublic;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    city: json['city'] as String?,
    stateRegion: json['state_region'] as String?,
    countryCode: json['country_code'] as String? ?? 'IN',
    isPublic: json['profile_is_public'] as bool? ?? false,
  );
}
