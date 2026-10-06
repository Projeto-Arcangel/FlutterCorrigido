import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/auth_panel.dart';
import '../landing_section.dart';
import '../widgets/back_to_top_button.dart';
import '../widgets/landing_about.dart';
import '../widgets/landing_footer.dart';
import '../widgets/landing_header.dart';
import '../widgets/landing_hero.dart';
import '../widgets/landing_layout.dart';
import '../widgets/landing_nav_drawer.dart';
import '../widgets/landing_plans.dart';
import '../widgets/landing_section_container.dart';
import '../widgets/landing_support.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, this.initialAuthView});

  /// Vem de `/?auth=...`, para onde as rotas antigas (/login, /register,
  /// /forgot-password) redirecionam: abre o painel já na aba certa.
  final AuthPanelView? initialAuthView;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _pageTitle = 'Arcangel — Conhecimento também é uma aventura!';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _sectionKeys = {
    for (final section in LandingSection.values) section: GlobalKey(),
  };

  LandingSection? _activeSection;
  bool _headerElevated = false;
  bool _showBackToTop = false;
  bool _authPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _openAuthPanelFromUrl(widget.initialAuthView);
  }

  @override
  void didUpdateWidget(LandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAuthView != oldWidget.initialAuthView) {
      _openAuthPanelFromUrl(widget.initialAuthView);
    }
  }

  @override
  void dispose() {
    // O Title só atualiza a aba quando é construído: ao sair da landing,
    // devolve o título padrão do app.
    SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(label: 'Arcangel'),
    );
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Duration get _scrollDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 650);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;

    final elevated = position.pixels > 4;
    final showBackToTop = position.pixels > position.viewportDimension * 0.8;
    final active = _sectionInView(position);

    if (elevated != _headerElevated ||
        showBackToTop != _showBackToTop ||
        active != _activeSection) {
      setState(() {
        _headerElevated = elevated;
        _showBackToTop = showBackToTop;
        _activeSection = active;
      });
    }
  }

  /// Seção cujo topo já passou de ~35% da altura visível. No fim da página a
  /// última seção fica ativa mesmo que seja curta demais para chegar lá.
  LandingSection? _sectionInView(ScrollPosition position) {
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 2) {
      return LandingSection.values.last;
    }

    final probe = position.pixels + position.viewportDimension * 0.35;
    LandingSection? current;
    for (final section in LandingSection.values) {
      final top = _sectionScrollOffset(section);
      if (top != null && top <= probe) current = section;
    }
    return current;
  }

  double? _sectionScrollOffset(LandingSection section) {
    final renderObject =
        _sectionKeys[section]!.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    return viewport?.getOffsetToReveal(renderObject, 0).offset;
  }

  Future<void> _scrollToSection(LandingSection section) async {
    final sectionContext = _sectionKeys[section]!.currentContext;
    if (sectionContext == null) return;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: _scrollDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    final duration = _scrollDuration;
    if (duration == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: duration, curve: Curves.easeInOutCubic);
    }
  }

  void _openAuthPanelFromUrl(AuthPanelView? view) {
    if (view == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openAuthPanel(view, clearUrl: true),
    );
  }

  Future<void> _openAuthPanel(
    AuthPanelView view, {
    bool clearUrl = false,
  }) async {
    if (_authPanelOpen || !mounted) return;
    _authPanelOpen = true;
    await showAuthPanel(context, initialView: view);
    _authPanelOpen = false;
    // Tira o ?auth= da URL para um F5 não reabrir o painel. Substitui a
    // entrada do histórico (neglect) em vez de empilhar: senão o Voltar do
    // navegador volta para ?auth= e reabre o painel em loop.
    if (clearUrl && mounted) {
      Router.neglect(context, () => context.go(AppRoutes.landing));
    }
  }

  void _openLogin() => _openAuthPanel(AuthPanelView.login);

  void _openRegister() => _openAuthPanel(AuthPanelView.register);

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final isDesktop = LandingBreakpoints.isDesktop(context);

    // Título da aba (e o que o Google mostra na busca) na página inicial.
    return Title(
      title: _pageTitle,
      color: AppColors.primary,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: palette.background,
        appBar: LandingHeader(
          activeSection: _activeSection,
          elevated: _headerElevated,
          onSectionTap: _scrollToSection,
          onBrandTap: _scrollToTop,
          onLoginTap: _openLogin,
          onRegisterTap: _openRegister,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: isDesktop
            ? null
            : LandingNavDrawer(
                activeSection: _activeSection,
                onSectionTap: _scrollToSection,
                onLoginTap: _openLogin,
                onRegisterTap: _openRegister,
              ),
        floatingActionButton: BackToTopButton(
          visible: _showBackToTop,
          onPressed: _scrollToTop,
        ),
        body: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            children: [
              LandingHero(
                onRegisterTap: _openRegister,
                onLoginTap: _openLogin,
                onLearnMoreTap: () => _scrollToSection(LandingSection.about),
              ),
              LandingSectionContainer(
                key: _sectionKeys[LandingSection.about],
                alternate: true,
                title: 'Conheça o Arcangel',
                subtitle: 'Feito para o professor: crie atividades em minutos, '
                    'organize suas turmas e acompanhe cada aluno, enquanto a '
                    'turma aprende em formato de jogo.',
                child: LandingAbout(onRegisterTap: _openRegister),
              ),
              LandingSectionContainer(
                key: _sectionKeys[LandingSection.plans],
                title: 'Planos',
                subtitle: 'Comece grátis e mude de plano quando precisar de '
                    'mais questões e recursos.',
                child: LandingPlans(onStartFree: _openRegister),
              ),
              LandingSectionContainer(
                key: _sectionKeys[LandingSection.support],
                alternate: true,
                title: 'Suporte',
                subtitle: 'Tire suas dúvidas ou fale com a nossa equipe.',
                child: LandingSupport(
                  onForgotPasswordTap: () =>
                      _openAuthPanel(AuthPanelView.forgotPassword),
                ),
              ),
              LandingFooter(
                onSectionTap: _scrollToSection,
                onLoginTap: _openLogin,
                onRegisterTap: _openRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
