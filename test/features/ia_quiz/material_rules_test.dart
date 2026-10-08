import 'package:arcangel_o_oficial/features/ia_quiz/domain/entities/study_material.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/material_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ExtractedMaterial _material(String name, List<String> segments) =>
    ExtractedMaterial(name: name, kind: MaterialKind.pdf, segments: segments);

void main() {
  group('formatos', () {
    test('aceita PDF, DOCX e PPTX (sem diferenciar maiúsculas)', () {
      expect(MaterialRules.kindOf('Aula 1.PDF'), MaterialKind.pdf);
      expect(MaterialRules.kindOf('resumo.docx'), MaterialKind.docx);
      expect(MaterialRules.kindOf('slides.pptx'), MaterialKind.pptx);
      expect(MaterialRules.unsupportedReason('slides.pptx'), isNull);
    });

    test('formatos antigos explicam como converter', () {
      expect(
        MaterialRules.unsupportedReason('aula.ppt'),
        contains('"Salvar como" .pptx'),
      );
      expect(
        MaterialRules.unsupportedReason('texto.doc'),
        contains('"Salvar como" .docx'),
      );
      expect(
        MaterialRules.unsupportedReason('foto.png'),
        'Formato não aceito. Envie PDF, DOCX ou PPTX.',
      );
    });
  });

  group('selectForAi', () {
    test('material que cabe vai inteiro, com rótulo de cada parte', () {
      final [selected] = MaterialRules.selectForAi([
        _material('a.pdf', ['primeira página', 'segunda página']),
      ]);
      expect(selected.coverage, 1);
      expect(selected.isPartial, isFalse);
      expect(
        selected.text,
        '[Página 1]\nprimeira página\n\n[Página 2]\nsegunda página',
      );
    });

    test('materiais sem texto ficam de fora', () {
      final selected = MaterialRules.selectForAi([
        _material('vazio.pdf', ['', '']),
        _material('ok.pdf', ['conteúdo']),
      ]);
      expect(selected.map((m) => m.name), ['ok.pdf']);
    });

    test('divisão justa: o pequeno entra inteiro, o grande é recortado', () {
      final small = _material('pequeno.pdf', ['x' * 1000]);
      final big = _material('grande.pdf', List.filled(100, 'y' * 1000));

      final [s, b] = MaterialRules.selectForAi([small, big], budget: 21000);

      expect(s.coverage, 1);
      expect(b.isPartial, isTrue);
      // O grande usa o que sobra do orçamento (20 mil), sem passar.
      expect(b.coverage, closeTo(0.2, 0.03));
    });

    test('o recorte fica espalhado pelo material, não só no começo', () {
      final pages = [for (var i = 1; i <= 100; i++) 'página $i ${'z' * 990}'];
      final [selected] = MaterialRules.selectForAi(
        [_material('apostila.pdf', pages)],
        budget: 10000,
      );

      final pagesRead = RegExp(r'\[Página (\d+)\]')
          .allMatches(selected.text)
          .map((m) => int.parse(m[1]!))
          .toList();
      // ~10% das páginas, cobrindo começo, meio e fim.
      expect(pagesRead.length, inInclusiveRange(8, 10));
      expect(pagesRead.first, 1);
      expect(pagesRead.any((p) => p >= 40 && p <= 60), isTrue);
      expect(pagesRead.last, greaterThanOrEqualTo(90));
    });

    test('um único bloco enorme também é recortado de forma espalhada', () {
      final text =
          List.generate(50, (i) => 'parte$i'.padRight(1000, '.')).join();
      final [selected] = MaterialRules.selectForAi(
        [
          _material('unico.pdf', [text]),
        ],
        budget: 10000,
      );

      expect(selected.isPartial, isTrue);
      expect(selected.text, contains('parte4'));
      expect(selected.text, contains('parte48'));
    });

    test('o total enviado respeita o orçamento', () {
      final materials = [
        for (var m = 0; m < 5; m++)
          _material('m$m.pdf', List.filled(80, 'w' * 1500)),
      ];
      final selected = MaterialRules.selectForAi(materials, budget: 50000);
      final chars = selected.fold<int>(0, (sum, m) => sum + m.text.length);
      // Rótulos "[Página N]" somam um pouco além do texto em si.
      expect(chars, lessThan(50000 * 1.05));
      for (final m in selected) {
        expect(m.coverage, closeTo(10000 / 120000, 0.02));
      }
    });
  });

  group('links', () {
    test('normaliza o endereço (https:// automático)', () {
      expect(
        MaterialRules.normalizeLink(' pt.wikipedia.org/wiki/Brasil ')
            .toString(),
        'https://pt.wikipedia.org/wiki/Brasil',
      );
      expect(
        MaterialRules.normalizeLink('http://site.com.br/a?b=1').toString(),
        'http://site.com.br/a?b=1',
      );
    });

    test('recusa endereços inválidos', () {
      for (final raw in [
        '',
        'texto solto',
        'localhost',
        'ftp://site.com/a',
        'javascript:alert(1)',
        'https://.com',
      ]) {
        expect(MaterialRules.normalizeLink(raw), isNull, reason: raw);
      }
    });

    test('vídeo do YouTube vira o endereço canônico, em qualquer formato', () {
      const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      for (final raw in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'youtube.com/watch?v=dQw4w9WgXcQ&t=42s',
        'https://www.youtube.com/watch?list=PL123&v=dQw4w9WgXcQ',
        'youtu.be/dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?si=abc',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
        'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
      ]) {
        expect(MaterialRules.linkProblem(raw), isNull, reason: raw);
        expect(
          MaterialRules.normalizeLink(raw).toString(),
          canonical,
          reason: raw,
        );
      }
    });

    test('link do YouTube que não é de um vídeo recebe orientação', () {
      expect(
        MaterialRules.linkProblem(
          'https://www.youtube.com/playlist?list=PL123',
        ),
        contains('playlist'),
      );
      for (final raw in [
        'https://www.youtube.com/@canal',
        'https://www.youtube.com/channel/UC123',
        'https://www.youtube.com/c/canal',
      ]) {
        expect(MaterialRules.linkProblem(raw), contains('canal'), reason: raw);
      }
      for (final raw in [
        'https://www.youtube.com/',
        'https://www.youtube.com/results?search_query=fotossintese',
        // ID com tamanho errado não é vídeo.
        'https://www.youtube.com/watch?v=abc',
        'youtu.be/abc',
      ]) {
        expect(
          MaterialRules.linkProblem(raw),
          contains('não aponta para um vídeo'),
          reason: raw,
        );
      }
      expect(MaterialRules.linkProblem('https://site.com/artigo'), isNull);
    });
  });
}
