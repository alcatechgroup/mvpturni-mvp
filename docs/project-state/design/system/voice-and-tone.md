# Voice & Tone

> Como o Turni fala com o usuário. Resumo aplicável no dia-a-dia. Detalhe pleno em `docs/skills/designer/references/tone-and-voice.md`. Vocabulário do domínio: `docs/skills/po/references/glossary.md`.
> Versão 0.1 — DDR-001. Última atualização: 2026-05-27.

## A persona em uma frase

Profissional de hospitalidade (garçom, cozinheiro, recepcionista) ou contratante (gestor de operações) brasileiro — **não-técnico**, ocupado, atenção fragmentada, decidindo sobre turno/escala. Cada escolha de tom passa por: **isso ajuda essa pessoa a fazer o trabalho dela?**

## Tom — atributos

- **Profissional**, não "app de delivery". Como um colega experiente do setor.
- **Direto.** Frase curta, verbo no início, sem rodeio.
- **Respeitoso.** Não condescendente, não infantilizado, **não culpa o usuário**.
- **Calmo.** Sem urgência fabricada. Urgência real merece urgência; o resto, não.
- **Honesto.** Não esconde o que aconteceu; não promete o que não pode.
- **Sóbrio, mas não árido.** "Match confirmado." — não "Match confirmado!! 🎉" nem "Operação efetivada com sucesso."

## Pessoa do discurso

**Tratamento direto na 2ª pessoa (você).** "Você ainda não publicou vagas." É o registro coloquial-respeitoso brasileiro padrão na web, próximo sem ser íntimo. O sistema fala de si na **1ª pessoa do plural** quando assume responsabilidade ("Não conseguimos salvar agora"). Justificativa: acolhe sem infantilizar, e a 1ª pessoa plural divide a responsabilidade do erro com a plataforma — nunca joga no usuário.

## O que evitar (sempre)

Emoji em microcopy · exclamação fabricada ("Tudo certo!!!") · gíria/infantilização ("Ops, deu ruim!", "Bora!") · mascotes · culpar o usuário ("Você digitou errado") · jargão técnico exposto ("Erro 500", "Timeout") · vagueza ("Ocorreu um erro") · burocratês · gamificação decorativa.

## Padrões de microcopy

| Situação | Padrão | Exemplo |
|---|---|---|
| CTA primário | verbo infinitivo + objeto | "Aceitar match", "Publicar vaga" |
| CTA secundário | verbo neutro | "Cancelar", "Voltar" |
| Confirmação destrutiva | nomeia o objeto | "Recusar este match? Esta ação não pode ser desfeita." |
| Sucesso | curto, sem emoji | "Match confirmado." |
| Erro recuperável | o que aconteceu + o que fazer | "Não conseguimos salvar agora. Tentar de novo." |
| Erro de campo | específico, associado ao campo | "Telefone deve ter DDD + 9 dígitos." |
| Vazio | o que falta + como conseguir | "Você ainda não publicou vagas. Publicar a primeira." |
| Loading | preferir skeleton — sem texto | — |
| Label de campo | substantivo curto, sem `:` final | "Telefone" |
| Placeholder | exemplo, não instrução | `Ex.: 11912345678` |
| Hint | restrição/contexto curto | "Use o telefone com DDD que recebe WhatsApp." |

## Vocabulário

Termos canônicos do domínio (do glossário do PO) — **não rebatize**: `Vaga`, `Turno`, `Profissional`, `Contratante`, `Estabelecimento`, `Match`, `PIN`, `Pix`. Genéricos da web seguem o padrão usual: `Usuário`, `Sessão`, `Conta`.

## Acentuação e pontuação

- **Acentuação portuguesa correta sempre** — acento ausente em produto sério parece desleixo.
- Sem ponto final em label de campo; com ponto final em frase completa.
- Sem exclamação dupla. Aspas duplas ("texto"). Travessão "—" (em-dash).

## Hábitos pró-i18n futura (pt-BR é único no MVP)

Microcopy em **tabela única no spec** · frase curta · sem trocadilho · **placeholders nomeados** (`Match de {profissional} confirmado em {estabelecimento}`) em vez de concatenação.

## Checklist antes de marcar um spec como `ready`

- [ ] Copy em tabela única.
- [ ] Sem emoji, sem exclamação fabricada, sem gíria.
- [ ] Erros têm "o que aconteceu" + "o que fazer".
- [ ] Estados vazios instruem o próximo passo.
- [ ] Vocabulário bate com o glossário.
- [ ] Acentuação correta.
- [ ] CTA primário = verbo infinitivo + objeto.
- [ ] Sem jargão técnico exposto.
