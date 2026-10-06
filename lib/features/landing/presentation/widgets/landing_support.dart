import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../landing_contact.dart';
import 'landing_layout.dart';
import 'landing_reveal.dart';

/// Conteúdo da seção "Suporte": perguntas frequentes e contato por e-mail.
class LandingSupport extends StatelessWidget {
  const LandingSupport({super.key, required this.onForgotPasswordTap});

  final VoidCallback onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = LandingBreakpoints.isDesktop(context);
    final faq = LandingReveal(
      child: _Faq(onForgotPasswordTap: onForgotPasswordTap),
    );
    const contact = LandingReveal(
      delay: Duration(milliseconds: 150),
      child: _ContactCard(),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: faq),
          const SizedBox(width: 32),
          const Expanded(flex: 2, child: contact),
        ],
      );
    }
    return Column(children: [faq, const SizedBox(height: 32), contact]);
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.onForgotPasswordTap});

  final VoidCallback onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      const _FaqItem(
        question: 'O Arcangel é gratuito?',
        answer: 'Sim. O plano Free não tem custo e não pede cartão. Os '
            'planos Pro e Premium aumentam os limites mensais e liberam '
            'recursos extras, como exportar atividades em PDF.',
      ),
      const _FaqItem(
        question: 'O que são questões com IA a partir dos seus materiais?',
        answer: 'Você anexa o material da aula (PDFs, links de vídeos, '
            'artigos etc.) e a IA cria questões com base nesse conteúdo. '
            'Cada plano tem uma quantidade mensal desse tipo de questão.',
      ),
      const _FaqItem(
        question: 'Como meus alunos entram na turma?',
        answer: 'Depois de criar a turma, copie o código dela na tela de '
            'detalhes e envie aos alunos. Eles criam a conta como aluno e '
            'entram na turma usando esse código.',
      ),
      const _FaqItem(
        question: 'Posso editar as questões geradas pela IA?',
        answer: 'Pode. Antes de salvar, você revisa cada questão sugerida: '
            'ajusta o enunciado e as alternativas, marca a correta, descarta '
            'o que não quiser e salva só as aprovadas.',
      ),
      const _FaqItem(
        question: 'Existe limite de uso da IA?',
        answer: 'Sim. Cada plano tem uma quantidade de questões por mês (veja '
            'a seção Planos), e a tela de geração mostra quanto você já usou.',
      ),
      const _FaqItem(
        question: 'Não recebi o e-mail de confirmação. E agora?',
        answer: 'Confira as pastas de spam e lixo eletrônico. Abra o link no '
            'mesmo navegador em que você criou a conta. Se ainda assim não '
            'chegar em alguns minutos, fale com a gente.',
      ),
      _FaqItem(
        question: 'Esqueci minha senha. Como recupero?',
        answer: 'Em "Entrar", use "Esqueci minha senha" e informe o e-mail da '
            'conta. Enviaremos um link para você criar uma nova senha.',
        actionLabel: 'Recuperar senha',
        onAction: onForgotPasswordTap,
      ),
      const _FaqItem(
        question: 'Como troco de plano?',
        answer: 'Por enquanto, a troca é feita pelo nosso e-mail de suporte. '
            'Envie uma mensagem com o plano desejado e o e-mail da sua conta.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          items[i],
        ],
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
    this.actionLabel,
    this.onAction,
  });

  final String question;
  final String answer;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final actionLabel = this.actionLabel;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return Material(
      color: palette.card,
      shape: shape.copyWith(side: BorderSide(color: palette.border)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: shape,
        collapsedShape: shape,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: palette.accentText,
        collapsedIconColor: palette.textMuted,
        title: Text(
          question,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.55,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: palette.accentText,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 18);
    const buttonLabelStyle =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    return LandingCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LandingIconBadge(icon: Icons.mail_outline_rounded),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'Ainda precisa de ajuda?',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envie um e-mail para a nossa equipe. Respondemos o mais rápido '
            'possível. Assinantes Premium têm atendimento prioritário.',
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            LandingContact.supportEmail,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.accentText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => LandingContact.sendEmail(
                context,
                subject: 'Suporte Arcangel',
              ),
              style: FilledButton.styleFrom(
                padding: buttonPadding,
                shape: buttonShape,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Enviar e-mail', style: buttonLabelStyle),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => LandingContact.copyEmail(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: buttonPadding,
                shape: buttonShape,
              ),
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copiar endereço', style: buttonLabelStyle),
            ),
          ),
        ],
      ),
    );
  }
}
