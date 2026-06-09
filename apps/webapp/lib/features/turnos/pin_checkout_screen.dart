import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ds/typography.dart';
import 'pin_checkin_service.dart'
    show PinCancelEstadoInvalido, PinCancelErro, PinCancelado;
import 'pin_checkout_service.dart';

/// STORY-064 / SCREEN-064 §3.2/3.5 — tela do PIN de check-out.
///
/// Espelho da PinCheckinScreen (061) com duas diferenças intencionais: microcopy de
/// check-out e SEM nota de geofencing — a captura é silenciosa (CA-2; o registro vai
/// para a timeline, §4.12) e uma nota aqui criaria expectativa de simetria que não
/// existe. View EFÊMERA: empilhada via Navigator, sem rota própria — refresh cai no
/// detalhe em `aguardando_checkout`. Cancelar devolve a `ativo` (cronômetro retoma).
class PinCheckoutScreen extends StatefulWidget {
  const PinCheckoutScreen({
    super.key,
    required this.turnoId,
    required this.pin,
    required this.funcao,
    required this.estabelecimento,
    PinCheckoutService? pinService,
  }) : _pinService = pinService;

  final String turnoId;
  final String pin;
  final String funcao;
  final String? estabelecimento;
  final PinCheckoutService? _pinService;

  @override
  State<PinCheckoutScreen> createState() => _PinCheckoutScreenState();
}

class _PinCheckoutScreenState extends State<PinCheckoutScreen> {
  late final PinCheckoutService _service =
      widget._pinService ?? PinCheckoutService();

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
            'Mostre este PIN ao contratante para validar o fim do turno',
            key: const Key('pin-checkout-instrucao'),
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
        // Dígito a dígito no leitor de tela ("8, 3, 4, 1"), nunca "oito mil…".
        Semantics(
          label: 'PIN de check-out: ${widget.pin.split('').join(', ')}',
          excludeSemantics: true,
          child: Text(
            widget.pin,
            key: const Key('pin-checkout-codigo'),
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Se sair desta tela, será preciso gerar um novo PIN.',
            key: const Key('pin-checkout-efemero-msg'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textMuted, height: 1.45),
          ),
        ),
        const SizedBox(height: TurniSpacing.sm),
        TextButton(
          key: const Key('pin-checkout-cancelar-btn'),
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
                  'Ainda não terminou? Cancelar PIN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );

    return Scaffold(
      key: const Key('pin-checkout-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('pin-checkout-voltar'),
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('PIN de check-out'),
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
