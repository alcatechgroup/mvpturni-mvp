---
id: DDR-002
title: Locale pt-BR e horário sempre em 24h (sem AM/PM) em todo o app
status: accepted
created_at: 2026-06-02
decided_at: 2026-06-02
approved_by: Alexandro
supersedes: ~
superseded_by: ~
related_ddrs: [DDR-001]
related_adrs: [ADR-001]
related_pdrs: []
scope: transversal
affects_screens: [SCREEN-STORY-046-publicar-vaga]
---

# DDR-002 — Locale pt-BR e horário sempre em 24h (sem AM/PM)

## Contexto

Testando a tela de publicar vaga (STORY-046), o seletor de hora (`showTimePicker`) apareceu com **AM/PM**. No Brasil o padrão é **24 horas**; AM/PM confunde a persona (profissional/contratante) e é estranho ao público-alvo. A causa: o WebApp não tinha **locale** configurado nem `flutter_localizations`, então os pickers herdavam o formato do dispositivo/navegador (que no ambiente de teste reportava 12h).

Pedido explícito de Alexandro (chat 2026-06-02): "para horas use sempre o padrão 24h usado no Brasil; registre isso para sempre ser assim em futuros desenvolvimentos."

Documentos: STORY-046 + SCREEN-STORY-046; DDR-001 (fundação do DS); ADR-001 (Flutter Web).

## Forças (drivers)

- **Persona / país** (alto): usuário brasileiro não-técnico; 24h é o esperado, AM/PM gera erro de leitura.
- **Consistência transversal** (alto): vale para toda data/hora do produto, não só esta tela — datas, meses e horários no padrão pt-BR.
- **Princípio #3 (tom profissional do domínio)** (médio): formato local reforça familiaridade.
- **Custo** (baixo): `flutter_localizations` é SDK; configuração é pontual no `MaterialApp`.

## Opções consideradas

### Opção A — Locale pt-BR + forçar `alwaysUse24HourFormat: true` app-wide (escolhida)
Configura `MaterialApp` com `locale: pt-BR`, `GlobalMaterialLocalizations` e força `MediaQuery.alwaysUse24HourFormat = true` no `builder` (vale para todos os pickers e formatações sensíveis ao MediaQuery, independente do dispositivo). Bulletproof.

### Opção B — Só configurar o locale pt-BR
pt-BR já usa 24h por padrão, mas no Web o `alwaysUse24HourFormat` vem da plataforma; sem o override, ambientes que reportam 12h voltariam a mostrar AM/PM. Frágil.

### Opção C — Passar `builder` 24h caso a caso em cada `showTimePicker`
Repetitivo, fácil de esquecer numa tela futura. Vira débito. Descartada.

### Status quo — sem locale
Mostra AM/PM conforme o dispositivo. Rejeitado (motivou esta DDR).

## Decisão

> **Todo o app usa locale pt-BR e exibe horário em 24h, sempre, sem AM/PM.** Implementado no `MaterialApp` (`locale`/`supportedLocales`/`localizationsDelegates` + `MediaQuery(alwaysUse24HourFormat: true)` no `builder`). Toda exibição/edição de hora (pickers e texto) segue 24h; datas no formato brasileiro (dd/mm/aaaa).

## Consequências

- **Para qualquer desenvolvimento futuro:** nunca exibir AM/PM. Campos e pickers de hora em 24h; datas dd/mm/aaaa; meses/dias localizados em pt-BR. Não reintroduzir `showTimePicker`/formatadores que dependam do locale do dispositivo sem o override — o app já garante 24h globalmente, então basta usar os widgets padrão.
- **Implementação:** `flutter_localizations` adicionado; `MaterialApp` configurado (`apps/webapp/lib/main.dart`).
- **Verificação:** `test/locale_24h_test.dart` (alwaysUse24HourFormat=true + locale pt-BR sob `TurniApp`). Manual: abrir o seletor de hora em qualquer tela → sem AM/PM.
- **Trade-off:** app fixado em pt-BR (sem i18n multi-idioma) — coerente com o MVP só-Brasil; internacionalização futura reabre esta DDR.

## Histórico

| Data | Mudança | Quem |
|---|---|---|
| 2026-06-02 | criada e aceita (mandato de Alexandro em chat); implementada na STORY-046 | claude-opus-4-8 |
