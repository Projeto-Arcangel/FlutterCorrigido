import 'dart:convert';
import 'dart:typed_data';

import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/material_extractor.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/material_read_exception.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/office_text_extractor.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um ZIP (docx/pptx) em memória com os arquivos dados.
Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((path, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _w =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
const _a = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

String _slide(List<String> paragraphs) => '<p:sld $_a><p:cSld><p:spTree>'
    '<p:sp><p:txBody>'
    '${paragraphs.map((t) => '<a:p><a:r><a:t>$t</a:t></a:r></a:p>').join()}'
    '</p:txBody></p:sp></p:spTree></p:cSld></p:sld>';

void main() {
  group('docx', () {
    test('lê parágrafos, tabulações e quebras de linha', () async {
      final bytes = _zip({
        'word/document.xml': '<w:document $_w><w:body>'
            '<w:p><w:r><w:t>Revolução</w:t></w:r><w:r><w:t xml:space="preserve"> Francesa</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>Causa</w:t><w:tab/><w:t>Crise</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>Linha 1</w:t><w:br/><w:t>Linha 2</w:t></w:r></w:p>'
            '<w:p></w:p>'
            '</w:body></w:document>',
      });

      expect(
        (await OfficeTextExtractor.docx(bytes)).join('\n'),
        'Revolução Francesa\nCausa\tCrise\nLinha 1\nLinha 2',
      );
    });

    test('caixa de texto dentro de parágrafo não duplica o texto', () async {
      final bytes = _zip({
        'word/document.xml': '<w:document $_w><w:body>'
            '<w:p><w:r><w:t>Antes</w:t></w:r>'
            '<w:r><w:pict><w:txbxContent>'
            '<w:p><w:r><w:t>Dentro da caixa</w:t></w:r></w:p>'
            '</w:txbxContent></w:pict></w:r>'
            '<w:r><w:t>Depois</w:t></w:r></w:p>'
            '</w:body></w:document>',
      });

      final text = (await OfficeTextExtractor.docx(bytes)).join('\n');
      expect(text, 'Antes\nDentro da caixa\nDepois');
      expect('Dentro da caixa'.allMatches(text).length, 1);
    });

    test('decodifica entidades e ignora texto excluído', () async {
      final bytes = _zip({
        'word/document.xml': '<w:document $_w><w:body>'
            '<w:p><w:r><w:t>Sal &amp; açúcar &lt;3</w:t></w:r>'
            '<w:del><w:r><w:delText>apagado</w:delText></w:r></w:del></w:p>'
            '</w:body></w:document>',
      });
      expect(await OfficeTextExtractor.docx(bytes), ['Sal & açúcar <3']);
    });

    test('agrupa parágrafos em blocos para o recorte de materiais grandes',
        () async {
      final paragraphs = List.generate(
        30,
        (i) => '<w:p><w:r><w:t>${'p$i '.padRight(200, 'x')}</w:t></w:r></w:p>',
      ).join();
      final blocks = await OfficeTextExtractor.docx(
        _zip({
          'word/document.xml':
              '<w:document $_w><w:body>$paragraphs</w:body></w:document>',
        }),
      );
      expect(blocks.length, greaterThan(1));
      expect(blocks.every((b) => b.length < 2400), isTrue);
    });

    test('arquivo que não é ZIP gera mensagem amigável', () async {
      await expectLater(
        OfficeTextExtractor.docx(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<MaterialReadException>()),
      );
    });
  });

  group('pptx', () {
    test('segue a ordem da apresentação e inclui as notas do apresentador',
        () async {
      final bytes = _zip({
        'ppt/presentation.xml': '<p:presentation $_a><p:sldIdLst>'
            '<p:sldId id="256" r:id="rId3"/><p:sldId id="257" r:id="rId2"/>'
            '</p:sldIdLst></p:presentation>',
        'ppt/_rels/presentation.xml.rels': '<Relationships>'
            '<Relationship Id="rId2" Target="slides/slide1.xml"/>'
            '<Relationship Id="rId3" Target="slides/slide2.xml"/>'
            '</Relationships>',
        // Arquivo slide2 é o PRIMEIRO slide da apresentação.
        'ppt/slides/slide2.xml': _slide(['Introdução', 'Objetivos']),
        'ppt/slides/slide1.xml': _slide(['Conclusão']),
        'ppt/slides/_rels/slide1.xml.rels': '<Relationships>'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide1.xml"/>'
            '</Relationships>',
        'ppt/notesSlides/notesSlide1.xml':
            _slide(['Retomar os pontos principais', '2']),
      });

      expect(await OfficeTextExtractor.pptx(bytes), [
        'Introdução\nObjetivos',
        'Conclusão\nNotas do apresentador:\nRetomar os pontos principais',
      ]);
    });

    test('sem índice, usa a numeração dos arquivos', () async {
      final bytes = _zip({
        'ppt/slides/slide10.xml': _slide(['Dez']),
        'ppt/slides/slide2.xml': _slide(['Dois']),
      });
      expect(await OfficeTextExtractor.pptx(bytes), ['Dois', 'Dez']);
    });
  });

  group('MaterialExtractor', () {
    const extractor = MaterialExtractor();

    test('formato antigo é recusado com orientação', () async {
      await expectLater(
        extractor.extract('aula.ppt', Uint8List(0)),
        throwsA(
          isA<MaterialReadException>().having(
            (e) => e.message,
            'message',
            contains('.pptx'),
          ),
        ),
      );
    });

    test('apresentação só com imagens avisa que não há texto', () async {
      final bytes = _zip({'ppt/slides/slide1.xml': _slide([])});
      await expectLater(
        extractor.extract('fotos.pptx', bytes),
        throwsA(
          isA<MaterialReadException>().having(
            (e) => e.message,
            'message',
            contains('só imagens'),
          ),
        ),
      );
    });

    test('junta palavras hifenizadas no fim da linha', () async {
      final bytes = _zip({
        'word/document.xml': '<w:document $_w><w:body>'
            '<w:p><w:r><w:t>o concei-</w:t><w:br/><w:t>to de   estado</w:t></w:r></w:p>'
            '</w:body></w:document>',
      });
      final material = await extractor.extract('texto.docx', bytes);
      expect(material.segments.single, 'o conceito de estado');
    });
  });
}
