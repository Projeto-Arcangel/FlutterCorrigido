import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_messages.dart';
import '../../domain/entities/study_material.dart';
import '../../domain/material_rules.dart';
import 'material_read_exception.dart';

/// Texto de uma página (ou vídeo) e, se houver, um aviso sobre ele (ex.:
/// conteúdo para assinantes do qual só a prévia pôde ser lida, vídeo longo
/// do qual só o começo foi lido).
typedef LinkMaterial = ({ExtractedMaterial material, String? warning});

/// Lê o texto de um link pelas Edge Functions (o navegador não pode baixar
/// conteúdo de outros sites): `extract-url` para páginas e `extract-video`
/// para vídeos do YouTube (anotações de aula do vídeo). Nada fica salvo: o
/// texto volta para o app e segue o mesmo caminho dos arquivos.
class LinkMaterialSource {
  LinkMaterialSource(this._client);

  final SupabaseClient _client;

  /// Lança [MaterialReadException] com a mensagem para o professor.
  Future<LinkMaterial> read(Uri url) async {
    final video = MaterialRules.isYouTube(url);
    final fallback = video
        ? 'Não consegui ler este vídeo.'
        : 'Não consegui ler esta página.';
    try {
      final res = await _client.functions.invoke(
        video ? 'extract-video' : 'extract-url',
        body: {'url': url.toString()},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final segments = [
        for (final s in data['segments'] as List) s as String,
      ];
      final title = (data['title'] as String?)?.trim();
      return (
        material: ExtractedMaterial(
          name: title == null || title.isEmpty ? url.host : title,
          kind: video ? MaterialKind.video : MaterialKind.link,
          segments: segments,
        ),
        warning: data['warning'] as String?,
      );
    } on FunctionException catch (e) {
      // O servidor responde { error: <mensagem pronta>, code } — textos
      // nossos, em português.
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw MaterialReadException(message ?? fallback);
    } catch (e) {
      throw MaterialReadException(
        ErrorMessages.isNetworkError(e) ? ErrorMessages.network : fallback,
      );
    }
  }
}
