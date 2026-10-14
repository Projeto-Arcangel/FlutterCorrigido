import 'entities/bank_question.dart';

/// Uma linha do banco "Reutilizar minhas questões": uma questão, na turma e
/// na fase em que ela está. A mesma questão em fases diferentes aparece uma
/// vez para cada fase — cada uma é copiada ou excluída isoladamente.
class BankEntry {
  BankEntry({
    required this.question,
    required this.inThisPhase,
  }) : searchText = foldForSearch(
          [
            question.question.text,
            ...question.question.options,
            question.classroomName,
            question.phaseTitle,
          ].join(' '),
        );

  final BankQuestion question;

  /// Já existe uma igual na fase de destino: copiar de novo duplicaria.
  final bool inThisPhase;

  /// Texto pré-processado para a busca (sem acento, minúsculo).
  final String searchText;

  String get id => question.id;
}

/// Monta o banco para copiar para a fase [phaseId]: todas as questões do
/// professor fora dessa fase ([all] vem da mais nova para a mais antiga),
/// marcando as que já têm uma igual nela.
List<BankEntry> buildBankEntries(
  List<BankQuestion> all, {
  required String phaseId,
}) {
  final inPhase = {
    for (final q in all)
      if (q.phaseId == phaseId) q.signature,
  };
  return [
    for (final q in all)
      if (q.phaseId != phaseId)
        BankEntry(question: q, inThisPhase: inPhase.contains(q.signature)),
  ];
}

/// Filtra pela busca (todas as palavras, sem diferença de acento), pela
/// turma e por já estar na fase.
List<BankEntry> filterBank(
  List<BankEntry> entries, {
  String query = '',
  String? classroomId,
  bool showInPhase = false,
}) {
  final words =
      foldForSearch(query).split(' ').where((w) => w.isNotEmpty).toList();
  return [
    for (final e in entries)
      if ((showInPhase || !e.inThisPhase) &&
          (classroomId == null || e.question.classroomId == classroomId) &&
          words.every(e.searchText.contains))
        e,
  ];
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculo, sem acento e com espaços simples.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
