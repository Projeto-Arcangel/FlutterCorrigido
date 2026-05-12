import 'subject.dart';

/// Define o XP mínimo necessário para desbloquear cada matéria.
/// Ajuste os valores aqui conforme o balanceamento do jogo.
const Map<SubjectId, double> subjectXpRequirements = {
  SubjectId.history:    0,
//  SubjectId.philosophy: 100,
//  SubjectId.sociology:  300,
//  SubjectId.geography:  600,
};

/// Recebe o XP atual do usuário e retorna quais SubjectIds estão desbloqueados.
Set<SubjectId> unlockedSubjectIds(double xp) {
  return subjectXpRequirements.entries
      .where((entry) => xp >= entry.value)
      .map((entry) => entry.key)
      .toSet();
}