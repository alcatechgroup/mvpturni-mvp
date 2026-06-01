# LGPD · Registro de campos coletados por fluxo

Registro vivo dos dados pessoais coletados pelo Turni, por fluxo/estória, com a
classificação (dado pessoal **comum** vs **sensível**, conforme LGPD art. 5º) e a
base legal. Complementa `non-functional.md` §LGPD. Cada estória que coleta dado
pessoal **acrescenta** sua seção aqui.

> Lembrete de classificação (LGPD art. 5º, II): dado **sensível** é o que revela
> origem racial/étnica, convicção religiosa, opinião política, filiação sindical,
> dado referente à saúde/vida sexual, **genético ou biométrico** quando usado para
> identificar unicamente uma pessoa. Os demais são dados pessoais **comuns**.

---

## STORY-017 — Pré-cadastro de Profissional (PF/MEI/PJ)

- **Fluxo:** formulário público `/cadastro/profissional` → `POST /api/cadastro/profissional`.
- **Base legal:** **consentimento** explícito do titular (checkbox obrigatório "Li e
  aceito os Termos de Uso e a Política de Privacidade", com `termos_aceitos_at`
  registrado) + execução de medidas pré-contratuais (LGPD art. 7º, I e V).
- **Titular:** o próprio profissional (maior de idade pressuposto).
- **Retenção:** enquanto a conta existir; recusa pela equipe Turni remove o usuário
  (sem histórico além do log de operação do admin — `domain/usuario.md`).

| Campo | Classificação | Observações |
|---|---|---|
| Nome completo | Pessoal **comum** | Identificação. |
| E-mail | Pessoal **comum** | Identificador único do sistema. Mascarado em logs (ADR-008). |
| Telefone | Pessoal **comum** | Contato. |
| Cidade | Pessoal **comum** | Localização aproximada (não é endereço completo). |
| Bairro | Pessoal **comum** | Localização aproximada. |
| Função pretendida | **Comum** (profissional) | Referência a `funcoes` (não revela dado sensível). |
| Tipo de pessoa (PF/MEI/PJ) | **Comum** | Intenção declarada; **não** é o documento. |
| Foto de perfil | Pessoal **comum** | Imagem facial usada como avatar. **Não** é tratada como dado biométrico: não há identificação biométrica automatizada. Armazenada em disco privado, sem URL pública direta (ADR-004 / CA-13). |
| Senha | **Credencial** (não PII) | Hash Argon2id (ADR-007). Nunca em claro, em log ou em response (CA-3). |
| Aceite dos Termos (timestamp) | Registro de **consentimento** | Evidência do consentimento explícito. |

### Dados deliberadamente **NÃO** coletados neste fluxo

Política "dado sensível só pós-aprovação humana" (`domain/usuario.md`, PDR-001):

- **CPF/CNPJ (documento):** pessoal comum, porém só após aprovação — STORY-023.
- **Dados bancários / chave Pix:** dado financeiro sensível — STORY-023, criptografado em repouso (ADR-009 §F6).
- **Documentos comprobatórios (foto de documento, comprovante MEI):** STORY-023.

---

## STORY-023 — Completar cadastro de Profissional (pós-aprovação)

- **Fluxo:** rota autenticada `/completar-cadastro` → `POST /api/cadastro/profissional/completar`
  (multipart). Disponível só ao profissional `liberado, welcome_visto=true,
  cadastro_completo=false`.
- **Base legal:** execução de contrato/medidas pré-contratuais (LGPD art. 7º, V) +
  **consentimento explícito** do contrato de adesão, registrado como `AceiteEletronico`
  imutável (timestamp + IP + fingerprint) no clique de "Aceito e concluir cadastro" (ADR-010).
- **Titular:** o próprio profissional.
- **Retenção:** enquanto a conta existir. O aceite eletrônico é **imutável** (trigger + REVOKE)
  e preservado como evidência jurídica mesmo após mudança de versão do template.
- **Controle de acesso:** os campos sensíveis (abaixo) só são acessíveis a `admin` via
  permissões controladas; nunca trafegam em log claro (mascarados — ADR-008).

| Campo | Classificação | Observações |
|---|---|---|
| Documento — CPF (PF) ou CNPJ (MEI/PJ) | **Sensível** (financeiro/fiscal) | **Criptografado em repouso** (Eloquent encrypted cast — ADR-009 5A). Unicidade via `documento_hash` HMAC-SHA256 determinístico (IDR-022). Validação de dígitos server-side; sem consulta à Receita (PDR-001). |
| Chave Pix | **Sensível** (financeiro) | **Criptografada em repouso** (ADR-009 5A). Validação básica de formato (CPF/CNPJ/e-mail/telefone/aleatória). |
| Documentos comprobatórios (foto de RG/CNH, Cartão CNPJ/CCMEI) | **Sensível** | Upload JPG/PNG/PDF ≤10 MB; MIME validado server-side; disco privado com path não-enumerável (ADR-004). |
| Funções secundárias | **Comum** (profissional) | Lista de referências a `funcoes`. |
| Raio máximo de deslocamento (km) | **Comum** | Preferência operacional. |
| Preço/hora pretendido | **Comum** | Preferência comercial. |
| Bio curta | Pessoal **comum** | Texto livre ≤500 chars informado pelo titular. |
| Aceite eletrônico (conteúdo renderizado, timestamp, IP, fingerprint) | Registro de **consentimento** + evidência jurídica | Imutável (ADR-010). `dados_renderizados` guarda os pares usados na renderização. |

---

## STORY-018 — Pré-cadastro de Contratante (estabelecimento — sempre PJ)

- **Fluxo:** formulário público `/cadastro/contratante` → `POST /api/cadastro/contratante`.
- **Base legal:** **consentimento** explícito do titular (checkbox obrigatório "Li e
  aceito os Termos de Uso e a Política de Privacidade", com `termos_aceitos_at`
  registrado) + execução de medidas pré-contratuais (LGPD art. 7º, I e V).
- **Titular:** o **responsável** pelo estabelecimento (pessoa física que cadastra a conta
  do contratante PJ).
- **Retenção:** enquanto a conta existir; recusa pela equipe Turni remove o usuário
  (sem histórico além do log de operação do admin — `domain/usuario.md`).

| Campo | Classificação | Observações |
|---|---|---|
| Nome do responsável | Pessoal **comum** | Identificação da pessoa que opera a conta. |
| E-mail | Pessoal **comum** | Identificador único do sistema. Mascarado em logs (ADR-008). |
| Telefone | Pessoal **comum** | Contato do responsável. |
| Nome do estabelecimento | **Não-pessoal** (dado da empresa) | Razão/nome fantasia do negócio. |
| Tipo de operação | **Não-pessoal** (dado da empresa) | Enum fechado (restaurante/bar/hotel/evento/catering/outro). |
| Cidade | Pessoal **comum** | Localização aproximada (não é endereço completo). |
| Foto de perfil | Pessoal **comum** | Imagem facial do responsável usada como avatar. **Não** é tratada como dado biométrico (sem identificação biométrica automatizada). Armazenada em disco privado, sem URL pública direta (ADR-004). |
| Senha | **Credencial** (não PII) | Hash Argon2id (ADR-007). Nunca em claro, em log ou em response (CA-3). |
| Aceite dos Termos (timestamp) | Registro de **consentimento** | Evidência do consentimento explícito. |

### Dados deliberadamente **NÃO** coletados neste fluxo

Política "dado sensível/identificador fiscal só pós-aprovação humana" (`domain/usuario.md`, PDR-001; STORY-018 CA-13):

- **CNPJ:** identificador fiscal da PJ — só após aprovação (STORY-024).
- **Endereço completo (logradouro, bairro, UF, CEP, complemento):** STORY-024.
- **Segmento, cultura/valores, ano de fundação, nº de funcionários, redes sociais, contatos adicionais, logo:** STORY-024.
