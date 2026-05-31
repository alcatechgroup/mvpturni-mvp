# Requisitos não-funcionais e SLOs

Promessas operacionais que viraram parte da identidade do produto. O contratante e o profissional podem cobrar.

## Promessas públicas

| Promessa | Métrica | Meta | Status MVP |
|---|---|---|---|
| Pix em até **15 minutos** após check-out validado | p95 do tempo entre captura Pagar.me e Pix entregue | ≤ 15 min | Caminho feliz coberto; falha → backoffice manual (PDR-010) |
| **Match em até 2h** (Member Start, Member) | p50 do tempo entre publicação da vaga e primeira candidatura aprovada | ≤ 2h | Caminho feliz; falha → vaga continua aberta sem SLA enforcement |
| **Match em até 1h** (Enterprise) | idem, segmentado por plano | ≤ 1h | Fora do MVP; Enterprise é plano da segunda onda |
| **Análise de cadastro em até 24h** | p95 do tempo entre submit e decisão do admin | ≤ 24h | Manual pelo admin; depende de capacidade da equipe |
| **Resolução de disputa em até 30 min** | p95 do tempo entre abertura e resolução | ≤ 30 min | Manual pelo admin |
| **Geofencing 100m** no check-in | Raio de tolerância | 100m | Alerta-e-registra (PDR-008) |

## SLOs internos (não publicados)

| SLO | Métrica | Meta MVP |
|---|---|---|
| **Disponibilidade WebApp** | Uptime mensal | ≥ 99.5% |
| **Disponibilidade Backoffice** | Uptime mensal | ≥ 99% |
| **Tempo de resposta médio (caminho crítico do WebApp)** | p95 | ≤ 800ms |
| **Erro de transação Pagar.me** | % falhas / total transações | ≤ 1% |
| **Erro de transação Pix** | % falhas / total Pix | ≤ 1% |

## Segurança

| Requisito | Decisão |
|---|---|
| Auth | E-mail + senha, sessão segura. Multi-fator fora do MVP. |
| Dados sensíveis em repouso | Criptografados (decisão do Arquiteto sobre como). Documento, dados bancários, chave Pix, fotos de comprovante. |
| Dados sensíveis em trânsito | HTTPS obrigatório em todas as interfaces. |
| LGPD | Conformidade básica: política de privacidade publicada, termo de consentimento no cadastro, dados acessíveis ao titular. Direito ao esquecimento — fluxo manual no MVP. |
| Logs de admin | Toda ação do admin no backoffice gera log auditável (quem, quando, o quê). |
| Trilha de auditoria do turno | Imutável após finalizado; mutável apenas pelo admin com registro de modificação. |

### Inventário LGPD — dados coletados (atualizado conforme as estórias coletam)

> Classificação: **sensível** = exige criptografia em repouso (ADR-009) + acesso restrito (admin lê; titular vê os próprios; ninguém mais). **pessoal comum** = dado pessoal sem categoria especial.

**Profissional — completar cadastro (STORY-023):**

| Campo | Classificação | Tratamento |
|---|---|---|
| Documento (CPF se PF / CNPJ se MEI/PJ) | **sensível** | Encrypted Cast (`documento_encrypted`); `documento_hash` (HMAC) só para unicidade; nunca em log claro. |
| Chave Pix | **sensível** | Encrypted Cast (`chave_pix_encrypted`). |
| Documento comprobatório (foto RG/CNH/CCMEI/Cartão CNPJ) | **sensível** | Arquivo em disco privado (ADR-004), path não-enumerável; sem URL pública. |
| Função(ões) secundária(s) | pessoal comum | — |
| Raio máximo de deslocamento (km) | pessoal comum | — |
| Preço/hora pretendido | pessoal comum | — |
| Bio | pessoal comum | — |

**Consentimento (STORY-023):** o `AceiteEletronico` registra o consentimento informado e explícito — `timestamp`, `ip`, `fingerprint` da sessão no clique de "Aceito e concluir cadastro" — e é imutável (ADR-010). Acesso aos campos sensíveis sempre via permissões controladas; titular acessa os próprios (auto-serviço pleno fora do MVP, estrutura preparada).

## Observabilidade

| Aspecto | Mínimo MVP |
|---|---|
| **Logs estruturados** | Tudo que afeta turno e pagamento. Decisão de Arquiteto sobre formato e destino. |
| **Métricas operacionais** | Métrica de norte + 3 métricas de apoio (definidas em `product/north-star.md`) acessíveis em dashboard interno. |
| **Alertas** | Pix com falha, geofencing fora do raio acima do esperado, disputa aberta. |
| **Trace de transações financeiras** | Sequência completa pré-autorização → captura → Pix, com IDs Pagar.me. |

## Acessibilidade

| Requisito | MVP |
|---|---|
| Contraste WCAG AA | Sim. |
| Navegação por teclado | Sim no backoffice; mobile-first do WebApp com pads de toque adequados. |
| Leitor de tela | Sim, nas principais interações. |
| Texto base mínimo | 14px em mobile, 13px em desktop. |

## Temas (aparência)

Decisão registrada em **PDR-013**.

| Aspecto | MVP |
|---|---|
| Temas suportados | **Claro e escuro**, em todas as interfaces (WebApp e Backoffice). |
| Tema padrão | **Claro.** Melhor para a página pública/3G e coerente com `background_color` do manifest. |
| Seleção | `prefers-color-scheme` do sistema + toggle persistido por usuário. |
| Esquema de cor | Por perfil (profissional/contratante/admin), em ambos os temas — ver Design System (DDR-001, `docs/project-state/design/system/tokens.md`). |
| Contraste | WCAG 2.1 AA verificado nos dois temas (tabela em `tokens.md §6`). |

## Internacionalização

Idioma único no MVP: **Português Brasileiro (pt-BR)**. Sem multi-idioma.

## Compatibilidade

| Plataforma | Mínimo MVP |
|---|---|
| WebApp (mobile) | iOS Safari 15+, Android Chrome 100+. |
| WebApp (desktop fallback) | Chrome, Firefox, Safari, Edge nas duas últimas versões major. |
| Backoffice | Chrome, Firefox, Safari, Edge nas duas últimas versões major. Desktop only. |
| PWA | WebApp instalável como PWA no Android e iOS (suporte parcial iOS). |

## Performance específica

| Cenário | Meta |
|---|---|
| Carregamento inicial do WebApp em 3G | ≤ 5s (FCP) |
| Carregamento de feed (após login) | ≤ 1.5s (p95) |
| Validação de PIN | ≤ 500ms (p95) — operação crítica em pé na rua |

## Qualidade de código (herdado dos princípios do PO)

| Métrica | Meta |
|---|---|
| Cobertura unitária geral | ≥ 80% |
| Cobertura unitária em núcleo (regras de negócio) | ≥ 98% |
| E2E em todo fluxo de usuário | obrigatório |

## Lacunas conhecidas

- SLOs de Pagar.me e Pix dependem da disponibilidade do provedor — definir compensações em caso de falha externa é trabalho jurídico/comercial, fora do MVP.
- Backup e disaster recovery — decisão do Arquiteto via ADR.
- Política de retenção de dados (logs, trilha de auditoria) — definir com assessoria jurídica.
