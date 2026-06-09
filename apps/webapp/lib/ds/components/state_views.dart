import 'package:flutter/material.dart';

import '../tokens.dart';

// STORY-079 — Estados vazio / erro / carregamento padronizados (pattern.empty,
// pattern.error e o placeholder de carregamento do DDR-001). Antes desta estória
// cada tela reimplementava o seu `_VazioView`/`_ErroView`/`_SkeletonCard`; aqui
// os três viram componentes do DS, consumidos por todas as listas do WebApp.
//
// Regras herdadas dos tokens (DDR-001): "estado vazio sempre instrui o próximo
// passo" e "erro nunca é só cor" — por isso todos carregam ícone + texto, e a
// cor é só reforço. AA por construção (texto forte/muted, alvos ≥48dp nos CTAs).
//
// Convenção de `key`: o componente NÃO fixa Key — a tela passa a sua
// (`feed-vazio`, `turnos-erro-banner`, …) via `super.key`, preservando os
// seletores de teste/E2E já existentes.

/// Estado **vazio** padronizado: ícone + título + mensagem (o próximo passo) +
/// CTA contextual opcional. Centralizado.
///
/// A `message` deve instruir o que fazer ou o que esperar — nunca só "vazio".
class TurniEmptyState extends StatelessWidget {
  const TurniEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconSize = 48,
  });

  /// Ícone ilustrativo (contornado, neutro). Reforça o texto, não o substitui.
  final IconData icon;

  /// Título curto do estado (ex.: "Você ainda não publicou vagas").
  final String title;

  /// O próximo passo / o que esperar. Sempre instrui.
  final String message;

  /// CTA contextual opcional (ex.: `FilledButton` "Publicar vaga"). A tela
  /// constrói o botão com a sua própria `Key` e acento de perfil.
  final Widget? action;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: textMuted),
            const SizedBox(height: TurniSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            const SizedBox(height: TurniSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: TurniSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de **erro recuperável** padronizado: ícone + título + mensagem +
/// "Tentar de novo", que re-dispara a ação de carga. Centralizado.
///
/// Para erro **não-recuperável** (sem retry, só saída para um destino do shell)
/// use [TurniEmptyState] com um ícone de bloqueio e um CTA de saída — é o mesmo
/// arranjo visual, mudando ícone, copy e a ação do botão.
class TurniRetryState extends StatelessWidget {
  const TurniRetryState({
    super.key,
    required this.title,
    required this.onRetry,
    this.message = 'Verifique sua conexão.',
    this.retryKey,
    this.accent,
  });

  /// Linha principal: "Não foi possível carregar …".
  final String title;

  /// Linha de apoio (default: orienta a checar a conexão).
  final String message;

  /// Re-dispara a carga. Mesmo callback do load inicial da tela.
  final VoidCallback onRetry;

  /// `Key` do botão de retry (preserva os seletores `*-retry-btn`).
  final Key? retryKey;

  /// Acento do CTA por perfil (mostarda do contratante / sage do profissional).
  /// Quando `null`, usa `colorScheme.primary` (perfil profissional / pré-login).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final cta = accent ?? Theme.of(context).colorScheme.primary;
    // on-accent segue o tema (tokens §6): acentos claros pareiam com branco;
    // acentos escuros (todos claros visualmente) pareiam com quase-preto. Antes
    // era `Colors.white` fixo — reprovava AA no escuro (branco/sage = 2.99:1).
    final onCta = isDark ? TurniColors.onAccentDark : TurniColors.onAccentLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: textMuted),
            const SizedBox(height: TurniSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            const SizedBox(height: TurniSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textMuted),
            ),
            const SizedBox(height: TurniSpacing.md),
            FilledButton(
              key: retryKey,
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: cta,
                foregroundColor: onCta,
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primitivo de **carregamento**: barra/círculo cinza neutro no lugar do
/// conteúdo que ainda vai chegar. Sem animação (placeholder estático, mesma
/// leitura nos dois temas). `ExcludeSemantics`: não anuncia ao leitor de tela.
class TurniSkeletonBox extends StatelessWidget {
  const TurniSkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.circle = false,
  });

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final side = circle ? (width ?? height) : height;

    return ExcludeSemantics(
      child: Container(
        width: width,
        height: side,
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// Skeleton de um **card** de lista (feed, vagas, turnos): contorno do card com
/// 3 linhas. Reusa o visual do card real (surface + borda) para a transição
/// não "saltar".
class TurniSkeletonCard extends StatelessWidget {
  const TurniSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.all(TurniRadius.md),
          border: Border.all(color: border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TurniSkeletonBox(width: 140),
            SizedBox(height: 10),
            TurniSkeletonBox(width: 200),
            SizedBox(height: 10),
            TurniSkeletonBox(width: double.infinity, height: 8),
          ],
        ),
      ),
    );
  }
}

/// Lista de skeletons: repete [itemBuilder] `count` vezes num `ListView` com o
/// espaçamento padrão. A tela passa a sua `Key` (`feed-skeleton`, …) e, quando
/// precisa de um formato diferente do card (ex.: linha com avatar das
/// notificações), passa o próprio [itemBuilder].
class TurniSkeletonList extends StatelessWidget {
  const TurniSkeletonList({
    super.key,
    this.count = 3,
    this.itemBuilder = _defaultItem,
  });

  final int count;
  final WidgetBuilder itemBuilder;

  static Widget _defaultItem(BuildContext context) => const TurniSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(TurniSpacing.md),
      children: List.generate(
        count,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: TurniSpacing.md),
          child: Builder(builder: itemBuilder),
        ),
        growable: false,
      ),
    );
  }
}
