/// Materiais do professor usados para gerar questões ("Dos meus materiais").
///
/// O texto é extraído no NAVEGADOR (ver data/materials/): os arquivos nunca
/// são enviados — só o texto, já recortado por [MaterialRules.selectForAi].
library;

enum MaterialKind {
  pdf('PDF', 'página'),
  docx('Word', 'trecho'),
  pptx('PowerPoint', 'slide'),

  /// Página da web (artigo, notícia, verbete), lida pelo servidor.
  link('Página web', 'trecho'),

  /// Vídeo do YouTube, lido pelo servidor: anotações de aula da fala e do
  /// que aparece na tela.
  video('Vídeo do YouTube', 'trecho');

  const MaterialKind(this.label, this.unitLabel);

  /// Nome do formato para o professor.
  final String label;

  /// Como cada parte do material é chamada ("página 3", "slide 5").
  final String unitLabel;
}

/// Texto extraído de um arquivo, dividido nas partes naturais dele (páginas
/// do PDF, slides do PPTX, blocos de parágrafos do DOCX). As partes permitem
/// recortar um material grande de forma espalhada, em vez de só o começo.
class ExtractedMaterial {
  ExtractedMaterial({
    required this.name,
    required this.kind,
    required List<String> segments,
  }) : segments = List.unmodifiable(segments);

  final String name;
  final MaterialKind kind;
  final List<String> segments;

  late final int totalChars = segments.fold<int>(0, (sum, s) => sum + s.length);

  bool get isEmpty => totalChars == 0;
}

/// O que vai para a IA de cada material.
class MaterialForAi {
  const MaterialForAi({
    required this.name,
    required this.kind,
    required this.text,
    required this.coverage,
  });

  final String name;
  final MaterialKind kind;
  final String text;

  /// Fração do conteúdo do material que a IA vai ler (1 = tudo).
  final double coverage;

  bool get isPartial => coverage < 0.999;

  Map<String, Object> toJson() => {
        'name': name,
        'kind': kind.name,
        'text': text,
        'coverage': double.parse(coverage.toStringAsFixed(3)),
      };
}
