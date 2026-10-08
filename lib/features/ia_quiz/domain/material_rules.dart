import 'entities/study_material.dart';

/// Regras dos materiais anexados: formatos aceitos, limites e o recorte do
/// texto que vai para a IA. Os limites de texto ESPELHAM a Edge Function
/// generate-questions (MAX_MATERIAL_CHARS em _shared/openrouter.ts).
abstract final class MaterialRules {
  /// Soma dos arquivos anexados numa geração.
  static const int maxTotalBytes = 50 * 1024 * 1024;

  /// Arquivos + links numa geração (MAX_MATERIALS na Edge Function).
  static const int maxMaterials = 10;

  /// Texto máximo enviado à IA por geração (~50 mil tokens), somando todos
  /// os materiais. Controla custo e tempo de resposta.
  static const int maxCharsForAi = 200000;

  static const acceptedExtensions = ['pdf', 'docx', 'pptx'];

  /// Tamanho dos pedaços usados no recorte espaçado de um material grande.
  static const int _chunkChars = 2000;

  /// Formatos antigos do Office: binários, sem como ler no navegador.
  static const _legacyExtensions = {
    'doc': ('Word', 'docx'),
    'ppt': ('PowerPoint', 'pptx'),
    'pps': ('PowerPoint', 'pptx'),
  };

  /// Extensões oferecidas no seletor de arquivos: inclui os formatos antigos
  /// para o professor receber a orientação de conversão em vez de nem
  /// conseguir selecionar o arquivo.
  static List<String> get pickerExtensions =>
      [...acceptedExtensions, ..._legacyExtensions.keys];

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static MaterialKind? kindOf(String fileName) =>
      switch (_extensionOf(fileName)) {
        'pdf' => MaterialKind.pdf,
        'docx' => MaterialKind.docx,
        'pptx' => MaterialKind.pptx,
        _ => null,
      };

  /// Mensagem para um arquivo que não pode ser lido, ou `null` se o formato
  /// é aceito.
  static String? unsupportedReason(String fileName) {
    final ext = _extensionOf(fileName);
    final legacy = _legacyExtensions[ext];
    if (legacy != null) {
      final (app, newExt) = legacy;
      return 'Formato .$ext (antigo) não é aceito. Abra no $app, use '
          '"Salvar como" .$newExt e envie novamente.';
    }
    if (kindOf(fileName) == null) {
      return 'Formato não aceito. Envie PDF, DOCX ou PPTX.';
    }
    return null;
  }

  /// Link normalizado (https:// incluído se faltar), ou `null` se inválido.
  /// Vídeos do YouTube viram o endereço canônico (youtu.be/X, shorts/X e
  /// watch?v=X&t=30 são o mesmo vídeo).
  static Uri? normalizeLink(String raw) {
    var text = raw.trim();
    if (text.isEmpty || text.length > 2048 || text.contains(RegExp(r'\s'))) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text)) {
      text = 'https://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.host.contains('.') ||
        uri.host.startsWith('.') ||
        uri.host.endsWith('.')) {
      return null;
    }
    final videoId = youTubeVideoId(uri);
    return videoId == null
        ? uri
        : Uri.parse('https://www.youtube.com/watch?v=$videoId');
  }

  /// Mensagem para um link que não pode ser usado, ou `null` se ele pode ser
  /// enviado ao servidor (que ainda checa se o endereço é público).
  static String? linkProblem(String raw) {
    final uri = normalizeLink(raw);
    if (uri == null) {
      return 'Link inválido. Cole o endereço completo da página '
          '(ex.: https://site.com/artigo).';
    }
    if (isYouTube(uri) && youTubeVideoId(uri) == null) {
      final first = uri.pathSegments.firstOrNull ?? '';
      if (uri.queryParameters.containsKey('list')) {
        return 'Este é o link de uma playlist. Abra o vídeo desejado e cole '
            'o link dele.';
      }
      if (first.startsWith('@') ||
          const {'channel', 'c', 'user'}.contains(first)) {
        return 'Este é o link de um canal. Abra o vídeo desejado e cole o '
            'link dele.';
      }
      return 'Este link do YouTube não aponta para um vídeo. Abra o vídeo e '
          'cole o link dele.';
    }
    return null;
  }

  static String _youTubeHost(Uri uri) =>
      uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');

  static bool isYouTube(Uri uri) {
    final host = _youTubeHost(uri);
    return host == 'youtube.com' ||
        host == 'youtu.be' ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube.com');
  }

  static final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// ID do vídeo de um link do YouTube (watch, youtu.be, shorts, live,
  /// embed), ou `null` se o link não aponta para um vídeo. ESPELHA
  /// parseYouTube (supabase/functions/_shared/youtube.ts).
  static String? youTubeVideoId(Uri uri) {
    if (!isYouTube(uri)) return null;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final first = parts.firstOrNull ?? '';
    final id = _youTubeHost(uri) == 'youtu.be'
        ? first
        : first == 'watch'
            ? uri.queryParameters['v']
            : const {'shorts', 'live', 'embed', 'v', 'e'}.contains(first) &&
                    parts.length > 1
                ? parts[1]
                : null;
    return id != null && _videoId.hasMatch(id) ? id : null;
  }

  /// Escolhe o texto de cada material que cabe em [budget] caracteres.
  ///
  /// 1. Divide o orçamento de forma justa: materiais pequenos entram
  ///    inteiros e o que sobra é repartido entre os grandes.
  /// 2. Num material recortado, as partes escolhidas ficam ESPALHADAS ao
  ///    longo dele (ex.: páginas 1, 4, 7, …), para as questões cobrirem o
  ///    material todo e não só o começo.
  static List<MaterialForAi> selectForAi(
    List<ExtractedMaterial> materials, {
    int budget = maxCharsForAi,
  }) {
    final usable = materials.where((m) => !m.isEmpty).toList();
    final allowances = _fairShares(
      [for (final m in usable) m.totalChars],
      budget,
    );
    return [
      for (var i = 0; i < usable.length; i++) _select(usable[i], allowances[i]),
    ];
  }

  /// Quanto de cada material a IA vai ler (0–1), sem montar o texto: só a
  /// divisão do orçamento, O(n log n) no nº de materiais. Usado no aviso de
  /// leitura parcial, que é redesenhado com frequência; o texto em si só é
  /// montado ao gerar ([selectForAi]).
  static List<({String name, double coverage})> coverageOf(
    List<ExtractedMaterial> materials, {
    int budget = maxCharsForAi,
  }) {
    final usable = materials.where((m) => !m.isEmpty).toList();
    final shares = _fairShares([for (final m in usable) m.totalChars], budget);
    return [
      for (var i = 0; i < usable.length; i++)
        (name: usable[i].name, coverage: shares[i] / usable[i].totalChars),
    ];
  }

  /// "Enchimento por nível": acha o teto c tal que Σ min(tamanho, c) = budget.
  static List<int> _fairShares(List<int> sizes, int budget) {
    final total = sizes.fold<int>(0, (a, b) => a + b);
    if (total <= budget) return List.of(sizes);

    final order = List.generate(sizes.length, (i) => i)
      ..sort((a, b) => sizes[a].compareTo(sizes[b]));
    final shares = List.filled(sizes.length, 0);
    var remaining = budget;
    for (var k = 0; k < order.length; k++) {
      final i = order[k];
      final fair = remaining ~/ (order.length - k);
      shares[i] = sizes[i] < fair ? sizes[i] : fair;
      remaining -= shares[i];
    }
    return shares;
  }

  static MaterialForAi _select(ExtractedMaterial material, int allowance) {
    final segments = material.segments;
    final total = material.totalChars;
    final label = material.kind.unitLabel;
    String labelled(int i) =>
        '[${label[0].toUpperCase()}${label.substring(1)} ${i + 1}]\n'
        '${segments[i]}';

    if (allowance >= total) {
      return MaterialForAi(
        name: material.name,
        kind: material.kind,
        text: [
          for (var i = 0; i < segments.length; i++)
            if (segments[i].isNotEmpty) labelled(i),
        ].join('\n\n'),
        coverage: 1,
      );
    }

    // Pedaços de até _chunkChars: com poucas partes enormes (um DOCX inteiro
    // num bloco, uma página muito densa) a seleção ainda fica espalhada.
    final chunks = <(int, String)>[
      for (var i = 0; i < segments.length; i++)
        for (var start = 0; start < segments[i].length; start += _chunkChars)
          (
            i,
            segments[i].substring(
              start,
              start + _chunkChars < segments[i].length
                  ? start + _chunkChars
                  : segments[i].length,
            ),
          ),
    ];

    // Seleção espaçada: k pedaços com índices igualmente espaçados do
    // primeiro ao último, então o começo, o meio e o fim entram.
    final average = total / chunks.length;
    final k = (allowance / average).floor().clamp(1, chunks.length);
    final indices = <int>{
      for (var j = 0; j < k; j++)
        k == 1 ? 0 : (j * (chunks.length - 1) / (k - 1)).round(),
    };
    final picked = <String>[];
    var used = 0;
    for (final c in indices) {
      final (segment, text) = chunks[c];
      // Pedaço que não cabe é pulado (os próximos podem ser menores).
      if (used + text.length > allowance) continue;
      final unit = '${label[0].toUpperCase()}${label.substring(1)}';
      picked.add('[$unit ${segment + 1}]\n$text');
      used += text.length;
    }

    return MaterialForAi(
      name: material.name,
      kind: material.kind,
      text: picked.join('\n\n'),
      coverage: (used / total).clamp(0.0, 1.0),
    );
  }
}
