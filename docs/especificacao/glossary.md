# Glossário do Turni

Vocabulário canônico do domínio. Termos abaixo são os únicos aceitos em estórias, ADRs, DDRs e comunicação interna. Sinônimos comuns que **não** se usam estão listados como "evitar".

## Atores e papéis

| Termo | Significa |
|---|---|
| **Profissional** | Pessoa que vende seu turno na plataforma. Pode ser **PF**, **MEI** ou **PJ**. *Evitar*: "trabalhador", "freelancer", "wkr". |
| **Contratante** | Estabelecimento (empresa) que publica vagas e contrata profissionais por turno. *Evitar*: "empresa", "emp", "cliente". |
| **Admin** | Equipe interna Turni que opera o backoffice. *Evitar*: "operador", "ops". |
| **Tipo de pessoa** | Atributo do profissional: `PF` (CPF, sem empresa), `MEI` (microempreendedor individual com CNPJ), `PJ` (pessoa jurídica não-MEI). Definido em PDR-001. |

## Entidades centrais

| Termo | Significa |
|---|---|
| **Vaga** | Oferta de um ou mais turnos publicada pelo contratante. Tem função, data/hora, valor, número de posições, observações. |
| **Candidatura** | Manifestação de interesse de um profissional por uma vaga aberta. |
| **Turno** | Unidade central do produto. Nasce quando o contratante aceita uma candidatura. Tem ciclo de vida próprio (confirmado → ativo → finalizado, ou variantes com disputa, cancelamento, etc.). |
| **Match** | Pareamento ranqueado entre profissional e vaga, calculado pelo algoritmo do Turni. Score 0-100 com breakdown explicável. |
| **Score** | Média de avaliações estrelas (0-5) recebidas pelo profissional. Alimenta o match e a trilha de níveis. |
| **Nível** | Posição do profissional na trilha: `Iniciante`, `Confiável`, `Destaque`, `Elite`. Determinado por pontos acumulados. |
| **XP** | Pontos acumulados pelo profissional ao concluir turnos e cumprir tarefas do checklist. Determina o nível. |
| **Estabelecimento** | Unidade física do contratante (um bar, um restaurante, um hotel). Contratantes Enterprise podem ter múltiplos. |

## Ciclos críticos

| Termo | Significa |
|---|---|
| **Check-in** | Momento em que o profissional declara ter chegado ao estabelecimento. Gera PIN de 4 dígitos para validação pelo contratante. Carrega flag de geofencing (sucesso/falha, distância). |
| **Check-out** | Momento em que o profissional declara ter encerrado o turno. Gera novo PIN para validação pelo contratante. Validado, libera pagamento. |
| **PIN bilateral** | Código numérico de 4 dígitos gerado pelo profissional e validado pelo contratante. Existe no check-in e no check-out. |
| **Cronômetro bilateral** | Contagem de tempo visível para ambos os lados, iniciada na validação do check-in, encerrada na validação do check-out. |
| **Geofencing** | Verificação de distância entre o profissional e o estabelecimento no momento do PIN. Raio padrão 100m. Alerta-e-registra (PDR-008), não bloqueia. |

## Modelo financeiro

| Termo | Significa |
|---|---|
| **Valor do turno** | Quantia que o profissional recebe pelo turno. Visível para o profissional sem desconto. |
| **Taxa Turni** | Percentual cobrado **do contratante**, em cima do valor do turno. Inicialmente 15% (PDR-004). |
| **Total contratante** | Valor do turno + Taxa Turni. O que o contratante efetivamente paga. |
| **Pré-autorização** | Bloqueio do valor no meio de pagamento do contratante no momento do aceite da candidatura, via Pagar.me. |
| **Captura** | Débito efetivo do valor pré-autorizado, executado no check-out validado. |
| **Pix de 15 min** | Promessa pública: profissional recebe Pix em até 15 minutos após check-out validado. Tratamento de falha pós-15min está fora do escopo MVP (PDR-010). |
| **Pagar.me** | Provedor de pagamento. Único PSP do MVP. |

## Compliance e confiança

| Termo | Significa |
|---|---|
| **Habitualidade** | Frequência de alocações de um mesmo profissional no mesmo estabelecimento. Regra: máximo 2/semana. Detalhe em `domain/compliance.md` (PDR-002). |
| **Zona verde** | Padrão de uso eventual, dentro da regra de habitualidade. Sem alerta. |
| **Zona amarela** | Sinais iniciais de habitualidade ou concentração de renda. Plataforma alerta ambos os lados. |
| **Zona vermelha** | Padrão excessivo. Alocação bloqueada (PF) ou alerta com override do contratante (PJ). |
| **Aceite eletrônico** | Documento contratual gerado por turno, com cláusulas distintas para PF (autônomo eventual) e MEI/PJ (B2B). Timestampado e auditável. |
| **Trilha de auditoria** | Registro imutável de eventos do turno: candidatura, aceite, PIN, geofencing, checklist, avaliação, pagamento. |

## Operação e backoffice

| Termo | Significa |
|---|---|
| **Disputa** | Estado do turno quando o contratante recusa validar o check-out. Resolvida no backoffice admin em até 30 min (PDR-006). |
| **Mediação Turni** | Atuação do admin para resolver disputa. Três resoluções possíveis: pagamento integral, parcial, ou sem pagamento. |
| **Pré-cadastro** | Estado do usuário (contratante ou profissional) entre o submit do cadastro e a aprovação manual do admin. |
| **Aprovação** | Ato do admin que ativa o usuário e o coloca no funil de welcome + completar cadastro. SLA público: 24h. |
| **Funil de aprovação** | Sequência obrigatória pós-aprovação: welcome → completar cadastro → uso normal. Bloqueia rotas internas até completo. |

## Planos e produtos

| Termo | Significa |
|---|---|
| **Member Start** | Plano gratuito do contratante. Cadastro, publicação ilimitada de vagas, checklist padrão, match IA básico. |
| **Member Turni** | Plano pago do contratante (R$ 399/mês/unidade). Checklist personalizado, prioridade no match, analytics. |
| **Enterprise** | Plano para redes (R$ 799/mês). Multi-unidade, SLA de match < 1h, API, dashboard executivo. |
| **Profissional Turni** | Cadastro gratuito do profissional. Match por score e proximidade, Pix em 15 min, checklist gamificado. |
| **Turni Ads** | Plano pago do profissional (R$ 49/mês). Boost de visibilidade no algoritmo de match. |
| **Turnificado** | Plano premium do profissional (R$ 149/mês). Antecipação de turnos, prioridade premium, dashboard de carreira. |

## Interfaces

| Termo | Significa |
|---|---|
| **WebApp** | Aplicação mobile-first PWA que serve Contratante e Profissional. Login decide qual visão é apresentada. |
| **Backoffice** | Aplicação web desktop-first que serve apenas o Admin Turni. Separada do WebApp em deploy e pipeline (PDR-003). |

## Conceitos transversais

| Termo | Significa |
|---|---|
| **Core FHP** | Future Hospitality Platform — motor compartilhado de tarefas e checklists do Grupo Noiz. Provê 40+ funções com checklist padrão. |
| **Briefing** | Texto livre do contratante anexado à vaga, lido pelo profissional antes do turno. |
| **Checklist** | Lista de tarefas com sequência e tempo estimado, gerada por função. Versionada no Core FHP. Personalizável no plano Member. |
| **Avaliação recíproca** | Ao fim do turno, ambos avaliam o outro (estrelas obrigatórias, comentário opcional). Obrigatória e bloqueante (PDR-005). |
