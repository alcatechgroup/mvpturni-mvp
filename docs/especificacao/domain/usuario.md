# Domínio · Usuário

Decisão de referência: **PDR-001** (tipos de pessoa aceitos), **PDR-003** (duas interfaces).

## Papéis

Um usuário tem **um** papel:

- `profissional` — vende turnos. Aparece no WebApp.
- `contratante` — publica vagas. Aparece no WebApp.
- `admin` — opera o backoffice. Não aparece no WebApp; só backoffice.

Auth e base de usuários são compartilhadas entre WebApp e Backoffice. O roteamento pós-login leva o usuário para a interface certa conforme seu papel.

## Tipos de pessoa (apenas profissional)

Atributo `tipo_pessoa` exclusivo do papel `profissional`:

| Tipo | Documento | Contrato eletrônico | Regra de habitualidade |
|---|---|---|---|
| `PF` | CPF | Autônomo eventual | Bloqueio duro na 3ª alocação semanal no mesmo estabelecimento |
| `MEI` | CNPJ (MEI) | B2B PJ↔PJ | Alerta + override do contratante na 3ª alocação semanal |
| `PJ` | CNPJ (não MEI) | B2B PJ↔PJ | Alerta + override do contratante na 3ª alocação semanal |

Contratantes são sempre PJ (CNPJ obrigatório). Não há `tipo_pessoa` para contratante.

Validação de documento é **manual pela equipe Turni** (SLA público de 24h). Não há consulta automática à Receita no MVP.

## Estados do usuário

```
   submit cadastro
        │
        ▼
  ┌──────────────┐
  │ pendente_aprovacao │
  └──────┬───────┘
         │ admin aprova                admin recusa
         │                                 │
         ▼                                 ▼
  ┌──────────────┐                  ┌────────────┐
  │  liberado    │                  │  recusado  │ (removido)
  │ welcome=false│
  │ cad=false    │
  └──────┬───────┘
         │ usuário vê tela welcome (uma vez)
         ▼
  ┌──────────────┐
  │  liberado    │
  │ welcome=true │
  │ cad=false    │
  └──────┬───────┘
         │ usuário completa cadastro
         ▼
  ┌──────────────┐
  │    ativo     │ ← uso normal a partir daqui
  └──────────────┘
```

Detalhes:

- O cadastro inicial (formulário público) só captura dados mínimos para a equipe Turni avaliar. Dados sensíveis (documento, dados bancários, endereço completo, fotos de comprovante) ficam para o **completar cadastro**, depois da aprovação.
- O **funil pós-aprovação** é obrigatório: o router do WebApp bloqueia rotas internas se o usuário liberado ainda não viu o welcome ou ainda não completou o cadastro.
- Recusa pela equipe Turni remove o usuário (não há histórico de recusa no MVP além do log de operação do admin).

## Atributos por papel

### Profissional

Mínimo no cadastro inicial (pré-aprovação):

- Nome completo, e-mail, telefone.
- Cidade, bairro.
- Função primária pretendida.
- Tipo de pessoa pretendido (PF/MEI/PJ).
- Foto.

Adicionados no completar cadastro (pós-aprovação):

- Documento (CPF para PF, CNPJ para MEI/PJ).
- Função(ões) secundária(s) opcionais.
- Raio máximo de deslocamento (km).
- Preço/hora pretendido.
- Bio curta.
- Dados bancários / chave Pix.
- Documentos comprobatórios (foto do documento, comprovante MEI quando aplicável).

Atributos do sistema (não editáveis pelo usuário):

- `nivel` (Iniciante → Confiável → Destaque → Elite).
- `score` (média de avaliações 0-5).
- `turnos_realizados` (contador).
- `xp` (pontos acumulados).
- Indicadores de plano (Turni Ads, Turnificado).

### Contratante

Mínimo no cadastro inicial:

- Nome do responsável, e-mail, telefone.
- Nome do estabelecimento.
- Tipo de operação (restaurante, bar, hotel, evento, catering, outro).
- Cidade.
- Foto/avatar do responsável.

Adicionados no completar cadastro:

- CNPJ.
- Endereço completo (logradouro, bairro, cidade, UF, CEP, complemento).
- Apelido do estabelecimento (usado em UI compacta).
- Segmento (descrição livre).
- Ano de fundação.
- Quantidade de funcionários.
- Turnos de operação típicos (texto livre).
- Cultura e valores-chave.
- Redes sociais e site.
- Contatos adicionais (gerente, chef, sommelier, etc.).
- Logo.
- Plano contratado (Member Start gratuito por padrão; mudança para Member ou Enterprise via fluxo separado).

### Admin

Mínimo no cadastro (não é público; admin é criado pela equipe Turni):

- Nome, e-mail, telefone.
- Cargo (CEO, ops, suporte, etc.).
- Foto.

Admin não passa pelo funil de welcome + completar cadastro — é criado já como `ativo`.

## Regras importantes

- **Login**: e-mail + senha. Sem multi-fator no MVP (avaliar para épicos futuros).
- **Recuperação de senha**: via e-mail, fluxo padrão.
- **Logout**: encerra sessão.
- **Único usuário por papel + e-mail**: e-mail é chave única do sistema; a mesma pessoa não pode ter perfil de profissional e contratante no mesmo e-mail (caso queira, registrar dois e-mails distintos).

## Lacunas conhecidas (para PDR/spike futuros)

- Política de exclusão de conta / direito ao esquecimento (LGPD).
- Multi-fator de autenticação.
- Múltiplos estabelecimentos por contratante (Enterprise) — fora do MVP.
- Histórico de recusas no admin para análise de padrão.
