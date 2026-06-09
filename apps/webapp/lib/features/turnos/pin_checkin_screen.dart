import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ds/typography.dart';
import 'geofencing_copy.dart';
import 'pin_checkin_service.dart';
import 'turno_detalhe_service.dart' show GeofencingCheckin;

/// STORY-061 / SCREEN-061 §3.2/3.3 — tela do PIN de check-in.
///
/// View EFÊMERA (CA-4): empilhada via Navigator após a geração, sem rota própria —
/// refresh/deep-link caem no detalhe em `aguardando_checkin`, de onde o profissional
/// gera novo PIN. O PIN é o herói: JetBrains Mono 72pt (96 no desktop), contraste AAA
/// (`text.strong` sobre `surface.page` = 15.7:1), leitor de tela anuncia dígito a
/// dígito. A nota de geofencing é o registro honesto do que o contratante verá
/// (PDR-008 — alerta-e-registra).
class PinCheckinScreen extends StatefulWidget {
  const PinCheckinScreen({
    super.key,
    required this.turnoId,
    required this.pin,
    required this.geofencing,
    required this.funcao,
    required this.estabelecimento,
    PinCheckinService? pinService,
  }) : _pinService = pinService;

  final String turnoId;
  final String pin;
  final GeofencingCheckin geofencing;
  final String funcao;
  final String? estabelecimento;
  final PinCheckinService? _pinService;

  @override
  State<PinCheckinScreen> createState() => _PinCheckinScreenState();
}

class _PinCheckinScreenState extends State<PinCheckinScreen> {
  late final PinCheckinService _service =
      widget._pinService ?? PinCheckinService();

  bool _cancelando = false;
  bool _erroCancelar = false;

  Future<void> _cancelar() async {
    setState(() {
      _cancelando = true;
      _erroCancelar = false;
    });

    final result = await _service.cancelar(widget.turnoId);
    if (!mounted) return;

    switch (result) {
      // Estado inválido = o turno mudou por baixo (ex.: contratante validou) —
      // não há o que cancelar; volta ao detalhe, que recarrega a verdade.
      case PinCancelado() || PinCancelEstadoInvalido():
        Navigator.of(context).pop();
      case PinCancelErro():
        setState(() {
          _cancelando = false;
          _erroCancelar = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final textStrong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final textMuted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final accentInk = isDark ? TurniColors.accentDark : TurniColors.accentLight;

    final largura = MediaQuery.sizeOf(context).width;
    final desktop = largura >= 1024;

    final conteudo = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${widget.funcao}${(widget.estabelecimento ?? '').isNotEmpty ? ' · ${widget.estabelecimento}' : ''}',
          style: TextStyle(fontSize: 13, color: textMuted),
        ),
        const SizedBox(height: TurniSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Mostre este PIN ao contratante para validar a chegada',
            key: const Key('pin-checkin-instrucao'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: textStrong,
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.sm),
        // Dígito a dígito no leitor de tela ("4, 7, 0, 2"), nunca "quatro mil…".
        Semantics(
          label: 'PIN de check-in: ${widget.pin.split('').join(', ')}',
          excludeSemantics: true,
          child: Text(
            widget.pin,
            key: const Key('pin-checkin-codigo'),
            style: dsMono(
              fontSize: desktop ? 96 : 72,
              fontWeight: FontWeight.w600,
              letterSpacing: desktop ? 17 : 13, // ~0.18em
              height: 1,
              color: textStrong,
            ),
          ),
        ),
        const SizedBox(height: TurniSpacing.md),
        Semantics(
          liveRegion: true,
          child: _GeoNota(geofencing: widget.geofencing, isDark: isDark),
        ),
        const SizedBox(height: TurniSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Se sair desta tela, será preciso gerar um novo PIN.',
            key: const Key('pin-checkin-efemero-msg'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textMuted, height: 1.45),
          ),
        ),
        const SizedBox(height: TurniSpacing.sm),
        TextButton(
          key: const Key('pin-checkin-cancelar-btn'),
          onPressed: _cancelando ? null : _cancelar,
          style: TextButton.styleFrom(
            foregroundColor: accentInk,
            minimumSize: const Size(48, 48),
          ),
          child: _cancelando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text(
                  'Não chegou ainda? Cancelar PIN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );

    return Scaffold(
      key: const Key('pin-checkin-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('pin-checkin-voltar'),
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('PIN de check-in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: desktop ? 560 : double.infinity,
                minHeight: MediaQuery.sizeOf(context).height - 180,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_erroCancelar)
                    Container(
                      margin: const EdgeInsets.only(bottom: TurniSpacing.md),
                      padding: const EdgeInsets.all(TurniSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? TurniColors.errorSoftDark
                            : TurniColors.errorSoftLight,
                        borderRadius: const BorderRadius.all(TurniRadius.md),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Não foi possível cancelar o PIN.',
                              style: TextStyle(
                                color: isDark
                                    ? TurniColors.errorDark
                                    : TurniColors.errorLight,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _cancelar,
                            child: const Text('Tentar de novo'),
                          ),
                        ],
                      ),
                    ),
                  conteudo,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nota de geofencing (§4.5) — registro honesto do que foi capturado.
class _GeoNota extends StatelessWidget {
  const _GeoNota({required this.geofencing, required this.isDark});

  final GeofencingCheckin geofencing;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (geofencing.ok) {
      // Success escuro reusa o verde-sage claro do tema dark (mesma família AA).
      final cor = isDark ? TurniColors.accentDark : TurniColors.successLight;
      return Row(
        key: const Key('pin-checkin-geo-nota'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: cor),
          const SizedBox(width: TurniSpacing.sm),
          Flexible(
            child: Text(
              'Localização confirmada — você está no local.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cor,
              ),
            ),
          ),
        ],
      );
    }

    final texto = geofencing.distanciaMetros != null
        ? 'Você está a cerca de ${formatDistanciaMetros(geofencing.distanciaMetros!)} '
              'do estabelecimento. O contratante verá esse aviso ao validar.'
        : 'Sua localização não pôde ser confirmada (${razaoHumana(geofencing.razao)}). '
              'O contratante verá esse aviso ao validar.';

    return Container(
      key: const Key('pin-checkin-geo-nota'),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight,
        borderRadius: const BorderRadius.all(TurniRadius.md),
        border: Border.all(
          color: (isDark ? TurniColors.warnDark : TurniColors.warnLight)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            // Warn ink mostarda (#6E4E12, 7.6:1) — mesmo do badge `aguardando`.
            color: isDark
                ? TurniColors.warnDark
                : TurniColors.contratanteAccentInkLight,
          ),
          const SizedBox(width: TurniSpacing.sm),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark
                    ? TurniColors.textStrongDark
                    : TurniColors.contratanteAccentInkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
