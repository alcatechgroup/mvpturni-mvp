import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import '../cadastro/shared/cadastro_widgets.dart';
import '../cadastro/shared/input_formatters.dart';
import 'vaga_service.dart';

/// STORY-046 / SCREEN-STORY-046 — formulário de publicação de vaga do contratante.
/// Gate PDR-005 (CA-5) antes do form; RBAC (CA-1) mostra "sem permissão" a profissional.
class PublicarVagaScreen extends StatefulWidget {
  const PublicarVagaScreen({super.key, VagaService? service, AuthService? auth})
    : _service = service,
      _auth = auth;

  final VagaService? _service;
  final AuthService? _auth;

  @override
  State<PublicarVagaScreen> createState() => _PublicarVagaScreenState();
}

enum _Phase { loading, semPermissao, gate, form, erroCarregar }

class _PublicarVagaScreenState extends State<PublicarVagaScreen> {
  late final VagaService _service = widget._service ?? VagaService();
  late final AuthService _auth = widget._auth ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  final _dataInicioCtrl = TextEditingController();
  final _horaInicioCtrl = TextEditingController();
  final _dataFimCtrl = TextEditingController();
  final _horaFimCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  _Phase _phase = _Phase.loading;
  List<Funcao> _funcoes = [];
  int? _funcaoId;
  int _posicoes = 1;
  int _gatePending = 0;
  String? _funcaoErro; // erro do seletor de função (não é FormField)
  String? _quandoErro; // erro do bloco "Quando" (datas)
  bool _submitting = false;
  bool _erroServidor = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _dataInicioCtrl.dispose();
    _horaInicioCtrl.dispose();
    _dataFimCtrl.dispose();
    _horaFimCtrl.dispose();
    _valorCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // CA-1 — profissional não vê o formulário (sem permissão). O backend ainda
    // responde 403; aqui evitamos a chamada e mostramos a saída clara.
    if (_auth.session?.role != 'contratante') {
      setState(() => _phase = _Phase.semPermissao);
      return;
    }

    setState(() => _phase = _Phase.loading);
    final gate = await _service.fetchGate();
    if (gate == null) {
      if (mounted) setState(() => _phase = _Phase.erroCarregar);
      return;
    }
    if (gate.bloqueado) {
      if (mounted) {
        setState(() {
          _gatePending = gate.pending;
          _phase = _Phase.gate;
        });
      }
      return;
    }
    final funcoes = await _service.fetchFuncoes();
    if (!mounted) return;
    setState(() {
      _funcoes = funcoes;
      _phase = _Phase.form;
    });
  }

  // ──────────────────────────── ações ────────────────────────────

  /// Parseia "dd/mm/aaaa" + "HH:mm" num DateTime; null se inválido.
  DateTime? _parseDataHora(String data, String hora) {
    final dm = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(data.trim());
    final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hora.trim());
    if (dm == null || hm == null) return null;
    final dia = int.parse(dm.group(1)!);
    final mes = int.parse(dm.group(2)!);
    final ano = int.parse(dm.group(3)!);
    final h = int.parse(hm.group(1)!);
    final min = int.parse(hm.group(2)!);
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31 || h > 23 || min > 59) {
      return null;
    }
    final dt = DateTime(ano, mes, dia, h, min);
    // Rejeita datas que "transbordam" (ex.: 31/02 vira 02/03).
    if (dt.month != mes || dt.day != dia) return null;
    return dt;
  }

  Future<void> _submit() async {
    setState(() => _erroServidor = false);
    final formOk = _formKey.currentState?.validate() ?? false;

    // Função: DropdownMenu não é FormField, então valida-se à parte (como as datas).
    final funcaoErro = _funcaoId == null ? 'Escolha a função do turno.' : null;

    final inicio = _parseDataHora(_dataInicioCtrl.text, _horaInicioCtrl.text);
    final fim = _parseDataHora(_dataFimCtrl.text, _horaFimCtrl.text);

    String? quandoErro;
    if (inicio == null) {
      quandoErro = 'Informe quando o turno começa.';
    } else if (fim == null) {
      quandoErro = 'Informe quando o turno termina.';
    } else if (!fim.isAfter(inicio)) {
      quandoErro = 'O fim precisa ser depois do início.'; // CA-3
    }
    setState(() {
      _funcaoErro = funcaoErro;
      _quandoErro = quandoErro;
    });

    if (!formOk ||
        funcaoErro != null ||
        quandoErro != null ||
        inicio == null ||
        fim == null) {
      return;
    }

    setState(() => _submitting = true);
    final result = await _service.publicar(
      funcaoId: _funcaoId!,
      dataInicio: inicio,
      dataFim: fim,
      valor: moedaParaNumero(_valorCtrl.text),
      posicoes: _posicoes,
      observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case PublicarSuccess():
        // CA-7 — vai para "Minhas vagas" (STORY-047 / placeholder) com toast.
        context.go(
          '/contratante/vagas',
          extra: 'Vaga publicada — começou a aparecer para profissionais.',
        );
      case PublicarValidationError(:final errors):
        _aplicarErrosServidor(errors);
      case PublicarForbidden():
        setState(() => _phase = _Phase.semPermissao);
      case PublicarServerError():
        setState(() => _erroServidor = true);
    }
  }

  void _aplicarErrosServidor(Map<String, String> errors) {
    // Espelha os erros nos campos certos (função/datas); o resto vai pro banner.
    final funcao = errors['funcao_id'];
    final quando = errors['data_inicio'] ?? errors['data_fim'];
    final tratados = (funcao != null ? 1 : 0) + (quando != null ? 1 : 0);
    setState(() {
      _funcaoErro = funcao;
      _quandoErro = quando;
      _erroServidor = errors.length > tratados;
    });
  }

  Future<void> _escolherData(TextEditingController ctrl) async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: hoje.add(const Duration(days: 1)),
      firstDate: hoje,
      lastDate: hoje.add(const Duration(days: 365)),
      helpText: 'Escolha a data',
    );
    if (escolhida != null) {
      ctrl.text =
          '${escolhida.day.toString().padLeft(2, '0')}/'
          '${escolhida.month.toString().padLeft(2, '0')}/${escolhida.year}';
    }
  }

  Future<void> _escolherHora(TextEditingController ctrl) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Escolha a hora',
    );
    if (escolhida != null) {
      ctrl.text =
          '${escolhida.hour.toString().padLeft(2, '0')}:'
          '${escolhida.minute.toString().padLeft(2, '0')}';
    }
  }

  // ──────────────────────────── cores do papel ────────────────────────────

  Color _accent(bool isDark) => isDark
      ? TurniColors.contratanteAccentDark
      : TurniColors.contratanteAccentLight;

  // ──────────────────────────── build ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(isDark);
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('publicar-vaga-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('publicar-vaga-voltar-btn'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_phase == _Phase.gate ? 'Publicar vaga' : 'Publicar vaga'),
      ),
      body: SafeArea(child: _body(isDark, accent)),
    );
  }

  Widget _body(bool isDark, Color accent) {
    switch (_phase) {
      case _Phase.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(TurniSpacing.xl),
            child: CircularProgressIndicator(),
          ),
        );
      case _Phase.semPermissao:
        return _SemPermissaoView(accent: accent);
      case _Phase.gate:
        return _GateView(pending: _gatePending, accent: accent, isDark: isDark);
      case _Phase.erroCarregar:
        return _ErroCarregarView(accent: accent, onRetry: _bootstrap);
      case _Phase.form:
        return _form(isDark, accent);
    }
  }

  Widget _form(bool isDark, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= 1024;
        final content = Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_erroServidor)
                Padding(
                  padding: const EdgeInsets.only(bottom: TurniSpacing.sm),
                  child: _ErroServidorBanner(isDark: isDark),
                ),

              const CadastroSection('Função'),
              Padding(
                padding: const EdgeInsets.only(top: TurniSpacing.md),
                // DropdownMenu (Material 3): campo com busca embutida — o usuário
                // digita um termo e a lista filtra (enableFilter). Melhor que um
                // select simples para a lista canônica de funções (~14 itens).
                child: DropdownMenu<int>(
                  key: const Key('publicar-vaga-funcao-dropdown'),
                  initialSelection: _funcaoId,
                  requestFocusOnTap: true,
                  enableFilter: true,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: 320,
                  leadingIcon: const Icon(Icons.search),
                  label: const Text('Função'),
                  hintText: 'Selecione ou busque a função',
                  errorText: _funcaoErro,
                  dropdownMenuEntries: _funcoes
                      .map(
                        (f) =>
                            DropdownMenuEntry<int>(value: f.id, label: f.nome),
                      )
                      .toList(),
                  onSelected: (v) => setState(() {
                    _funcaoId = v;
                    _funcaoErro = null;
                  }),
                ),
              ),

              const CadastroSection('Quando'),
              _dataHoraLinha(
                rotulo: 'Início',
                dataKey: 'publicar-vaga-data-inicio',
                horaKey: 'publicar-vaga-hora-inicio',
                dataCtrl: _dataInicioCtrl,
                horaCtrl: _horaInicioCtrl,
              ),
              const SizedBox(height: TurniSpacing.sm),
              _dataHoraLinha(
                rotulo: 'Fim',
                dataKey: 'publicar-vaga-data-fim',
                horaKey: 'publicar-vaga-hora-fim',
                dataCtrl: _dataFimCtrl,
                horaCtrl: _horaFimCtrl,
              ),
              if (_quandoErro != null)
                CadastroErrorText(
                  _quandoErro!,
                  key: const Key('publicar-vaga-quando-erro'),
                ),

              const CadastroSection('Pagamento e posições'),
              CadastroTextField(
                fieldKey: 'publicar-vaga-valor',
                controller: _valorCtrl,
                label: 'Valor por turno',
                hint: 'R\$ 0,00',
                helper: 'O quanto o profissional recebe por este turno.',
                keyboardType: TextInputType.number,
                inputFormatters: [MoedaInputFormatter()],
                validator: (v) => moedaParaNumero(v ?? '') <= 0
                    ? 'Informe o valor por turno.'
                    : null,
              ),
              const SizedBox(height: TurniSpacing.md),
              _PosicoesStepper(
                value: _posicoes,
                accent: accent,
                onChanged: (v) => setState(() => _posicoes = v),
              ),

              const CadastroSection('Observações (opcional)'),
              CadastroTextField(
                fieldKey: 'publicar-vaga-observacoes',
                controller: _obsCtrl,
                label: 'Observações',
                hint: 'Dress code, instruções, ponto de encontro…',
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: TurniSpacing.xl),
              _ctaRow(largo: largo, accent: accent),
              const SizedBox(height: TurniSpacing.lg),
            ],
          ),
        );

        final padded = SingleChildScrollView(
          padding: const EdgeInsets.all(TurniSpacing.md),
          child: largo
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: content,
                  ),
                )
              : content,
        );
        return padded;
      },
    );
  }

  Widget _ctaRow({required bool largo, required Color accent}) {
    final publicar = FilledButton(
      key: const Key('publicar-vaga-submit-btn'),
      onPressed: _submitting ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        // Altura mínima 48 (toque); largura 0 para não exigir largura infinita dentro
        // do Row do layout largo — no mobile o Column `stretch` já estica full-width.
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
      child: _submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Publicar vaga'),
    );

    if (!largo) return publicar;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: const Key('publicar-vaga-cancelar-btn'),
          onPressed: _submitting ? null : () => context.go('/'),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: TurniSpacing.md),
        publicar,
      ],
    );
  }

  Widget _dataHoraLinha({
    required String rotulo,
    required String dataKey,
    required String horaKey,
    required TextEditingController dataCtrl,
    required TextEditingController horaCtrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: TurniSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: TurniSpacing.xs),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: Key(dataKey),
                  controller: dataCtrl,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    hintText: 'dd/mm/aaaa',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      tooltip: 'Escolher data de $rotulo',
                      onPressed: () => _escolherData(dataCtrl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TurniSpacing.sm),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: Key(horaKey),
                  controller: horaCtrl,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    hintText: '--:--',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.schedule_outlined),
                      tooltip: 'Escolher hora de $rotulo',
                      onPressed: () => _escolherHora(horaCtrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stepper de posições (− / +), mínimo 1. Key da raiz `publicar-vaga-posicoes`.
class _PosicoesStepper extends StatelessWidget {
  const _PosicoesStepper({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Column(
      key: const Key('publicar-vaga-posicoes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantas pessoas?', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: TurniSpacing.xs),
        Row(
          children: [
            IconButton.outlined(
              key: const Key('publicar-vaga-posicoes-menos'),
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Diminuir posições',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TurniSpacing.md),
              child: Semantics(
                label: 'Número de posições: $value',
                child: Text('$value', style: const TextStyle(fontSize: 18)),
              ),
            ),
            IconButton.outlined(
              key: const Key('publicar-vaga-posicoes-mais'),
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add),
              tooltip: 'Aumentar posições',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: TurniSpacing.xs),
          child: Text(
            'Quantos profissionais você precisa para este turno.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    );
  }
}

/// Banner de erro de servidor/rede no submit (§4.7). Live region para leitor de tela.
class _ErroServidorBanner extends StatelessWidget {
  const _ErroServidorBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.errorSoftDark : TurniColors.errorSoftLight;
    final color = isDark ? TurniColors.errorDark : TurniColors.errorLight;
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('publicar-vaga-erro-banner'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: color.withAlpha(128)),
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: color),
            const SizedBox(width: TurniSpacing.sm),
            Expanded(
              child: Text(
                'Não foi possível publicar agora. '
                'Verifique sua conexão e tente de novo.',
                style: TextStyle(fontSize: 13, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateView extends StatelessWidget {
  const _GateView({
    required this.pending,
    required this.accent,
    required this.isDark,
  });

  final int pending;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final corpo = pending == 1
        ? 'Você tem 1 turno finalizado aguardando sua avaliação. '
              'Avaliar mantém o histórico de todos justo.'
        : 'Você tem $pending turnos finalizados aguardando sua avaliação. '
              'Avaliar mantém o histórico de todos justo.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: Column(
          key: const Key('publicar-vaga-gate'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined, size: 44),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Avalie seus turnos pendentes para publicar uma nova vaga',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.md),
            Container(
              padding: const EdgeInsets.all(TurniSpacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? TurniColors.warnSoftDark
                    : TurniColors.warnSoftLight,
                borderRadius: const BorderRadius.all(TurniRadius.md),
              ),
              child: Column(
                children: [
                  Text(corpo, textAlign: TextAlign.center),
                  const SizedBox(height: TurniSpacing.md),
                  FilledButton(
                    key: const Key('publicar-vaga-gate-avaliar-btn'),
                    onPressed: () =>
                        context.go('/contratante/avaliacoes/pendentes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Avaliar turnos pendentes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemPermissaoView extends StatelessWidget {
  const _SemPermissaoView({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: Column(
          key: const Key('publicar-vaga-sem-permissao'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 44),
            const SizedBox(height: TurniSpacing.md),
            Text(
              'Esta área é do contratante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: TurniSpacing.sm),
            const Text(
              'Publicar vagas é uma ação de quem contrata. '
              'Sua conta é de profissional.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                shape: const StadiumBorder(),
              ),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErroCarregarView extends StatelessWidget {
  const _ErroCarregarView({required this.accent, required this.onRetry});

  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: TurniSpacing.md),
            const Text(
              'Não foi possível carregar agora. Verifique sua conexão.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              key: const Key('publicar-vaga-retry-btn'),
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
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
