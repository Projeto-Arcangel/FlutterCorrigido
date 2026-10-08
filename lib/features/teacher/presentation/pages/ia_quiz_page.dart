import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ia_quiz/domain/entities/ia_model_option.dart';
import '../../../ia_quiz/domain/material_rules.dart';
import '../../../ia_quiz/presentation/providers/ia_quiz_providers.dart';
import '../../../ia_quiz/presentation/providers/study_materials_controller.dart';
import '../widgets/ia_materials_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local — exclusiva da tela de IA
// Accent azul-IA consistente com o atalho rápido em TeacherPage.
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color accent = Color(0xFF7296D0);
  static const Color accentSubtle = Color(0x1A7296D0);
  static const Color gradientEnd = Color(0xFF8B72D0);

  static const Color border = Color(0x14FFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);

  static Color cardBg(bool dark) => dark ? AppColors.surfaceDark : Colors.white;
  static Color adaptiveBorder(bool dark) => dark ? border : Colors.black12;
  static Color primaryText(bool dark) => dark ? Colors.white : AppColors.textPrimary;
  static Color mutedText(bool dark) => dark ? textMuted : const Color(0xFF5A6B78);
  static Color disabledBg(bool dark) => dark ? AppColors.surfaceDark : const Color(0xFFE0E0E0);
  static Color trackInactive(bool dark) => dark ? AppColors.surfaceDark : const Color(0xFFCFD8DC);
}

// ─────────────────────────────────────────────────────────────────────────────
// Metadados por disciplina — cor, ícone e placeholder do campo de tema.
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectMeta {
  const _SubjectMeta({
    required this.color,
    required this.icon,
    required this.hint,
  });
  final Color color;
  final IconData icon;
  final String hint;
}

const _kSubjectMeta = <String, _SubjectMeta>{
  'português': _SubjectMeta(
    color: AppColors.subjectPortuguese,
    icon: FontAwesomeIcons.bookOpen,
    hint: 'Ex: análise textual, redação, gramática...',
  ),
  'matemática': _SubjectMeta(
    color: AppColors.subjectMath,
    icon: FontAwesomeIcons.calculator,
    hint: 'Ex: funções, matrizes, trigonometria...',
  ),
  'história': _SubjectMeta(
    color: Color(0xFFB8906A),
    icon: FontAwesomeIcons.buildingColumns,
    hint: 'Ex: Estado Novo, Vargas, industrialização...',
  ),
  'geografia': _SubjectMeta(
    color: AppColors.subjectGeography,
    icon: FontAwesomeIcons.earthAmericas,
    hint: 'Ex: clima, biomas, geopolítica...',
  ),
  'filosofia': _SubjectMeta(
    color: AppColors.subjectPhilosophy,
    icon: FontAwesomeIcons.infinity,
    hint: 'Ex: Platão, ética, existencialismo...',
  ),
  'sociologia': _SubjectMeta(
    color: AppColors.subjectSociology,
    icon: FontAwesomeIcons.users,
    hint: 'Ex: capitalismo, movimentos sociais...',
  ),
  'biologia': _SubjectMeta(
    color: AppColors.subjectBiology,
    icon: FontAwesomeIcons.dna,
    hint: 'Ex: genética, ecossistemas, citologia...',
  ),
  'química': _SubjectMeta(
    color: AppColors.subjectChemistry,
    icon: FontAwesomeIcons.flask,
    hint: 'Ex: reações, tabela periódica, termodinâmica...',
  ),
  'física': _SubjectMeta(
    color: AppColors.subjectPhysics,
    icon: FontAwesomeIcons.atom,
    hint: 'Ex: mecânica, eletricidade, óptica...',
  ),
  'artes': _SubjectMeta(
    color: AppColors.subjectArts,
    icon: FontAwesomeIcons.paintbrush,
    hint: 'Ex: renascimento, arte moderna, linguagem visual...',
  ),
  'educação física': _SubjectMeta(
    color: AppColors.subjectPhysEd,
    icon: FontAwesomeIcons.personRunning,
    hint: 'Ex: esportes, saúde, biomecânica...',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de domínio de apresentação
// ─────────────────────────────────────────────────────────────────────────────

enum _Difficulty {
  easy(1, 'Fácil', 'easy'),
  medium(2, 'Médio', 'medium'),
  hard(3, 'Difícil', 'hard'),
  expert(4, 'Expert', 'expert');

  const _Difficulty(this.stars, this.label, this.key);
  final int stars;
  final String label;
  // [key] casa com `DIFFICULTY_LABELS` em supabase/functions/_shared/openrouter.ts.
  final String key;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// Heurística #1: feedback imediato de estado (botão, loading, snackbar).
// Heurística #3: voltar sempre acessível.
// Heurística #5: botão desabilitado enquanto tema estiver vazio.
// Heurística #8: densidade visual controlada, hierarquia clara.
// ─────────────────────────────────────────────────────────────────────────────

class IaQuizPage extends ConsumerStatefulWidget {
  const IaQuizPage({
    super.key,
    this.classroomId,
    this.phaseId,
    this.phaseTitle,
    this.subject,
  });

  /// ID da sala de aula em que a fase gerada será salva.
  /// Passado via `extra` do router. Se nulo, o salvamento na review
  /// page exibe erro pedindo para o professor entrar em uma turma.
  final String? classroomId;

  /// ID de uma fase já existente. Quando informado, as questões
  /// geradas são **adicionadas a essa fase** (sem criar fase nova).
  final String? phaseId;

  /// Título da fase-alvo (apenas para exibição/contexto na review).
  final String? phaseTitle;

  /// Disciplina da fase (ex: 'história', 'matemática'). Determina cor,
  /// ícone e placeholder do campo de tema.
  final String? subject;

  @override
  ConsumerState<IaQuizPage> createState() => _IaQuizPageState();
}

class _IaQuizPageState extends ConsumerState<IaQuizPage> {
  final _topicCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _topicFocus = FocusNode();

  _Difficulty _difficulty = _Difficulty.medium;
  double _quantity = 5;
  int _alternatives = 4;
  IaModelOption _selectedModel = IaModelOption.defaultOption;

  /// "Dos meus materiais" (true) ou "Por tema" (false).
  bool _fromMaterials = false;

  bool get _canGenerate {
    final isLoading = ref.read(iaGenerationNotifierProvider).isLoading;
    if (isLoading) return false;
    if (_fromMaterials) {
      final materials = ref.read(studyMaterialsProvider.notifier);
      return materials.readyMaterials.isNotEmpty && !materials.isReading;
    }
    return _topicCtrl.text.trim().isNotEmpty;
  }

  /// Título usado na revisão (e como nome da fase, quando ela é criada).
  String get _reviewTitle {
    if (!_fromMaterials) return _topicCtrl.text.trim();
    final names = ref
        .read(studyMaterialsProvider.notifier)
        .readyMaterials
        .map((m) => m.name.replaceAll(RegExp(r'\.(pdf|docx|pptx)$'), ''))
        .join(', ');
    final title = 'Materiais: $names';
    return title.length <= 60 ? title : '${title.substring(0, 57)}...';
  }

  /// Guardado no initState: o dispose não pode mais usar o `ref`.
  late final IaGenerationNotifier _generation;

  @override
  void initState() {
    super.initState();
    // Com a tela aberta, é ela que leva o professor à revisão.
    _generation = ref.read(iaGenerationNotifierProvider.notifier)
      ..attachScreen();
    // Questões que ficaram prontas com o professor fora daqui.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingReview());
  }

  @override
  void dispose() {
    _generation.detachScreen();
    _topicCtrl.dispose();
    _descCtrl.dispose();
    _topicFocus.dispose();
    super.dispose();
  }

  void _openPendingReview() {
    if (!mounted) return;
    final outcome = _generation.take();
    if (outcome == null) return;
    context.push(
      AppRoutes.teacherIaQuizReview,
      extra: outcome.reviewExtra(fromCreation: true),
    );
  }

  Future<void> _generate() async {
    if (!_canGenerate) return;
    FocusScope.of(context).unfocus();

    // Só o texto (já recortado no limite da IA) sai do navegador.
    final materials = _fromMaterials
        ? MaterialRules.selectForAi(
            ref.read(studyMaterialsProvider.notifier).readyMaterials,
          )
        : null;

    await _generation.generate(
      // Com materiais não há tema: o recorte vem da descrição.
      topic: _fromMaterials ? '' : _topicCtrl.text,
      difficulty: _difficulty.key,
      quantity: _quantity.round(),
      alternatives: _alternatives,
      description: _descCtrl.text,
      model: _selectedModel,
      subject: widget.subject,
      materials: materials,
      // O professor pode sair antes do fim: o destino vai junto.
      target: IaReviewTarget(
        title: _reviewTitle,
        difficultyLabel: _difficulty.label,
        classroomId: widget.classroomId,
        phaseId: widget.phaseId,
        phaseTitle: widget.phaseTitle,
      ),
    );
  }

  /// Sair durante a leitura dos anexos descarta os materiais: confirma antes.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _LeaveWhileReadingDialog(),
    );
    if ((leave ?? false) && mounted) Navigator.of(context).pop();
  }

  void _showErrorSnack(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.circleExclamation,
              size: 15,
              color: Color(0xFFFF6B6B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _C.cardBg(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Observa o estado da geração e reage: sucesso abre a revisão, erro
    // exibe snack. (Com a tela fechada, o IaGenerationWatcher avisa.)
    ref.listen<AsyncValue<IaGenerationOutcome?>>(
      iaGenerationNotifierProvider,
      (prev, next) {
        next.when(
          data: (outcome) {
            if (outcome != null) _openPendingReview();
          },
          error: (err, _) {
            final msg = err is Failure
                ? err.message
                : 'Falha ao gerar questões. Tente novamente.';
            _showErrorSnack(msg);
            _generation.reset();
          },
          loading: () {},
        );
      },
    );

    final isLoading = ref.watch(
      iaGenerationNotifierProvider.select((s) => s.isLoading),
    );

    final quotaAsync = ref.watch(aiDailyQuotaProvider);

    // Mantém os anexos vivos enquanto a tela estiver aberta. A página só se
    // redesenha quando muda o que habilita o botão "Gerar" — o progresso de
    // leitura de cada arquivo redesenha apenas o painel de materiais.
    final materials = ref.watch(
      studyMaterialsProvider.select(
        (items) => (
          anyReady: items.any((m) => m.status == MaterialStatus.ready),
          reading: items.any(
            (m) =>
                m.status == MaterialStatus.reading ||
                m.status == MaterialStatus.waiting,
          ),
        ),
      ),
    );

    final meta = _kSubjectMeta[widget.subject?.toLowerCase()] ??
        _kSubjectMeta['história']!;

    final page = GestureDetector(
      // Heurística #3: toque fora do campo fecha o teclado
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // maybePop: passa pelo PopScope (context.pop não passa).
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho da tela
                      const _ScreenTitle(),
                      const SizedBox(height: 20),

                      // Cota diária de IA — limite + quanto já foi gerado hoje
                      quotaAsync.when(
                        data: (q) => _QuotaBanner(
                          used: q.used,
                          limit: q.limit,
                          remaining: q.remaining,
                        ),
                        loading: () => const _QuotaBanner.loading(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 28),

                      // Origem: tema digitado ou materiais do professor
                      _sectionLabel('GERAR A PARTIR DE'),
                      const SizedBox(height: 10),
                      _SourceToggle(
                        fromMaterials: _fromMaterials,
                        enabled: !isLoading,
                        onChanged: (value) =>
                            setState(() => _fromMaterials = value),
                      ),
                      const SizedBox(height: 28),

                      // Disciplina — dinâmica conforme a fase selecionada
                      _sectionLabel('DISCIPLINA'),
                      const SizedBox(height: 10),
                      _SubjectBadge(
                        subject: widget.subject ?? 'história',
                        meta: meta,
                      ),
                      const SizedBox(height: 28),

                      if (_fromMaterials) ...[
                        _sectionLabel('MATERIAIS'),
                        const SizedBox(height: 10),
                        IaMaterialsPanel(onWarning: _showErrorSnack),
                        const SizedBox(height: 28),
                      ],

                      // Tema geral — só na geração por tema. Com materiais,
                      // o assunto já vem dos arquivos e o recorte vai na
                      // descrição.
                      if (!_fromMaterials) ...[
                        _sectionLabel('TEMA GERAL'),
                        const SizedBox(height: 10),
                        _TopicField(
                          controller: _topicCtrl,
                          focusNode: _topicFocus,
                          placeholder: meta.hint,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Descrição opcional: estilo das questões e, com
                      // materiais, também o foco (capítulo, assunto...)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('DESCRIÇÃO (OPCIONAL)'),
                          Text(
                            '${_descCtrl.text.length}/500',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _C.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DescriptionField(
                        controller: _descCtrl,
                        hint: _fromMaterials
                            ? 'Ex: foque no capítulo 3 e na fotossíntese, '
                                'priorize causas e consequências, use '
                                'linguagem acessível para o 8º ano...'
                            : 'Ex: foco em causas e consequências, evite '
                                'questões só de datas, use linguagem '
                                'acessível para o 8º ano...',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 28),

                      // Dificuldade
                      _sectionLabel('DIFICULDADE'),
                      const SizedBox(height: 10),
                      _DifficultySelector(
                        selected: _difficulty,
                        onSelect: (d) => setState(() => _difficulty = d),
                      ),
                      const SizedBox(height: 28),

                      // Quantidade — label + contador dinâmico lado a lado (Nielsen #1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('QUANTIDADE'),
                          Text(
                            '${_quantity.round()} questões',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _QuantitySlider(
                        value: _quantity,
                        onChanged: (v) => setState(() => _quantity = v),
                      ),
                      const SizedBox(height: 28),

                      // Alternativas por questão
                      _sectionLabel('ALTERNATIVAS POR QUESTÃO'),
                      const SizedBox(height: 10),
                      _AlternativesSelector(
                        selected: _alternatives,
                        onSelect: (n) => setState(() => _alternatives = n),
                      ),
                      const SizedBox(height: 28),

                      // Modelo de IA
                      _sectionLabel('MODELO DE IA'),
                      const SizedBox(height: 10),
                      _ModelSelector(
                        selected: _selectedModel,
                        onSelect: (m) => setState(() => _selectedModel = m),
                      ),
                      const SizedBox(height: 40),

                      // Botão principal
                      _GenerateButton(
                        enabled: _canGenerate,
                        loading: isLoading,
                        onTap: _generate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      // Durante a leitura dos anexos, sair pede confirmação. A geração em
      // si pode ficar para trás: ela continua e avisa quando terminar.
      canPop: !materials.reading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: page,
    );
  }

  // Label de seção — reutilizado inline para não criar widget separado
  Widget _sectionLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _C.mutedText(isDark),
        letterSpacing: 2.0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar — Voltar
// Heurística #3 (controle): saída sempre visível e acessível.
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(24),
          splashColor: _C.accentSubtle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _C.accent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Voltar',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.accent,
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

// ─────────────────────────────────────────────────────────────────────────────
// Source Toggle — "Por tema" ou "Dos meus materiais".
// Heurística #4 (consistência): mesmo estilo de seleção da dificuldade.
// Heurística #6 (reconhecimento): ícone + rótulo + descrição curta.
// ─────────────────────────────────────────────────────────────────────────────

/// Confirmação ao sair enquanto os anexos ainda estão sendo lidos.
class _LeaveWhileReadingDialog extends StatelessWidget {
  const _LeaveWhileReadingDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: _C.cardBg(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Sair e descartar os materiais?',
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _C.primaryText(isDark),
        ),
      ),
      content: Text(
        // Vale mesmo se a leitura terminar com o diálogo aberto.
        'Os materiais anexados ficam só nesta tela. Se você sair agora, eles '
        'serão descartados e precisarão ser anexados de novo.',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _C.mutedText(isDark),
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Continuar aqui',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.mutedText(isDark),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _C.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Sair',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({
    required this.fromMaterials,
    required this.enabled,
    required this.onChanged,
  });

  final bool fromMaterials;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceOption(
            icon: FontAwesomeIcons.lightbulb,
            label: 'Por tema',
            caption: 'Você descreve o assunto',
            selected: !fromMaterials,
            onTap: enabled ? () => onChanged(false) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SourceOption(
            icon: FontAwesomeIcons.paperclip,
            label: 'Dos meus materiais',
            caption: 'Arquivos, links e vídeos',
            selected: fromMaterials,
            onTap: enabled ? () => onChanged(true) : null,
          ),
        ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _C.accentSubtle : _C.cardBg(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? _C.accent.withValues(alpha: 0.55)
                    : _C.adaptiveBorder(isDark),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  size: 15,
                  color: selected ? _C.accent : _C.mutedText(isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? _C.accent
                              : _C.primaryText(isDark),
                        ),
                      ),
                      Text(
                        caption,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
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

// ─────────────────────────────────────────────────────────────────────────────
// Screen Title
// Heurística #1: função e contexto da tela claros no topo.
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _C.accentSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.wandMagicSparkles,
              color: _C.accent,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Questões com IA',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _C.primaryText(isDark),
                  height: 1.15,
                ),
              ),
              Text(
                'Gere questões por tema ou a partir dos seus materiais',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _C.mutedText(isDark),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quota Banner — limite diário de IA + quanto o professor já gerou hoje.
// Heurística #1 (visibilidade do estado): o teto e o consumo ficam explícitos
// antes da geração; quando esgota, a mensagem orienta a voltar amanhã.
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({
    required this.used,
    required this.limit,
    required this.remaining,
  }) : _loading = false;

  const _QuotaBanner.loading()
      : used = 0,
        limit = 0,
        remaining = 0,
        _loading = true;

  final int used;
  final int limit;
  final int remaining;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exhausted = !_loading && remaining <= 0;
    final accent = exhausted ? const Color(0xFFE0795B) : _C.accent;
    final progress =
        (_loading || limit == 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);

    final String caption;
    if (_loading) {
      caption = 'Carregando seu uso de hoje…';
    } else if (exhausted) {
      caption = 'Limite diário atingido. Tente novamente amanhã.';
    } else {
      caption =
          'Você ainda pode gerar $remaining ${remaining == 1 ? 'questão' : 'questões'} hoje.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.boltLightning, size: 13, color: accent),
              const SizedBox(width: 8),
              Text(
                'Uso diário de IA',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.primaryText(isDark),
                ),
              ),
              const Spacer(),
              Text(
                _loading ? '—' : '$used / $limit',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _loading ? null : progress,
              minHeight: 6,
              backgroundColor: _C.trackInactive(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _C.mutedText(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Badge — disciplina dinâmica conforme a fase selecionada.
// Heurística #6 (reconhecimento): ícone + texto tornam a matéria inequívoca.
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.subject, required this.meta});

  final String subject;
  final _SubjectMeta meta;

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: meta.color.withValues(alpha: 0.40),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(meta.icon, size: 13, color: meta.color),
          const SizedBox(width: 8),
          Text(
            _capitalize(subject),
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: meta.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic Field
// Heurística #6: placeholder com exemplos reais de uso por disciplina.
// Heurística #1: borda destacada no foco indica campo ativo.
// ─────────────────────────────────────────────────────────────────────────────

class _TopicField extends StatelessWidget {
  const _TopicField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _C.primaryText(isDark),
      ),
      cursorColor: _C.accent,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _C.mutedText(isDark),
        ),
        filled: true,
        fillColor: _C.cardBg(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Description Field — campo livre para afunilar o estilo das questões.
// Heurística #6: hint com exemplos guia o uso.
// Heurística #5: limite de caracteres exibido na label.
// ─────────────────────────────────────────────────────────────────────────────

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: 500,
      maxLines: 4,
      minLines: 3,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _C.primaryText(isDark),
      ),
      cursorColor: _C.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _C.mutedText(isDark),
          height: 1.4,
        ),
        filled: true,
        fillColor: _C.cardBg(isDark),
        contentPadding: const EdgeInsets.all(14),
        counterText: '', // contador é renderizado na label (controle manual)
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty Selector
// Heurística #6 (reconhecimento): estrelas + rótulo tornam cada nível claro.
// Heurística #4 (consistência): estilo de seleção igual ao restante do app.
// ─────────────────────────────────────────────────────────────────────────────

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({
    required this.selected,
    required this.onSelect,
  });

  final _Difficulty selected;
  final ValueChanged<_Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _Difficulty.values.asMap().entries.map((entry) {
        final isLast = entry.key == _Difficulty.values.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: _DifficultyOption(
              difficulty: entry.value,
              isSelected: selected == entry.value,
              onTap: () => onSelect(entry.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  final _Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _C.accentSubtle : _C.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _C.accent.withValues(alpha: 0.55)
                : _C.adaptiveBorder(isDark),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Estrelas representando o nível
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(difficulty.stars, (_) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: FaIcon(
                    FontAwesomeIcons.solidStar,
                    size: 10,
                    color: isSelected
                        ? _C.accent
                        : _C.textMuted.withValues(alpha: 0.35),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            // Rótulo textual — heurística #6
            Text(
              difficulty.label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? _C.accent : _C.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity Slider
// Heurística #7 (flexibilidade): controle contínuo com granularidade fina.
// ─────────────────────────────────────────────────────────────────────────────

class _QuantitySlider extends StatelessWidget {
  const _QuantitySlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _C.accent,
        inactiveTrackColor: _C.trackInactive(isDark),
        thumbColor: _C.accent,
        overlayColor: _C.accentSubtle,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      child: Slider(
        value: value,
        min: 1,
        max: 20,
        divisions: 19,
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alternatives Selector — quantas alternativas cada questão terá (2–5).
// Heurística #4: mesmo padrão visual do _DifficultySelector.
// ─────────────────────────────────────────────────────────────────────────────

class _AlternativesSelector extends StatelessWidget {
  const _AlternativesSelector({
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  static const _options = [2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.asMap().entries.map((entry) {
        final isLast = entry.key == _options.length - 1;
        final n = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: _AlternativesOption(
              count: n,
              isSelected: selected == n,
              onTap: () => onSelect(n),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AlternativesOption extends StatelessWidget {
  const _AlternativesOption({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _C.accentSubtle : _C.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _C.accent.withValues(alpha: 0.55)
                : _C.adaptiveBorder(isDark),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isSelected ? _C.accent : _C.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Selector — chips para escolher qual IA gera as questões.
// Heurística #4: mesmo padrão visual do _DifficultySelector.
// Heurística #6: nome + descrição curta tornam a escolha clara.
// ─────────────────────────────────────────────────────────────────────────────

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.selected,
    required this.onSelect,
  });

  final IaModelOption selected;
  final ValueChanged<IaModelOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: IaModelOption.values.asMap().entries.map((entry) {
        final isLast = entry.key == IaModelOption.values.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
          child: _ModelOption(
            model: entry.value,
            isSelected: selected == entry.value,
            onTap: () => onSelect(entry.value),
          ),
        );
      }).toList(),
    );
  }
}

class _ModelOption extends StatelessWidget {
  const _ModelOption({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final IaModelOption model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _C.accentSubtle : _C.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _C.accent.withValues(alpha: 0.55)
                : _C.adaptiveBorder(isDark),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Ícone — varia conforme o modelo, mas mantém estilo
            FaIcon(
              FontAwesomeIcons.microchip,
              size: 14,
              color: isSelected ? _C.accent : _C.mutedText(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.label,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _C.primaryText(isDark) : _C.mutedText(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _C.textMuted.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            // Radio visual à direita
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _C.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? _C.accent
                      : _C.textMuted.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate Button
// Heurística #1 (visibilidade): gradiente e ícone distinguem a ação primária.
// Heurística #5 (prevenção de erro): desabilitado sem tema preenchido.
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled && !loading ? onTap : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [_C.accent, _C.gradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : _C.disabledBg(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.wandMagicSparkles,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Gerar Questões',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
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