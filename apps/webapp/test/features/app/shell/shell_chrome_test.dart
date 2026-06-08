import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turni_webapp/ds/tokens.dart';
import 'package:turni_webapp/features/app/shell/shell_chrome.dart';

// STORY-077 CA-4 — cor de chrome do shell segue o perfil (mostarda contratante /
// verde-sage profissional), escura NOS DOIS TEMAS (DDR-001 §2.2). A superfície de
// navegação (bar/rail/drawer) carrega a assinatura do papel em light e dark.

void main() {
  group('ShellChrome.forRole (CA-4)', () {
    test('(a) feliz — profissional usa chrome verde-sage #1B2E1F', () {
      final c = ShellChrome.forRole('profissional');
      expect(c.surface, TurniColors.chromeProfissional);
      expect(c.surface, const Color(0xFF1B2E1F));
      expect(c.accent, TurniColors.accentDark); // #5FA37C sobre chrome escuro
    });

    test('(a) feliz — contratante usa chrome mostarda #3D2A0E', () {
      final c = ShellChrome.forRole('contratante');
      expect(c.surface, TurniColors.chromeContratante);
      expect(c.surface, const Color(0xFF3D2A0E));
      expect(c.accent, TurniColors.contratanteAccentDark); // #D4A95C
    });

    test('(b) inválido — papel desconhecido cai no chrome neutro do profissional '
        '(fail-secure: nunca a identidade do outro papel)', () {
      // Sem papel reconhecido, o shell não "vira" contratante por engano.
      final desconhecido = ShellChrome.forRole('admin');
      final nulo = ShellChrome.forRole(null);
      expect(desconhecido.surface, TurniColors.chromeProfissional);
      expect(nulo.surface, TurniColors.chromeProfissional);
      expect(desconhecido.surface, isNot(TurniColors.chromeContratante));
    });

    test('(d) borda — chrome é o MESMO valor independentemente do tema '
        '(escuro nos dois temas, DDR-001)', () {
      // ShellChrome não recebe brightness: a assinatura do chrome é invariante ao tema.
      final prof = ShellChrome.forRole('profissional');
      final contr = ShellChrome.forRole('contratante');
      // on/onMuted são neutros claros sobre o chrome escuro.
      expect(prof.on, TurniColors.chromeOn);
      expect(contr.on, TurniColors.chromeOn);
      expect(prof.onMuted.a, lessThan(prof.on.a)); // inativo mais apagado
      // accentSoft é o acento com baixa opacidade (pílula do item ativo).
      expect(prof.accentSoft.a, lessThan(1.0));
      expect(contr.accentSoft.a, lessThan(1.0));
    });
  });
}
