class LocalUserAccount {
  final String username;
  final String? passwordHash;

  const LocalUserAccount({
    required this.username,
    this.passwordHash,
  });

  factory LocalUserAccount.fromJson(Map<String, dynamic> json) {
    return LocalUserAccount(
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'passwordHash': passwordHash,
      };
}
