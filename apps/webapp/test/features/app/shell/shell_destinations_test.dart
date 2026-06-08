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
}
