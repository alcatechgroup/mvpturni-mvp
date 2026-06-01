---
id: BUG-XXX
slug: <kebab-case>
title: <título canônico curto, em prosa, descrevendo o defeito>
status: reported        # reported | triaged | confirmed | planned | fixed | verified | wont_fix | duplicate
severity: <a definir>   # critical | high | medium | low
origin: <a definir>     # validation | user | monitoring | po_review | dev_review | designer_review | e2e
origin_ref: null        # ex: epics/EPIC-XXX/validation/report.md#sec-3, ou ID de alerta, ou nome do usuário
environment: <a definir># homolog | producao | dev | local
version_ref: null       # ex: rc.28, commit hash, sprint
area: <a definir>       # epic/módulo/spec afetado
tags: []
linked_validation: null # path do validation report onde apareceu, se houver
fix_link: null          # preenchido quando virar estória/épico de correção
duplicate_of: null      # BUG-YYY ou STORY-YYY (se duplicate)
wont_fix_reason: null   # obrigatório se wont_fix
found_at: YYYY-MM-DD
last_seen_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
---

# BUG-XXX — <título>

## One-liner

<Uma frase descrevendo o defeito do ponto de vista do usuário. O que tenta fazer e o que acontece de errado.>

## Reprodução

Ambiente: <homolog / produção / dev / local> · Versão: <rc.X / commit / sprint>
Persona/perfil: <profissional / contratante / admin>
Dispositivo/navegador (se relevante): <iPhone 14 Safari / Chrome desktop / Android Pixel>

Passos:
1. <passo>
2. <passo>
3. <passo>

Frequência: <sempre | intermitente N/M tentativas | uma vez (suspeito)>

## Comportamento esperado

<O que deveria acontecer segundo spec, protótipo ou regra de negócio. Cite o documento que estabelece a expectativa.>

## Comportamento observado

<O que acontece de fato. Inclua mensagens de erro literais, screenshots se houver (caminho relativo), trecho de log.>

## Impacto

- **Persona afetada:** <profissional / contratante / admin / todas>
- **Fluxo afetado:** <cadastro / publicação de vaga / match / PIN / Pix / etc>
- **Severidade justificada:** <por que classifiquei como critical/high/medium/low — qual critério do README.md se aplica>
- **Workaround:** <existe? qual? aceitável?>
- **Dado em risco:** <não / sim — qual tipo>

## Referências

- Spec/regra que estabelece o comportamento esperado: `docs/especificacao/...`
- Tela: SCREEN-... (`docs/project-state/design/screens/...`)
- Validation report onde apareceu: `docs/project-state/epics/EPIC-XXX/validation/report.md`
- Estória que introduziu o bug (se identificado): STORY-...
- Bug correlato (não duplicate, mas relacionado): BUG-...
- Alerta/log: <ID Sentry, link, timestamp>

## Hipótese inicial (opcional)

<Hipótese rápida do PO sobre causa. Não é diagnóstico técnico — é só pista para o Programador. Em dúvida, deixe vazio.>

## Notas / histórico

- `YYYY-MM-DD` — Reportado. Origem: <quem/onde>. Severidade inicial: <X>.
- `YYYY-MM-DD` — <evento: triagem, repro confirmada, promoção a estória, fix, verificação>
