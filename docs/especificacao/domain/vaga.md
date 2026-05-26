# Domínio · Vaga

Decisão de referência: **PDR-009** (edição pós-candidatura).

## O que é

Vaga é a oferta publicada pelo contratante. Cada vaga descreve **um ou mais turnos idênticos** que precisam ser preenchidos: mesma função, mesma data/hora, mesmo valor, mesmo estabelecimento.

Quando uma vaga tem `vagas > 1` (múltiplas posições), cada aprovação de candidato consome uma posição. Quando todas são preenchidas, a vaga fecha automaticamente.

## Atributos

Obrigatórios:

- `estabelecimento` — referência ao contratante dono da vaga.
- `funcao` — função pretendida (Garçom, Cozinheira, Bartender, Pizzaiolo, etc.). Deve estar na lista canônica do Core FHP.
- `data_inicio` — data e hora de início do turno.
- `data_fim` — data e hora de fim previsto.
- `valor` — valor que o profissional recebe por turno (R$).
- `posicoes` — número de profissionais a contratar (1+).

Opcionais:

- `valor_hora` — valor/hora derivado, exibido para fins de comparação.
- `observacoes` — texto livre do contratante (briefing curto, instruções, dress code, particularidades).
- `tags` — atributos extras (turno noturno, evento corporativo, etc.) — futuro.

## Estados

| Estado | Significa |
|---|---|
| `aberta` | Aceita candidaturas. |
| `fechada` | Todas as posições preenchidas. Não aceita novas candidaturas. |
| `cancelada` | Contratante cancelou a vaga antes ou durante o período de candidaturas. |

Transições:

- `aberta → fechada`: automática quando a última posição é preenchida.
- `aberta → cancelada`: explícita pelo contratante. Candidatos pendentes são notificados.
- `fechada → cancelada`: não permitido. Para cancelar turnos já confirmados, opera-se sobre cada turno individualmente (ver `domain/turno.md`).

## Publicação

- Contratante deve estar `ativo` (passou pelo funil de aprovação).
- Contratante não pode publicar vaga se tiver turnos finalizados pendentes de avaliação (PDR-005).
- A vaga pode ser publicada para data futura próxima (sem prazo mínimo no MVP). A urgência influencia o feed e o SLA de match.
- Não há limite numérico de vagas abertas simultâneas no MVP (Member Start, Member e Enterprise têm publicação ilimitada).

## Edição pós-candidatura (PDR-009)

Após uma vaga receber a primeira candidatura, ela continua editável. A edição classifica-se em:

**Edição material** (notifica candidatos):
- Função.
- Data de início ou fim.
- Valor.
- Número de posições.
- Localização do estabelecimento (caso aplicável).
- Observações.

**Edição não material** (sem notificação):
- Correções de ortografia ou formatação.

Quando há edição material:

1. A vaga registra a versão original e a nova versão (snapshot).
2. Todos os candidatos pendentes são notificados com diff antes/depois.
3. Cada candidatura entra em estado `pendente_revisao_apos_edicao` e o profissional tem 24h ou até o início do turno (o que ocorrer antes) para confirmar a manutenção.
4. Sem confirmação no prazo, a candidatura é retirada automaticamente.

## Duplicação

O contratante pode duplicar uma vaga existente para criar nova vaga com os mesmos parâmetros (apenas data/hora muda). Cada duplicação gera uma vaga nova e independente (não há ligação histórica obrigatória).

## Cancelamento

- Antes de qualquer candidatura: cancelamento direto, sem impacto.
- Com candidatos pendentes: contratante confirma; candidatos são notificados. A vaga vai para `cancelada` e não retorna.
- Após aprovação de candidato (turno criado em `confirmado`): cancelar a vaga **não cancela o turno** — turno tem seu próprio fluxo de cancelamento (ver `domain/turno.md`).

## Visibilidade

Profissional vê vagas que:

- Estão `aberta`.
- A função primária ou secundária do profissional bate (filtro padrão; pode ampliar manualmente).
- Estão dentro do raio máximo declarado pelo profissional.
- A data/hora ainda não passou.

Filtros do feed:

- "Todas" (todas as vagas que atendem os critérios).
- "Minha função" (apenas função primária).
- "Alto match (80%+)" — filtro pelo score do match (ver `domain/match.md`).
- "Candidatadas" — vagas em que já enviou candidatura.

## Lacunas conhecidas

- Política de visibilidade para profissionais Iniciante vs. Elite — hoje todos veem o mesmo feed; futuro pode segmentar.
- Vagas recorrentes (publicar uma vez, repetir semanalmente) — fora do MVP.
- Vagas com múltiplas funções diferentes no mesmo turno — fora do MVP, força publicar separado.
