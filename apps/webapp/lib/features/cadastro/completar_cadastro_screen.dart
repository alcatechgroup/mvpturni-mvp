import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/components/app_version_label.dart';
import '../../ds/components/contract_view.dart';
import '../../ds/tokens.dart';
import '../auth/auth_service.dart';
import 'cadastro_service.dart' show CadastroService, Funcao;
import 'completar_cadastro_service.dart';
import 'shared/cadastro_widgets.dart';
import 'shared/document_picker.dart';
import 'shared/input_formatters.dart';

/// Fase do fluxo de completar cadastro (STORY-023).
enum _Fase { form, preview, sucesso }

/// Seam de E2E (IDR-021/harness): o `file_picker` abre um diálogo nativo do SO que o
/// Chrome headless do `flutter drive` não consegue dirigir. Sob `--dart-define=E2E_FAKE_PICKER=true`
/// (só no gate E2E — nunca em build de produção), o picker padrão devolve um arquivo em memória.
const _e2eFakePicker = bool.fromEnvironment('E2E_FAKE_PICKER');

/// Tela de completar cadastro do profissional + aceite eletrônico (STORY-023).
///
/// Fluxo em duas fases (decisão técnica — alternativa ao wizard de 3 passos, dentro da
/// liberdade da estória): formulário único seccionado → revisão do contrato renderizado
/// com checkbox de consentimento explícito (CA-7/8). Só após ver o preview e marcar o
/// checkbox o botão "Aceito e concluir cadastro" habilita. O aceite é gerado no servidor
/// em transação atômica; a sessão vira `ativo` e o router leva à home.
class CompletarCadastroScreen extends StatefulWidget {
  const CompletarCadastroScreen({
    super.key,
    this.service,
    this.catalogo,
    this.documentPicker,
    this.auth,
  });

  final CompletarCadastroService? service;
  final CadastroService? catalogo;
  final Future<List<ArquivoUpload>?> Function()? documentPicker;
  final AuthService? auth;

  @override
  State<CompletarCadastroScreen> createState() =>
      _CompletarCadastroScreenState();
}

class _CompletarCadastroScreenState extends State<CompletarCadastroScreen> {
  late final CompletarCadastroService _service =
      widget.service ?? CompletarCadastroService();
  late final CadastroService _catalogo = widget.catalogo ?? CadastroService();
  late final AuthService _auth = widget.auth ?? AuthService();

  final _formKey = GlobalKey<FormState>();
  final _documento = TextEditingController();
  final _raio = TextEditingController();
  final _preco = TextEditingController();
  final _bio = TextEditingController();
  final _pix = TextEditingController();

  CompletarContexto? _contexto;
  List<Funcao> _funcoes = [];
  final Set<int> _funcoesSecundarias = {};
  List<ArquivoUpload> _documentos = [];

  _Fase _fase = _Fase.form;
  String _contrato = '';
  bool _aceitou = false;

  bool _loading = false;
  String? _docsError;
  CadastroBanner? _banner;
  final Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final contexto = await _service.fetchContexto();
    final funcoes = await _catalogo.fetchFuncoes();
    if (!mounted) return;
    setState(() {
      _contexto = contexto;
      _funcoes = funcoes;
    });
  }

  @override
  void dispose() {
    for (final c in [_documento, _raio, _preco, _bio, _pix]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _documentoTipo => _contexto?.documentoTipo ?? 'CPF';
  int get _documentoDigitos => _documentoTipo == 'CPF' ? 11 : 14;

  Future<void> _pickDocumentos() async {
    final picker = widget.documentPicker ?? _defaultDocumentPicker;
    List<ArquivoUpload>? arquivos;
    try {
      arquivos = await picker();
    } catch (_) {
      return;
    }
    if (arquivos == null || arquivos.isEmpty || !mounted) return;

    for (final a in arquivos) {
      final lower = a.filename.toLowerCase();
      final extOk =
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.pdf');
      if (!extOk) {
        setState(() => _docsError = 'Cada documento deve ser JPG, PNG ou PDF.');
        return;
      }
      if (a.bytes.length > 10 * 1024 * 1024) {
        setState(() => _docsError = 'Cada documento deve ter no máximo 10 MB.');
        return;
      }
    }
    setState(() {
      _documentos = arquivos!;
      _docsError = null;
    });
  }

  Future<List<ArquivoUpload>?> _defaultDocumentPicker() async {
    if (_e2eFakePicker) {
      return [
        ArquivoUpload(
          bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]),
          filename: 'documento-e2e.jpg',
        ),
      ];
    }
    return pickDocuments();
  }

  bool _validarExtras() {
    setState(() {
      _docsError = _documentos.isEmpty
          ? 'Envie ao menos um documento comprobatório.'
          : _docsError;
    });
    return _documentos.isNotEmpty && _docsError == null;
  }

  /// Fase 1 → 2: valida o formulário e busca o preview do contrato (CA-7).
  Future<void> _revisarContrato() async {
    _serverErrors.clear();
    final formOk = _formKey.currentState!.validate();
    final extrasOk = _validarExtras();
    if (!formOk || !extrasOk) return;

    setState(() {
      _loading = true;
      _banner = null;
    });

    final result = await _service.preview(_documento.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case PreviewSuccess(:final conteudo):
        setState(() {
          _contrato = conteudo;
          _aceitou = false;
          _fase = _Fase.preview;
        });
      case PreviewError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
    }
  }

  /// Fase 2: clique em "Aceito e concluir cadastro" — gera o aceite (CA-9/12).
  Future<void> _aceitar() async {
    setState(() {
      _loading = true;
      _banner = null;
    });

    final result = await _service.completar(
      documento: _documento.text.trim(),
      funcoesSecundarias: _funcoesSecundarias.toList(),
      raioMaxKm: int.tryParse(_raio.text.trim()) ?? 0,
      precoHora: moedaParaNumero(_preco.text).toStringAsFixed(2),
      bio: _bio.text.trim(),
      chavePix: _pix.text.trim(),
      documentos: _documentos,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case CadastroSuccess():
        await _auth.markCadastroCompleto();
        if (!mounted) return;
        setState(() => _fase = _Fase.sucesso);
      case CadastroValidationError(:final errors):
        setState(() {
          _serverErrors.addAll(errors);
          _fase = _Fase.form;
          if (errors.containsKey('documentos_comprobatorios') ||
              errors.keys.any(
                (k) => k.startsWith('documentos_comprobatorios'),
              )) {
            _docsError = 'Revise os documentos enviados.';
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _formKey.currentState?.validate();
        });
      case CadastroGenericError(:final message):
        setState(() => _banner = CadastroBanner.generic(message));
      case CadastroThrottle():
        setState(() => _banner = CadastroBanner.throttle());
      case CadastroServerError():
        setState(() => _banner = CadastroBanner.server());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? TurniColors.accentDark : TurniColors.accentLight;
    final surfacePage = isDark
        ? TurniColors.surfacePageDark
        : TurniColors.surfacePageLight;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    return Scaffold(
      key: const Key('completar-cadastro:screen'),
      backgroundColor: surfacePage,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: TurniSpacing.lg,
            vertical: isDesktop ? TurniSpacing.x3l : TurniSpacing.x2l,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 640 : 480),
            child: switch (_fase) {
              _Fase.form => _formView(isDark, isDesktop, accent),
              _Fase.preview => _previewView(isDark, accent),
              _Fase.sucesso => _sucessoView(accent),
            },
          ),
        ),
      ),
    );
  }

  Widget _formView(bool isDark, bool isDesktop, Color accent) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            'Complete seu cadastro',
            'Falta pouco para você começar a pegar turnos. Esses dados ficam protegidos.',
            isDark,
          ),
          _ProgressoFases(fase: _fase, accent: accent, isDark: isDark),

          CadastroSection('Seu documento ($_documentoTipo)'),
          CadastroTextField(
            fieldKey: 'completar-cadastro:documento',
            controller: _documento,
            label: _documentoTipo,
            hint: _documentoTipo == 'CPF'
                ? '000.000.000-00'
                : '00.000.000/0000-00',
            keyboardType: TextInputType.number,
            inputFormatters: [DocumentoInputFormatter(_documentoTipo)],
            helper: 'Usado no contrato. Fica criptografado.',
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return 'Informe seu $_documentoTipo.';
              if (digits.length != _documentoDigitos) {
                return 'Informe um $_documentoTipo válido com $_documentoDigitos dígitos.';
              }
              return _serverErrors['documento'];
            },
          ),

          const CadastroSection('Sua atuação'),
          _funcoesSecundariasField(isDark, accent),
          CadastroTextField(
            fieldKey: 'completar-cadastro:raio',
            controller: _raio,
            label: 'Raio máximo de deslocamento (km)',
            hint: 'Ex.: 15',
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 1) return 'Informe um raio em km (ex.: 15).';
              if (n > 500) return 'O raio máximo é 500 km.';
              return _serverErrors['raio_max_km'];
            },
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:preco',
            controller: _preco,
            label: 'Preço/hora pretendido (R\$)',
            hint: 'Ex.: R\$ 45,00',
            keyboardType: TextInputType.number,
            inputFormatters: [MoedaInputFormatter()],
            helper: 'Valor por hora que você pretende receber.',
            validator: (v) {
              if (moedaParaNumero(v ?? '') < 1) {
                return 'Informe um valor por hora (ex.: R\$ 45,00).';
              }
              return _serverErrors['preco_hora'];
            },
          ),
          CadastroTextField(
            fieldKey: 'completar-cadastro:bio',
            controller: _bio,
            label: 'Bio curta (opcional)',
            hint: 'Conte em 1-2 frases sua experiência.',
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').length > 500
                ? 'A bio deve ter no máximo 500 caracteres.'
                : _serverErrors['bio'],
          ),

          const CadastroSection('Recebimento'),
          CadastroTextField(
            fieldKey: 'completar-cadastro:pix',
            controller: _pix,
            label: 'Chave Pix',
            hint: 'CPF, CNPJ, e-mail, telefone (+55...) ou chave aleatória',
            helper: 'Você recebe por aqui, via Pix. Fica criptografada.',
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe sua chave Pix.'
                : _serverErrors['chave_pix'],
          ),

          const CadastroSection('Documento comprobatório'),
          _documentosField(isDark, accent, muted),

          const SizedBox(height: TurniSpacing.lg),
          _botao(
            key: 'completar-cadastro:revisar',
            label: 'Revisar contrato',
            onPressed: _loading ? null : _revisarContrato,
            accent: accent,
          ),

          if (_banner != null) ...[
            const SizedBox(height: TurniSpacing.md),
            CadastroBannerWidget(
              banner: _banner!,
              isDark: isDark,
              onLogin: () => context.go('/login'),
              onRetry: _revisarContrato,
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
    );
  }

  Widget _previewView(bool isDark, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          'Revise e aceite o contrato',
          'Leia o contrato com seus dados. Você só conclui o cadastro após aceitar.',
          isDark,
        ),
        _ProgressoFases(fase: _fase, accent: accent, isDark: isDark),
        const SizedBox(height: TurniSpacing.md),
        Container(
          key: const Key('completar-cadastro:contrato'),
          padding: const EdgeInsets.all(TurniSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? TurniColors.surfaceDark : TurniColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? TurniColors.borderSubtleDark
                  : TurniColors.borderSubtleLight,
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(child: ContractView(_contrato)),
        ),
        const SizedBox(height: TurniSpacing.md),
        _consentimento(isDark, accent),
        const SizedBox(height: TurniSpacing.md),
        _botao(
          key: 'completar-cadastro:concluir',
          label: 'Aceito e concluir cadastro',
          onPressed: (_aceitou && !_loading) ? _aceitar : null,
          accent: accent,
        ),
        const SizedBox(height: TurniSpacing.sm),
        Center(
          child: TextButton(
            key: const Key('completar-cadastro:voltar'),
            onPressed: _loading
                ? null
                : () => setState(() => _fase = _Fase.form),
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Voltar e editar os dados'),
          ),
        ),
        if (_banner != null) ...[
          const SizedBox(height: TurniSpacing.md),
          CadastroBannerWidget(
            banner: _banner!,
            isDark: isDark,
            onLogin: () => context.go('/login'),
            onRetry: _aceitar,
          ),
        ],
      ],
    );
  }

  Widget _sucessoView(Color accent) {
    return Column(
      key: const Key('completar-cadastro:sucesso'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: accent, size: 56),
        const SizedBox(height: TurniSpacing.md),
        Text(
          'Cadastro concluído!',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: TurniSpacing.sm),
        const Text(
          'Seu aceite foi registrado e você já está ativo na Turni. '
          'Em breve você terá o feed de vagas por aqui.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: TurniSpacing.xl),
        _botao(
          key: 'completar-cadastro:continuar',
          label: 'Continuar',
          onPressed: () => context.go('/'),
          accent: accent,
        ),
      ],
    );
  }

  /// Consentimento explícito do contrato (CA-8). Distinto do aceite de Termos/Política
  /// do pré-cadastro — aqui o usuário aceita o contrato renderizado exibido acima.
  Widget _consentimento(bool isDark, Color accent) {
    final textColor = isDark
        ? TurniColors.textStrongDark
        : TurniColors.textStrongLight;
    return InkWell(
      key: const Key('completar-cadastro:aceite'),
      onTap: () => setState(() => _aceitou = !_aceitou),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _aceitou,
            activeColor: accent,
            onChanged: (v) => setState(() => _aceitou = v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: TurniSpacing.sm),
              child: Text(
                'Li, entendi e aceito os termos do contrato apresentado acima.',
                style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String titulo, String subtitulo, bool isDark) {
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: TurniSpacing.xs),
        Text(subtitulo, style: TextStyle(fontSize: 14, color: muted)),
        const SizedBox(height: TurniSpacing.md),
      ],
    );
  }

  Widget _funcoesSecundariasField(bool isDark, Color accent) {
    final disponiveis = _funcoes
        .where((f) => f.id != _contexto?.funcaoId)
        .toList();
    if (disponiveis.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: TurniSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Funções secundárias (opcional)',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? TurniColors.textMutedDark
                  : TurniColors.textMutedLight,
            ),
          ),
          const SizedBox(height: TurniSpacing.xs),
          Wrap(
            spacing: TurniSpacing.xs,
            runSpacing: TurniSpacing.xs,
            children: disponiveis.map((f) {
              final sel = _funcoesSecundarias.contains(f.id);
              return FilterChip(
                key: Key('completar-cadastro:funcao-${f.id}'),
                label: Text(f.nome),
                selected: sel,
                selectedColor: accent.withValues(alpha: 0.18),
                checkmarkColor: accent,
                onSelected: (v) => setState(() {
                  if (v) {
                    _funcoesSecundarias.add(f.id);
                  } else {
                    _funcoesSecundarias.remove(f.id);
                  }
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _documentosField(bool isDark, Color accent, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _documentoTipo == 'CPF'
              ? 'Foto do seu documento (RG ou CNH). JPG, PNG ou PDF, até 10 MB.'
              : 'Cartão CNPJ ou CCMEI. JPG, PNG ou PDF, até 10 MB.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: TurniSpacing.sm),
        OutlinedButton.icon(
          key: const Key('completar-cadastro:anexar'),
          onPressed: _pickDocumentos,
          icon: const Icon(Icons.upload_file),
          label: Text(
            _documentos.isEmpty
                ? 'Anexar documento'
                : 'Trocar (${_documentos.length} anexado(s))',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent),
          ),
        ),
        if (_documentos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: TurniSpacing.xs),
            child: Text(
              _documentos.map((d) => d.filename).join(', '),
              key: const Key('completar-cadastro:documentos-lista'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        if (_docsError != null) CadastroErrorText(_docsError!),
      ],
    );
  }

  Widget _botao({
    required String key,
    required String label,
    required VoidCallback? onPressed,
    required Color accent,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: Key(key),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          shape: const StadiumBorder(),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Indicador discreto de progresso entre as duas fases (dados → contrato).
class _ProgressoFases extends StatelessWidget {
  const _ProgressoFases({
    required this.fase,
    required this.accent,
    required this.isDark,
  });

  final _Fase fase;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final passo = fase == _Fase.form ? 1 : 2;
    final muted = isDark
        ? TurniColors.textMutedDark
        : TurniColors.textMutedLight;
    return Semantics(
      label: 'Passo $passo de 2',
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: TurniSpacing.xs),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: passo >= 2 ? accent : muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: TurniSpacing.sm),
          Text('$passo/2', style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}
