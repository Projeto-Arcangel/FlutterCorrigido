import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'material_read_exception.dart';
import 'time_slicer.dart';

/// Lê o texto de .docx e .pptx. Os dois são pacotes ZIP com o conteúdo em
/// XML (Office Open XML), então dá para ler em Dart puro, no navegador.
///
/// Desempenho (roda na thread da interface — a web não tem isolates):
/// - só os XML de texto são descompactados; imagens e mídias nunca são
///   abertas, então um arquivo pesado de fotos continua rápido;
/// - o XML é lido em fluxo (eventos), sem montar a árvore inteira na memória;
/// - o trabalho é fatiado ([TimeSlicer]) para a tela continuar respondendo.
abstract final class OfficeTextExtractor {
  /// Parágrafos do Word agrupados em blocos de ~[_docxBlockChars]: o "trecho"
  /// usado no recorte de materiais grandes.
  static const int _docxBlockChars = 2000;

  static const _word = _Tags(
    paragraph: 'w:p',
    text: 'w:t',
    breaks: {'w:br', 'w:cr'},
    tabs: {'w:tab'},
  );
  static const _drawing =
      _Tags(paragraph: 'a:p', text: 'a:t', breaks: {'a:br'}, tabs: {});

  static Future<List<String>> docx(Uint8List bytes) async {
    final slicer = TimeSlicer();
    final archive = _open(bytes, 'Word');
    final xml = _readText(archive, 'word/document.xml');
    if (xml == null) {
      throw const MaterialReadException(
        'Não parece um documento do Word válido.',
      );
    }

    final blocks = <String>[];
    final current = StringBuffer();
    for (final paragraph in await _paragraphs(xml, _word, slicer)) {
      if (current.isNotEmpty) current.write('\n');
      current.write(paragraph);
      if (current.length >= _docxBlockChars) {
        blocks.add(current.toString());
        current.clear();
      }
    }
    if (current.isNotEmpty) blocks.add(current.toString());
    return blocks;
  }

  /// Um item por slide, na ordem da apresentação, incluindo as notas do
  /// apresentador (costumam ter a explicação do conteúdo do slide).
  static Future<List<String>> pptx(Uint8List bytes) async {
    final slicer = TimeSlicer();
    final archive = _open(bytes, 'PowerPoint');
    final slidePaths = _slideOrder(archive);
    if (slidePaths.isEmpty) {
      throw const MaterialReadException(
        'Não encontramos slides nesta apresentação.',
      );
    }

    final slides = <String>[];
    for (final path in slidePaths) {
      slides.add(await _slideText(archive, path, slicer));
      // Descompactar e ler os índices de cada slide também custa: confere o
      // relógio entre um slide e outro.
      await slicer.yieldIfBusy();
    }
    return slides;
  }

  static Archive _open(Uint8List bytes, String app) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw MaterialReadException(
        'Não foi possível abrir o arquivo. Ele pode estar corrompido ou '
        'protegido por senha — abra no $app e salve novamente.',
      );
    }
  }

  static String? _readText(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    try {
      return utf8.decode(file.content as List<int>, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Só para os índices pequenos (presentation.xml e .rels).
  static XmlDocument? _readXml(Archive archive, String path) {
    final text = _readText(archive, path);
    if (text == null) return null;
    try {
      return XmlDocument.parse(text);
    } catch (_) {
      return null;
    }
  }

  /// Texto de cada parágrafo, em ordem, lido em fluxo. Cada trecho de texto
  /// entra uma única vez — inclusive quando um parágrafo contém outro (caixa
  /// de texto dentro de um parágrafo do Word): o texto do parágrafo de fora
  /// é fechado antes do de dentro começar. Texto excluído com controle de
  /// alterações (`w:delText`) e códigos de campo não entram.
  static Future<List<String>> _paragraphs(
    String xml,
    _Tags tags,
    TimeSlicer slicer,
  ) async {
    final paragraphs = <String>[];
    final current = StringBuffer();
    var inText = false;

    void flush() {
      final text = current.toString().trim();
      if (text.isNotEmpty) paragraphs.add(text);
      current.clear();
    }

    for (final event in parseEvents(xml)) {
      if (slicer.tick()) await slicer.yieldNow();

      if (event is XmlStartElementEvent) {
        final name = event.name;
        if (name == tags.paragraph) {
          flush(); // parágrafo aninhado: fecha o texto do parágrafo de fora
        } else if (name == tags.text) {
          inText = !event.isSelfClosing;
        } else if (tags.breaks.contains(name)) {
          current.write('\n');
        } else if (tags.tabs.contains(name)) {
          current.write('\t');
        }
      } else if (event is XmlEndElementEvent) {
        if (event.name == tags.text) {
          inText = false;
        } else if (event.name == tags.paragraph) {
          flush();
        }
      } else if (inText) {
        if (event is XmlTextEvent) {
          current.write(event.value);
        } else if (event is XmlCDATAEvent) {
          current.write(event.value);
        }
      }
    }
    flush();
    return paragraphs;
  }

  /// Caminhos dos slides na ordem da apresentação (ppt/presentation.xml).
  /// Se o índice não puder ser lido, usa a numeração dos arquivos.
  static List<String> _slideOrder(Archive archive) {
    final presentation = _readXml(archive, 'ppt/presentation.xml');
    final rels = _readXml(archive, 'ppt/_rels/presentation.xml.rels');
    if (presentation != null && rels != null) {
      final targets = {
        for (final rel in rels.findAllElements('Relationship'))
          rel.getAttribute('Id') ?? '': rel.getAttribute('Target') ?? '',
      };
      final ordered = [
        for (final slide in presentation.findAllElements('p:sldId'))
          if (targets[slide.getAttribute('r:id')] case final target?)
            _resolve('ppt', target),
      ].where((path) => archive.findFile(path) != null).toList();
      if (ordered.isNotEmpty) return ordered;
    }

    final pattern = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
    final numbered = [
      for (final file in archive.files)
        if (pattern.firstMatch(file.name) case final match?)
          (int.parse(match.group(1)!), file.name),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, path) in numbered) path];
  }

  static Future<String> _slideText(
    Archive archive,
    String slidePath,
    TimeSlicer slicer,
  ) async {
    final slide = _readText(archive, slidePath);
    final lines =
        slide == null ? <String>[] : await _paragraphs(slide, _drawing, slicer);

    final notes = await _notesFor(archive, slidePath, slicer);
    if (notes.isNotEmpty) {
      lines
        ..add('Notas do apresentador:')
        ..addAll(notes);
    }
    return lines.join('\n');
  }

  static Future<List<String>> _notesFor(
    Archive archive,
    String slidePath,
    TimeSlicer slicer,
  ) async {
    final slash = slidePath.lastIndexOf('/');
    final relsPath =
        '${slidePath.substring(0, slash)}/_rels/${slidePath.substring(slash + 1)}.rels';
    final rels = _readXml(archive, relsPath);
    if (rels == null) return const [];

    for (final rel in rels.findAllElements('Relationship')) {
      final type = rel.getAttribute('Type') ?? '';
      final target = rel.getAttribute('Target');
      if (!type.endsWith('/notesSlide') || target == null) continue;
      final notes =
          _readText(archive, _resolve(slidePath.substring(0, slash), target));
      if (notes == null) return const [];
      return (await _paragraphs(notes, _drawing, slicer))
          // O número do slide aparece como texto no próprio slide de notas.
          .where((line) => int.tryParse(line) == null)
          .toList();
    }
    return const [];
  }

  /// Resolve um alvo relativo ("slides/slide1.xml", "../notesSlides/x.xml")
  /// a partir da pasta [base] dentro do ZIP.
  static String _resolve(String base, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = base.split('/');
    for (final piece in target.split('/')) {
      if (piece == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (piece != '.' && piece.isNotEmpty) {
        parts.add(piece);
      }
    }
    return parts.join('/');
  }
}

/// Nomes das tags de parágrafo/texto de cada formato.
class _Tags {
  const _Tags({
    required this.paragraph,
    required this.text,
    required this.breaks,
    required this.tabs,
  });

  final String paragraph;
  final String text;
  final Set<String> breaks;
  final Set<String> tabs;
}
