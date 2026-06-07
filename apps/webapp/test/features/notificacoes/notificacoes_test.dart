import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:turni_webapp/features/notificacoes/notificacao.dart';
import 'package:turni_webapp/features/notificacoes/notificacoes_controller.dart';
import 'package:turni_webapp/features/notificacoes/notificacoes_painel.dart';
import 'package:turni_webapp/features/notificacoes/notificacoes_service.dart';
import 'package:turni_webapp/features/notificacoes/notificacoes_sino.dart';

Notificacao notif({
  String id = '1',
  String tipo = 'candidatura_recebida',
  String? vagaId = '10',
  Map<String, dynamic>? payload,
  String? lidaEm,
  String? criadaEm,
}) => Notificacao.fromJson({
  'id': id,
  'tipo': tipo,
  'vaga_id': vagaId,
  'candidatura_id': null,
  'payload':
      payload ?? {'profissional_nome': 'Júlia Santos', 'vaga_funcao': 'Garçom'},
  'lida_em': lidaEm,
  'criada_em': criadaEm ?? DateTime.now().toIso8601String(),
});

NotificacoesController controllerComResposta({
  required int naoLidas,
  required List<Map<String, dynamic>> lista,
  bool falharMarcarTodas = false,
}) {
  final client = MockClient((req) async {
    if (req.url.path.endsWith('/notificacoes')) {
      final somenteNaoLidas = req.url.queryParameters['lidas'] == 'false';
      final itens = somenteNaoLidas
          ? lista.where((n) => n['lida_em'] == null).toList()
          : lista;
      return http.Response(
        jsonEncode({'notificacoes': itens, 'nao_lidas': naoLidas}),
        200,
      );
    }
    if (req.url.path.endsWith('/marcar-todas-lidas')) {
      return http.Response('{}', falharMarcarTodas ? 500 : 200);
    }
    return http.Response('{"ok":true}', 200);
  });
  return NotificacoesController(service: NotificacoesService(client: client));
}

void main() {
  group('Notificacao (model)', () {
    test('título e resumo por tipo interpolam o payload', () {
      expect(notif().titulo, 'Nova candidatura recebida');
      expect(
        notif().resumo,
        'Júlia Santos se candidatou à sua vaga de Garçom.',
      );

      final cancelada = notif(
        tipo: 'vaga_cancelada',
        payload: {
          'vaga_funcao': 'Cozinheiro',
          'vaga_data_inicio': '12/06 · 18:00',
        },
      );
      expect(cancelada.titulo, 'Vaga cancelada pelo contratante');
      expect(cancelada.resumo, contains('Cozinheiro'));
    });

    test('rota de destino por tipo', () {
      expect(
        notif(tipo: 'candidatura_recebida', vagaId: '7').rotaDestino,
        '/contratante/vagas/7/candidatos',
      );
      expect(
        notif(tipo: 'vaga_editada_material', vagaId: '7').rotaDestino,
        '/vaga/7',
      );
      expect(notif(tipo: 'vaga_cancelada', vagaId: '7').rotaDestino, '/feed');
    });

    // STORY-067 (SCREEN-067 §2) — os 8 tipos do turno.
    test('título e resumo dos 8 tipos do turno interpolam o payload', () {
      final payloadTurno = {
        'turno_id': 't-1',
        'vaga_funcao': 'Garçom',
        'estabelecimento_nome': 'Vela Bar',
        'turno_data_inicio': '01/07/2026 18:00',
        'valor': '200,00',
        'profissional_nome': 'Júlia Santos',
        'cancelado_por': 'pelo contratante',
      };
      Notificacao deTurno(String tipo) =>
          notif(tipo: tipo, vagaId: null, payload: payloadTurno);

      expect(deTurno('turno_confirmado').titulo, 'Turno confirmado');
      expect(
        deTurno('turno_confirmado').resumo,
        'Seu turno de Garçom no Vela Bar em 01/07/2026 18:00 está confirmado.',
      );
      expect(
        deTurno('checkin_solicitado').titulo,
        'Check-in aguardando validação',
      );
      expect(
        deTurno('checkin_solicitado').resumo,
        'Júlia Santos gerou o PIN de check-in do turno de Garçom. '
        'Valide para iniciar.',
      );
      expect(deTurno('turno_ativo').titulo, 'Turno em andamento');
      expect(
        deTurno('checkout_solicitado').resumo,
        contains('Valide para encerrar.'),
      );
      expect(
        deTurno('turno_finalizado').resumo,
        contains(r'R$ 200,00 está em processamento'),
      );
      expect(
        deTurno('pix_enviado').resumo,
        r'O Pix de R$ 200,00 do turno de Garçom foi enviado.',
      );
      expect(
        deTurno('turno_cancelado').resumo,
        contains('cancelado pelo contratante'),
      );
      expect(
        deTurno('no_show_pro').titulo,
        'Turno encerrado — check-in não realizado',
      );
      expect(
        deTurno('no_show_pro').resumo,
        contains('o check-in não aconteceu no prazo'),
      );
    });

    test('destino dos 8 tipos do turno é /turnos/{id} do payload', () {
      for (final tipo in [
        'turno_confirmado',
        'checkin_solicitado',
        'turno_ativo',
        'checkout_solicitado',
        'turno_finalizado',
        'pix_enviado',
        'turno_cancelado',
        'no_show_pro',
      ]) {
        expect(
          notif(
            tipo: tipo,
            vagaId: null,
            payload: {'turno_id': 't-9'},
          ).rotaDestino,
          '/turnos/t-9',
          reason: tipo,
        );
      }
      // Sem turno_id no payload → sem destino (não navega para lugar errado).
      expect(
        notif(tipo: 'pix_enviado', vagaId: '7', payload: {}).rotaDestino,
        isNull,
      );
    });

    test('tempo relativo pt-BR (sem AM/PM)', () {
      final agora = DateTime(2026, 6, 3, 12, 0);
      expect(
        notif(
          criadaEm: agora
              .subtract(const Duration(seconds: 20))
              .toIso8601String(),
        ).tempoRelativo(agora),
        'agora',
      );
      expect(
        notif(
          criadaEm: agora
              .subtract(const Duration(minutes: 8))
              .toIso8601String(),
        ).tempoRelativo(agora),
        'há 8 min',
      );
      expect(
        notif(
          criadaEm: agora.subtract(const Duration(hours: 2)).toIso8601String(),
        ).tempoRelativo(agora),
        'há 2 h',
      );
      final velha = notif(
        criadaEm: agora.subtract(const Duration(days: 3)).toIso8601String(),
      ).tempoRelativo(agora);
      expect(velha, isNot(contains('AM')));
      expect(velha, matches(RegExp(r'\d{2}/\d{2} · \d{2}:\d{2}')));
    });
  });

  group('NotificacoesController (otimista)', () {
    test('carregarContagem alimenta o badge', () async {
      final c = controllerComResposta(naoLidas: 3, lista: const []);
      await c.carregarContagem();
      expect(c.naoLidas, 3);
    });

    test('abrirPainel carrega a lista (pronto)', () async {
      final c = controllerComResposta(
        naoLidas: 1,
        lista: [
          {
            'id': '1',
            'tipo': 'candidatura_recebida',
            'vaga_id': '10',
            'payload': {},
            'lida_em': null,
            'criada_em': DateTime.now().toIso8601String(),
          },
        ],
      );
      await c.abrirPainel();
      expect(c.fase, NotificacoesFase.pronto);
      expect(c.itens, hasLength(1));
    });

    test('abrirPainel em erro de rede vira fase erro', () async {
      final client = MockClient((_) async => http.Response('boom', 500));
      final c = NotificacoesController(
        service: NotificacoesService(client: client),
      );
      await c.abrirPainel();
      expect(c.fase, NotificacoesFase.erro);
    });

    test('marcarLida é otimista (decrementa e marca)', () async {
      final c = controllerComResposta(naoLidas: 2, lista: const []);
      c.naoLidas = 2;
      final n = notif();
      await c.marcarLida(n);
      expect(n.lida, isTrue);
      expect(c.naoLidas, 1);
    });

    test('marcarTodasLidas reverte o otimismo se o servidor falha', () async {
      final c = controllerComResposta(
        naoLidas: 2,
        lista: const [],
        falharMarcarTodas: true,
      );
      c.naoLidas = 2;
      c.itens = [notif(id: '1'), notif(id: '2')];
      final ok = await c.marcarTodasLidas();
      expect(ok, isFalse);
      expect(c.naoLidas, 2); // revertido
      expect(c.itens.every((n) => !n.lida), isTrue);
    });
  });

  group('NotificacoesSino (badge)', () {
    testWidgets('mostra a contagem quando há não-lidas', (tester) async {
      final c = controllerComResposta(naoLidas: 5, lista: const []);
      c.naoLidas = 5;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [NotificacoesSino(controller: c)]),
          ),
        ),
      );
      expect(find.byKey(const Key('notificacoes-badge')), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('mostra "9+" acima de 9 e some com 0', (tester) async {
      final c = controllerComResposta(naoLidas: 0, lista: const []);
      c.naoLidas = 12;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [NotificacoesSino(controller: c)]),
          ),
        ),
      );
      expect(find.text('9+'), findsOneWidget);

      c.naoLidas = 0;
      c.notifyListeners();
      await tester.pump();
      expect(find.byKey(const Key('notificacoes-badge')), findsNothing);
    });
  });

  group('NotificacoesPainel (estados)', () {
    Future<void> pumpPainel(
      WidgetTester tester,
      NotificacoesController c,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox(),
            endDrawer: NotificacoesPainel(controller: c),
            appBar: AppBar(actions: [NotificacoesSino(controller: c)]),
          ),
        ),
      );
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openEndDrawer();
      await tester.pumpAndSettle();
    }

    testWidgets('lista os itens (pronto)', (tester) async {
      final c = controllerComResposta(naoLidas: 1, lista: const []);
      c.fase = NotificacoesFase.pronto;
      c.naoLidas = 1;
      c.itens = [notif(id: '9')];
      await pumpPainel(tester, c);
      expect(find.byKey(const Key('notificacoes-lista')), findsOneWidget);
      expect(find.byKey(const Key('notificacao-item-9')), findsOneWidget);
      expect(find.text('Nova candidatura recebida'), findsOneWidget);
      expect(
        find.byKey(const Key('notificacoes-marcar-todas-btn')),
        findsOneWidget,
      );
    });

    testWidgets('vazio', (tester) async {
      final c = controllerComResposta(naoLidas: 0, lista: const []);
      c.fase = NotificacoesFase.pronto;
      c.itens = const [];
      await pumpPainel(tester, c);
      expect(find.byKey(const Key('notificacoes-vazio')), findsOneWidget);
      expect(
        find.byKey(const Key('notificacoes-marcar-todas-btn')),
        findsNothing,
      );
    });

    testWidgets('erro com retry', (tester) async {
      final c = controllerComResposta(naoLidas: 0, lista: const []);
      c.fase = NotificacoesFase.erro;
      await pumpPainel(tester, c);
      expect(find.byKey(const Key('notificacoes-erro')), findsOneWidget);
      expect(find.byKey(const Key('notificacoes-retry-btn')), findsOneWidget);
    });

    testWidgets('loading mostra skeleton', (tester) async {
      final c = controllerComResposta(naoLidas: 0, lista: const []);
      c.fase = NotificacoesFase.carregando;
      await pumpPainel(tester, c);
      expect(find.byKey(const Key('notificacoes-skeleton')), findsOneWidget);
    });
  });
}
