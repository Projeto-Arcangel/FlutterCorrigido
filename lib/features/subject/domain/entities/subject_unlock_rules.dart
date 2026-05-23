import 'subject.dart';

/// XP mínimo para desbloquear cada matéria.
/// 
/// Andaime Pedagógico (Vygotsky): o conteúdo avança do mais simples para o
/// mais complexo — cada matéria desbloqueada apoia a seguinte.
/// 
/// Microlearning (Ebbinghaus): o aluno não é exposto a todas as matérias
/// de uma só vez; o espaçamento garante retenção antes de ampliar o escopo.
const Map<SubjectId, double> subjectXpRequirements = {
  // ── Ponto de entrada: sempre disponível ──────────────────────────────────
  SubjectId.portuguese: 0,   // âncora do currículo — base linguística
  SubjectId.history:    0,   // narrativa humanística inicial

  // ── Camada 2: desbloqueadas após primeiras conquistas (≥ 100 XP) ────────
  SubjectId.math:       100, // raciocínio lógico-formal
  SubjectId.geography:  100, // espaço e território

  // ── Camada 3: expansão científica e artística (≥ 250 XP) ────────────────
  SubjectId.biology:    250, // vida e saúde
  SubjectId.arts:       250, // expressão e cultura

  // ── Camada 4: aprofundamento (≥ 450 XP) ─────────────────────────────────
  SubjectId.philosophy: 450, // pensamento crítico
  SubjectId.sociology:  450, // sociedade e relações

  // ── Camada 5: ciências exatas avançadas (≥ 700 XP) ──────────────────────
  SubjectId.chemistry:  700, // matéria e transformações
  SubjectId.physics:    700, // fenômenos e leis naturais

  // ── Camada 6: bem-estar e síntese (≥ 1000 XP) ───────────────────────────
  SubjectId.physEd:    1000, // saúde, movimento e práxis
};

/// Recebe o XP atual do usuário e retorna quais SubjectIds estão desbloqueados.
Set<SubjectId> unlockedSubjectIds(double xp) {
  return subjectXpRequirements.entries
      .where((entry) => xp >= entry.value)
      .map((entry) => entry.key)
      .toSet();
}