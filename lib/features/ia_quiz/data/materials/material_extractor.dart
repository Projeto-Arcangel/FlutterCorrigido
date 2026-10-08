import 'dart:typed_data';

import '../../domain/entities/study_material.dart';
import '../../domain/material_rules.dart';
import 'material_read_exception.dart';
import 'office_text_extractor.dart';
import 'pdf_text_extractor.dart';
import 'time_slicer.dart';

/// Lê um arquivo anexado e devolve o texto dele, no próprio navegador.
class MaterialExtractor {
  const MaterialExtractor();

  /// Abaixo disso, em média por página, o PDF é quase certamente digitalizado
  /// (imagem das páginas, sem camada de texto).
  static const int _minCharsPerPdfPage = 30;

  /// Lança [MaterialReadException] com a mensagem para o professor.
  Future<ExtractedMaterial> extract(
    String fileName,
    Uint8List bytes, {
    void Function(int done, int total)? onProgress,
  }) async {
    final unsupported = MaterialRules.unsupportedReason(fileName);
    if (unsupported != null) throw MaterialReadException(unsupported);
    final kind = MaterialRules.kindOf(fileName)!;

    final segments = switch (kind) {
      MaterialKind.pdf => await extractPdfPages(bytes, onProgress: onProgress),
      MaterialKind.docx => await OfficeTextExtractor.docx(bytes),
      MaterialKind.pptx => await OfficeTextExtractor.pptx(bytes),
      // O tipo de arquivo vem da extensão: nunca é "link" nem "video" (links
      // e vídeos são lidos pelo servidor, em LinkMaterialSource).
      MaterialKind.link ||
      MaterialKind.video =>
        throw ArgumentError.value(fileName, 'fileName'),
    };

    // Normaliza parte a parte, cedendo a vez à interface em textos longos.
    final slicer = TimeSlicer();
    final cleaned = <String>[];
    for (final segment in segments) {
      cleaned.add(_normalize(segment));
      await slicer.yieldIfBusy();
    }
    final material =
        ExtractedMaterial(name: fileName, kind: kind, segments: cleaned);

    if (material.isEmpty ||
        (kind == MaterialKind.pdf &&
            material.totalChars < cleaned.length * _minCharsPerPdfPage)) {
      throw MaterialReadException(
        switch (kind) {
          MaterialKind.pdf => 'Não encontramos texto neste PDF. Ele parece ser '
              'digitalizado (imagem das páginas) — use um PDF com texto '
              'selecionável.',
          MaterialKind.docx => 'Este documento não tem texto.',
          MaterialKind.pptx => 'Esta apresentação não tem texto nos slides '
              '(só imagens).',
          MaterialKind.link => 'Esta página não tem texto.',
          MaterialKind.video => 'Este vídeo não tem fala nem texto.',
        },
      );
    }
    return material;
  }

  /// Junta hifenização de fim de linha ("concei-\nto") e espaços repetidos.
  static String _normalize(String text) => text
      .replaceAll('\u0000', '')
      .replaceAllMapped(
        RegExp(r'(\p{L})-\n(\p{Ll})', unicode: true),
        (m) => '${m[1]}${m[2]}',
      )
      .replaceAll(RegExp(r'[ \t ]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
