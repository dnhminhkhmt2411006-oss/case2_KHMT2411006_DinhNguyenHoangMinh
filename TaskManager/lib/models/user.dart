class AppUser {
  final String id;
  final String fullName;
  final String email;

  const AppUser({required this.id, required this.fullName, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: (j['id'] ?? j['_id'] ?? '').toString(),
    fullName: (j['fullName'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
  );
}

class Assignee {
  final AppUser user;
  final bool isPrimary;

  const Assignee({required this.user, required this.isPrimary});

  factory Assignee.fromJson(Map<String, dynamic> j) =>
      Assignee(user: AppUser.fromJson(j), isPrimary: j['isPrimary'] == true);
}