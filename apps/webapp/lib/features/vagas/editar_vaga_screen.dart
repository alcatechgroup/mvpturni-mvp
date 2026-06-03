import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/turni_datetime.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import '../cadastro/shared/cadastro_widgets.dart';
import '../cadastro/shared/input_formatters.dart';
import 'vaga_service.dart';

/// STORY-052 / SCREEN-STORY-052 — edição material da vaga do contratante (PDR-009).
/// Reusa o formulário de publicar (046), pré-preenchido, e adiciona o passo de confirmação
/// com o diff ("o que muda") + quantos candidatos serão avisados antes de salvar (CA-10).
class EditarVagaScreen extends StatefulWidget {
  const EditarVagaScreen({
    super.key,
    required this.vagaId,
    VagaService? service,
    AuthService? auth,
  }) : _service = service,
       _auth = auth;

  final int vagaId;
  final VagaService? _service;
  final AuthService? _auth;

  @override
  State<EditarVagaScreen> createState() => _EditarVagaScreenState();
}

enum _Phase { loading, semPermissao, naoEditavel, erroCarregar, form }

class _EditarVagaScreenState extends State<EditarVagaScreen> {
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
  VagaEditar? _original;
  int? _funcaoId;
  int _posicoes = 1;
  String? _funcaoErro;
  String? _quandoErro;
  String? _nadaMudou; // inline quando "Revisar" sem ter mudado nada (§4.3)

  // Passo de confirmação (overlay sheet — §3).
  bool _confirmando = false;
  List<DiffLinha> _diff = const [];
  bool _submitting = false;
  bool _erroSubmit = false;

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
    if (_auth.session?.role != 'contratante') {
      setState(() => _phase = _Phase.semPermissao);
      return;
    }
    setState(() => _phase = _Phase.loading);

    final result = await _service.fetchEditar(widget.vagaId);
    if (!mounted) return;
    switch (result) {
      case CarregarEdicaoForbidden():
        setState(() => _phase = _Phase.semPermissao);
        return;
      case CarregarEdicaoNotFound():
      case CarregarEdicaoError():
        setState(() => _phase = _Phase.erroCarregar);
        return;
      case CarregarEdicaoSuccess(:final vaga):
        if (!vaga.editavel) {
          setState(() => _phase = _Phase.naoEditavel);
          return;
        }
        _original = vaga;
        _preencher(vaga);
    }

    final funcoes = await _service.fetchFuncoes();
    if (!mounted) return;
    setState(() {
      _funcoes = funcoes;
      _phase = _Phase.form;
    });
  }

  void _preencher(VagaEditar v) {
    _funcaoId = v.funcaoId;
    _posicoes = v.posicoes;
    // Exibição local 24h é política do TurniDateTime (mesma do card/detalhe) — IDR-026.
    _dataInicioCtrl.text = TurniDateTime.formatData(v.dataInicio);
    _horaInicioCtrl.text = TurniDateTime.formatHora(v.dataInicio);
    _dataFimCtrl.text = TurniDateTime.formatData(v.dataFim);
    _horaFimCtrl.text = TurniDateTime.formatHora(v.dataFim);
    _valorCtrl.text = _fmtMoeda(v.valor);
    _obsCtrl.text = v.observacoes ?? '';
  }

  // ──────────────────────────── format de moeda (local) ────────────────────────────

  String _fmtMoeda(double v) {
    final centavos = (v * 100).round();
    final reais = (centavos ~/ 100).toString();
    final dec = (centavos % 100).toString().padLeft(2, '0');
    final b = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) b.write('.');
      b.write(reais[i]);
    }
    return 'R\$ $b,$dec';
  }

  String _funcaoNome(int? id) =>
      _funcoes.where((f) => f.id == id).map((f) => f.nome).firstOrNull ?? '—';

  // ──────────────────────────── ações ────────────────────────────

  /// Monta o diff cliente (a UI tem antes/depois do próprio form). Mesma ordem/rótulos do
  /// servidor (EdicaoMaterial); usado só para o preview — a verdade material é do PATCH.
  List<DiffLinha> _calcularDiff(DateTime inicio, DateTime fim) {
    final orig = _original!;
    final out = <DiffLinha>[];
    if (_funcaoId != orig.funcaoId) {
      out.add(
        DiffLinha(
          campo: 'funcao_id',
          label: 'Função',
          tipo: 'funcao',
          antes: _funcaoNome(orig.funcaoId),
          depois: _funcaoNome(_funcaoId),
        ),
      );
    }
    if (!TurniDateTime.mesmoInstante(inicio, orig.dataInicio)) {
      out.add(
        DiffLinha(
          campo: 'data_inicio',
          label: 'Início',
          tipo: 'data',
          antes: TurniDateTime.toApi(orig.dataInicio),
          depois: TurniDateTime.toApi(inicio),
        ),
      );
    }
    if (!TurniDateTime.mesmoInstante(fim, orig.dataFim)) {
      out.add(
        DiffLinha(
          campo: 'data_fim',
          label: 'Fim',
          tipo: 'data',
          antes: TurniDateTime.toApi(orig.dataFim),
          depois: TurniDateTime.toApi(fim),
        ),
      );
    }
    final valor = moedaParaNumero(_valorCtrl.text);
    if ((valor - orig.valor).abs() > 0.001) {
      out.add(
        DiffLinha(
          campo: 'valor',
          label: 'Valor',
          tipo: 'valor',
          antes: orig.valor,
          depois: valor,
        ),
      );
    }
    if (_posicoes != orig.posicoes) {
      out.add(
        DiffLinha(
          campo: 'posicoes',
          label: 'Quantas pessoas',
          tipo: 'posicoes',
          antes: orig.posicoes,
          depois: _posicoes,
        ),
      );
    }
    final obsAtual = _obsCtrl.text.trim();
    final obsOrig = (orig.observacoes ?? '').trim();
    if (obsAtual != obsOrig) {
      out.add(
        DiffLinha(
          campo: 'observacoes',
          label: 'Observações',
          tipo: 'texto',
          antes: obsOrig.isEmpty ? '—' : obsOrig,
          depois: obsAtual.isEmpty ? '—' : obsAtual,
        ),
      );
    }
    return out;
  }

  void _revisar() {
    setState(() => _nadaMudou = null);
    final formOk = _formKey.currentState?.validate() ?? false;
    final funcaoErro = _funcaoId == null ? 'Escolha a função do turno.' : null;
    final inicio = TurniDateTime.parseEntrada(
      _dataInicioCtrl.text,
      _horaInicioCtrl.text,
    );
    final fim = TurniDateTime.parseEntrada(
      _dataFimCtrl.text,
      _horaFimCtrl.text,
    );

    String? quandoErro;
    if (inicio == null) {
      quandoErro = 'Informe quando o turno começa.';
    } else if (fim == null) {
      quandoErro = 'Informe quando o turno termina.';
    } else if (!fim.isAfter(inicio)) {
      quandoErro = 'O fim precisa ser depois do início.';
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

    final diff = _calcularDiff(inicio, fim);
    if (diff.isEmpty) {
      setState(() => _nadaMudou = 'Você ainda não alterou nada.');
      return;
    }
    setState(() {
      _diff = diff;
      _erroSubmit = false;
      _confirmando = true;
    });
  }

  Future<void> _confirmar() async {
    final inicio = TurniDateTime.parseEntrada(
      _dataInicioCtrl.text,
      _horaInicioCtrl.text,
    )!;
    final fim = TurniDateTime.parseEntrada(
      _dataFimCtrl.text,
      _horaFimCtrl.text,
    )!;
    setState(() {
      _submitting = true;
      _erroSubmit = false;
    });

    final result = await _service.editar(
      widget.vagaId,
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
      case EditarSuccess(:final material, :final candidatosNotificados):
        final msg = material && candidatosNotificados > 0
            ? 'Vaga atualizada — $candidatosNotificados '
                  '${candidatosNotificados == 1 ? 'candidato foi avisado' : 'candidatos foram avisados'}.'
            : 'Vaga atualizada.';
        context.go('/contratante/vagas', extra: msg);
      case EditarValidationError(:final errors):
        setState(() {
          _confirmando = false;
          _funcaoErro = errors['funcao_id'];
          _quandoErro = errors['data_inicio'] ?? errors['data_fim'];
        });
      case EditarConflict():
        setState(() {
          _confirmando = false;
          _phase = _Phase.naoEditavel;
        });
      case EditarForbidden():
        setState(() {
          _confirmando = false;
          _phase = _Phase.semPermissao;
        });
      case EditarServerError():
        setState(() => _erroSubmit = true);
    }
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
      setState(() => ctrl.text = TurniDateTime.formatData(escolhida));
    }
  }

  Future<void> _escolherHora(TextEditingController ctrl) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Escolha a hora',
    );
    if (escolhida != null) {
      setState(
        () => ctrl.text = TurniDateTime.formatHoraComponentes(
          escolhida.hour,
          escolhida.minute,
        ),
      );
    }
  }

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
      key: const Key('editar-vaga-screen'),
      backgroundColor: surfacePage,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('editar-vaga-appbar-voltar'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/contratante/vagas'),
        ),
        title: const Text('Editar vaga'),
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
      case _Phase.naoEditavel:
        return _NaoEditavelView(accent: accent, vagaId: widget.vagaId);
      case _Phase.erroCarregar:
        return _ErroCarregarView(accent: accent, onRetry: _bootstrap);
      case _Phase.form:
        return Stack(
          children: [
            _form(isDark, accent),
            if (_confirmando)
              _ConfirmarSheet(
                diff: _diff,
                candidatos: _original?.candidatosEmRevisao ?? 0,
                accent: accent,
                isDark: isDark,
                submitting: _submitting,
                erro: _erroSubmit,
                fmtMoeda: _fmtMoeda,
                onConfirmar: _submitting ? null : _confirmar,
                onVoltar: _submitting
                    ? null
                    : () => setState(() => _confirmando = false),
              ),
          ],
        );
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
              const CadastroSection('Função'),
              Padding(
                padding: const EdgeInsets.only(top: TurniSpacing.md),
                child: DropdownMenu<int>(
                  key: const Key('editar-vaga-funcao-dropdown'),
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
                dataKey: 'editar-vaga-data-inicio',
                horaKey: 'editar-vaga-hora-inicio',
                dataCtrl: _dataInicioCtrl,
                horaCtrl: _horaInicioCtrl,
              ),
              const SizedBox(height: TurniSpacing.sm),
              _dataHoraLinha(
                rotulo: 'Fim',
                dataKey: 'editar-vaga-data-fim',
                horaKey: 'editar-vaga-hora-fim',
                dataCtrl: _dataFimCtrl,
                horaCtrl: _horaFimCtrl,
              ),
              if (_quandoErro != null)
                CadastroErrorText(
                  _quandoErro!,
                  key: const Key('editar-vaga-quando-erro'),
                ),

              const CadastroSection('Pagamento e posições'),
              CadastroTextField(
                fieldKey: 'editar-vaga-valor',
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
                onChanged: (v) => setState(() => _posicoes = v),
              ),

              const CadastroSection('Observações (opcional)'),
              CadastroTextField(
                fieldKey: 'editar-vaga-observacoes',
                controller: _obsCtrl,
                label: 'Observações',
                hint: 'Dress code, instruções, ponto de encontro…',
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: TurniSpacing.xl),
              FilledButton(
                key: const Key('editar-vaga-revisar-btn'),
                onPressed: _revisar,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Revisar alteração'),
              ),
              if (_nadaMudou != null)
                Padding(
                  padding: const EdgeInsets.only(top: TurniSpacing.sm),
                  child: Text(
                    _nadaMudou!,
                    key: const Key('editar-vaga-nada-mudou'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: TurniSpacing.lg),
            ],
          ),
        );

        return SingleChildScrollView(
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
      },
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

/// Sheet de confirmação com o diff + aviso de candidatos (overlay in-tree — §3).
class _ConfirmarSheet extends StatelessWidget {
  const _ConfirmarSheet({
    required this.diff,
    required this.candidatos,
    required this.accent,
    required this.isDark,
    required this.submitting,
    required this.erro,
    required this.fmtMoeda,
    required this.onConfirmar,
    required this.onVoltar,
  });

  final List<DiffLinha> diff;
  final int candidatos;
  final Color accent;
  final bool isDark;
  final bool submitting;
  final bool erro;
  final String Function(double) fmtMoeda;
  final VoidCallback? onConfirmar;
  final VoidCallback? onVoltar;

  String _valorLinha(DiffLinha l) {
    switch (l.tipo) {
      case 'valor':
        return '${fmtMoeda((l.antes as num).toDouble())} → ${fmtMoeda((l.depois as num).toDouble())}';
      case 'data':
        return '${_fmtDataHora(l.antes as String?)} → ${_fmtDataHora(l.depois as String?)}';
      default:
        return '${l.antes} → ${l.depois}';
    }
  }

  String _fmtDataHora(String? iso) {
    final d = TurniDateTime.parse(iso);
    return d == null ? '—' : TurniDateTime.formatDataHoraCurta(d);
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight;
    final largo = MediaQuery.sizeOf(context).width >= 1024;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    final card = Container(
      key: const Key('editar-vaga-confirmar-sheet'),
      width: largo ? 520 : double.infinity,
      padding: const EdgeInsets.all(TurniSpacing.lg),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: largo
            ? const BorderRadius.all(TurniRadius.lg)
            : const BorderRadius.vertical(top: TurniRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisar alteração',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: TurniSpacing.xs),
          Text(
            'Confira o que muda antes de salvar.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: TurniSpacing.md),
          _DiffCard(diff: diff, valorLinha: _valorLinha, isDark: isDark),
          const SizedBox(height: TurniSpacing.md),
          _AvisoCandidatos(candidatos: candidatos, isDark: isDark),
          if (erro) ...[
            const SizedBox(height: TurniSpacing.md),
            _ErroSubmitBanner(isDark: isDark),
          ],
          const SizedBox(height: TurniSpacing.md),
          FilledButton(
            key: const Key('editar-vaga-confirmar-btn'),
            onPressed: onConfirmar,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(erro ? 'Tentar de novo' : 'Confirmar alteração'),
          ),
          TextButton(
            key: const Key('editar-vaga-voltar-btn'),
            onPressed: onVoltar,
            child: const Text('Voltar e ajustar'),
          ),
        ],
      ),
    );

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Align(
          alignment: largo ? Alignment.center : Alignment.bottomCenter,
          child: SingleChildScrollView(child: card),
        ),
      ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({
    required this.diff,
    required this.valorLinha,
    required this.isDark,
  });

  final List<DiffLinha> diff;
  final String Function(DiffLinha) valorLinha;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderSubtleLight;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final strong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    return Container(
      padding: const EdgeInsets.all(TurniSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: const BorderRadius.all(TurniRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O QUE MUDA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: muted,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: TurniSpacing.sm),
          for (final l in diff)
            Padding(
              key: Key('editar-vaga-diff-${l.campo}'),
              padding: const EdgeInsets.symmetric(vertical: TurniSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Semantics(
                    label: '${l.label}: de ${l.antes} para ${l.depois}',
                    child: Text(
                      valorLinha(l),
                      style: TextStyle(
                        fontSize: 15,
                        color: strong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AvisoCandidatos extends StatelessWidget {
  const _AvisoCandidatos({required this.candidatos, required this.isDark});

  final int candidatos;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.warnSoftDark : TurniColors.warnSoftLight;
    final ink = isDark
        ? TurniColors.contratanteAccentDark
        : TurniColors.contratanteAccentInkLight;
    final texto = candidatos == 0
        ? 'Ninguém se candidatou ainda — a alteração entra na hora, sem avisos.'
        : candidatos == 1
        ? '1 candidato pendente vai ser avisado e tem até 24h (ou até o turno começar) '
              'para confirmar. Quem não confirmar sai automaticamente.'
        : '$candidatos candidatos pendentes vão ser avisados e têm até 24h (ou até o turno '
              'começar) para confirmar. Quem não confirmar sai automaticamente.';

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('editar-vaga-aviso-candidatos'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: ink),
            const SizedBox(width: TurniSpacing.sm),
            Expanded(
              child: Text(texto, style: TextStyle(fontSize: 13, color: ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErroSubmitBanner extends StatelessWidget {
  const _ErroSubmitBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? TurniColors.errorSoftDark : TurniColors.errorSoftLight;
    final color = isDark ? TurniColors.errorDark : TurniColors.errorLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('editar-vaga-erro-rede'),
        padding: const EdgeInsets.all(TurniSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: color.withAlpha(128)),
          borderRadius: const BorderRadius.all(TurniRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: color),
            const SizedBox(width: TurniSpacing.sm),
            const Expanded(
              child: Text(
                'Não foi possível salvar agora. Verifique sua conexão e tente de novo.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosicoesStepper extends StatelessWidget {
  const _PosicoesStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('editar-vaga-posicoes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantas pessoas?', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: TurniSpacing.xs),
        Row(
          children: [
            IconButton.outlined(
              key: const Key('editar-vaga-posicoes-menos'),
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
              key: const Key('editar-vaga-posicoes-mais'),
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add),
              tooltip: 'Aumentar posições',
            ),
          ],
        ),
      ],
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
          key: const Key('editar-vaga-sem-permissao'),
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
              'Editar vagas é uma ação de quem contrata. Sua conta é de profissional.',
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

class _NaoEditavelView extends StatelessWidget {
  const _NaoEditavelView({required this.accent, required this.vagaId});

  final Color accent;
  final int vagaId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: Column(
          key: const Key('editar-vaga-erro-409'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 44),
            const SizedBox(height: TurniSpacing.md),
            const Text(
              'Esta vaga não pode mais ser editada (ela foi fechada ou cancelada).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TurniSpacing.lg),
            FilledButton(
              onPressed: () => context.go('/contratante/vagas'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Ver a vaga'),
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
              key: const Key('editar-vaga-retry-btn'),
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
