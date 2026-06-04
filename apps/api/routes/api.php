<?php

// Rotas da API (Sanctum SPA + sessão stateful — ADR-007 §b).
// auth.session: grupo com sessão para endpoints que precisam de Auth::login().
// auth.protected: requer sessão ativa + role check + funnel guard.

use App\Http\Controllers\AuthController;
use App\Http\Controllers\Avaliacao\AvaliacoesPendentesController;
use App\Http\Controllers\Cadastro\CompletarCadastroContratanteController;
use App\Http\Controllers\Cadastro\CompletarCadastroProfissionalController;
use App\Http\Controllers\Cadastro\ContratanteCadastroController;
use App\Http\Controllers\Cadastro\FuncaoController;
use App\Http\Controllers\Cadastro\ProfissionalCadastroController;
use App\Http\Controllers\Candidatura\CandidaturaController;
use App\Http\Controllers\Feed\FeedController;
use App\Http\Controllers\Feed\VagaDetalheController;
use App\Http\Controllers\Notificacao\NotificacaoController;
use App\Http\Controllers\Turno\CheckinGeoController;
use App\Http\Controllers\Turno\CronometroController;
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
    Route::get('/turnos/{turno}/cronometro', [CronometroController::class, 'show']);
    Route::post('/turnos/{turno}/checkin-geo', [CheckinGeoController::class, 'store']);
});
