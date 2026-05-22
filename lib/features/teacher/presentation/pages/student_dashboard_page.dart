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
import '../../../classroom/domain/entities/classroom_result.dart';
import '../providers/student_dashboard_provider.dart';

// ─── Cores internas ──────────────────────────────────────────────────────────

abstract class _C {
  static const Color card        = Color(0xFF282932);
  static const Color cardBorder  = Color(0x14FFFFFF);
  static const Color textMuted   = Color(0xFF8FA3AE);
  static const Color good        = Color(0xFF72D082); // ≥ 70 %
  static const Color medium      = Color(0xFFEAD47F); // 50–69 %
  static const Color bad         = Color(0xFFE53935); // < 50 %
  static const Color accent      = AppColors.primary;
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

// ─── Situação do aluno ────────────────────────────────────────────────────────

enum _Situation { approved, recovery, failed }

_Situation _situationOf(double pct) {
  if (pct >= 0.70) return _Situation.approved;
  if (pct >= 0.50) return _Situation.recovery;
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
  String  _query     = '';
  _Filter _filter    = _Filter.all;
  bool    _sortByScore = false;
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

  // ── Filtro + busca ────────────────────────────────────────────────────────

  List<ClassroomResult> _applyFilters(List<ClassroomResult> raw) {
    var list = raw.where((r) {
      if (_query.isEmpty) return true;
      return r.studentName.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    if (_filter != _Filter.all) {
      list = list.where((r) {
        final s = _situationOf(r.percentage);
        return switch (_filter) {
          _Filter.approved => s == _Situation.approved,
          _Filter.recovery => s == _Situation.recovery,
          _Filter.failed   => s == _Situation.failed,
          _Filter.all      => true,
        };
      }).toList();
    }

    list.sort((a, b) => _sortByScore
        ? b.percentage.compareTo(a.percentage)
        : a.studentName.compareTo(b.studentName),);

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
    List<ClassroomResult> results,
  ) async {
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
          '',            // Prontuário — preenchido manualmente pelo professor
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

      final bytes = Uint8List.fromList(excel.encode()!);
      final filename =
          'notas_${classroom.name.replaceAll(' ', '_')}_${DateFormat('ddMMyyyy').format(DateTime.now())}.xlsx';

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final classroomsAsync = ref.watch(teacherAllClassroomsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF1F4F8),
      appBar: _buildAppBar(context, isDark, classroomsAsync),
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

          final resultsAsync = ref
              .watch(classroomStudentResultsProvider(classroom.id));

          return resultsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => _buildError(e),
            data: (results) =>
                _buildBody(context, isDark, classrooms, classroom, results),
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
  ) {
    final bgColor =
        isDark ? AppColors.backgroundDark : const Color(0xFFF1F4F8);

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
        // Ordenar
        Tooltip(
          message: _sortByScore ? 'Ordenar A–Z' : 'Ordenar por nota',
          child: IconButton(
            icon: FaIcon(
              _sortByScore
                  ? FontAwesomeIcons.arrowDownAZ
                  : FontAwesomeIcons.arrowDownWideShort,
              size: 16,
              color: _C.accent,
            ),
            onPressed: () => setState(() => _sortByScore = !_sortByScore),
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

                final resultsAsync = ref
                    .watch(classroomStudentResultsProvider(classroom.id));
                return resultsAsync.whenOrNull(
                  data: (results) => results.isEmpty
                      ? null
                      : Tooltip(
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
                                  onPressed: () =>
                                      _exportXlsx(classroom, results),
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
    List<ClassroomResult> results,
  ) {
    final filtered = _applyFilters(results);
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
              onChanged: (id) => setState(() => _classroomId = id),
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

        // ── Contagem ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              '${filtered.length} aluno${filtered.length != 1 ? 's' : ''} exibido${filtered.length != 1 ? 's' : ''}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: _C.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ── Lista de alunos ─────────────────────────────────────────────────
        filtered.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyResults())
            : SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StudentCard(result: filtered[i], rank: i + 1),
                ),
              ),

        // ── Alunos sem resultado ─────────────────────────────────────────────
        if (_filter == _Filter.all && _query.isEmpty)
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
                      fontSize: 13, color: _C.textMuted,),),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.userGroup,
                  size: 48, color: _C.textMuted.withValues(alpha: 0.6),),
              const SizedBox(height: 16),
              Text(
                'Nenhuma turma encontrada',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.textMuted,),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie uma turma em "Minhas Turmas".',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 13, color: _C.textMuted,),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmptyResults() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(FontAwesomeIcons.magnifyingGlass,
                  size: 36, color: _C.textMuted.withValues(alpha: 0.6),),
              const SizedBox(height: 16),
              Text(
                'Nenhum resultado encontrado',
                style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.textMuted,),
              ),
            ],
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.cardBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            dropdownColor: _C.card,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: _C.accent,),
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,),
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

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.totalStudents,
    required this.resultsCount,
    required this.avgPct,
    required this.participationRate,
    required this.topName,
  });

  final int    totalStudents;
  final int    resultsCount;
  final double avgPct;
  final double participationRate;
  final String? topName;

  @override
  Widget build(BuildContext context) {
    final avgColor = avgPct >= 0.70
        ? _C.good
        : avgPct >= 0.50
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.cardBorder),
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
                color: Colors.white,
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
                color: _C.textMuted,
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
                color: Colors.white,),
            decoration: InputDecoration(
              hintText: 'Buscar aluno pelo nome…',
              hintStyle: GoogleFonts.nunito(
                  fontSize: 14, color: _C.textMuted,),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: _C.textMuted, size: 20,),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: _C.textMuted, size: 18,),
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: _C.card,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _C.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
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
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : _C.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : _C.cardBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primary : _C.textMuted,
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

// ─── Card do aluno ────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.result, required this.rank});

  final ClassroomResult result;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final situation = _situationOf(result.percentage);
    final color     = _situationColor(situation);
    final fmt       = DateFormat("dd 'de' MMM 'de' yyyy", 'pt_BR');
    final initials  = _initials(result.studentName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder),
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
                        color: Colors.white,
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
                          '${result.totalQuestions} questões  ·  '
                          '${result.correctAnswers} corretas',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: _C.textMuted,
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
            backgroundColor: Colors.white12,
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
                color: _C.textMuted,
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
