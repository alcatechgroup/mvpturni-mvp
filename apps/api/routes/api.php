<?php

// Rotas da API (Sanctum SPA + sessão stateful — ADR-007 §b).
// auth.session: grupo com sessão para endpoints que precisam de Auth::login().
// auth.protected: requer sessão ativa + role check + funnel guard.

use App\Http\Controllers\AuthController;
use App\Http\Controllers\Avaliacao\AvaliacoesPendentesController;
use App\Http\Controllers\Avaliacao\AvaliarTurnoController;
use App\Http\Controllers\Avaliacao\PerfilReputacaoController;
use App\Http\Controllers\Cadastro\CompletarCadastroContratanteController;
use App\Http\Controllers\Cadastro\CompletarCadastroProfissionalController;
use App\Http\Controllers\Cadastro\ContratanteCadastroController;
use App\Http\Controllers\Cadastro\FuncaoController;
use App\Http\Controllers\Cadastro\ProfissionalCadastroController;
use App\Http\Controllers\Candidatura\AprovarCandidaturaController;
use App\Http\Controllers\Candidatura\CandidaturaController;
use App\Http\Controllers\Feed\FeedController;
use App\Http\Controllers\Feed\VagaDetalheController;
use App\Http\Controllers\Notificacao\NotificacaoController;
use App\Http\Controllers\Turno\CancelarTurnoController;
use App\Http\Controllers\Turno\CheckinGeoController;
use App\Http\Controllers\Turno\CronometroController;
use App\Http\Controllers\Turno\PinCheckinController;
use App\Http\Controllers\Turno\PinCheckoutController;
use App\Http\Controllers\Turno\TurnoAtivoController;
use App\Http\Controllers\Turno\TurnoDetalheController;
use App\Http\Controllers\Turno\TurnosController;
use App\Http\Controllers\Turno\ValidarCheckinController;
use App\Http\Controllers\Turno\ValidarCheckoutController;
use App\Http\Controllers\Usuario\WelcomeController;
use App\Http\Controllers\Vaga\CandidatosController;
use App\Http\Controllers\Vaga\VagaController;
use App\Http\Controllers\Webhook\PagarmeWebhookController;
use App\Http\Middleware\FunnelGuard;
use App\Http\Middleware\WebAppOnly;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

// Auth — sem sessão requerida para validação de credencial; com sessão para criar a sessão.
// StartSession é explícito aqui porque o grupo `api` não inclui sessão por padrão.
Route::middleware([StartSession::class])->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Pré-cadastro público de profissional (STORY-017). Pública (sem auth), mas dentro
    // do escopo stateful/CSRF do Sanctum — segue o padrão de submit da API (ADR-007).
    Route::post('/cadastro/profissional', [ProfissionalCadastroController::class, 'store']);

    // Pré-cadastro público de contratante (STORY-018). Mesmo padrão stateful/CSRF.
    Route::post('/cadastro/contratante', [ContratanteCadastroController::class, 'store']);
});

// Lista pública de funções para o select do pré-cadastro (STORY-017). GET sem estado.
Route::get('/funcoes', [FuncaoController::class, 'index']);

// Webhook entrante do Pagar.me (STORY-056 / ADR-016 CA-6). PÚBLICO — é o provedor que chama,
// não o WebApp: FORA de auth/sessão/CSRF/FunnelGuard. A autenticidade vem da assinatura HMAC
// validada no controller (401 se inválida); dedup por event_id; processamento async no worker.
Route::post('/webhooks/pagarme', PagarmeWebhookController::class);

// Welcome pós-aprovação (STORY-022). Protegida por sessão + WebApp-only, mas FORA do
// FunnelGuard: o usuário que marca welcome está em `await_welcome` (o guard o bloquearia
// com 423). Idempotente — ver WelcomeController.
Route::middleware(['auth:web', WebAppOnly::class, StartSession::class])->group(function () {
    Route::post('/usuarios/me/welcome-visto', [WelcomeController::class, 'markSeen']);

    // Completar cadastro do profissional (STORY-023). FORA do FunnelGuard: o usuário está
    // em `await_cadastro` (o guard o bloquearia com 423). O controller/Request garantem o
    // estado. preview = contrato renderizado; store = aceite imutável + transição → ativo.
    Route::get('/cadastro/profissional/completar/contexto', [CompletarCadastroProfissionalController::class, 'contexto']);
    Route::post('/cadastro/profissional/completar/preview', [CompletarCadastroProfissionalController::class, 'preview']);
    Route::post('/cadastro/profissional/completar', [CompletarCadastroProfissionalController::class, 'store']);

    // Completar cadastro do contratante (STORY-024). Mesmo padrão: FORA do FunnelGuard;
    // contexto + busca de CEP (fail-soft, IDR-024) + preview dos termos + aceite imutável.
    Route::get('/cadastro/contratante/completar/contexto', [CompletarCadastroContratanteController::class, 'contexto']);
    Route::get('/cadastro/contratante/completar/cep/{cep}', [CompletarCadastroContratanteController::class, 'cep']);
    Route::post('/cadastro/contratante/completar/preview', [CompletarCadastroContratanteController::class, 'preview']);
    Route::post('/cadastro/contratante/completar', [CompletarCadastroContratanteController::class, 'store']);
});

// Rotas protegidas — requerem sessão + WebApp-only + funnel guard
Route::middleware(['auth:web', WebAppOnly::class, FunnelGuard::class, StartSession::class])->group(function () {
    Route::get('/user', function () {
        $user = Auth::user();

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'status' => $user->status,
            'welcome_visto' => $user->welcome_seen_at !== null,
            'cadastro_completo' => $user->cadastro_completed_at !== null,
        ]);
    });

    // Publicar vaga (STORY-046). RBAC contratante no StoreVagaRequest::authorize() (403).
    Route::post('/vagas', [VagaController::class, 'store']);

    // Minhas vagas + cancelar (STORY-047). RBAC (papel contratante + dono) no controller.
    // GET lista as próprias (CA-1/CA-2); DELETE cancela via soft-transition (CA-4/CA-5).
    // `/vagas/minhas` antes de `/vagas/{vaga}` para não ser capturado como parâmetro.
    Route::get('/vagas/minhas', [VagaController::class, 'minhas']);
    Route::delete('/vagas/{vaga}', [VagaController::class, 'destroy']);

    // Edição material da vaga (STORY-052 / PDR-009). RBAC (papel contratante + dono) no controller.
    // GET /editar carrega os valores atuais + candidatos a notificar (CA-10); PATCH detecta edição
    // material, snapshota, transita candidaturas pendentes e devolve o diff (CA-1..CA-5). Vaga não
    // `aberta` → 409. `/editar` antes do PATCH `/{vaga}` por clareza (sufixo não conflita).
    Route::get('/vagas/{vaga}/editar', [VagaController::class, 'editar']);
    Route::patch('/vagas/{vaga}', [VagaController::class, 'update']);

    // Gate PDR-005 (STORY-046 CA-5): turnos finalizados pendentes de avaliação do
    // contratante. Contrato { pending, turnos }; stub-honesto até o EPIC-003.
    Route::get('/avaliacoes/pendentes-do-contratante', [AvaliacoesPendentesController::class, 'index']);

    // Feed ranqueado do profissional (STORY-048). RBAC profissional (403 p/ contratante) no
    // controller. ?filtro=todas|minha_funcao|alto_match|candidatadas&page=N. Visibilidade +
    // distância + match + ranqueamento + telemetria ficam no FeedQuery (ADR-013/ADR-014).
    Route::get('/feed', [FeedController::class, 'index']);

    // Detalhe da vaga + breakdown explicável (STORY-049). RBAC profissional (403 p/
    // contratante) no controller; 404 p/ vaga inexistente/encerrada/no passado. Reusa o
    // match do feed (ADR-014). Depois de `/vagas/minhas` e `/vagas/{vaga}` (DELETE) — GET
    // com sufixo /detalhe não conflita.
    Route::get('/vagas/{vaga}/detalhe', [VagaDetalheController::class, 'show']);

    // Candidatura em 1 toque + 3 gates (STORY-050). RBAC profissional (403 p/ contratante) no
    // controller; vaga inexistente → 404 (model binding). POST aplica gates server-side e cria
    // `pendente` (CA-1..CA-7). DELETE retira a própria candidatura `pendente` (CA-8).
    Route::post('/vagas/{vaga}/candidaturas', [CandidaturaController::class, 'store']);
    Route::delete('/candidaturas/{candidatura}', [CandidaturaController::class, 'destroy']);

    // Revisão da candidatura após edição material da vaga (STORY-052 CA-7/CA-8). RBAC profissional
    // dono no controller (404 esconde p/ terceiros). `confirmar` mantém (→pendente); `retirar`
    // sai (→retirada_por_edicao). Fora de `pendente_revisao_apos_edicao` → 409.
    Route::post('/candidaturas/{candidatura}/confirmar-apos-edicao', [CandidaturaController::class, 'confirmarAposEdicao']);
    Route::post('/candidaturas/{candidatura}/retirar-apos-edicao', [CandidaturaController::class, 'retirarAposEdicao']);

    // Painel de candidatos do contratante (STORY-051). RBAC contratante dono (403 p/ não-dono e
    // profissional) no controller; vaga inexistente → 404 (model binding). Lista os candidatos
    // `pendentes` ranqueados por score (snapshot persistido — não recalcula) com breakdown (CA-1..CA-9).
    Route::get('/vagas/{vaga}/candidatos', [CandidatosController::class, 'index']);

    // Aprovar candidatura → abrir o turno (STORY-058). RBAC contratante DONO no controller
    // (decisão PO 2026-06-04). Transação: habitualidade do aceite (PDR-002 sobre turnos) +
    // Turno `confirmado` + AceiteEletronicoTurno imutável + audit; pré-autorização assíncrona
    // pós-commit (PreAutorizarTurnoJob — ADR-016/PDR-017). `{ override: true }` p/ PJ na 3ª.
    Route::post('/candidaturas/{candidatura}/aprovar', AprovarCandidaturaController::class);

    // Caixa de notificações in-app (STORY-053 CA-7). Qualquer papel ativo lê as PRÓPRIAS
    // (RBAC por destinatario_id no controller; 404 p/ terceiros). `marcar-todas-lidas` (path
    // estático) antes de `{notificacao}/marcar-lida` por clareza — paths distintos não conflitam.
    Route::get('/notificacoes', [NotificacaoController::class, 'index']);
    Route::post('/notificacoes/marcar-todas-lidas', [NotificacaoController::class, 'marcarTodasLidas']);
    Route::post('/notificacoes/{notificacao}/marcar-lida', [NotificacaoController::class, 'marcarLida']);

    // Cronômetro bilateral + geofencing de check-in (STORY-057 / ADR-017 — PoC do spike).
    // (a) Âncora do cronômetro: GET devolve iniciado_em (check_in_at) + servidor_agora; o cliente
    //     tica local e faz polling curto. Servidor é a fonte de verdade do tempo (CA-4). RBAC: só
    //     os dois lados do turno (404 p/ terceiros).
    // (b) Geofencing de check-in: POST recebe a posição do navegador e calcula a distância em
    //     metros via Haversine (reuso STORY-049). RBAC: só o profissional do turno.
    // Atalho de navegação: turno ativo do usuário (path estático antes de `{turno}` por clareza).
    Route::get('/turnos/meu-ativo', [TurnoAtivoController::class, 'show']);

    // Listas de turnos por papel (STORY-059). Agrupadas por estado na ordem do ciclo de vida
    // (SCREEN-059 §4.1; em_disputa é seção própria — decisão PO 2026-06-05). RBAC fail-secure
    // no controller: 403 para o papel errado (CA-5). Profissional vê `valor`; contratante vê
    // `total_contratante` (PDR-004).
    Route::get('/profissional/turnos', [TurnosController::class, 'doProfissional']);
    Route::get('/contratante/turnos', [TurnosController::class, 'doContratante']);
    Route::get('/turnos/{turno}/cronometro', [CronometroController::class, 'show']);
    Route::post('/turnos/{turno}/checkin-geo', [CheckinGeoController::class, 'store']);

    // PIN de check-in (STORY-061 / PDR-008) — geração pelo profissional dentro da janela
    // (config/turno.php) com captura de geofencing (alerta-e-registra, nunca bloqueia);
    // cancelamento volta a `confirmado`. RBAC: só o profissional do turno (403 — CA-8).
    Route::post('/turnos/{turno}/gerar-pin-checkin', [PinCheckinController::class, 'gerar']);
    Route::post('/turnos/{turno}/cancelar-pin-checkin', [PinCheckinController::class, 'cancelar']);

    // Validação do PIN pelo contratante (STORY-062) — PIN correto transita para `ativo`
    // (evento TurnoIniciado → 063/067); 3 erros expiram o PIN (volta a `confirmado`);
    // recusa com motivo opcional. Rate limit 5/60s por turno no controller (CA-2).
    // RBAC: só o contratante do turno (403 — CA-1).
    Route::post('/turnos/{turno}/validar-checkin', [ValidarCheckinController::class, 'validar']);
    Route::post('/turnos/{turno}/recusar-checkin', [ValidarCheckinController::class, 'recusar']);

    // PIN de check-out (STORY-064) — espelho da dupla 061/062 com origem em `ativo`:
    // geração SEM janela horária (CA-1; geofencing opcional e silencioso — CA-2);
    // validação transita para `finalizado` + evento TurnoFinalizado (065/067 — CA-3);
    // 3 erros expiram o PIN e recusa/cancelamento devolvem a `ativo` (CA-4/CA-5 —
    // NUNCA `em_disputa`, que é EPIC-005). RBAC espelhado: gerar/cancelar só o
    // profissional (403); validar/recusar só o contratante (403).
    Route::post('/turnos/{turno}/gerar-pin-checkout', [PinCheckoutController::class, 'gerar']);
    Route::post('/turnos/{turno}/cancelar-pin-checkout', [PinCheckoutController::class, 'cancelar']);
    Route::post('/turnos/{turno}/validar-checkout', [ValidarCheckoutController::class, 'validar']);
    Route::post('/turnos/{turno}/recusar-checkout', [ValidarCheckoutController::class, 'recusar']);

    // Cancelamento antes do check-in (STORY-066 CA-2, PDR-007) — rota compartilhada pelos
    // 2 papéis; RBAC no controller decide o lado (cancelado_pro|cancelado_emp); 422 fora
    // de `confirmado`; libera a pré-autorização via ACL pós-commit (CA-2/CA-3).
    Route::post('/turnos/{turno}/cancelar', [CancelarTurnoController::class, 'cancelar']);

    // Detalhe do turno (STORY-060) — rota compartilhada pelos 2 papéis (RBAC no controller:
    // cruzados 403, CA-1). Atributos + valor por papel (CA-2) + timeline filtrada (CA-3) +
    // aceite eletrônico inline para o modal somente-leitura (CA-5). Registrada DEPOIS de
    // `/turnos/meu-ativo` (path estático vence o binding `{turno}`).
    Route::get('/turnos/{turno}', [TurnoDetalheController::class, 'show']);

    // Avaliação recíproca do turno (STORY-085 / ADR-019 — CA-3). Rota compartilhada pelos 2
    // papéis: a direção e o avaliado derivam do papel do AUTOR no turno (RBAC fail-secure no
    // service — não-participante → 403). Estrelas obrigatórias 1–5 + comentário opcional;
    // estado não-avaliável → 422; reenvio na mesma direção → 409. Insere + dispara
    // AvaliacaoRegistrada na transação (motor de reputação síncrono).
    Route::post('/turnos/{turno}/avaliar', [AvaliarTurnoController::class, 'store']);

    // Perfil de reputação (STORY-085 / ADR-019 + DDR-004 — CA-6). Score (1 casa) + nível +
    // turnos + depoimentos (comentário não-vazio, mais recentes 1º) de qualquer usuário ativo;
    // o XP atual + XP até o próximo nível só aparecem para o próprio dono (visibilidade). A
    // assimetria LGPD dos depoimentos (autor anônimo sobre o contratante) vive na Query.
    Route::get('/perfil/{user}', [PerfilReputacaoController::class, 'show']);
});
