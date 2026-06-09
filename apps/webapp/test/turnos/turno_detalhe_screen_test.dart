import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turni_webapp/ds/theme.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_screen.dart';
import 'package:turni_webapp/features/turnos/turno_detalhe_service.dart';
import 'package:turni_webapp/features/turnos/turnos_service.dart'
    show TurnoEstadoResumo;

// STORY-060 — widget tests da TurnoDetalheScreen (SCREEN-060).
// CA-2 (header + badge + card de valor com visibilidade por papel), CA-3 (timeline
// descendente com descrições por papel), CA-4 (área de ações placeholder; oculta em
// terminais), CA-5 (modal do aceite somente-leitura). Estados: loading/erro/não-encontrado/
// timeline degradada (§4.6).

class _FakeService extends TurnoDetalheService {
  _FakeService(this.result);

  TurnoDetalheResult Function() result;
  int calls = 0;

  @override
  Future<TurnoDetalheResult> fetch(String id) async {
    calls++;
    return result();
  }
}

TimelineEvento _evento(
  TimelineEventoTipo tipo, {
  String? id,
  double? valor,
  String? lado,
  DateTime? em,
}) => TimelineEvento(
  id: id ?? 'ev-${tipo.slug}',
  tipo: tipo,
  ocorridoEm: em ?? DateTime(2026, 6, 3, 15, 47),
  valor: valor,
  lado: lado,
);

TurnoDetalhe _turno({
  String estadoRaw = 'confirmado',
  TurnoEstadoResumo estado = TurnoEstadoResumo.confirmado,
  double? taxaTurni,
  double? totalContratante,
  String? profissional,
  AceiteDoTurno? aceite = const AceiteDoTurno(
    emitidoEm: null,
    conteudoRenderizado: 'Contrato eventual de turno. Garçom — R\$ 200,00.',
  ),
  List<TimelineEvento>? timeline,
  AvaliacaoPendencia? avaliacao,
}) => TurnoDetalhe(
  id: 'u1',
  funcao: 'Garçom',
  dataInicio: DateTime(2026, 6, 12, 18),
  dataFim: DateTime(2026, 6, 12, 23),
  estado: estado,
  estadoRaw: estadoRaw,
  valor: 200.0,
  estabelecimento: 'Bar do Zé',
  taxaTurni: taxaTurni,
  totalContratante: totalContratante,
  profissional: profissional,
  aceite: aceite,
  avaliacao: avaliacao,
  timeline:
      timeline ??
      [
        _evento(TimelineEventoTipo.pagamentoPreAutorizado, valor: null),
        _evento(TimelineEventoTipo.aceiteEmitido),
        _evento(TimelineEventoTipo.turnoCriado),
      ],
);

/// Espelho do contratante: payload carrega taxa/total/profissional (souContratante).
TurnoDetalhe _turnoContratante({List<TimelineEvento>? timeline}) => _turno(
  taxaTurni: 30.0,
  totalContratante: 230.0,
  profissional: 'Júlia Santos',
  timeline: timeline,
);

Widget _comRouter(_FakeService svc) {
  final router = GoRouter(
    initialLocation: '/turnos/u1',
    routes: [
      GoRoute(
        path: '/turnos/:id',
        builder: (_, _) => TurnoDetalheScreen(turnoId: 'u1', service: svc),
      ),
      GoRoute(
        path: '/profissional/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA PRO')),
      ),
      GoRoute(
        path: '/contratante/turnos',
        builder: (_, _) => const Scaffold(body: Text('LISTA CONTR')),
      ),
    ],
  );
  return MaterialApp.router(theme: buildLightTheme(), routerConfig: router);
}

void main() {
  // ───────────────── CA-2 — header + valor por papel ─────────────────

  testWidgets('profissional: header, badge, valor em destaque sem taxa/total', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-screen')), findsOneWidget);
    expect(find.text('Detalhe do turno'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-estado')), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('Garçom'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-onde')), findsOneWidget);
    expect(find.text('Bar do Zé'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-quando')), findsOneWidget);
    expect(find.textContaining('18:00'), findsWidgets);

    // Card de valor do profissional (domain/pagamento.md): destaque + nota; sem total.
    expect(find.text('VOCÊ RECEBE'), findsOneWidget);
    expect(find.text('R\$ 200,00'), findsOneWidget);
    expect(
      find.text('valor integral · taxa Turni cobrada do contratante'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('turno-detalhe-valor-total')), findsNothing);
    expect(find.text('Taxa Turni'), findsNothing);
  });

  testWidgets('contratante: valor + taxa + total separados e quem vem (CA-2)', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turnoContratante()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.text('PAGAMENTO DESTE TURNO'), findsOneWidget);
    expect(find.text('Valor do profissional'), findsOneWidget);
    expect(find.text('R\$ 200,00'), findsOneWidget);
    expect(find.text('Taxa Turni'), findsOneWidget);
    expect(find.text('R\$ 30,00'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    final total = tester.widget<Text>(
      find.byKey(const Key('turno-detalhe-valor-total')),
    );
    expect(total.data, 'R\$ 230,00');

    // Header do contratante: quem vem (profissional) + estabelecimento.
    expect(find.text('Júlia Santos'), findsOneWidget);
    expect(find.text('Bar do Zé'), findsOneWidget);
  });

  // ───────────────── CA-3 — timeline ─────────────────

  testWidgets('timeline renderiza títulos e descrições do papel profissional', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('turno-detalhe-historico-header')),
      findsOneWidget,
    );
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.byKey(const Key('turno-detalhe-timeline')), findsOneWidget);
    expect(find.text('Pagamento reservado'), findsOneWidget);
    expect(
      find.text('O contratante garantiu o pagamento deste turno.'),
      findsOneWidget,
    );
    expect(find.text('Aceite eletrônico emitido'), findsOneWidget);
    expect(find.text('Turno confirmado'), findsOneWidget);
    expect(find.text('Candidatura aprovada.'), findsOneWidget);
    expect(find.textContaining('Qua, 03/06 · 15:47'), findsWidgets);
  });

  testWidgets(
    'STORY-062: timeline renderiza checkin_recusado e checkin_pin_expirado (§4.11)',
    (tester) async {
      final svc = _FakeService(
        () => TurnoDetalheSuccess(
          _turno(
            timeline: [
              _evento(TimelineEventoTipo.checkinPinExpirado),
              _evento(TimelineEventoTipo.checkinRecusado),
            ],
          ),
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.text('Check-in recusado'), findsOneWidget);
      expect(find.text('Recusado pelo contratante.'), findsOneWidget);
      expect(find.text('PIN de check-in expirado'), findsOneWidget);
      expect(
        find.text('Expirado por excesso de tentativas de validação.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('timeline do contratante mostra o total; pix sem valor', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turnoContratante(
          timeline: [
            _evento(TimelineEventoTipo.pixEnviado),
            _evento(TimelineEventoTipo.pagamentoPreAutorizado, valor: 230.0),
          ],
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(
      find.text('R\$ 230,00 reservados no seu meio de pagamento.'),
      findsOneWidget,
    );
    expect(find.text('Pix enviado ao profissional.'), findsOneWidget);
  });

  testWidgets('pix_enviado do profissional mostra o valor que é dele', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(
          estadoRaw: 'finalizado',
          estado: TurnoEstadoResumo.finalizado,
          timeline: [_evento(TimelineEventoTipo.pixEnviado, valor: 200.0)],
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.text('R\$ 200,00 enviados para você.'), findsOneWidget);
  });

  testWidgets(
    'cancelado nomeia o lado; evento desconhecido não quebra (§4.1/§4.6)',
    (tester) async {
      final svc = _FakeService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: 'cancelado_emp',
            estado: TurnoEstadoResumo.cancelado,
            timeline: [
              _evento(TimelineEventoTipo.cancelado, lado: 'emp'),
              _evento(TimelineEventoTipo.desconhecido, id: 'ev-x'),
            ],
          ),
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.text('Turno cancelado'), findsOneWidget);
      expect(find.text('Cancelado pelo contratante.'), findsOneWidget);
      expect(find.text('Atualização do turno'), findsOneWidget);
    },
  );

  testWidgets('timeline vazia: degrada para "Histórico indisponível" (§4.6)', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(_turno(timeline: const [])),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.text('Histórico indisponível no momento.'), findsOneWidget);
    // O resto da tela continua de pé.
    expect(find.text('Garçom'), findsOneWidget);
  });

  // ───────────────── CA-4 — área de ações ─────────────────

  testWidgets('área de ações placeholder visível em estado não-terminal', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-acoes')), findsOneWidget);
    expect(find.text('Nenhuma ação disponível no momento'), findsOneWidget);
    expect(
      find.text('As ações deste turno aparecem aqui conforme ele avança.'),
      findsOneWidget,
    );
  });

  testWidgets('área de ações OCULTA em estado terminal (finalizado)', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(estadoRaw: 'finalizado', estado: TurnoEstadoResumo.finalizado),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-acoes')), findsNothing);
  });

  // ───────────────── CA-5 — modal do aceite ─────────────────

  testWidgets('link abre modal do aceite somente-leitura; fechar volta', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(
          aceite: AceiteDoTurno(
            emitidoEm: DateTime(2026, 6, 3, 15, 47),
            conteudoRenderizado:
                'Contrato eventual de turno. Garçom — R\$ 200,00.',
          ),
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-aceite-btn')), findsOneWidget);
    await tester.tap(find.byKey(const Key('turno-detalhe-aceite-btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aceite-modal')), findsOneWidget);
    expect(find.text('Aceite eletrônico'), findsOneWidget);
    expect(
      find.textContaining('Emitido em Qua, 03/06 · 15:47'),
      findsOneWidget,
    );
    expect(
      find.text('Contrato eventual de turno. Garçom — R\$ 200,00.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aceite-modal-fechar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aceite-modal')), findsNothing);
  });

  testWidgets('turno sem aceite (degradado): link não aparece', (tester) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno(aceite: null)));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-aceite-btn')), findsNothing);
  });

  // ───────────────── Estados: loading / erro / não encontrado ─────────────────

  testWidgets('loading mostra skeleton antes do payload', (tester) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(_comRouter(svc));
    // Sem settle: ainda no primeiro frame async.
    expect(find.byKey(const Key('turno-detalhe-skeleton')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('turno-detalhe-skeleton')), findsNothing);
  });

  testWidgets('erro de rede: banner com retry refaz o fetch', (tester) async {
    var falha = true;
    final svc = _FakeService(
      () => falha ? TurnoDetalheError() : TurnoDetalheSuccess(_turno()),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-erro-banner')), findsOneWidget);
    expect(
      find.text('Não foi possível carregar o turno. Verifique sua conexão.'),
      findsOneWidget,
    );

    falha = false;
    await tester.tap(find.byKey(const Key('turno-detalhe-retry-btn')));
    await tester.pumpAndSettle();

    expect(svc.calls, 2);
    expect(find.text('Garçom'), findsOneWidget);
  });

  testWidgets('403/404 caem no "não encontrado" fail-secure; CTA leva à lista', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheNaoEncontrado());
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-nao-encontrado')), findsOneWidget);
    expect(find.text('Turno não encontrado'), findsOneWidget);
    expect(
      find.text('O link pode estar errado ou o turno não existe mais.'),
      findsOneWidget,
    );

    // Sem sessão no teste → papel default profissional ("Ir para meus turnos").
    await tester.tap(find.byKey(const Key('turno-nao-encontrado-cta')));
    await tester.pumpAndSettle();
    expect(find.text('LISTA PRO'), findsOneWidget);
  });

  // ───────────────── STORY-087 — CTA de avaliação ─────────────────

  testWidgets('turno finalizado PENDENTE mostra o CTA "Avaliar turno"', (
    tester,
  ) async {
    final svc = _FakeService(
      () => TurnoDetalheSuccess(
        _turno(
          estadoRaw: 'finalizado',
          estado: TurnoEstadoResumo.finalizado,
          avaliacao: const AvaliacaoPendencia(
            pendente: true,
            direcao: 'profissional_para_contratante',
          ),
        ),
      ),
    );
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-avaliar')), findsOneWidget);
    expect(find.text('Avaliar turno'), findsOneWidget);
  });

  testWidgets(
    'turno finalizado JÁ avaliado (pendente:false) NÃO mostra o CTA',
    (tester) async {
      final svc = _FakeService(
        () => TurnoDetalheSuccess(
          _turno(
            estadoRaw: 'finalizado',
            estado: TurnoEstadoResumo.finalizado,
            avaliacao: const AvaliacaoPendencia(
              pendente: false,
              direcao: 'profissional_para_contratante',
            ),
          ),
        ),
      );
      await tester.pumpWidget(_comRouter(svc));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('turno-detalhe-avaliar')), findsNothing);
    },
  );

  testWidgets('turno não-avaliável (sem bloco avaliacao) NÃO mostra o CTA', (
    tester,
  ) async {
    final svc = _FakeService(() => TurnoDetalheSuccess(_turno()));
    await tester.pumpWidget(_comRouter(svc));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('turno-detalhe-avaliar')), findsNothing);
  });
}
