import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'cronometro_ancora.dart';
import 'geolocalizacao.dart';
import 'turno_poc_service.dart';

/// STORY-057 / ADR-017 — tela de PROVA DE CONCEITO do cronômetro bilateral + geofencing (CA-5).
/// NÃO é a UI final (essa vive em STORY-063/061): aqui só demonstramos o mecanismo em homolog,
/// nos dois navegadores (profissional e contratante) simultaneamente.
///
/// Cronômetro (decisão a): o servidor é a fonte de verdade (CA-4). A tela faz polling curto (~5s)
/// para sincronizar a [CronometroAncora] e tica LOCALMENTE a cada 1s — sem rede por tique. Os dois
/// lados, ancorados no mesmo `iniciado_em`, ficam sincronizados ≤ 2s por construção.
///
/// Geofencing (decisão b): o botão captura a posição do navegador e a envia ao backend, que calcula
/// a distância em metros via Haversine (reuso STORY-049) e devolve a flag (PDR-008).
class CronometroPocScreen extends StatefulWidget {
  const CronometroPocScreen({super.key, required this.turnoId});

  final String turnoId;

  @override
  State<CronometroPocScreen> createState() => _CronometroPocScreenState();
}

class _CronometroPocScreenState extends State<CronometroPocScreen> {
  final _service = TurnoPocService();

  CronometroAncora _ancora = CronometroAncora.vazio;
  String _estado = '—';
  bool _sincronizou = false;
  bool _souProfissional =
      false; // só o profissional captura o geofencing (PDR-008)

  Timer? _tick; // re-render a cada 1s
  Timer? _poll; // reconciliação a cada 5s

  GeoResultado? _geo;
  String? _geoRazaoCliente; // razão da falha de captura no navegador
  bool _capturando = false;
  bool _falhouEnvio = false; // POST não voltou 200 (rede/sessão)

  @override
  void initState() {
    super.initState();
    _sincronizar();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _sincronizar());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _sincronizar() async {
    final snap = await _service.cronometro(widget.turnoId);
    if (!mounted || snap == null) return;
    setState(() {
      _ancora = CronometroAncora.sincronizar(
        iniciadoEm: snap.iniciadoEm,
        encerradoEm: snap.encerradoEm,
        servidorAgora: snap.servidorAgora,
        agoraCliente: DateTime.now().toUtc(),
      );
      _estado = snap.estado;
      _souProfissional = snap.souProfissional;
      _sincronizou = true;
    });
  }

  Future<void> _capturarCheckin() async {
    setState(() {
      _capturando = true;
      _falhouEnvio = false;
    });
    final pos = await capturarPosicao();
    final res = await _service.checkinGeo(
      widget.turnoId,
      lat: pos.lat,
      lng: pos.lng,
      razao: pos.razao,
    );
    if (!mounted) return;
    setState(() {
      if (res != null) _geo = res;
      _geoRazaoCliente = pos.ok ? null : pos.razao;
      _falhouEnvio =
          res == null; // POST falhou (rede/sessão) — feedback explícito
      _capturando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decorrido = _ancora.decorrido(DateTime.now().toUtc());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Botão explícito de volta — no PWA instalado (standalone) não há barra de URL nem,
        // após `go()`, botão de voltar automático.
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Início',
          onPressed: () => context.go('/'),
        ),
        title: const Text('PoC — Cronômetro + Geofencing'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Estado do turno', style: theme.textTheme.labelMedium),
                Text(_estado, style: theme.textTheme.titleLarge),
                const SizedBox(height: 32),
                Text('Tempo decorrido', style: theme.textTheme.labelMedium),
                Text(
                  _sincronizou
                      ? CronometroAncora.formatar(decorrido)
                      : '--:--:--',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _ancora.rodando
                      ? 'rodando (servidor é a fonte de verdade)'
                      : 'parado',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Geofencing de check-in (PDR-008)',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                // O geofencing é a captura do PROFISSIONAL no check-in; o contratante valida o PIN.
                if (_souProfissional) ...[
                  FilledButton.icon(
                    onPressed: _capturando ? null : _capturarCheckin,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _capturando ? 'Capturando…' : 'Capturar localização',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _geoView(theme),
                ] else
                  Text(
                    'A captura de localização é feita pelo profissional no check-in. '
                    'Você (contratante) valida o PIN.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _geoView(ThemeData theme) {
    if (_falhouEnvio) {
      return Text(
        'Não foi possível enviar ao backend (rede/sessão). Tente de novo.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    final geo = _geo;
    if (geo == null) {
      return Text(
        'Toque para enviar sua posição ao backend.',
        style: theme.textTheme.bodySmall,
      );
    }
    if (geo.distanciaMetros == null) {
      return Text(
        'Sem coordenada (${_geoRazaoCliente ?? geo.razao ?? 'indisponível'}) — '
        'registrado como fora do raio (não bloqueia).',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    final metros = geo.distanciaMetros!.toStringAsFixed(1);
    return Text(
      geo.ok
          ? 'Dentro do raio: $metros m do estabelecimento.'
          : 'Fora do raio: $metros m (alerta ao contratante, não bloqueia).',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: geo.ok ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      textAlign: TextAlign.center,
    );
  }
}
