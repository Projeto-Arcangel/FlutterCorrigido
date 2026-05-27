/// Representa um evento recente de uma sala de aula.
///
/// Usado na seção "Atividade Recente" do dashboard do professor.
/// Os eventos são gravados na subcoleção `activities` de cada sala.
class ClassroomActivity {
  const ClassroomActivity({
    required this.type,
    required this.description,
    required this.createdAt,
  });

  /// Tipo do evento: 'phase_created', 'student_joined', 'student_completed'.
  final String type;

  /// Texto formatado para exibição (ex.: 'Aluno João concluiu uma fase').
  final String description;

  final DateTime createdAt;
}
