---
idr_id: IDR-031
slug: medicao-de-sincronia-do-cronometro-por-skew-modo-comum
title: Medição da sincronia bilateral do cronômetro por skew local + diferença de medianas (modo-comum)
status: accepted
decided_at: 2026-06-09
decided_by: programador
owner_agent: claude-opus-4-8-programador-2026-06-09
related_story: STORY-082
related_adrs: [ADR-017]
related_idrs: [IDR-004, IDR-010, IDR-011, IDR-021, IDR-026]
supersedes: null
superseded_by: null
created_at: 2026-06-09
updated_at: 2026-06-09
---

# IDR-031 — Medição da sincronia bilateral do cronômetro por skew local + diferença de medianas

## Contexto

O E2E de sincronia bilateral do cronômetro (`integration_test/turnos/cronometro_test.dart`,
nascido na STORY-063) é **gate de release** (IDR-004). Na validação do EPIC-003 ele foi
classificado como **flaky bloqueante (F-B-1)**: falhou 1/5 execuções completas do gate no dia
do fechamento da W28 (e 1 ocorrência anterior na STORY-065), sempre com o mesmo sintoma —
`display 2222s × servidor 2224s` (2s de desvio, contra um limite de 1s/amostra). A
funcionalidade de produto (sincronia ≤ 2s) foi verificada **viva em homolog** dentro do alvo
(Δ=1s entre 2 navegadores). O PO aceitou o F-B-1 como dívida e mandou esta estória (STORY-082)
estabilizar o gate. Aprendizado de processo da W28: *"asserção de SLA de timing em build debug
(flutter drive/DDC) é fonte estrutural de flake"*.

### Causa-raiz da intermitência

A forma antiga, para cada amostra:
1. fazia `GET /turnos/{id}/cronometro` **fresco** e lia `servidor_agora`;
2. lia o display do app;
3. exigia `|display − (servidor_agora − iniciado_em)| ≤ 1s`.

Mas o display do app **não** usa esse fetch: ele deriva da própria sincronização periódica do
app, que por ADR-017 calcula `offset = agoraCliente − servidorAgora` e, daí em diante, tica
localmente. Esse `offset` embute a **latência da resposta do poll do app**: o servidor carimba
`servidorAgora`, e o cliente só recebe a resposta L segundos depois → o app super-estima o
offset em L → o display fica **L segundos atrás** do tempo real até o próximo poll limpo. Em
build debug sob carga, L passa de 1s e estoura a tolerância — sem que a sincronia funcional
tenha falhado. A medição antiga, na prática, media a **latência de rede do ambiente de teste**,
não a sincronia entre os dois lados.

## Decisão

> **A sincronia bilateral passa a ser medida pelo _skew local de cada lado_ contra a âncora,
> e o veredito é a _diferença das medianas_ dos dois lados (≤ 2s) — uma quantidade modo-comum
> em que a lentidão do ambiente e o skew de relógio cancelam. A âncora (`iniciado_em`) é lida
> uma única vez por lado (imutável enquanto `ativo`); o laço de amostragem não faz rede.**

### Derivação (por que é faithful e robusto a carga)

O display de um lado é, por construção (ADR-017):

```
display = (agoraCliente − offset) − iniciadoEm
```

Definindo o **skew local** medido pelo teste no instante da amostra (relógio do cliente):

```
skew = display − (agoraCliente − iniciadoEm) = −offset
```

A sincronia bilateral que o produto promete é a diferença entre os dois lados:

```
median(skew_pro) − median(skew_contr) = offset_contr − offset_pro
```

E `offset = (skew_de_relógio cliente↔servidor) + (latência_da_resposta)`. Como os dois lados
rodam na **mesma máquina** contra o **mesmo servidor** e ancoram no **mesmo `iniciadoEm`**, o
skew de relógio é idêntico nos dois e **cancela** na diferença. Sobra apenas
`latência_contr − latência_pro`:

- ambiente saudável → sub-segundo;
- ambiente lento de forma uniforme → as duas medianas deslocam **juntas** (a lentidão é
  modo-comum) → a diferença continua pequena;
- a **mediana** sobre ≥ 6 amostras/lado rejeita o pico transitório de latência — exatamente o
  outlier de 2s que causava o F-B-1.

### Forma do teste

- Por lado: navega até o cronômetro, lê a âncora **uma vez** (`CronometroService.fetch`,
  confirma `estado == ativo` e `iniciado_em != null`), depois amostra o display ≥ 6× a cada
  ~5s (≥ 30s/lado, **≥ 12 amostras em ≥ 60s** no total — preserva a janela da CA-3 da 063).
- Sanidade funcional por amostra (não-temporal, não sensível a carga): o display **nunca
  regride** (o relógio anda pra frente).
- Veredito único (CA-3): `|median(skew_pro) − median(skew_contr)| ≤ 2s`.
- O laço de amostragem **não faz rede** → nenhum SLA de fetch por amostra (CA-2).

## Consequências

- **Positivas:** o gate deixa de depender da latência absoluta do build debug (CA-2); a medição
  reflete a sincronia funcional (CA-3) e o requisito de produto `≤ 2s` (ADR-017) permanece
  intacto — não foi relaxado, foi medido corretamente. Estabilidade demonstrada na STORY-082
  (ver Notas do agente: ≥ 20 execuções consecutivas verdes).
- **Limites:** o método pressupõe os dois lados na mesma máquina/relógio (verdade no harness
  same-origin, IDR-021) — é o que faz o skew de relógio cancelar. Num cenário multi-máquina o
  skew de relógio NÃO cancelaria e a medição precisaria de outra âncora de tempo comum (NTP).
  O E2E é single-host por IDR-010/011/021, então a premissa vale; quem mover o harness para
  multi-host precisa revisitar esta decisão.
- **Detecção preservada:** um desync funcional real (um lado ancorado em `iniciado_em` errado,
  offset não cancelado, display congelado) aparece como diferença de medianas > 2s ou como
  display regredindo — continua sendo pego.

## Alternativas consideradas

- **Tolerância por-amostra alargada com a latência medida do fetch** (tolerância = round-trip +
  1 tick): também absorve carga, mas continua acoplando o veredito à latência de _um_ request e
  é menos faithful (mede o lado contra o servidor, não os dois lados entre si). Descartada por
  ser mais ruidosa que a diferença de medianas modo-comum.
- **Comparar os dois displays simultaneamente:** impossível no harness same-origin, que loga um
  papel de cada vez (sequencial). É justamente por isso que a 063 usou a âncora do servidor como
  intermediário — aqui trocamos o intermediário "fetch fresco por amostra" pelo "relógio local
  comum + âncora única", que cancela o ruído.
