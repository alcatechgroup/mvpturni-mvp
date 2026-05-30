---
id: SCREEN-STORY-021-emails-transacionais
story: STORY-021-emails-transacionais
epic: EPIC-001-cadastro-e-aprovacao
status: ready
created_at: 2026-05-30
updated_at: 2026-05-30
owner_designer: Designer (claude-opus-4-8)
related_ddrs: [DDR-001]
related_adrs: [ADR-011]
ds_components_used: [brand.logo, button.primary, link.text, divider, footer.legal]
exceptions_to_ds: [HTML de e-mail por tabelas inline (clients legados não suportam flexbox/grid nem <style> externo confiável) — não é tela do produto, é artefato de e-mail; sem componente novo do DS; tokens DDR-001 aplicados como literais inline já que e-mail não carrega tokens.dart/CSS-vars]
viewports: [email-desktop (600px), email-mobile (≤480px), text-plain]
prototype_path: SCREEN-STORY-021-emails-transacionais/index.html
prototype_last_validated_at: 2026-05-30
---

# Spec de tela — E-mails transacionais (3 mensagens canônicas)

> Referência: estória `STORY-021-emails-transacionais`. CAs e contexto vêm de lá — **não duplico**.
> Contrato fixado por decisão: **ADR-011 §d** fixa remetente, assunto e contrato de `dados` de cada mensagem — **não reabro**. Este spec entrega o **conteúdo textual final** e a **identidade visual** (responsabilidade que ADR-011 §d delega ao Designer).
> Fundação visual: `DDR-001` + `docs/project-state/design/system/` (tokens, voice-and-tone).
> Princípios que guiaram: **#1** simplicidade (uma mensagem, uma ação), **#3** tom profissional (notificação sistêmica sóbria, não marketing), **#5** acessibilidade (semântica, alt, contraste AA, text/plain de paridade), **#7** todos os estados (variações de dado: nome ausente → fallback).

---

## Nota de plataforma (≠ resto do produto)

Estes artefatos **não são telas Flutter nem Blade do produto** — são **e-mails HTML** renderizados por clients heterogêneos (Gmail web/app, Apple Mail, Outlook, webmails BR como UOL/Globo). Por isso o spec foge de duas convenções do DS, deliberadamente:

1. **Layout por `<table>` com atributos e estilo inline**, não flexbox/grid. Clients legados (Outlook/Word engine) ignoram CSS moderno; tabela é o único layout confiável universalmente.
2. **Tokens DDR-001 entram como literais inline** (`#2D5F3F`, `#F7F4EC`…), não como CSS-vars ou `tokens.dart` — e-mail não tem runtime de tokens. Os valores são os **mesmos** da fundação; a tabela §3 mapeia token → literal para rastreabilidade.

Identificadores estáveis (§7) são marcações para o teste de renderização do Mailable (Pest), não `data-testid` de browser.

## 1. Objetivo

Entregar as **3 mensagens canônicas do MVP** (ADR-011 §d) com identidade Turni e tom correto, cada uma com **versão HTML** (identidade DDR-001) e **versão text/plain** de paridade (acessibilidade + clients antigos + CA-10/CA-11):

| `tipo` (TipoEmail) | Quando | Ação única do usuário |
|---|---|---|
| `aprovacao_concedida` | admin aprova o cadastro (STORY-019) | "Acessar o Turni" → login |
| `lembrete_completar_cadastro` | job 48h/5d/14d sem completar cadastro | "Completar cadastro" → login |
| `recuperacao_senha` | usuário pede "Esqueci minha senha" no `/login` | "Redefinir senha" → link assinado |

Cada e-mail é **uma coluna, uma mensagem, um CTA primário**. Sem navegação, sem múltiplas ações concorrentes — disciplina de e-mail transacional.

## 2. Decisão de tema e perfil

- **Esquema neutro = `profissional` (verde)** para os três e-mails. Justificativa DDR-001 §1: e-mail transacional é **pré-perfil** (o destinatário pode ser profissional **ou** contratante, e no reset pode nem ter sessão). Igual ao login do protótipo: a **marca conduz**, o **verde** é o acento interativo. Não pinto o e-mail pelo papel do destinatário — manteria dois templates por mensagem sem ganho real e quebraria a sobriedade.
- **Marca:** `brand.green #00A868` **apenas** na logomarca textual `TURNI.` no topo. **Nunca** como cor de CTA ou texto (reprova AA — DDR-001 §2.1).
- **CTA:** fundo `accent` profissional `#2D5F3F`, texto branco (`on-accent`) — **7.4:1**, passa AA.
- **Tema claro apenas.** E-mail HTML não tem toggle confiável; o MVP liga só o claro (PDR-013). Incluo um bloco `@media (prefers-color-scheme: dark)` **opcional e degradável** (clients que respeitam ganham fundo escuro; os que ignoram ficam no claro — sem regressão). Contrastes do dark em §6.

## 3. Tokens → literais inline (rastreabilidade DDR-001)

| Papel no e-mail | Token DDR-001 | Literal (claro) | Literal (dark opcional) |
|---|---|---|---|
| Fundo externo (body) | `surface.page` | `#F7F4EC` | `#0F1411` |
| Card/conteúdo | `surface` | `#FFFFFF` | `#1A2018` |
| Borda do card / divisor | `border.subtle` | `#E0DDD3` | `#2A322D` |
| Texto título/primário | `text.strong` | `#0F1B2D` | `#ECEDE5` |
| Texto corpo/secundário | `text.muted` | `#42504A` | `#A8B2A8` |
| Marca `TURNI.` | `brand.green` | `#00A868` | `#00A868` |
| CTA fundo | `accent` (profissional) | `#2D5F3F` | `#5FA37C` |
| CTA texto | `on-accent` | `#FFFFFF` | `#0F1411` |
| Banner sucesso (soft) | `success.soft` | `#E2F0E5` | `rgba(95,163,124,.14)` |
| Texto de aviso de segurança | `text.muted` | `#42504A` | `#A8B2A8` |

Tipografia: **Inter** com fallback `-apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif` (e-mail não embute webfont com segurança; Inter degrada para sans-serif do sistema). Marca `TURNI.` usa Bebas Neue **com fallback** para sans-serif bold + `letter-spacing` — a fonte de marca não embute em e-mail; o fallback preserva o wordmark sem quebrar identidade.

## 4. Anatomia comum (todos os 3 e-mails)

```
┌───────────────────────────────────────── body bg #F7F4EC ──┐
│                  (padding 24px)                              │
│   ┌──────────────── card #FFFFFF, max-width 600px ───────┐  │
│   │  [ TURNI. ]            ← logo wordmark, brand.green   │  │
│   │  ──────────────────────────────────────────────────  │  │
│   │  H1  título da mensagem (text.strong, 24/28)         │  │
│   │                                                       │  │
│   │  parágrafo de corpo (text.muted, 16/24)              │  │
│   │  [ opcional: banner soft ou linha de dado ]          │  │
│   │                                                       │  │
│   │        ┌──────────────────────────┐                  │  │
│   │        │   CTA primário (accent)  │  ← botão tabela  │  │
│   │        └──────────────────────────┘                  │  │
│   │                                                       │  │
│   │  fallback do link em texto (para quem não clica)     │  │
│   │  ──────────────────────────────────────────────────  │  │
│   │  rodapé: o que é este e-mail · contato · privacidade │  │
│   └───────────────────────────────────────────────────────┘ │
│   Turni · pré-aviso anti-phishing curto (fora do card)      │
└──────────────────────────────────────────────────────────────┘
```

- **Largura:** card `max-width: 600px` (padrão de e-mail), fluido abaixo disso (mobile).
- **Logo:** wordmark **textual** `TURNI.` (não imagem) — evita "imagens bloqueadas" derrubarem a identidade; se virar imagem no futuro, exige `alt="Turni"`.
- **CTA como botão-tabela** (`<table>` com `bgcolor` + padding), não `<a>` estilizado puro — renderiza em Outlook.
- **Fallback de link textual** abaixo do CTA: a URL crua, para quem usa client que não renderiza o botão ou leitor de tela (CA-11).
- **Rodapé legal:** 1 linha do que é o e-mail + contato (`contato@turni.com.br`) + link "Política de privacidade". Lembrete e aprovação são **comunicação operacional** (não marketing) — sem link de "descadastrar" (não se aplica a transacional; LGPD §comunicação necessária, story §LGPD).

## 5. Microcopy completo (tabela única — pt-BR, fonte de verdade)

> Placeholders nomeados `{nome}`, `{horas_pendente}`, `{expiracao_minutos}`, `{link_*}` (hábito pró-i18n, voice-and-tone). `{nome}` pode vir vazio → usar fallback. Todas as URLs vêm do contrato `dados` de ADR-011 §d.

### 5.1 `aprovacao_concedida` — assunto: **"Seu cadastro foi aprovado — acesse o Turni"** _(fixado ADR-011 §d)_

| Slot | Copy |
|---|---|
| Preheader (oculto) | `Seu cadastro foi aprovado. Acesse para finalizar e começar a usar o Turni.` |
| H1 | `Cadastro aprovado` |
| Saudação | `Olá, {nome}.` _(fallback sem nome: `Olá.`)_ |
| Corpo 1 | `Seu cadastro no Turni foi aprovado. Você já pode acessar a plataforma.` |
| Corpo 2 | `O próximo passo é completar seu cadastro — leva poucos minutos e libera o uso completo.` |
| CTA | `Acessar o Turni` → `{link_acesso}` |
| Fallback link | `Se o botão não funcionar, copie e cole este endereço no navegador: {link_acesso}` |
| Rodapé | `Você recebeu este e-mail porque seu cadastro no Turni foi aprovado. Dúvidas: contato@turni.com.br · Política de privacidade.` |

### 5.2 `lembrete_completar_cadastro` — assunto: **"Complete seu cadastro no Turni"** _(fixado ADR-011 §d)_

| Slot | Copy |
|---|---|
| Preheader (oculto) | `Falta completar seu cadastro para começar a usar o Turni.` |
| H1 | `Falta completar seu cadastro` |
| Saudação | `Olá, {nome}.` _(fallback: `Olá.`)_ |
| Corpo 1 | `Seu cadastro no Turni está aprovado, mas ainda não foi finalizado.` |
| Corpo 2 | `Quando você completar, poderá usar a plataforma por inteiro. Leva poucos minutos.` |
| CTA | `Completar cadastro` → `{link_completar}` |
| Fallback link | `Se o botão não funcionar, copie e cole este endereço no navegador: {link_completar}` |
| Rodapé | `Você recebeu este lembrete porque seu cadastro no Turni ainda não foi concluído. Se não quiser concluir agora, é só ignorar. Dúvidas: contato@turni.com.br · Política de privacidade.` |

> **Tom (voice-and-tone):** calmo, sem chantagem nem urgência fabricada (story §2). Sem "última chance", sem contagem regressiva. `{horas_pendente}` do contrato **não** é exibido como número no corpo (soaria como cobrança) — fica disponível ao código para decisão de envio, não para o texto. Decisão de design registrada.

### 5.3 `recuperacao_senha` — assunto: **"Redefina sua senha no Turni"** _(fixado ADR-011 §d)_

| Slot | Copy |
|---|---|
| Preheader (oculto) | `Recebemos um pedido para redefinir sua senha no Turni.` |
| H1 | `Redefinir senha` |
| Saudação | `Olá, {nome}.` _(fallback: `Olá.`)_ |
| Corpo 1 | `Recebemos um pedido para redefinir a senha da sua conta no Turni.` |
| Corpo 2 | `Este link expira em {expiracao_minutos} minutos e só pode ser usado uma vez.` |
| CTA | `Redefinir senha` → `{link_redefinicao}` |
| Fallback link | `Se o botão não funcionar, copie e cole este endereço no navegador: {link_redefinicao}` |
| Aviso de segurança | `Se você não pediu para redefinir sua senha, ignore este e-mail — sua senha continua a mesma.` |
| Rodapé | `Por segurança, o Turni nunca pede sua senha por e-mail. Dúvidas: contato@turni.com.br · Política de privacidade.` |

## 6. Acessibilidade (WCAG 2.1 AA — CA-11)

- **Semântica:** um `<h1>` por e-mail (o título da mensagem); corpo em `<p>`. Ordem de leitura linear bate com a ordem visual.
- **Idioma:** `<html lang="pt-BR">`.
- **Contraste (claro):** texto título `#0F1B2D` sobre `#FFFFFF` = 16:1; corpo `#42504A` sobre `#FFFFFF` = 8.9:1; CTA branco sobre `#2D5F3F` = 7.4:1 — todos ≥ 4.5:1.
- **Contraste (dark opcional):** título `#ECEDE5`/`#1A2018` ≈ 13:1; corpo `#A8B2A8`/`#1A2018` ≈ 6.5:1; CTA `#0F1411`/`#5FA37C` ≈ 8:1 — todos AA.
- **Não depende de cor:** o CTA tem rótulo textual explícito e o link aparece também como texto cru (fallback). Banner de sucesso usa texto + (se ícone) `alt`, nunca só cor.
- **Imagens:** o wordmark é texto; se algum dia virar `<img>`, exige `alt="Turni"`. Nenhuma imagem decorativa essencial.
- **text/plain de paridade (CA-10):** cada e-mail tem versão `.text.blade.php` com o **mesmo conteúdo** (saudação, corpo, CTA como URL crua rotulada, aviso, rodapé) — leitor de tela e clients sem HTML recebem a mensagem completa. Multipart/alternative.
- **Alvo de toque:** CTA com `padding` ≥ 12px vertical / 24px horizontal (altura de toque ≥ 44px no mobile).

## 7. Identificadores estáveis (teste de renderização — Pest)

O teste do Mailable (`assertSeeInHtml` / `assertSeeInText` ou render + asserts) verifica presença de:

| Marcação | Onde | Verifica |
|---|---|---|
| H1 textual de cada tipo | HTML + text | título correto por `tipo` |
| `{nome}` renderizado (ou fallback `Olá.`) | HTML + text | personalização + borda de nome vazio |
| URL do CTA (`link_*` do contrato) | HTML (`href`) + text (cru) | link correto e presente em ambos formatos |
| Assunto (`Subject`) | envelope | bate com ADR-011 §d por `tipo` |
| Remetente `no-reply@mail.turni.com.br` | envelope `from` | ADR-011 §d |
| `{expiracao_minutos}` (só recuperacao) | HTML + text | TTL comunicado |
| Ausência de endereço de e-mail do destinatário em log | log estruturado | mascaramento (CA-9) — testado no adapter, não aqui |

## 8. Exceções ao Design System

1. **Layout por tabela inline + literais de cor inline** — justificado na §Nota de plataforma (e-mail ≠ tela). Não cria padrão para o produto; é convenção universal de e-mail HTML. **Não** vira DDR.
2. **Fonte de marca com fallback sans-serif** — Bebas Neue não embute em e-mail; o wordmark degrada para sans-serif bold + tracking. Aceito (a marca aparece pequena, no topo).
3. **Bloco `prefers-color-scheme: dark` opcional** — não é "ligar o dark no MVP"; é degradação graciosa para clients que já forçam dark. Sem ele, e-mail claro fica ilegível em alguns clients que invertem cores automaticamente. Decisão de robustez, não de escopo.

## 9. Protótipo HTML fiel (validação humana)

`SCREEN-STORY-021-emails-transacionais/index.html` — renderiza os **3 e-mails** empilhados (cada um no seu card 600px), no claro, fiéis aos literais da §3 e ao microcopy da §5, para o Alexandro abrir no browser e validar identidade + tom antes de virar Blade. O HTML do protótipo é a **referência** que o programador transcreve para os `*.blade.php` (com os placeholders trocados por variáveis).

### Checklist antes de `ready`

- [x] Copy em tabela única (§5).
- [x] Sem emoji, sem exclamação fabricada, sem gíria.
- [x] Reset/segurança tem "o que aconteceu" + "o que fazer" (ignore se não pediu).
- [x] Vocabulário bate com o glossário (`Cadastro`, `Turni`, `senha`).
- [x] Acentuação correta.
- [x] CTA primário = verbo infinitivo + objeto ("Acessar o Turni", "Completar cadastro", "Redefinir senha").
- [x] Sem jargão técnico exposto (sem "token", "signed URL", "TTL" no corpo — vira "link expira em N minutos").
- [x] Contraste AA verificado nos dois temas (§6).
- [x] text/plain de paridade especificado (CA-10/CA-11).
- [x] Assuntos e remetente conferem com ADR-011 §d (não reabertos).

## 10. Dependências e premissas

- **ADR-011 §d** fixa remetente/assunto/contrato de `dados`. Este spec não os altera.
- O CTA de `aprovacao_concedida` e de `lembrete_completar_cadastro` aponta para `{link_acesso}`/`{link_completar}` = URL pública de login do WebApp (sem login automático — story §1, decisão de segurança). Coordenação com **STORY-022** (welcome): após login bem-sucedido o usuário é levado a `/welcome` / completar cadastro; o e-mail só leva ao login.
- `recuperacao_senha`: `{link_redefinicao}` é o link assinado do Fortify (TTL 60 min — ADR-007 §f). O Designer não define o mecanismo do link, só sua apresentação.
- Renderização real (Blade + Mailpit) e entrega (Resend homolog) são do Programador.

## 11. Histórico de mudanças

- 2026-05-30 — criado e marcado `ready` por Designer (claude-opus-4-8) na abertura da STORY-021 (sessão dupla Designer+Programador). Conteúdo textual final das 3 mensagens + identidade DDR-001 (esquema neutro/profissional) + paridade text/plain + acessibilidade AA. Sync com o Programador registrado nas "Notas do agente" da estória.
