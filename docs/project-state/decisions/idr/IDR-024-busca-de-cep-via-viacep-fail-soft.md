---
idr_id: IDR-024
slug: busca-de-cep-via-viacep-fail-soft
title: Busca de endereço por CEP via ViaCEP, fail-soft (não bloqueia o cadastro)
status: accepted
decided_at: 2026-06-01
decided_by: programador
owner_agent: claude-opus-4-8-programador-2026-06-01
related_story: STORY-024
related_adrs: []
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-06-01
updated_at: 2026-06-01
---

# IDR-024 — Busca de endereço por CEP via ViaCEP (fail-soft)

## Contexto

A STORY-024 (CA-4) pede busca automática de endereço por CEP no completar cadastro do contratante,
deixando a escolha da API ao programador (com registro em IDR) e exigindo que **falha da API externa
não bloqueie o submit** (degrada para entrada manual + log de falha de integração). Não havia
nenhuma integração HTTP de saída no app `api` até aqui.

## Decisão

> **Busco CEP no ViaCEP (`https://viacep.com.br/ws/{cep}/json/`) via `Http` facade nativo do Laravel,
> com timeout curto e contrato fail-soft: o serviço `CepLookup` NUNCA lança — qualquer falha retorna
> `null`.**

- Sem biblioteca nova: o cliente HTTP do Laravel (`Illuminate\Support\Facades\Http`, baseado em
  Guzzle já presente) cobre o caso.
- `base_url` e `timeout` (default 4s) configuráveis em `config/services.php` (`services.viacep.*`),
  parametrizáveis por env (`VIACEP_BASE_URL`, `VIACEP_TIMEOUT`).
- Normaliza o CEP para 8 dígitos antes de chamar; CEP malformado nem dispara request.
- Mapeia a resposta do ViaCEP para o vocabulário do domínio (`localidade → cidade`).
- CEP inexistente (`{"erro": true}`), status HTTP de erro, timeout/indisponibilidade → `null`. Falhas
  de rede/HTTP logam `cadastro.cep_lookup_falhou` (warning) para observabilidade, sem dado pessoal.

## Por quê

- **ViaCEP**: gratuito, sem chave/credencial, amplamente usado e estável no Brasil, resposta simples.
  Não acopla o MVP a um fornecedor pago nem a cadastro de API key.
- **Fail-soft é requisito (CA-4)**: o endereço pode ser preenchido à mão; a conveniência do
  autocomplete jamais pode derrubar o fechamento do funil do contratante. Retornar `null` em vez de
  propagar exceção mantém o controller simples e o fluxo resiliente.
- **`Http` nativo > lib nova** (disciplina de bibliotecas): menos dependência para manter/auditar.

## Alternativas consideradas

- **BrasilAPI (`/cep/v2`)**: também gratuita e boa; agrega múltiplas fontes. Descartada como default
  por o ViaCEP ser suficiente e mais simples; fica como **fallback futuro** trocando `base_url`/mapa
  se o ViaCEP se mostrar instável (não-bloqueante para o MVP).
- **Busca client-side direto do Flutter Web**: descartada — CORS/instabilidade no browser e a CA-4
  pede *log de falha de integração no servidor*, o que exige o caminho server-side.
- **Validar/normalizar CEP contra base local**: fora de escopo; sem base de CEP no MVP.

## Consequência

- O endpoint que expõe a busca (a ser adicionado no controller do completar contratante) chama
  `CepLookup` e responde 200 com o endereço ou 204/`null` — o WebApp trata ausência como "preencha
  manualmente".
- Se o ViaCEP ficar instável em produção, a troca para BrasilAPI é só `base_url` + ajuste do mapa de
  campos; o contrato fail-soft e os testes (HTTP mockado) permanecem.
