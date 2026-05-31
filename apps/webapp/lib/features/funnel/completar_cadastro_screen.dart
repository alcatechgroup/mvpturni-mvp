import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../ds/components/app_version_label.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import '../cadastro/cadastro_service.dart';
import '../cadastro/completar_cadastro_service.dart';
import '../cadastro/shared/cadastro_widgets.dart';

/// STORY-023 — Completar cadastro do Profissional (SCREEN-STORY-023).
///
/// Wizard de 3 passos (Identidade → Atuação → Financeiro e documento) → preview do contrato
/// renderizado server-side → aceite explícito (checkbox + CTA) → geração do AceiteEletronico e
/// transição para `ativo`. Substitui o placeholder de STORY-016.
class CompletarCadastroScreen extends StatefulWidget {
  const CompletarCadastroScreen({
    super.key,
    this.service,
    this.funcoesService,
    this.documentPicker,
    this.auth,
  });

  final CompletarCadastroService? service;
  final CadastroService? funcoesService;
  final Future<FotoUpload?> Function()? documentPicker;
  final AuthService? auth;

  @override
  State<CompletarCadastroScreen> createState() =>
      _CompletarCadastroScreenState();
}

enum _Fase { formulario, preview, concluido }

class _CompletarCadastroScreenState extends State<CompletarCadastroScreen> {
  late final CompletarCadastroService _service =
      widget.service ?? CompletarCadastroService();
  late final CadastroService _funcoesService =
      widget.funcoesService ?? CadastroService();
  late final AuthService _auth = widget.auth ?? AuthService();

  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  final _documento = TextEditingController();
  final _raio = TextEditingController();
  final _preco = TextEditingController();
  final _bio = TextEditingController();
  final _chavePix = TextEditingController();
  final _previewScroll = ScrollController();

  int _step = 0;
  _Fase _fase = _Fase.formulario;

  String _documentoTipo = 'CPF'; // CPF (PF) | CNPJ (MEI/PJ) — carregado no init
  List<Funcao> _funcoes = const [];
  final Set<int> _funcoesSel = {};
  FotoUpload? _documentoArquivo;
  String? _documentoError;

  // Preview / aceite
  String? _previewConteudo;
  bool _previewLido = false; // rolou até o fim (ou coube sem rolar)
  bool _aceiteMarcado = false;

  bool _carregandoPreview = false;
  bool _enviando = false;
  CadastroBanner? _banner;
  final Map<String, String> _serverErrors = {};

  bool get _ehPf => _documentoTipo == 'CPF';

  @override
  void initState() {
    super.initState();
    _carregarContexto();
  }

  Future<void> _carregarContexto() async {
    final tipo = await _service.fetchDocumentoTipo();
    final funcoes = await _funcoesService.fetchFuncoes();
    if (!mounted) return;
    setState(() {
      _documentoTipo = tipo;
      _funcoes = funcoes;
    });
  }

  @override
  void dispose() {
    for (final c in [_documento, _raio, _preco, _bio, _chavePix]) {
      c.dispose();
    }
    _previewScroll.dispose();
    super.dispose();
  }

  // ── Navegação entre passos ────────────────────────────────────────────────
  void _continuar() {
    final formOk = _formKeys[_step].currentState?.validate() ?? false;
    if (!formOk) return;

    if (_step == 2 && _documentoArquivo == null) {
      setState(() => _documentoError = 'Envie a foto do seu documento.');
      return;
    }

    if (_step < 2) {
      setState(() => _step++);
    } else {
      _abrirPreview();
    }
  }

  void _voltar() {
    if (_step > 0) setState(() => _step--);
  }

  CompletarCadastroDados _coletarDados() => CompletarCadastroDados(
    documento: _documento.text.trim(),
    raioMaxKm: _raio.text.trim(),
    precoHora: _preco.text.trim(),
    bio: _bio.text.trim(),
    chavePix: _chavePix.text.trim(),
    funcoesSecundarias: _funcoesSel.toList(),
  );

  // ── Preview do contrato (render server-side) ──────────────────────────────
  Future<void> _abrirPreview() async {
    setState(() {
      _carregandoPreview = true;
      _banner = null;
      _serverErrors.clear();
    });

    final result = await _service.preview(_coletarDados());
    if (!mounted) return;

    switch (result) {
      case PreviewSuccess(:final conteudo):
        setState(() {
          _previewConteudo = conteudo;
          _fase = _Fase.preview;
          _previewLido = false;
          _aceiteMarcado = false;
          _carregandoPreview = false;
        });
      case PreviewValidationError(:final errors):
        // Erro num campo de passo anterior — volta ao formulário e mostra.
        setState(() {
          _serverErrors.addAll(errors);
          _carregandoPreview = false;
        });
        for (final k in _formKeys) {
          k.currentState?.validate();
        }
      case PreviewServerError():
        setState(() {
          _banner = CadastroBanner.server();
          _carregandoPreview = false;
        });
    }
  }

  void _onPreviewScroll() {
    if (!_previewScroll.hasClients) return;
    final pos = _previewScroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 24 && !_previewLido) {
      setState(() => _previewLido = true);
    }
  }

  // ── Submit final (aceite) ─────────────────────────────────────────────────
  Future<void> _aceitar() async {
    if (!_previewLido || !_aceiteMarcado || _documentoArquivo == null) return;

    setState(() {
      _enviando = true;
      _banner = null;
    });

    final result = await _service.completar(
      _coletarDados(),
      _documentoArquivo!,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    switch (result) {
      case CompletarSuccess():
        await _auth.markCadastroCompleto();
        if (!mounted) return;
        setState(() => _fase = _Fase.concluido);
      case CompletarValidationError(:final errors):
        setState(() {
          _serverErrors.addAll(errors);
          _fase = _Fase.formulario;
          _step = 0;
        });
      case CompletarGenericError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
      case CompletarServerError():
        setState(() => _banner = CadastroBanner.server());
    }
  }

  Future<void> _pickDocumento() async {
    final picker = widget.documentPicker ?? _defaultPicker;
    FotoUpload? arquivo;
    try {
      arquivo = await picker();
    } catch (_) {
      return;
    }
    if (arquivo == null || !mounted) return;

    final lower = arquivo.filename.toLowerCase();
    final ok =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.pdf');
    if (!ok) {
      setState(() => _documentoError = 'Envie um arquivo JPG, PNG ou PDF.');
      return;
    }
    if (arquivo.bytes.length > 10 * 1024 * 1024) {
      setState(() => _documentoError = 'O arquivo deve ter no máximo 10 MB.');
      return;
    }
    setState(() {
      _documentoArquivo = arquivo;
      _documentoError = null;
    });
  }

  Future<FotoUpload?> _defaultPicker() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return FotoUpload(bytes: bytes, filename: file.name);
  }

  /// Seletor de funções secundárias com busca (bottom sheet). Mantém a tela limpa:
  /// a lista completa só aparece sob demanda; inline ficam apenas as escolhidas.
  Future<void> _abrirSeletorFuncoes(Color accent, bool isDark) async {
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            final filtradas = _funcoes
                .where(
                  (f) => f.nome.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return Padding(
              padding: EdgeInsets.only(
                left: TurniSpacing.lg,
                right: TurniSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Funções secundárias',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: TurniSpacing.sm),
                    TextField(
                      key: const Key('input-busca-funcoes'),
                      autofocus: false,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar função',
                      ),
                      onChanged: (v) => setSheet(() => query = v),
                    ),
                    const SizedBox(height: TurniSpacing.sm),
                    Expanded(
                      child: filtradas.isEmpty
                          ? const Center(
                              child: Text('Nenhuma função encontrada.'),
                            )
                          : ListView.builder(
                              itemCount: filtradas.length,
                              itemBuilder: (_, i) {
                                final f = filtradas[i];
                                final sel = _funcoesSel.contains(f.id);
                                return CheckboxListTile(
                                  key: Key('func-opt-${f.id}'),
                                  value: sel,
                                  activeColor: accent,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(f.nome),
                                  onChanged: (v) {
                                    setSheet(() {
                                      (v ?? false)
                                          ? _funcoesSel.add(f.id)
                                          : _funcoesSel.remove(f.id);
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('btn-concluir-funcoes'),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          _funcoesSel.isEmpty
                              ? 'Concluir'
                              : 'Concluir (${_funcoesSel.length})',
                        ),
                      ),
                    ),
                    const SizedBox(height: TurniSpacing.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) context.go('/login');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;

    return Scaffold(
      key: const Key('screen-completar-cadastro'),
      backgroundColor: surfacePage,
      body: SafeArea(
        child: switch (_fase) {
          _Fase.formulario => _buildFormulario(isDark, accent),
          _Fase.preview => _buildPreview(isDark, accent),
          _Fase.concluido => _buildConcluido(accent),
        },
      ),
    );
  }

  Widget _buildFormulario(bool isDark, Color accent) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: TurniSpacing.lg,
          vertical: TurniSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TURNI.',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 40,
                  color: TurniColors.brandGreen,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              Text(
                'Complete seu cadastro',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: TurniSpacing.xs),
              Text(
                'Faltam alguns dados para você começar a pegar turnos.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: TurniSpacing.md),
              Theme(
                // Acento do perfil no stepper.
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(
                    context,
                  ).colorScheme.copyWith(primary: accent),
                ),
                child: Stepper(
                  key: const Key('stepper-completar'),
                  currentStep: _step,
                  physics: const NeverScrollableScrollPhysics(),
                  onStepContinue: _continuar,
                  onStepCancel: _voltar,
                  controlsBuilder: (context, details) {
                    // O Stepper invoca o builder para cada passo; só renderiza os
                    // controles do passo atual (evita botões duplicados na árvore).
                    if (details.stepIndex != details.currentStep) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: TurniSpacing.lg),
                      // Wrap (não Row) para nunca estourar a largura quando o rótulo
                      // do CTA é longo em viewports estreitos.
                      child: Wrap(
                        spacing: TurniSpacing.sm,
                        runSpacing: TurniSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              key: const Key('btn-continuar'),
                              onPressed: _carregandoPreview
                                  ? null
                                  : details.onStepContinue,
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                shape: const StadiumBorder(),
                              ),
                              child: _carregandoPreview && _step == 2
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _step < 2
                                          ? 'Continuar'
                                          : 'Revisar e assinar o contrato',
                                    ),
                            ),
                          ),
                          if (_step > 0)
                            TextButton(
                              key: const Key('btn-voltar-passo'),
                              onPressed: details.onStepCancel,
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                              ),
                              child: const Text('Voltar'),
                            ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Identidade'),
                      isActive: _step >= 0,
                      state: _step > 0 ? StepState.complete : StepState.indexed,
                      content: _stepIdentidade(),
                    ),
                    Step(
                      title: const Text('Atuação'),
                      isActive: _step >= 1,
                      state: _step > 1 ? StepState.complete : StepState.indexed,
                      content: _stepAtuacao(accent, isDark),
                    ),
                    Step(
                      title: const Text('Financeiro'),
                      isActive: _step >= 2,
                      state: StepState.indexed,
                      content: _stepFinanceiro(accent, isDark),
                    ),
                  ],
                ),
              ),
              if (_banner != null) ...[
                const SizedBox(height: TurniSpacing.md),
                CadastroBannerWidget(
                  banner: _banner!,
                  isDark: isDark,
                  onLogin: () => context.go('/login'),
                  onRetry: _abrirPreview,
                ),
              ],
              const SizedBox(height: TurniSpacing.lg),
              const Center(
                child: AppVersionLabel(
                  key: Key('app-version-label-completar-cadastro'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIdentidade() => Form(
    key: _formKeys[0],
    child: CadastroTextField(
      fieldKey: 'input-documento',
      controller: _documento,
      label: _ehPf ? 'CPF' : 'CNPJ',
      hint: _ehPf ? '000.000.000-00' : '00.000.000/0000-00',
      helper: 'Só você e a equipe Turni veem esse dado.',
      keyboardType: TextInputType.number,
      validator: (v) {
        final t = (v ?? '').replaceAll(RegExp(r'\D'), '');
        if (t.isEmpty) return 'Informe seu ${_ehPf ? 'CPF' : 'CNPJ'}.';
        if (_ehPf && t.length != 11) return 'O CPF deve ter 11 dígitos.';
        if (!_ehPf && t.length != 14) return 'O CNPJ deve ter 14 dígitos.';
        return _serverErrors['documento'];
      },
    ),
  );

  Widget _stepAtuacao(Color accent, bool isDark) => Form(
    key: _formKeys[1],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_funcoes.isNotEmpty) ...[
          const CadastroSection('Funções secundárias (opcional)'),
          // Só as selecionadas aparecem inline (removíveis) — a lista completa fica
          // atrás de um seletor com busca (progressive disclosure: a tela não polui
          // mesmo com dezenas de funções).
          if (_funcoesSel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: TurniSpacing.xs),
              child: Wrap(
                key: const Key('chips-funcoes-secundarias'),
                spacing: TurniSpacing.sm,
                runSpacing: TurniSpacing.xs,
                children: _funcoes
                    .where((f) => _funcoesSel.contains(f.id))
                    .map(
                      (f) => InputChip(
                        label: Text(f.nome),
                        onDeleted: () =>
                            setState(() => _funcoesSel.remove(f.id)),
                        deleteIconColor: accent,
                        side: BorderSide(color: accent.withAlpha(90)),
                      ),
                    )
                    .toList(),
              ),
            ),
          OutlinedButton.icon(
            key: const Key('btn-add-funcoes'),
            onPressed: () => _abrirSeletorFuncoes(accent, isDark),
            icon: const Icon(Icons.add, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              shape: const StadiumBorder(),
            ),
            label: Text(
              _funcoesSel.isEmpty
                  ? 'Adicionar funções'
                  : 'Adicionar ou remover',
            ),
          ),
        ],
        CadastroTextField(
          fieldKey: 'input-raio',
          controller: _raio,
          label: 'Até quantos km você se desloca?',
          helper: 'Ex.: 30',
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Informe um número de km.';
            if (n < 1 || n > 500) return 'Informe um valor entre 1 e 500 km.';
            return _serverErrors['raio_max_km'];
          },
        ),
        CadastroTextField(
          fieldKey: 'input-preco-hora',
          controller: _preco,
          label: 'Seu preço por hora (R\$)',
          helper: 'Quanto você cobra por hora de trabalho.',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
            if (n == null) return 'Informe um valor por hora.';
            if (n < 1) return 'O valor deve ser maior que zero.';
            return _serverErrors['preco_hora'];
          },
        ),
        CadastroTextField(
          fieldKey: 'input-bio',
          controller: _bio,
          label: 'Conte rápido sua experiência (opcional)',
          helper: 'Até 500 caracteres.',
          validator: (v) => (v ?? '').length > 500
              ? 'A bio deve ter no máximo 500 caracteres.'
              : _serverErrors['bio'],
        ),
      ],
    ),
  );

  Widget _stepFinanceiro(Color accent, bool isDark) => Form(
    key: _formKeys[2],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CadastroTextField(
          fieldKey: 'input-chave-pix',
          controller: _chavePix,
          label: 'Sua chave Pix',
          helper: 'É nela que você recebe em até 15 min após cada turno.',
          validator: (v) => (v ?? '').trim().isEmpty
              ? 'Informe sua chave Pix.'
              : _serverErrors['chave_pix'],
        ),
        const CadastroSection('Documento comprobatório'),
        _uploadDocumento(accent, isDark),
        if (_documentoError != null) CadastroErrorText(_documentoError!),
      ],
    ),
  );

  Widget _uploadDocumento(Color accent, bool isDark) {
    final border = isDark
        ? TurniColors.borderSubtleDark
        : TurniColors.borderStrongLight;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final strong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;

    if (_documentoArquivo != null) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: accent),
          const SizedBox(width: TurniSpacing.sm),
          Expanded(
            child: Text(
              _documentoArquivo!.filename,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: strong),
            ),
          ),
          TextButton(
            key: const Key('btn-trocar-documento'),
            onPressed: _pickDocumento,
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Trocar'),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Enviar foto do documento',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('field-documento-upload'),
        onTap: _pickDocumento,
        borderRadius: const BorderRadius.all(TurniRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: _documentoError != null
                  ? (isDark ? TurniColors.errorDark : TurniColors.errorLight)
                  : border,
              width: 2,
            ),
            borderRadius: const BorderRadius.all(TurniRadius.lg),
          ),
          child: Row(
            children: [
              Icon(Icons.upload_file_outlined, color: accent),
              const SizedBox(width: TurniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto do seu documento',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: strong,
                      ),
                    ),
                    Text(
                      _ehPf
                          ? 'RG ou CNH — JPG, PNG ou PDF até 10 MB.'
                          : 'Cartão CNPJ ou CCMEI — JPG, PNG ou PDF até 10 MB.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista do preview do contrato + aceite ─────────────────────────────────
  Widget _buildPreview(bool isDark, Color accent) {
    final strong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final surfaceCard = isDark
        ? TurniColors.surfaceDark
        : TurniColors.surfaceLight;

    _previewScroll.removeListener(_onPreviewScroll);
    _previewScroll.addListener(_onPreviewScroll);
    // Se o conteúdo couber sem rolagem, libera o aceite assim que renderizar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_previewScroll.hasClients) return;
      if (_previewScroll.position.maxScrollExtent <= 0 && !_previewLido) {
        setState(() => _previewLido = true);
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TurniSpacing.md),
          child: Row(
            children: [
              IconButton(
                key: const Key('btn-fechar-preview'),
                tooltip: 'Voltar e editar',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _fase = _Fase.formulario),
              ),
              const SizedBox(width: TurniSpacing.xs),
              Expanded(
                child: Text(
                  'Contrato de adesão Turni',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: TurniSpacing.lg),
                padding: const EdgeInsets.all(TurniSpacing.lg),
                decoration: BoxDecoration(
                  color: surfaceCard,
                  borderRadius: const BorderRadius.all(TurniRadius.md),
                ),
                child: Semantics(
                  label: 'Contrato de adesão. Role para ler até o fim.',
                  child: Scrollbar(
                    controller: _previewScroll,
                    child: SingleChildScrollView(
                      key: const Key('contract-preview-body'),
                      controller: _previewScroll,
                      child: SelectableText(
                        _previewConteudo ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: strong,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _rodapeAceite(isDark, accent),
      ],
    );
  }

  Widget _rodapeAceite(bool isDark, Color accent) {
    final strong = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    final habilitado = _previewLido && _aceiteMarcado && !_enviando;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TurniSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? TurniColors.borderSubtleDark
                : TurniColors.borderStrongLight,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_previewLido)
              Padding(
                padding: const EdgeInsets.only(bottom: TurniSpacing.xs),
                child: Text(
                  'Role o contrato até o fim para habilitar o aceite.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: const Key('check-aceite'),
                  value: _aceiteMarcado,
                  activeColor: accent,
                  onChanged: _previewLido
                      ? (v) => setState(() => _aceiteMarcado = v ?? false)
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: TurniSpacing.sm),
                    child: Text(
                      'Li, entendi e aceito os termos do contrato.',
                      style: TextStyle(color: strong),
                    ),
                  ),
                ),
              ],
            ),
            if (_banner != null) ...[
              const SizedBox(height: TurniSpacing.sm),
              CadastroBannerWidget(
                banner: _banner!,
                isDark: isDark,
                onLogin: () => context.go('/login'),
                onRetry: _aceitar,
              ),
            ],
            const SizedBox(height: TurniSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('btn-aceito-concluir'),
                onPressed: habilitado ? _aceitar : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: const StadiumBorder(),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Aceito e concluir cadastro',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vista de conclusão ────────────────────────────────────────────────────
  Widget _buildConcluido(Color accent) {
    return Center(
      key: const Key('screen-cadastro-concluido'),
      child: Padding(
        padding: const EdgeInsets.all(TurniSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TURNI.',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 40,
                  color: TurniColors.brandGreen,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: TurniSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: accent,
                ),
              ),
              const SizedBox(height: TurniSpacing.md),
              Text(
                'Cadastro concluído. Bem-vindo ao Turni!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: TurniSpacing.sm),
              const Text(
                'Em breve você verá o feed de vagas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TurniSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const Key('btn-ir-para-app'),
                  onPressed: () => context.go('/'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Ir para o Turni'),
                ),
              ),
              const SizedBox(height: TurniSpacing.sm),
              TextButton(
                key: const Key('btn-logout'),
                onPressed: _logout,
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
