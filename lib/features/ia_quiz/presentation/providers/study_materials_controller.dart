import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../data/materials/link_material_source.dart';
import '../../data/materials/material_extractor.dart';
import '../../data/materials/material_read_exception.dart';
import '../../domain/entities/study_material.dart';
import '../../domain/material_rules.dart';

enum MaterialStatus { waiting, reading, ready, failed }

/// Um material anexado (arquivo ou link) e o estado da leitura dele.
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.status,
    this.kind,
    this.url,
    this.done = 0,
    this.total = 0,
    this.content,
    this.error,
    this.warning,
  });

  final int id;
  final String name;
  final int sizeBytes;
  final MaterialKind? kind;
  final MaterialStatus status;

  /// Endereço, quando o material é um link.
  final Uri? url;

  /// Progresso da leitura (páginas lidas / total), quando houver.
  final int done;
  final int total;

  final ExtractedMaterial? content;
  final String? error;

  /// Aviso sobre um material lido (ex.: pode estar incompleto).
  final String? warning;

  /// Arquivos recusados não ocupam o limite de tamanho.
  bool get countsTowardsLimit => status != MaterialStatus.failed;

  MaterialItem copyWith({
    MaterialStatus? status,
    int? done,
    int? total,
    ExtractedMaterial? content,
    String? error,
    String? warning,
  }) =>
      MaterialItem(
        id: id,
        name: name,
        sizeBytes: sizeBytes,
        kind: kind,
        url: url,
        status: status ?? this.status,
        done: done ?? this.done,
        total: total ?? this.total,
        content: content ?? this.content,
        error: error ?? this.error,
        warning: warning ?? this.warning,
      );
}

/// Arquivo escolhido pelo professor (nome + bytes, lidos pelo seletor).
typedef PickedMaterialFile = ({String name, Uint8List bytes});

final materialExtractorProvider =
    Provider<MaterialExtractor>((_) => const MaterialExtractor());

final linkMaterialSourceProvider = Provider<LinkMaterialSource>(
  (ref) => LinkMaterialSource(ref.watch(supabaseClientProvider)),
);

/// Lista de materiais da tela "Dos meus materiais". Os bytes de cada arquivo
/// ficam só até a leitura terminar; depois resta apenas o texto. Ao sair da
/// tela (autoDispose) tudo é descartado.
final studyMaterialsProvider =
    NotifierProvider.autoDispose<StudyMaterialsController, List<MaterialItem>>(
  StudyMaterialsController.new,
);

class StudyMaterialsController extends AutoDisposeNotifier<List<MaterialItem>> {
  static const _progressIntervalMs = 100;

  final _pendingBytes = <int, Uint8List>{};
  var _nextId = 0;
  var _processing = false;
  var _disposed = false;

  @override
  List<MaterialItem> build() {
    ref.onDispose(() {
      _disposed = true;
      _pendingBytes.clear();
    });
    return const [];
  }

  int get totalBytes => state
      .where((m) => m.countsTowardsLimit)
      .fold<int>(0, (sum, m) => sum + m.sizeBytes);

  bool get isReading => state.any(
        (m) =>
            m.status == MaterialStatus.reading ||
            m.status == MaterialStatus.waiting,
      );

  List<ExtractedMaterial> get readyMaterials => [
        for (final m in state)
          if (m.status == MaterialStatus.ready && m.content != null) m.content!,
      ];

  /// Adiciona os arquivos e começa a ler. Devolve avisos de arquivos que não
  /// couberam (quantidade ou tamanho total); formatos não aceitos entram na
  /// lista como "falhou", com a explicação de como resolver.
  List<String> addFiles(List<PickedMaterialFile> files) {
    final warnings = <String>[];
    final added = <MaterialItem>[];
    var count = state.where((m) => m.countsTowardsLimit).length;
    var bytes = totalBytes;

    for (final file in files) {
      final unsupported = MaterialRules.unsupportedReason(file.name);
      if (unsupported != null) {
        added.add(
          MaterialItem(
            id: _nextId++,
            name: file.name,
            sizeBytes: file.bytes.length,
            status: MaterialStatus.failed,
            error: unsupported,
          ),
        );
        continue;
      }
      if (count >= MaterialRules.maxMaterials) {
        warnings.add(
          '"${file.name}" não foi adicionado: o limite é de '
          '${MaterialRules.maxMaterials} materiais por geração.',
        );
        continue;
      }
      if (bytes + file.bytes.length > MaterialRules.maxTotalBytes) {
        warnings.add(
          '"${file.name}" não foi adicionado: os materiais passariam de '
          '${MaterialRules.maxTotalBytes ~/ (1024 * 1024)} MB no total.',
        );
        continue;
      }

      final item = MaterialItem(
        id: _nextId++,
        name: file.name,
        sizeBytes: file.bytes.length,
        kind: MaterialRules.kindOf(file.name),
        status: MaterialStatus.waiting,
      );
      _pendingBytes[item.id] = file.bytes;
      added.add(item);
      count++;
      bytes += file.bytes.length;
    }

    state = [...state, ...added];
    _processQueue();
    return warnings;
  }

  /// Adiciona um link (página ou vídeo do YouTube) e começa a ler. Devolve a
  /// mensagem de erro (link inválido, repetido, de playlist ou acima do
  /// limite) ou `null` se aceito.
  ///
  /// Links são lidos pelo servidor — dependem de rede, não do processador do
  /// professor —, então rodam em paralelo à fila de arquivos.
  String? addLink(String raw) {
    final problem = MaterialRules.linkProblem(raw);
    if (problem != null) return problem;
    final url = MaterialRules.normalizeLink(raw)!;

    final duplicate = state.any(
      (m) => m.url != null && m.countsTowardsLimit && _sameLink(m.url!, url),
    );
    if (duplicate) return 'Este link já foi adicionado.';
    if (state.where((m) => m.countsTowardsLimit).length >=
        MaterialRules.maxMaterials) {
      return 'O limite é de ${MaterialRules.maxMaterials} materiais por '
          'geração.';
    }

    final video = MaterialRules.isYouTube(url);
    final item = MaterialItem(
      id: _nextId++,
      // O título do vídeo só chega com a transcrição.
      name: video ? 'Vídeo do YouTube' : _displayLink(url),
      sizeBytes: 0,
      kind: video ? MaterialKind.video : MaterialKind.link,
      url: url,
      status: MaterialStatus.reading,
    );
    state = [...state, item];
    _readLink(item);
    return null;
  }

  static bool _sameLink(Uri a, Uri b) =>
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.path.replaceFirst(RegExp(r'/$'), '') ==
          b.path.replaceFirst(RegExp(r'/$'), '') &&
      a.query == b.query;

  static String _displayLink(Uri url) {
    final path = url.path == '/' ? '' : url.path;
    return '${url.host.replaceFirst(RegExp(r'^www\.'), '')}$path';
  }

  Future<void> _readLink(MaterialItem item) async {
    final source = ref.read(linkMaterialSourceProvider);
    try {
      final result = await source.read(item.url!);
      _update(
        item.id,
        (m) => m.copyWith(
          status: MaterialStatus.ready,
          content: result.material,
          warning: result.warning,
        ),
      );
    } on MaterialReadException catch (e) {
      _update(
        item.id,
        (m) => m.copyWith(status: MaterialStatus.failed, error: e.message),
      );
    } catch (_) {
      _update(
        item.id,
        (m) => m.copyWith(
          status: MaterialStatus.failed,
          error: m.kind == MaterialKind.video
              ? 'Não consegui ler este vídeo.'
              : 'Não consegui ler esta página.',
        ),
      );
    }
  }

  void remove(int id) {
    _pendingBytes.remove(id);
    state = [
      for (final m in state)
        if (m.id != id) m,
    ];
  }

  /// Lê um arquivo por vez: menos memória e menos disputa de processador em
  /// computadores mais fracos.
  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (!_disposed) {
        final next =
            state.where((m) => m.status == MaterialStatus.waiting).firstOrNull;
        if (next == null) break;
        await _read(next);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _read(MaterialItem item) async {
    final bytes = _pendingBytes[item.id];
    if (bytes == null) return;
    final extractor = ref.read(materialExtractorProvider);
    _update(item.id, (m) => m.copyWith(status: MaterialStatus.reading));

    try {
      // Progresso no máximo a cada 100 ms: atualizar a tela a cada página de
      // um PDF longo custaria mais que a própria leitura.
      final sinceUpdate = Stopwatch()..start();
      final content = await extractor.extract(
        item.name,
        bytes,
        onProgress: (done, total) {
          if (done < total &&
              sinceUpdate.elapsedMilliseconds < _progressIntervalMs) {
            return;
          }
          sinceUpdate.reset();
          _update(item.id, (m) => m.copyWith(done: done, total: total));
        },
      );
      _update(
        item.id,
        (m) => m.copyWith(status: MaterialStatus.ready, content: content),
      );
    } on MaterialReadException catch (e) {
      _update(
        item.id,
        (m) => m.copyWith(status: MaterialStatus.failed, error: e.message),
      );
    } catch (_) {
      _update(
        item.id,
        (m) => m.copyWith(
          status: MaterialStatus.failed,
          error: 'Não foi possível ler este arquivo.',
        ),
      );
    } finally {
      // O texto já foi extraído: o arquivo em si não fica na memória.
      _pendingBytes.remove(item.id);
    }
  }

  /// Atualiza um item, se ele ainda estiver na lista (pode ter sido removido
  /// durante a leitura).
  void _update(int id, MaterialItem Function(MaterialItem) change) {
    // Saiu da tela no meio da leitura: o resultado é descartado.
    if (_disposed) return;
    state = [for (final m in state) m.id == id ? change(m) : m];
  }
}
