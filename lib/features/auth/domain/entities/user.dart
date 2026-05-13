import 'package:equatable/equatable.dart';

/// Papel do usuário no sistema.
///
/// Tudo o que vier depois do MVP de aluno (painel do professor, criação
/// de turmas, criação de conteúdo) depende deste discriminante existir
/// na entidade. Persistido em `Users/{uid}.role` no Firestore como
/// string ("student" | "teacher").
enum UserRole { student, teacher }

/// Converte uma string vinda do Firestore em `UserRole`.
/// Retorna `null` quando o valor é desconhecido ou ausente — usado pelo
/// gate de role no router para decidir se o usuário precisa passar pela
/// `RoleSelectionPage`.
UserRole? userRoleFromString(String? value) {
  switch (value) {
    case 'teacher':
      return UserRole.teacher;
    case 'student':
      return UserRole.student;
    default:
      return null;
  }
}

class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.role = UserRole.student,
  });

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, role];
}
