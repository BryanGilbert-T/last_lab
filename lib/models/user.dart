import 'package:flutter_app/models/log_in_method.dart';

class User {
  static const String defaultAvatarUrl = 'https://via.placeholder.com/150';

  String id; // use the ID from authentication service
  final String email;
  final String name;
  final String avatarUrl;
  late final List<LogInMethod> logInMethods;

  // Read-only fields that can only be set by the system
  bool _isModerator = false;
  bool get isModerator => _isModerator;

  User({
    required this.id,
    required this.email,
    required this.name,
    String? avatarUrl,
    logInMethods,
  })  : avatarUrl = avatarUrl ?? defaultAvatarUrl,
        logInMethods = logInMethods ?? [];

  User._({
    required this.id,
    required this.email,
    required this.name,
    String? avatarUrl,
    logInMethods,
    isModerator = false,
  })  : avatarUrl = avatarUrl ?? defaultAvatarUrl,
        logInMethods = logInMethods ?? [],
        _isModerator = isModerator;

  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User._(
      id: id,
      email: map['email'],
      name: map['name'],
      avatarUrl: map['avatarUrl'],
      logInMethods: (map['logInMethods'] as List<dynamic>)
          .map((logInMethod) => LogInMethod.values.byName(logInMethod))
          .toList(),
      isModerator: map['isModerator'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'logInMethods':
          logInMethods.map((logInMethod) => logInMethod.name).toList(),
      'isModerator': _isModerator,
    };
  }
}
