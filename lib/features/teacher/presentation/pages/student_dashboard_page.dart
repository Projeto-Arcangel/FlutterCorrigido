import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_phase.dart';
import '../../../classroom/domain/entities/classroom_result.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../providers/student_dashboard_provider.dart';

// ─── Cores internas ──────────────────────────────────────────────────────────

abstract class _C {
  // Cores de situação — funcionam em ambos os temas pois são usadas
  // apenas como cor de destaque (badge, barra, ícone), nunca como fundo sólido.
  static const Color good   = Color(0xFF72D082); // ≥ 70 %
  static const Color medium = Color(0xFFEAD47F); // 50–69 %
  static const Color bad    = Color(0xFFE53935); // < 50 %
  static const Color accent = Color(0xFF72D082); // verde professor

  // ── Theme-aware ───────────────────────────────────────────────────────────
  static Color card(bool dark) =>
      dark ? AppColors.surfaceDark : Colors.white;

  static Color cardBorder(bool dark) =>
      dark ? const Color(0x14FFFFFF) : Colors.black12;

  // Texto primário dentro dos cards
  static Color primaryText(bool dark) =>
      dark ? Colors.white : AppColors.textPrimary;

  // Texto secundário / rótulos pequenos
  // No claro: cinza-ardósia mais escuro para contraste mínimo WCAG AA
  static Color textMuted(bool dark) =>
      dark ? const Color(0xFF8FA3AE) : const Color(0xFF5A6B78);

  // Fundo do dropdown e do campo de busca
  static Color inputFill(bool dark) =>
      dark ? AppColors.surfaceDark : AppColors.surface;

  // Cor do ícone de engrenagem / ação secundária
  static Color iconSecondary(bool dark) =>
      dark ? Colors.white54 : AppColors.textSecondary;
}

// ─── Filtro ──────────────────────────────────────────────────────────────────

enum _Filter { all, approved, recovery, failed }

extension _FilterLabel on _Filter {
  String get label => switch (this) {
        _Filter.all      => 'Todos',
        _Filter.approved => 'Aprovados',
        _Filter.recovery => 'Recuperação',
        _Filter.failed   => 'Reprovados',
      };
}

// ─── Ordenação ─────────────────────────────────────────────────────────────────

enum _Sort { nameAsc, nameDesc, gradeDesc, gradeAsc }

extension _SortLabel on _Sort {
  String get label => switch (this) {
        _Sort.nameAsc   => 'Nome (A–Z)',
        _Sort.nameDesc  => 'Nome (Z–A)',
        _Sort.gradeDesc => 'Maior nota',
        _Sort.gradeAsc  => 'Menor nota',
      };
}

// ─── Situação do aluno ────────────────────────────────────────────────────────

enum _Situation { approved, recovery, failed }

_Situation _situationOf(double pct, double approveT, double recoveryT) {
  if (pct >= approveT) return _Situation.approved;
  if (pct >= recoveryT) return _Situation.recovery;
  return _Situation.failed;
}

Color _situationColor(_Situation s) => switch (s) {
      _Situation.approved => _C.good,
      _Situation.recovery => _C.medium,
      _Situation.failed   => _C.bad,
    };

String _situationLabel(_Situation s) => switch (s) {
      _Situation.approved => 'Aprovado',
      _Situation.recovery => 'Recuperação',
      _Situation.failed   => 'Reprovado',
    };

// ─── Página ───────────────────────────────────────────────────────────────────

class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key, this.initialClassroomId});

  final String? initialClassroomId;

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  String? _classroomId;
  String? _phaseFilter; // null = "Trilha geral" (média ponderada); senão phaseId
  String  _query     = '';
  _Filter _filter    = _Filter.all;
  _Sort   _sort      = _Sort.nameAsc;
  bool    _exporting = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classroomId = widget.initialClassroomId;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Notas por escopo (fase específica ou trilha geral ponderada) ──────────

  /// Constrói a lista de resultados conforme [_phaseFilter]:
  /// - fase específica → as notas dos alunos naquela fase;
  /// - "trilha geral" (null) → média ponderada por aluno sobre TODAS as fases
  ///   com questões (fase não feita = 0), usando o peso de cada fase.
  List<ClassroomResult> _scoresFor(
    List<ClassroomPhase> phases,
    List<ClassroomResult> phaseRows,
  ) {
    if (_phaseFilter != null) {
      return phaseRows.where((r) => r.phaseId == _phaseFilter).toList();
    }

    final gradable = phases.where((p) => p.totalQuestions > 0).toList();
    final totalWeight = gradable.fold<double>(0, (s, p) => s + p.weight);
    if (gradable.isEmpty || totalWeight <= 0) return const [];

    final byStudent = <String, List<ClassroomResult>>{};
    for (final r in phaseRows) {
      byStudent.putIfAbsent(r.studentId, () => []).add(r);
    }

    final out = <ClassroomResult>[];
    byStudent.forEach((studentId, rows) {
      final pctByPhase = <String?, double>{};
      var sumTotal = 0;
      var sumCorrect = 0;
      DateTime? last;
      for (final r in rows) {
        pctByPhase[r.phaseId] = r.percentage;
        sumTotal += r.totalQuestions;
        sumCorrect += r.correctAnswers;
        if (last == null || r.completedAt.isAfter(last)) last = r.completedAt;
      }
      var weighted = 0.0;
      for (final p in gradable) {
        weighted += (pctByPhase[p.id] ?? 0.0) * p.weight; // ausente = 0
      }
      final first = rows.first;
      out.add(ClassroomResult(
        studentId: studentId,
        studentName: first.studentName,
        studentRegistration: first.studentRegistration,
        totalQuestions: sumTotal,
        correctAnswers: sumCorrect,
        completedAt: last ?? DateTime.now(),
        finalScore: weighted / totalWeight,
      ),);
    });
    return out;
  }

  /// Título da fase atualmente filtrada (ou `null` quando em "Trilha geral").
  String? _selectedPhaseTitle(List<ClassroomPhase> phases) {
    if (_phaseFilter == null) return null;
    for (final p in phases) {
      if (p.id == _phaseFilter) return p.title;
    }
    return null;
  }

  // ── Filtro + busca ────────────────────────────────────────────────────────

  List<ClassroomResult> _applyFilters(
    List<ClassroomResult> raw,
    double approveT,
    double recoveryT,
  ) {
    var list = raw.where((r) {
      if (_query.isEmpty) return true;
      return r.studentName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    if (_filter != _Filter.all) {
      list = list.where((r) {
        final s = _situationOf(r.percentage, approveT, recoveryT);
        return switch (_filter) {
          _Filter.approved => s == _Situation.approved,
          _Filter.recovery => s == _Situation.recovery,
          _Filter.failed   => s == _Situation.failed,
          _Filter.all      => true,
        };
      }).toList();
    }

    list.sort((a, b) {
      switch (_sort) {
        case _Sort.nameAsc:
          return a.studentName
              .toLowerCase()
              .compareTo(b.studentName.toLowerCase());
        case _Sort.nameDesc:
          return b.studentName
              .toLowerCase()
              .compareTo(a.studentName.toLowerCase());
        case _Sort.gradeDesc:
          return b.percentage.compareTo(a.percentage);
        case _Sort.gradeAsc:
          return a.percentage.compareTo(b.percentage);
      }
    });

    return list;
  }

  // ── KPIs ──────────────────────────────────────────────────────────────────

  double _average(List<ClassroomResult> r) => r.isEmpty
      ? 0
      : r.fold(0.0, (s, x) => s + x.percentage) / r.length;

  double _participationRate(Classroom? c, List<ClassroomResult> r) {
    final total = c?.studentIds.length ?? 0;
    if (total == 0) return 0;
    return r.length / total;
  }

  ClassroomResult? _topStudent(List<ClassroomResult> r) =>
      r.isEmpty ? null : (List<ClassroomResult>.from(r)
            ..sort((a, b) => b.percentage.compareTo(a.percentage)))
          .first;

  // ── Exportar XLSX ─────────────────────────────────────────────────────────

  Future<void> _exportXlsx(
    Classroom classroom,
    List<ClassroomResult> results, {
    String? phaseTitle,
  }) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final excel  = xl.Excel.createExcel();
      final sheet  = excel['Notas'];
      excel.delete('Sheet1');

      // Cabeçalhos: Prontuário | Nome do Aluno | Nota
      const headers = ['Prontuário', 'Nome do Aluno', 'Nota'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        );
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#1E1F28'),
          fontColorHex: xl.ExcelColor.white,
        );
      }

      // Dados
      final sorted = List<ClassroomResult>.from(results)
        ..sort((a, b) => a.studentName.compareTo(b.studentName));

      for (var i = 0; i < sorted.length; i++) {
        final r    = sorted[i];
        final nota = (r.percentage * 10).toStringAsFixed(1);

        final rowData = [
          r.studentRegistration, // Prontuário (profiles.student_id); vazio se o aluno não preencheu
          r.studentName,
          nota,
        ];

        for (var c = 0; c < rowData.length; c++) {
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1),
              )
              .value = xl.TextCellValue(rowData[c]);
        }
      }

      // Larguras
      const widths = [18.0, 36.0, 12.0];
      for (var c = 0; c < widths.length; c++) {
        sheet.setColumnWidth(c, widths[c]);
      }

      final scopeSlug = (phaseTitle == null || phaseTitle.trim().isEmpty)
          ? 'geral'
          : phaseTitle.trim().replaceAll(' ', '_');
      final bytes = Uint8List.fromList(excel.encode()!);
      final filename =
          'notas_${classroom.name.replaceAll(' ', '_')}_${scopeSlug}_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx';

      await downloadXlsx(bytes, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Arquivo "$filename" baixado com sucesso.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _C.good,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao exportar: ${e.toString()}',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Critérios de aprovação ──────────────────────────────────────────────────

  Future<void> _openCriteriaEditor(GradeCriteria current) async {
    final result = await showDialog<({int approve, int recovery})>(
      context: context,
      builder: (_) => _CriteriaDialog(
        initialApprove: (current.approve * 100).round(),
        initialRecovery: (current.recovery * 100).round(),
      ),
    );
    if (result == null || !mounted) return;

    try {
      await saveTeacherGradeCriteria(
        ref,
        approvePct: result.approve.toDouble(),
        recoveryPct: result.recovery.toDouble(),
      );
      if (!mounted) return;
      _snack('Critérios de aprovação atualizados.', color: _C.good);
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao salvar critérios: $e', color: AppColors.error);
    }
  }

  void _snack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final classroomsAsync = ref.watch(teacherAllClassroomsProvider);
    final criteria = ref.watch(teacherGradeCriteriaProvider).valueOrNull ??
        kDefaultGradeCriteria;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: _buildAppBar(context, isDark, classroomsAsync, criteria),
      body: classroomsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildError(e),
        data: (classrooms) {
          // Seleciona turma padrão na primeira carga
          if (_classroomId == null && classrooms.isNotEmpty) {
            _classroomId = classrooms.first.id;
          }

          final classroom = classrooms.cast<Classroom?>().firstWhere(
                (c) => c?.id == _classroomId,
                orElse: () => classrooms.isNotEmpty ? classrooms.first : null,
              );

          if (classroom == null) return _buildEmpty();

          final phasesAsync = ref.watch(classroomPhasesProvider(classroom.id));
          final phaseResultsAsync =
              ref.watch(classroomPhaseResultsProvider(classroom.id));

          if (phasesAsync.isLoading || phaseResultsAsync.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (phasesAsync.hasError) return _buildError(phasesAsync.error!);
          if (phaseResultsAsync.hasError) {
            return _buildError(phaseResultsAsync.error!);
          }

          final phases = phasesAsync.value ?? const <ClassroomPhase>[];
          final phaseRows =
              phaseResultsAsync.value ?? const <ClassroomResult>[];

          // Se o filtro aponta para uma fase que não existe mais, volta p/ geral.
          if (_phaseFilter != null &&
              !phases.any((p) => p.id == _phaseFilter)) {
            _phaseFilter = null;
          }

          final scoped = _scoresFor(phases, phaseRows);
          return _buildBody(
            context,
            isDark,
            classrooms,
            classroom,
            phases,
            scoped,
            criteria,
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(
    BuildContext context,
    bool isDark,
    AsyncValue<List<Classroom>> classroomsAsync,
    GradeCriteria criteria,
  ) {
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.background;

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : AppColors.textPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Voltar',
      ),
      title: Text(
        'Dashboard de Alunos',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      actions: [
        // Critérios de aprovação
        Tooltip(
          message: 'Critérios de aprovação',
          child: IconButton(
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
            onPressed: () => _openCriteriaEditor(criteria),
          ),
        ),
        // Exportar
        classroomsAsync.whenOrNull(
              data: (classrooms) {
                final classroom = classrooms.cast<Classroom?>().firstWhere(
                      (c) => c?.id == _classroomId,
                      orElse: () =>
                          classrooms.isNotEmpty ? classrooms.first : null,
                    );
                if (classroom == null) return null;

                final phases = ref
                        .watch(classroomPhasesProvider(classroom.id))
                        .value ??
                    const <ClassroomPhase>[];
                final phaseRows = ref
                        .watch(classroomPhaseResultsProvider(classroom.id))
                        .value ??
                    const <ClassroomResult>[];
                final scoped = _scoresFor(phases, phaseRows);
                if (scoped.isEmpty) return null;

                final phaseTitle = _selectedPhaseTitle(phases);
                return Tooltip(
                  message: 'Exportar notas (.xlsx)',
                  child: _exporting
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _C.accent,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.fileExcel,
                            size: 18,
                            color: _C.good,
                          ),
                          onPressed: () => _exportXlsx(
                            classroom,
                            scoped,
                            phaseTitle: phaseTitle,
                          ),
                        ),
                );
              },
            ) ??
            const SizedBox.shrink(),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    List<Classroom> classrooms,
    Classroom classroom,
    List<ClassroomPhase> phases,
    List<ClassroomResult> results,
    GradeCriteria criteria,
  ) {
    final filtered = _applyFilters(results, criteria.approve, criteria.recovery);
    final avg      = _average(results);
    final part     = _participationRate(classroom, results);
    final top      = _topStudent(results);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Seletor de turma ────────────────────────────────────────────────
        if (classrooms.length > 1)
          SliverToBoxAdapter(
            child: _ClassroomSelector(
              classrooms: classrooms,
              selectedId: _classroomId ?? classroom.id,
              onChanged: (id) => setState(() {
                _classroomId = id;
                _phaseFilter = null; // ao trocar de turma, volta p/ geral
              }),
            ),
          ),

        // ── Filtro de fase (Trilha geral / fase específica) ──────────────────
        SliverToBoxAdapter(
          child: _PhaseFilter(
            phases: phases,
            selectedPhaseId: _phaseFilter,
            onChanged: (id) => setState(() => _phaseFilter = id),
          ),
        ),

        // ── KPI cards ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _KpiRow(
            totalStudents: classroom.studentIds.length,
            resultsCount: results.length,
            avgPct: avg,
            participationRate: part,
            topName: top?.studentName,
            approveT: criteria.approve,
            recoveryT: criteria.recovery,
          ),
        ),

        // ── Barra de busca + filtro ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SearchAndFilter(
            controller: _searchCtrl,
            filter: _filter,
            onSearch: (v) => setState(() => _query = v),
            onFilter: (f) => setState(() => _filter = f),
          ),
        ),

        // ── Contagem + ordenação ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} aluno${filtered.length != 1 ? 's' : ''} exibido${filtered.length != 1 ? 's' : ''}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: _C.textMuted(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _SortControl(
                  sort: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                ),
              ],
            ),
          ),
        ),

        // ── Lista de alunos ─────────────────────────────────────────────────
        filtered.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyResults())
            : SliverList.separated(
                key: ValueKey(
                  'filter_${_filter.name}_${_sort.name}_${_phaseFilter ?? 'geral'}_$_query',
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StudentCard(
                    result: filtered[i],
                    rank: i + 1,
                    approveT: criteria.approve,
                    recoveryT: criteria.recovery,
                  ),
                ),
              ),

        // ── Alunos sem resultado (só na visão geral da trilha) ───────────────
        if (_phaseFilter == null && _filter == _Filter.all && _query.isEmpty)
          SliverToBoxAdapter(
            child: _NoResultsNote(
              withResults: results.length,
              total: classroom.studentIds.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ── Estados auxiliares ────────────────────────────────────────────────────

  Widget _buildError(Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.triangleExclamation,
                  color: AppColors.error, size: 40,),
              const SizedBox(height: 16),
              Text('Erro ao carregar dados',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,),),
              const SizedBox(height: 8),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: _C.textMuted(Theme.of(context).brightness == Brightness.dark),),),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.userGroup,
                      size: 48, color: _C.textMuted(isDark).withValues(alpha: 0.6),),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma turma encontrada',
                    style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.textMuted(isDark),),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie uma turma em "Minhas Turmas".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: _C.textMuted(isDark),),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildEmptyResults() => Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.magnifyingGlass,
                      size: 36, color: _C.textMuted(isDark).withValues(alpha: 0.6),),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum resultado encontrado',
                    style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.textMuted(isDark),),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

// ─── Seletor de turma ─────────────────────────────────────────────────────────

class _ClassroomSelector extends StatelessWidget {
  const _ClassroomSelector({
    required this.classrooms,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Classroom> classrooms;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: _C.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.cardBorder(isDark)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            dropdownColor: _C.card(isDark),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: _C.accent,),
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.primaryText(isDark),),
            items: classrooms
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

// ─── Filtro de fase ───────────────────────────────────────────────────────────

class _PhaseFilter extends StatelessWidget {
  const _PhaseFilter({
    required this.phases,
    required this.selectedPhaseId,
    required this.onChanged,
  });

  final List<ClassroomPhase> phases;
  final String? selectedPhaseId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _C.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.cardBorder(isDark)),
        ),
        child: Row(
          children: [
            const Icon(Icons.layers_rounded, size: 18, color: _C.accent),
            const SizedBox(width: 8),
            Text(
              'Fase:',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.textMuted(isDark),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedPhaseId,
                  isExpanded: true,
                  dropdownColor: _C.card(isDark),
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _C.accent,),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.primaryText(isDark),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Trilha geral (média ponderada)'),
                    ),
                    for (final p in phases)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          p.title.trim().isEmpty
                              ? 'Fase ${p.order}'
                              : p.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalStudents,
    required this.resultsCount,
    required this.avgPct,
    required this.participationRate,
    required this.topName,
    required this.approveT,
    required this.recoveryT,
  });

  final int    totalStudents;
  final int    resultsCount;
  final double avgPct;
  final double participationRate;
  final String? topName;
  final double approveT;
  final double recoveryT;

  @override
  Widget build(BuildContext context) {
    final avgColor = avgPct >= approveT
        ? _C.good
        : avgPct >= recoveryT
            ? _C.medium
            : _C.bad;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _KpiCard(
            icon: FontAwesomeIcons.userGroup,
            value: '$totalStudents',
            label: 'Total\nAlunos',
            color: _C.accent,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: FontAwesomeIcons.chartSimple,
            value: '${(avgPct * 100).round()}%',
            label: 'Média\nGeral',
            color: avgColor,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: FontAwesomeIcons.clipboardCheck,
            value: '${(participationRate * 100).round()}%',
            label: 'Taxa de\nParticip.',
            color: participationRate >= 0.7
                ? _C.good
                : participationRate >= 0.4
                    ? _C.medium
                    : _C.bad,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: FontAwesomeIcons.trophy,
            value: topName?.split(' ').first ?? '—',
            label: 'Melhor\nAluno',
            color: const Color(0xFFEAD47F),
            small: topName != null,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.small = false,
  });

  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;
  final bool     small;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _C.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.cardBorder(isDark)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 14, color: color.withValues(alpha: 0.75)),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: small ? 13 : 18,
                fontWeight: FontWeight.w900,
                color: _C.primaryText(isDark),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: _C.textMuted(isDark),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barra de busca + filtros ─────────────────────────────────────────────────

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController controller;
  final _Filter    filter;
  final ValueChanged<String>  onSearch;
  final ValueChanged<_Filter> onFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Campo de busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _C.primaryText(isDark),),
            decoration: InputDecoration(
              hintText: 'Buscar aluno pelo nome…',
              hintStyle: GoogleFonts.nunito(
                  fontSize: 14, color: _C.textMuted(isDark),),
              prefixIcon: Icon(Icons.search_rounded,
                  color: _C.textMuted(isDark), size: 20,),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: _C.textMuted(isDark), size: 18,),
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _C.inputFill(isDark),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _C.cardBorder(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: _C.accent, width: 1.5),
              ),
            ),
          ),
        ),

        // Chips de filtro
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _Filter.values.map((f) {
              final selected = f == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilter(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6,),
                    decoration: BoxDecoration(
                      color: selected
                          ? _C.accent.withValues(alpha: 0.15)
                          : _C.card(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? _C.accent.withValues(alpha: 0.6)
                            : _C.cardBorder(isDark),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? _C.accent : _C.textMuted(isDark),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Controle de ordenação ────────────────────────────────────────────────────

class _SortControl extends StatelessWidget {
  const _SortControl({required this.sort, required this.onChanged});

  final _Sort sort;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: _C.inputFill(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.cardBorder(isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_vert_rounded, size: 16, color: _C.accent),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<_Sort>(
              value: sort,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _C.textMuted(isDark),
              ),
              dropdownColor: _C.card(isDark),
              borderRadius: BorderRadius.circular(12),
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _C.primaryText(isDark),
              ),
              items: _Sort.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card do aluno ────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.result,
    required this.rank,
    required this.approveT,
    required this.recoveryT,
  });

  final ClassroomResult result;
  final int rank;
  final double approveT;
  final double recoveryT;

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final situation = _situationOf(result.percentage, approveT, recoveryT);
    final color     = _situationColor(situation);
    final fmt       = DateFormat("dd 'de' MMM 'de' yyyy", 'pt_BR');
    final initials  = _initials(result.studentName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(
                      color: color.withValues(alpha: 0.4), width: 1.5,),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nome + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.studentName,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.primaryText(isDark),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _Badge(
                          label: _situationLabel(situation),
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${result.totalQuestions} quest${result.totalQuestions == 1 ? 'ão' : 'ões'}  ·  '
                          '${result.correctAnswers} corretas',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: _C.textMuted(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Percentual
              Text(
                '${(result.percentage * 100).round()}%',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progresso
          LinearPercentIndicator(
            padding: EdgeInsets.zero,
            width: MediaQuery.of(context).size.width - 32 - 32 - 32,
            lineHeight: 6,
            percent: result.percentage.clamp(0.0, 1.0),
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            progressColor: color,
            barRadius: const Radius.circular(3),
          ),

          const SizedBox(height: 10),

          // Nota 0–10 + última atividade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetaChip(
                icon: FontAwesomeIcons.star,
                label:
                    'Nota: ${(result.percentage * 10).toStringAsFixed(1)}',
                color: color,
              ),
              _MetaChip(
                icon: FontAwesomeIcons.clockRotateLeft,
                label: fmt.format(result.completedAt),
                color: _C.textMuted(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FaIcon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Nota de alunos sem resultado ─────────────────────────────────────────────

class _NoResultsNote extends StatelessWidget {
  const _NoResultsNote({
    required this.withResults,
    required this.total,
  });
  final int withResults;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pending = total - withResults;
    if (pending <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _C.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleInfo,
                size: 14, color: _C.accent.withValues(alpha: 0.8),),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$pending aluno${pending > 1 ? 's' : ''} ainda '
                'não ${pending > 1 ? 'realizaram' : 'realizou'} '
                'nenhuma atividade nesta turma.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.accent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo: critérios de aprovação ──────────────────────────────────────────

class _CriteriaDialog extends StatefulWidget {
  const _CriteriaDialog({
    required this.initialApprove,
    required this.initialRecovery,
  });

  final int initialApprove;
  final int initialRecovery;

  @override
  State<_CriteriaDialog> createState() => _CriteriaDialogState();
}

class _CriteriaDialogState extends State<_CriteriaDialog> {
  late final TextEditingController _approveCtrl;
  late final TextEditingController _recoveryCtrl;

  @override
  void initState() {
    super.initState();
    _approveCtrl = TextEditingController(text: '${widget.initialApprove}');
    _recoveryCtrl = TextEditingController(text: '${widget.initialRecovery}');
  }

  @override
  void dispose() {
    _approveCtrl.dispose();
    _recoveryCtrl.dispose();
    super.dispose();
  }

  int? get _approve => int.tryParse(_approveCtrl.text.trim());
  int? get _recovery => int.tryParse(_recoveryCtrl.text.trim());

  String? get _error {
    final a = _approve;
    final r = _recovery;
    if (a == null || r == null) return 'Informe valores numéricos.';
    if (a < 0 || a > 100 || r < 0 || r > 100) {
      return 'Use porcentagens entre 0 e 100.';
    }
    if (a < r) return 'Aprovado deve ser maior ou igual à recuperação.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final err = _error;

    return AlertDialog(
      backgroundColor: _C.card(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Critérios de aprovação',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          color: _C.primaryText(isDark),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valem para todas as suas turmas. A nota do aluno (geral ou da '
            'fase) define a situação.',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _C.textMuted(isDark),
            ),
          ),
          const SizedBox(height: 16),
          _CriteriaField(
            controller: _approveCtrl,
            label: 'Aprovado a partir de',
            color: _C.good,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _CriteriaField(
            controller: _recoveryCtrl,
            label: 'Recuperação a partir de',
            color: _C.medium,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            'Abaixo da recuperação = reprovado.',
            style: GoogleFonts.nunito(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _C.textMuted(isDark),
            ),
          ),
          if (err != null) ...[
            const SizedBox(height: 10),
            Text(
              err,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: _C.textMuted(isDark),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _C.accent),
          onPressed: err != null
              ? null
              : () => Navigator.of(context).pop(
                    (approve: _approve!, recovery: _recovery!),
                  ),
          child: Text(
            'Salvar',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CriteriaField extends StatelessWidget {
  const _CriteriaField({
    required this.controller,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.primaryText(isDark),
            ),
          ),
        ),
        SizedBox(
          width: 78,
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _C.primaryText(isDark),
            ),
            decoration: InputDecoration(
              suffixText: '%',
              isDense: true,
              filled: true,
              fillColor: _C.inputFill(isDark),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _C.cardBorder(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _C.cardBorder(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _C.accent, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
