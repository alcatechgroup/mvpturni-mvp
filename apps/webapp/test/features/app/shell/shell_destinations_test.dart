import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/features/app/shell/shell_destinations.dart';

// STORY-077 CA-2 — o shell mostra os destinos do papel autenticado (Profissional ×
// Contratante) conforme DDR-003; RBAC garante que nenhum destino do outro papel
// aparece (ADR-007), com fail-secure. Os 3 destinos (Vagas/Turnos/Perfil) têm a
// mesma ordem nos dois papéis; só o TÍTULO da tela muda por papel.

void main() {
  group('destinationsFor (CA-2)', () {
    test(
      '(a) feliz — profissional vê Vagas, Turnos e Perfil na ordem do DDR-003',
      () {
        final d = destinationsFor('profissional');
        expect(d.map((e) => e.id), ['vagas', 'turnos', 'perfil']);
        expect(d.map((e) => e.label), ['Vagas', 'Turnos', 'Perfil']);
        // Títulos do profissional (protótipo SCREEN-STORY-077).
        expect(d[0].title, 'Vagas');
        expect(d[1].title, 'Meus turnos');
        expect(d[2].title, 'Perfil');
        // Rotas canônicas dos branches.
        expect(d.map((e) => e.route), ['/', '/turnos', '/perfil']);
      },
    );

    test(
      '(a) feliz — contratante vê os mesmos 3 destinos com títulos próprios',
      () {
        final d = destinationsFor('contratante');
        expect(d.map((e) => e.id), ['vagas', 'turnos', 'perfil']);
        expect(d.map((e) => e.label), ['Vagas', 'Turnos', 'Perfil']);
        expect(d[0].title, 'Minhas vagas');
        expect(d[1].title, 'Turnos');
        expect(d[2].title, 'Perfil');
        expect(d.map((e) => e.route), ['/', '/turnos', '/perfil']);
      },
    );

    test(
      '(b) inválido / fail-secure — papel desconhecido não expõe destino nenhum',
      () {
        expect(destinationsFor('admin'), isEmpty);
        expect(destinationsFor(''), isEmpty);
      },
    );

    test(
      '(c) exceção — papel nulo (sessão ausente) não expõe destino nenhum',
      () {
        expect(destinationsFor(null), isEmpty);
      },
    );

    test('(d) borda — nenhum destino de um papel vaza para o outro', () {
      final prof = destinationsFor('profissional').map((e) => e.title).toSet();
      final contr = destinationsFor('contratante').map((e) => e.title).toSet();
      // O título exclusivo de cada papel não aparece no outro.
      expect(prof, contains('Meus turnos'));
      expect(contr, isNot(contains('Meus turnos')));
      expect(contr, contains('Minhas vagas'));
      expect(prof, isNot(contains('Minhas vagas')));
    });

    test(
      '(d) borda — contratante tem ação primária "Nova vaga"; profissional não',
      () {
        expect(destinationsFor('contratante'), isNotEmpty);
        expect(hasNovaVagaAction('contratante'), isTrue);
        expect(hasNovaVagaAction('profissional'), isFalse);
        expect(hasNovaVagaAction(null), isFalse);
      },
    );
  });

  // STORY-078 — a barra superior do shell só aparece nas RAÍZES de destino; os
  // drill-downs (detalhe de vaga/turno, candidatos, editar, nova, cronômetro)
  // mantêm a própria AppBar (voltar + título). isDestinationRoot decide isso a
  // partir da rota corrente (state.uri.path, sem query string).
  group('isDestinationRoot (CA-3/CA-4)', () {
    test('(a) feliz — raízes de destino dos dois papéis retornam true', () {
      for (final r in [
        '/', // home role-dispatch (feed / minhas vagas)
        '/feed', // feed do profissional
        '/contratante/vagas', // minhas vagas do contratante
        '/turnos', // turnos canônico (role-dispatch)
        '/profissional/turnos',
        '/contratante/turnos',
        '/perfil',
      ]) {
        expect(
          isDestinationRoot(r),
          isTrue,
          reason: 'raiz $r deveria ser true',
        );
      }
    });

    test('(b) inválido — drill-downs NÃO são raiz (shell sem AppBar)', () {
      for (final r in [
        '/vaga/abc',
        '/contratante/vagas/nova',
        '/contratante/vagas/abc/editar',
        '/contratante/vagas/abc/candidatos',
        '/turnos/abc',
        '/turno/abc/cronometro-poc',
      ]) {
        expect(isDestinationRoot(r), isFalse, reason: '$r é drill-down');
      }
    });

    test('(c) borda — rota desconhecida/vazia não é raiz (fail-safe)', () {
      expect(isDestinationRoot(''), isFalse);
      expect(isDestinationRoot('/qualquer-coisa'), isFalse);
      expect(isDestinationRoot('/login'), isFalse);
    });
  });

  // O título da barra do shell é o do destino ATIVO (varia por papel), derivado
  // do índice do branch corrente. Fail-secure: papel/índice inválido → null.
  group('sectionTitleFor (CA-3)', () {
    test('(a) feliz — título por papel e índice de branch', () {
      expect(sectionTitleFor('profissional', 0), 'Vagas');
      expect(sectionTitleFor('profissional', 1), 'Meus turnos');
      expect(sectionTitleFor('profissional', 2), 'Perfil');
      expect(sectionTitleFor('contratante', 0), 'Minhas vagas');
      expect(sectionTitleFor('contratante', 1), 'Turnos');
      expect(sectionTitleFor('contratante', 2), 'Perfil');
    });

    test('(b)/(c) fail-secure — papel desconhecido/nulo → null', () {
      expect(sectionTitleFor('admin', 0), isNull);
      expect(sectionTitleFor(null, 0), isNull);
    });

    test('(d) borda — índice fora do range → null (sem crash)', () {
      expect(sectionTitleFor('profissional', -1), isNull);
      expect(sectionTitleFor('profissional', 3), isNull);
      expect(sectionTitleFor('profissional', 99), isNull);
    });
  });
}
