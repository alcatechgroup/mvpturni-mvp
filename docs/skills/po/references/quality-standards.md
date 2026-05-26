# Padrões de qualidade exigidos pelo PO

Este documento é referenciado por toda estória. Ele descreve o que o PO **exige** do time de desenvolvimento, sem prescrever como atingir (a tecnologia é decisão do Arquiteto/Programador).

## Por que estes padrões

O Turni intermedia trabalho real entre profissionais e contratantes, envolvendo identidade, presença, escala e pagamento via Pix. Um bug que confirma o profissional errado, uma falha que perde um match no fim de semana, um vazamento de dado pessoal ou uma instabilidade no fluxo de Pix custa diretamente confiança de gente que tem pouco a perder. Por isso a régua é alta — e é o PO que paga o preço de a baixar, então não baixe.

## 1. Testes automatizados

### 1.1 Cobertura unitária

- **Mínimo geral:** 80% de cobertura de linhas e branches no código novo de cada estória.
- **Núcleo e regras de negócio:** 98% de cobertura — inclui lógica de matching, regras de elegibilidade de profissional/vaga, confirmação de PIN bilateral, repasse Pix, cálculo de comissão e qualquer transformação de dado pessoal/financeiro.
- Cobertura é medida no PR. Se cair abaixo da meta, o PR não merge.

### 1.2 Testes ponta-a-ponta (E2E)

- Todo fluxo de usuário visível ao usuário final tem **pelo menos um cenário E2E** automatizado.
- **Interface (mobile e web):** os E2E rodam em **app/browser real** via automação (não simulação por unit), exercendo a UI como o usuário exerce. **Ferramenta concreta é decisão de ADR do Arquiteto** — o PO exige só o resultado.
- **APIs sem interface:** E2E é via cliente HTTP real chamando o serviço deployado em ambiente equivalente ao produtivo.
- Cenários cobrem caminho feliz + ao menos um caminho de erro relevante.

### 1.3 Disciplina de TDD

- Estórias de funcionalidade nova: o agente escreve teste primeiro, vê falhar, implementa, vê passar. Este é um requisito herdado e ratificado (ver requisitos não-funcionais e jurídicos em `docs/especificacao/` conforme forem sendo consolidados pelo PO).
- Não é fetichismo: o sinal de TDD bem feito é que o histórico de commits mostra testes acompanhando ou precedendo o código.

### 1.4 Sem código não testado em produção

- Funções com `// no coverage` ou equivalente precisam de justificativa explícita no PR.
- Ramos catch genéricos não contam como código não testado se o teste cobre o gatilho.

## 2. Automação de tudo

O princípio: **se um humano precisa lembrar de fazer algo manualmente, o processo está quebrado**.

### 2.1 Ambiente de desenvolvimento local

- Um comando único leva alguém de "acabei de clonar o repo" até "API e FE rodando localmente com dados de seed".
- Esse comando é testado em CI periodicamente para não apodrecer.

### 2.2 CI/CD

> Política detalhada vive em ADR do Arquiteto quando for formalizada (`docs/project-state/decisions/adr/`). O texto abaixo descreve **o resultado exigido pelo PO** — ferramentas concretas são decisão do Arquiteto/Programador.

- **Antes do push (laptop do dev/agente):** git hook versionado (instalado por comando padrão do projeto) roda testes unitários + testes de integração contra **banco de dados real local** + testes E2E em **app/browser real** + medição de cobertura (gate 80% geral / 98% no núcleo de regras de negócio). Hook falha = `git push` abortado.
- **Todo push para branch de feature dispara CI leve:** lint da linguagem/framework escolhido, lint de commit messages, análise de dependências vulneráveis, análise estática de imagens de container (quando aplicável), detecção de segredos commitados, build do artefato de deploy. **Não** sobe banco nem browser/emulador no runner — testes pesados já foram cobrados localmente pelo hook.
- **Promoção é tag-based explícita:** criação da tag `vX.Y.Z-rc.N` dispara deploy automático em homologação (sem gate humano); criação da tag `vX.Y.Z` (sem `-rc`) dispara deploy em produção com **gate humano de 1 clique** via mecanismo de aprovação do CI escolhido.
- Deploy é sempre automatizado — execução nunca é manual. Gate humano em produção é o único ato humano no fluxo; tudo o que ele aciona é script/playbook versionado em git.

### 2.3 Infraestrutura

- Os ambientes de homologação e produção são criados/atualizados via Infra-as-Code. Nada de "ah, eu cliquei na UI do provedor pra criar isso".
- Recriar o ambiente do zero a partir do código é um caminho viável (e idealmente exercitado).

### 2.4 Banco de dados

- Migrações são automatizadas, versionadas e idempotentes.
- Backup e restore têm runbook automatizado.

## 3. Observabilidade mínima

Cada serviço entregue precisa, no mínimo:

- Endpoint de saúde (health check).
- Logs estruturados.
- Métricas básicas: requisições por segundo, latência p50/p95/p99, taxa de erro.
- Alerta configurado para indisponibilidade.

Isso é exigência por estória que entrega serviço novo, não opcional.

## 4. Segurança e LGPD

- Análise de dependências vulneráveis no pipeline.
- Segredos nunca no código — sempre em cofre/variável injetada.
- Dados pessoais tratados conforme requisitos não-funcionais e jurídicos consolidados em `docs/especificacao/` pelo PO (LGPD aplicável). Enquanto a spec não estiver pronta, a referência canônica é o protótipo (`docs/prototipo/`) — qualquer dúvida sobre tratamento de dado, escale ao PO.
- PRs que adicionam coleta de novo dado pessoal são bloqueados até o PO confirmar que está coberto pelo aviso de privacidade.

## 5. Acessibilidade (interface)

- Piso obrigatório: **WCAG 2.1 nível AA**.
- Componentes interativos novos têm **rótulos acessíveis** com semântica adequada à plataforma escolhida e funcionam por **entrada alternativa** (teclado em web, leitor de tela / switch control em mobile).
- Contraste mínimo WCAG AA respeitado conforme tokens do Design System em `docs/project-state/design/system/`.
- O Designer detalha o piso e o método de verificação na sua skill — o PO exige aqui apenas o resultado.

## 6. O que NÃO é exigência transversal (e portanto é decisão técnica do time)

Para deixar claro o que NÃO entra aqui:

- Linguagem ou framework (backend, frontend, mobile).
- Qual framework de teste usar.
- Qual ferramenta de E2E.
- Qual provedor de CI (e qual mecanismo concreto de aprovação humana em produção).
- Qual provedor de cloud / qual ferramenta de IaC.
- Qual banco de dados específico.
- Qual padrão arquitetural (monolito, microsserviços, etc).
- Qual padrão de versionamento semântico exato (desde que cumpra o resultado: promoção tag-based, RC em homologação, gate em produção).

Tudo isso é o Arquiteto/Programador que decide via ADRs/IDRs. O PO só fala em **resultado** ("o pipeline tem que ser verde", "o ambiente tem que recriar do zero", "o gate humano existe e é 1 clique") — não em ferramenta.

## 7. Como o PO escreve isso em estórias

Não copie este documento. Em cada estória, escreva:

> Esta estória segue os padrões em `docs/skills/po/references/quality-standards.md`. Em particular: [destacar o que for específico desta estória, ex.: cobertura 98% no módulo de matching, E2E cobrindo o fluxo de confirmação de PIN bilateral em mobile e web].

Se algum padrão NÃO se aplica (ex: estória de spike arquitetural não precisa de E2E), declare a exceção explicitamente na estória.
