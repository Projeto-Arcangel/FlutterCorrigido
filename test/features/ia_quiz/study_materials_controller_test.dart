import 'dart:async';
import 'dart:typed_data';

import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/link_material_source.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/material_extractor.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/data/materials/material_read_exception.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/entities/study_material.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/material_rules.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/presentation/providers/study_materials_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extrator falso: cada arquivo só termina quando o teste libera.
class _FakeExtractor implements MaterialExtractor {
  final pending = <String, Completer<ExtractedMaterial>>{};
  final started = <String>[];

  @override
  Future<ExtractedMaterial> extract(
    String fileName,
    Uint8List bytes, {
    void Function(int done, int total)? onProgress,
  }) {
    started.add(fileName);
    return (pending[fileName] = Completer()).future;
  }

  void finish(String name) => pending[name]!.complete(
        ExtractedMaterial(
          name: name,
          kind: MaterialKind.pdf,
          segments: ['texto de $name'],
        ),
      );

  void fail(String name, String message) =>
      pending[name]!.completeError(MaterialReadException(message));
}

/// Leitor de links falso: cada página só termina quando o teste libera.
class _FakeLinks implements LinkMaterialSource {
  final pending = <String, Completer<LinkMaterial>>{};

  @override
  Future<LinkMaterial> read(Uri url) =>
      (pending[url.host] = Completer()).future;

  void finish(String host, String title, {String? warning}) =>
      pending[host]!.complete(
        (
          material: ExtractedMaterial(
            name: title,
            kind: MaterialKind.link,
            segments: ['texto de $title'],
          ),
          warning: warning,
        ),
      );

  void fail(String host, String message) =>
      pending[host]!.completeError(MaterialReadException(message));
}

PickedMaterialFile _file(String name, [int size = 10]) =>
    (name: name, bytes: Uint8List(size));

void main() {
  late _FakeExtractor extractor;
  late _FakeLinks links;
  late ProviderContainer container;

  StudyMaterialsController controller() =>
      container.read(studyMaterialsProvider.notifier);
  List<MaterialItem> items() => container.read(studyMaterialsProvider);

  setUp(() {
    extractor = _FakeExtractor();
    links = _FakeLinks();
    container = ProviderContainer(
      overrides: [
        materialExtractorProvider.overrideWithValue(extractor),
        linkMaterialSourceProvider.overrideWithValue(links),
      ],
    );
    // Mantém o provider autoDispose vivo durante o teste.
    container.listen(studyMaterialsProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('lê um arquivo por vez, na ordem', () async {
    controller().addFiles([_file('a.pdf'), _file('b.pdf')]);
    await pumpEventQueue();
    expect(extractor.started, ['a.pdf']);
    expect(
      items().map((m) => m.status),
      [MaterialStatus.reading, MaterialStatus.waiting],
    );

    extractor.finish('a.pdf');
    await pumpEventQueue();
    expect(extractor.started, ['a.pdf', 'b.pdf']);

    extractor.finish('b.pdf');
    await pumpEventQueue();
    expect(items().every((m) => m.status == MaterialStatus.ready), isTrue);
    expect(controller().readyMaterials.length, 2);
    expect(controller().isReading, isFalse);
  });

  test('formato antigo entra na lista como falha, com orientação', () {
    controller().addFiles([_file('aula.ppt')]);
    final [item] = items();
    expect(item.status, MaterialStatus.failed);
    expect(item.error, contains('.pptx'));
    expect(extractor.started, isEmpty);
  });

  test('erro de leitura aparece no item, e a fila continua', () async {
    controller().addFiles([_file('ruim.pdf'), _file('bom.pdf')]);
    await pumpEventQueue();
    extractor.fail('ruim.pdf', 'Este PDF é protegido por senha.');
    await pumpEventQueue();
    extractor.finish('bom.pdf');
    await pumpEventQueue();

    expect(items()[0].status, MaterialStatus.failed);
    expect(items()[0].error, 'Este PDF é protegido por senha.');
    expect(items()[1].status, MaterialStatus.ready);
  });

  test('recusa o que passa de 50 MB no total, avisando', () {
    const mb = 1024 * 1024;
    final warnings = controller().addFiles([
      _file('a.pdf', 30 * mb),
      _file('b.pdf', 25 * mb),
      _file('c.pdf', 15 * mb),
    ]);

    expect(items().map((m) => m.name), ['a.pdf', 'c.pdf']);
    expect(warnings.single, contains('"b.pdf" não foi adicionado'));
    expect(controller().totalBytes, 45 * mb);
  });

  test('recusa além de ${MaterialRules.maxMaterials} arquivos', () {
    final warnings = controller().addFiles([
      for (var i = 0; i <= MaterialRules.maxMaterials; i++) _file('f$i.pdf'),
    ]);
    expect(items().length, MaterialRules.maxMaterials);
    expect(
      warnings.single,
      contains('limite é de ${MaterialRules.maxMaterials}'),
    );
  });

  test('remover durante a leitura descarta o resultado', () async {
    controller().addFiles([_file('a.pdf')]);
    await pumpEventQueue();
    final id = items().single.id;

    controller().remove(id);
    extractor.finish('a.pdf');
    await pumpEventQueue();

    expect(items(), isEmpty);
    expect(controller().readyMaterials, isEmpty);
  });

  group('links', () {
    test('link é lido em paralelo, sem esperar a fila de arquivos', () async {
      controller().addFiles([_file('grande.pdf')]);
      await pumpEventQueue();
      expect(
        controller().addLink('pt.wikipedia.org/wiki/Fotossíntese'),
        isNull,
      );
      await pumpEventQueue();

      // O PDF ainda está sendo lido, e o link já terminou.
      links.finish('pt.wikipedia.org', 'Fotossíntese');
      await pumpEventQueue();
      final link = items().last;
      expect(link.status, MaterialStatus.ready);
      expect(link.content!.name, 'Fotossíntese');
      expect(
        link.url.toString(),
        'https://pt.wikipedia.org/wiki/Fotoss%C3%ADntese',
      );
      expect(items().first.status, MaterialStatus.reading);
      expect(controller().isReading, isTrue);

      extractor.finish('grande.pdf');
      await pumpEventQueue();
      expect(
        controller().readyMaterials.map((m) => m.kind),
        [MaterialKind.pdf, MaterialKind.link],
      );
    });

    test('recusa link inválido, de playlist e repetido', () {
      expect(controller().addLink('isto não é um link'), contains('inválido'));
      expect(controller().addLink('ftp://site.com/a'), contains('inválido'));
      expect(
        controller().addLink('https://www.youtube.com/playlist?list=PL1'),
        contains('playlist'),
      );
      expect(controller().addLink('https://site.com/artigo'), isNull);
      expect(
        controller().addLink('site.com/artigo/'),
        'Este link já foi adicionado.',
      );
      expect(items().length, 1);
    });

    test('vídeo do YouTube entra como vídeo, e o mesmo vídeo não se repete',
        () async {
      expect(controller().addLink('youtu.be/dQw4w9WgXcQ'), isNull);
      final item = items().single;
      expect(item.kind, MaterialKind.video);
      expect(item.name, 'Vídeo do YouTube');
      expect(
        item.url.toString(),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      // Outro formato de link, mesmo vídeo.
      expect(
        controller().addLink('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=9'),
        'Este link já foi adicionado.',
      );

      links.fail('www.youtube.com', 'Não consegui abrir este vídeo.');
      await pumpEventQueue();
      expect(items().single.status, MaterialStatus.failed);
      expect(items().single.error, 'Não consegui abrir este vídeo.');
    });

    test('falha na leitura aparece no item, com a mensagem do servidor',
        () async {
      controller().addLink('https://site.com/privado');
      links.fail('site.com', 'Esse site bloqueia a leitura automática.');
      await pumpEventQueue();
      expect(items().single.status, MaterialStatus.failed);
      expect(items().single.error, 'Esse site bloqueia a leitura automática.');
      // Link que falhou não conta como repetido nem para o limite.
      expect(controller().addLink('https://site.com/privado'), isNull);
    });

    test('aviso do servidor (ex.: só a prévia para assinantes) fica no item',
        () async {
      controller().addLink('https://jornal.com/materia');
      links.finish(
        'jornal.com',
        'Matéria',
        warning: 'Parte deste conteúdo pode ser exclusiva para assinantes.',
      );
      await pumpEventQueue();
      final item = items().single;
      expect(item.status, MaterialStatus.ready);
      expect(item.warning, contains('assinantes'));
      // Com aviso, o material continua sendo usado na geração.
      expect(controller().readyMaterials.single.name, 'Matéria');
    });

    test('links contam para o limite de materiais', () {
      for (var i = 0; i < MaterialRules.maxMaterials; i++) {
        expect(controller().addLink('https://site$i.com/a'), isNull);
      }
      expect(
        controller().addLink('https://mais.com/a'),
        contains('limite é de ${MaterialRules.maxMaterials}'),
      );
    });
  });
}
