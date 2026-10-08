import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ia_quiz/domain/entities/study_material.dart';
import '../../../ia_quiz/domain/material_rules.dart';
import '../../../ia_quiz/presentation/providers/study_materials_controller.dart';

// Mesma paleta da IaQuizPage (tela onde este painel aparece).
abstract class _C {
  static const Color accent = Color(0xFF7296D0);
  static const Color accentSubtle = Color(0x1A7296D0);
  static const Color success = Color(0xFF4CAF7D);
  static const Color danger = Color(0xFFE0795B);
  static Color warning(bool dark) =>
      dark ? const Color(0xFFE8A838) : const Color(0xFF8A5A10);
  static const Color textMuted = Color(0xFF8FA3AE);

  static Color cardBg(bool dark) => dark ? AppColors.surfaceDark : Colors.white;
  static Color border(bool dark) =>
      dark ? const Color(0x14FFFFFF) : Colors.black12;
  static Color primaryText(bool dark) =>
      dark ? Colors.white : AppColors.textPrimary;
  static Color mutedText(bool dark) =>
      dark ? textMuted : const Color(0xFF5A6B78);
  static Color track(bool dark) =>
      dark ? AppColors.surfaceDark : const Color(0xFFCFD8DC);
}

/// Anexos do modo "Dos meus materiais": adicionar, acompanhar a leitura,
/// remover e ver quanto do limite foi usado.
///
/// Heurística #1 (visibilidade): progresso por arquivo e uso do limite.
/// Heurística #9 (recuperação de erros): cada falha diz como resolver.
/// Heurística #5 (prevenção): limites checados antes de ler os arquivos.
class IaMaterialsPanel extends ConsumerWidget {
  const IaMaterialsPanel({super.key, required this.onWarning});

  /// Avisos de arquivos que não couberam (quantidade/tamanho).
  final ValueChanged<String> onWarning;

  Future<void> _pick(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: MaterialRules.pickerExtensions,
      withData: true,
    );
    if (result == null) return;

    final files = <PickedMaterialFile>[
      for (final f in result.files)
        if (f.bytes != null) (name: f.name, bytes: f.bytes!),
    ];
    final warnings = ref.read(studyMaterialsProvider.notifier).addFiles(files);
    for (final w in warnings) {
      onWarning(w);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = ref.watch(studyMaterialsProvider);
    final controller = ref.read(studyMaterialsProvider.notifier);
    final usedBytes = controller.totalBytes;
    final full = items.where((m) => m.countsTowardsLimit).length >=
            MaterialRules.maxMaterials ||
        usedBytes >= MaterialRules.maxTotalBytes;

    final partial = MaterialRules.coverageOf(controller.readyMaterials)
        .where((m) => m.coverage < 0.999)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AddButton(
          enabled: !full,
          onTap: () => _pick(ref),
        ),
        const SizedBox(height: 10),
        _LinkInput(
          enabled: !full,
          onSubmit: (raw) =>
              ref.read(studyMaterialsProvider.notifier).addLink(raw),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                FontAwesomeIcons.lock,
                size: 11,
                color: _C.mutedText(isDark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Para manter sua privacidade, os arquivos são lidos pelo seu '
                'navegador e não são armazenados.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: _C.mutedText(isDark),
                ),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final item in items) ...[
            _MaterialTile(
              item: item,
              onRemove: () => controller.remove(item.id),
            ),
            const SizedBox(height: 8),
          ],
          // O limite de 50 MB é só de arquivos: com só links, não aparece.
          if (items.any((m) => m.url == null)) ...[
            const SizedBox(height: 4),
            _UsageBar(usedBytes: usedBytes),
          ],
        ],
        if (partial.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PartialNotice(materials: partial),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = enabled ? _C.accent : _C.mutedText(isDark);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Adicionar materiais: PDF, DOCX ou PPTX',
      excludeSemantics: true,
      child: Material(
        color: enabled ? _C.accentSubtle : _C.cardBg(isDark),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                FaIcon(FontAwesomeIcons.fileArrowUp, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled
                            ? 'Adicionar materiais'
                            : 'Limite de materiais atingido',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PDF, DOCX ou PPTX · até ${MaterialRules.maxMaterials} '
                        'materiais e ${_mb(MaterialRules.maxTotalBytes)} em '
                        'arquivos',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: _C.mutedText(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo para colar o link de uma página ou de um vídeo do YouTube. Erros
/// (link inválido, repetido, de playlist) aparecem logo abaixo do campo.
class _LinkInput extends StatefulWidget {
  const _LinkInput({required this.enabled, required this.onSubmit});

  final bool enabled;

  /// Devolve a mensagem de erro, ou `null` se o link foi aceito.
  final String? Function(String raw) onSubmit;

  @override
  State<_LinkInput> createState() => _LinkInputState();
}

class _LinkInputState extends State<_LinkInput> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.enabled || _controller.text.trim().isEmpty) return;
    final error = widget.onSubmit(_controller.text);
    setState(() => _error = error);
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: _C.primaryText(isDark),
            ),
            decoration: InputDecoration(
              hintText: 'Cole o link de uma página ou vídeo do YouTube',
              hintStyle: GoogleFonts.nunito(
                fontSize: 13,
                color: _C.mutedText(isDark),
              ),
              prefixIcon: Icon(
                Icons.link_rounded,
                size: 20,
                color: _C.mutedText(isDark),
              ),
              errorText: _error,
              errorMaxLines: 3,
              filled: true,
              fillColor: _C.cardBg(isDark),
              // Mesma altura do botão "Adicionar" (48 px, alvo de toque).
              constraints: const BoxConstraints(minHeight: 48),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              enabledBorder: border(_C.border(isDark)),
              disabledBorder: border(_C.border(isDark)),
              focusedBorder: border(_C.accent, 1.5),
              errorBorder: border(_C.danger),
              focusedErrorBorder: border(_C.danger, 1.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: widget.enabled ? _submit : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.accent,
              side: BorderSide(color: _C.accent.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Adicionar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.item, required this.onRemove});

  final MaterialItem item;
  final VoidCallback onRemove;

  IconData get _icon => switch (item.kind) {
        MaterialKind.pdf => FontAwesomeIcons.filePdf,
        MaterialKind.docx => FontAwesomeIcons.fileWord,
        MaterialKind.pptx => FontAwesomeIcons.filePowerpoint,
        MaterialKind.link => FontAwesomeIcons.link,
        MaterialKind.video => FontAwesomeIcons.youtube,
        null => FontAwesomeIcons.fileCircleExclamation,
      };

  String get _status {
    final content = item.content;
    return switch (item.status) {
      MaterialStatus.waiting => 'Na fila para leitura…',
      MaterialStatus.reading => switch (item.kind) {
          MaterialKind.link => 'Lendo a página…',
          // Costuma levar menos de 1 minuto; com o serviço do Google
          // sobrecarregado, até 2. O aviso evita que pareça travado.
          MaterialKind.video => 'Assistindo ao vídeo… pode levar até 2 minutos',
          _ when item.total > 0 =>
            'Lendo… ${item.done} de ${item.total} páginas',
          _ => 'Lendo…',
        },
      MaterialStatus.ready when content != null =>
        '${content.segments.length} ${_plural(content.kind.unitLabel, content.segments.length)} · '
            '${_formatChars(content.totalChars)} de texto',
      MaterialStatus.ready => 'Pronto',
      MaterialStatus.failed => item.error ?? 'Não foi possível ler.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final failed = item.status == MaterialStatus.failed;
    final reading = item.status == MaterialStatus.reading ||
        item.status == MaterialStatus.waiting;
    final statusColor = failed
        ? _C.danger
        : item.status == MaterialStatus.ready
            ? _C.success
            : _C.mutedText(isDark);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: _C.cardBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: failed ? _C.danger.withValues(alpha: 0.5) : _C.border(isDark),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                FaIcon(_icon, size: 18, color: failed ? _C.danger : _C.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content?.name ?? item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.primaryText(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Semantics(
                  liveRegion: failed || item.status == MaterialStatus.ready,
                  child: Text(
                    '${item.url != null ? _host(item.url!) : _mb(item.sizeBytes)}'
                    ' · $_status',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: failed ? FontWeight.w700 : FontWeight.w500,
                      color: statusColor,
                      height: 1.35,
                    ),
                  ),
                ),
                if (item.warning != null &&
                    item.status == MaterialStatus.ready) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: FaIcon(
                          FontAwesomeIcons.triangleExclamation,
                          size: 11,
                          color: _C.warning(isDark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.warning!,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.warning(isDark),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (reading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.total > 0 ? item.done / item.total : null,
                      minHeight: 4,
                      backgroundColor: _C.track(isDark),
                      valueColor: const AlwaysStoppedAnimation(_C.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover ${item.name}',
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: _C.mutedText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.usedBytes});

  final int usedBytes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction =
        (usedBytes / MaterialRules.maxTotalBytes).clamp(0.0, 1.0).toDouble();

    return Semantics(
      label: '${_mb(usedBytes)} usados de ${_mb(MaterialRules.maxTotalBytes)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: _C.track(isDark),
                valueColor: AlwaysStoppedAnimation(
                  fraction > 0.9 ? _C.danger : _C.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_mb(usedBytes)} de ${_mb(MaterialRules.maxTotalBytes)}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _C.mutedText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avisa, ANTES de gerar, quando a IA vai ler só parte de algum material.
class _PartialNotice extends StatelessWidget {
  const _PartialNotice({required this.materials});

  final List<({String name, double coverage})> materials;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = materials
        .map((m) => '${m.name} (${(m.coverage * 100).round()}%)')
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child:
                FaIcon(FontAwesomeIcons.circleInfo, size: 13, color: _C.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'O conteúdo é extenso, então a IA vai ler trechos espalhados '
              'ao longo de: $list. Para cobrir uma parte específica, '
              'indique-a na descrição abaixo ou envie só o trecho desejado.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                height: 1.4,
                color: _C.primaryText(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _mb(int bytes) {
  if (bytes < 100 * 1024) {
    // Arquivos pequenos em KB: "0,0 MB" pareceria um arquivo vazio.
    return '${(bytes / 1024).ceil()} KB';
  }
  final mb = bytes / (1024 * 1024);
  final text = mb < 10 ? mb.toStringAsFixed(1) : mb.toStringAsFixed(0);
  return '${text.replaceAll('.', ',')} MB';
}

String _plural(String unit, int count) => count == 1 ? unit : '${unit}s';

String _formatChars(int chars) {
  if (chars < 1000) return '$chars caracteres';
  final k = (chars / 1000).round();
  return '$k mil caracteres';
}

String _host(Uri url) => url.host.replaceFirst(RegExp(r'^www\.'), '');
