#!/usr/bin/env bash
# STORY-053 CA-12 — E2E de notificação por e-mail em HOMOLOG (Resend), 3 cenários × 3 runs.
#
# Homolog usa Resend (não Mailpit), então a asserção de "recebeu e-mail" é via Cloud Logging
# (`notificacao.email.sent` no worker), não por inbox. Os recipientes são usuários ENTREGÁVEIS
# (Gmail) semeados pelo Ca12EmailSmokeSeeder. Por run:
#   - cenário 1 (candidata→contratante): prof1+prof2 candidatam V_edit e V_cancel  → 4× candidatura_recebida
#   - cenário 2 (edita material→candidatos): contratante edita V_edit (valor)       → 2× vaga_editada_material
#   - cenário 3 (cancela→candidatos):       contratante cancela V_cancel            → 2× vaga_cancelada
# Runs são espaçados por SEMANA (habitualidade é por semana/estabelecimento; profs são MEI = não bloqueia).
#
# Uso: scripts/ca12-homolog-e2e.sh   (sai !=0 se algum run falhar a asserção)
set -uo pipefail

API="https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app"
ORIG="https://app.homolog.turni.com.br"
PROJ="turni-mvp"
WORKER_JOB="turni-worker-job-homolog"
PASS="turni-dev"
CONTRATANTE="xandroalmeida+turni-homolog@gmail.com"
PROF1="xandroalmeida+prof1-homolog@gmail.com"
PROF2="xandroalmeida+prof2-homolog@gmail.com"

H=(-H "Origin: $ORIG" -H "Referer: $ORIG/" -H "Accept: application/json")
JC=$(mktemp); J1=$(mktemp); J2=$(mktemp)
trap 'rm -f "$JC" "$J1" "$J2"' EXIT

xsrf() { awk '/XSRF-TOKEN/{print $7}' "$1" | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))"; }

login() { # email pass jar
  curl -sS -m 15 -c "$3" -o /dev/null "${H[@]}" "$API/sanctum/csrf-cookie"
  local code
  code=$(curl -sS -m 20 -b "$3" -c "$3" -o /dev/null -w '%{http_code}' "${H[@]}" \
    -H "X-XSRF-TOKEN: $(xsrf "$3")" -H "Content-Type: application/json" \
    -X POST "$API/login" -d "{\"email\":\"$1\",\"password\":\"$2\"}")
  [ "$code" = "200" ] || { echo "  ✗ login $1 → $code"; return 1; }
}

post() { # jar path jsonbody outfile
  curl -sS -m 25 -b "$1" -c "$1" "${H[@]}" -H "X-XSRF-TOKEN: $(xsrf "$1")" -H "Content-Type: application/json" \
    -o "$4" -w '%{http_code}' -X POST "$API$2" -d "$3"
}
patch() { curl -sS -m 25 -b "$1" -c "$1" "${H[@]}" -H "X-XSRF-TOKEN: $(xsrf "$1")" -H "Content-Type: application/json" -o "$4" -w '%{http_code}' -X PATCH "$API$2" -d "$3"; }
del()   { curl -sS -m 25 -b "$1" -c "$1" "${H[@]}" -H "X-XSRF-TOKEN: $(xsrf "$1")" -o "$3" -w '%{http_code}' -X DELETE "$API$2"; }
getj()  { curl -sS -m 20 -b "$1" "${H[@]}" -o "$3" -w '%{http_code}' "$API$2"; }

echo "── login dos 3 usuários ──"
login "$CONTRATANTE" "$PASS" "$JC" || exit 1
login "$PROF1" "$PASS" "$J1" || exit 1
login "$PROF2" "$PASS" "$J2" || exit 1
echo "  ✓ contratante, prof1, prof2 logados"

# funcao_id primária (menor id — igual ao seeder)
getj "$JC" "/api/funcoes" /tmp/ca12_func >/dev/null
FUNC=$(python3 -c "import json;d=json.load(open('/tmp/ca12_func'));fs=d.get('data') or d.get('funcoes') or d; print(min(f['id'] for f in fs))")
echo "  funcao_id primária=$FUNC"

criar_vaga() { # jar data_inicio data_fim valor obs outfile — funcao_id é UUID (ADR-018/W27.5)
  post "$1" "/api/vagas" "{\"funcao_id\":\"$FUNC\",\"data_inicio\":\"$2\",\"data_fim\":\"$3\",\"valor\":$4,\"posicoes\":2,\"observacoes\":\"$5\"}" "$6"
}
candidatar() { # jar vagaid
  local out=/tmp/ca12_cand_$$; local c
  c=$(post "$1" "/api/vagas/$2/candidaturas" "{}" "$out"); echo "$c"
}

# Offset aleatório de semanas por EXECUÇÃO: evita conflito de horário com candidaturas de
# execuções anteriores (homolog acumula). Cada run dentro da execução fica numa semana distinta.
WKOFF=$(( (RANDOM % 26) + 2 ))
echo "  offset de semanas desta execução: $WKOFF"

RUNS_OK=0
for RUN in 1 2 3; do
  echo ""
  echo "════════ RUN $RUN ════════"
  WIN=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  BASE=$(( 7*(RUN + WKOFF) + 4 ))   # semana distinta por run + offset por execução
  DAY=$(date -u -v+${BASE}d +%Y-%m-%d 2>/dev/null || date -u -d "+${BASE} days" +%Y-%m-%d)
  DI_E="${DAY}T14:00:00Z"; DF_E="${DAY}T18:00:00Z"   # V_edit
  DI_C="${DAY}T19:00:00Z"; DF_C="${DAY}T23:00:00Z"   # V_cancel (mesmo dia, sem overlap)

  c=$(criar_vaga "$JC" "$DI_E" "$DF_E" 200 "ca12-edit-r$RUN" /tmp/ca12_ve); VE=$(python3 -c "import json;print(json.load(open('/tmp/ca12_ve')).get('id',''))" 2>/dev/null)
  c2=$(criar_vaga "$JC" "$DI_C" "$DF_C" 210 "ca12-cancel-r$RUN" /tmp/ca12_vc); VC=$(python3 -c "import json;print(json.load(open('/tmp/ca12_vc')).get('id',''))" 2>/dev/null)
  echo "  vagas criadas: V_edit=$VE ($c)  V_cancel=$VC ($c2)"
  [ -n "$VE" ] && [ -n "$VC" ] || { echo "  ✗ falha ao criar vagas"; continue; }

  echo "  cenário 1: candidaturas (prof1/prof2 × V_edit/V_cancel)"
  for j in "$J1" "$J2"; do
    for v in "$VE" "$VC"; do
      cc=$(candidatar "$j" "$v"); echo "    candidatura vaga=$v → $cc"
    done
  done

  echo "  cenário 2: contratante edita V_edit (valor 200→260, material)"
  getj "$JC" "/api/vagas/$VE/editar" /tmp/ca12_ed >/dev/null
  pe=$(patch "$JC" "/api/vagas/$VE" "{\"funcao_id\":\"$FUNC\",\"data_inicio\":\"$DI_E\",\"data_fim\":\"$DF_E\",\"valor\":260,\"posicoes\":2,\"observacoes\":\"ca12-edit-r$RUN\"}" /tmp/ca12_pe)
  echo "    PATCH V_edit → $pe"

  echo "  cenário 3: contratante cancela V_cancel"
  dc=$(del "$JC" "/api/vagas/$VC" /tmp/ca12_dc); echo "    DELETE V_cancel → $dc"

  echo "  aguardando worker + logs (asserção via Cloud Logging desde $WIN)…"
  ok=0
  for try in $(seq 1 12); do
    sleep 20
    COUNTS=$(gcloud logging read "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"$WORKER_JOB\" AND jsonPayload.message=\"notificacao.email.sent\" AND timestamp>=\"$WIN\"" \
      --project="$PROJ" --limit=200 --format='value(jsonPayload.context.tipo)' 2>/dev/null | sort | uniq -c)
    CR=$(echo "$COUNTS" | awk '/candidatura_recebida/{print $1}'); CR=${CR:-0}
    VEM=$(echo "$COUNTS" | awk '/vaga_editada_material/{print $1}'); VEM=${VEM:-0}
    VCA=$(echo "$COUNTS" | awk '/vaga_cancelada/{print $1}'); VCA=${VCA:-0}
    echo "    try $try: candidatura_recebida=$CR vaga_editada_material=$VEM vaga_cancelada=$VCA"
    if [ "$CR" -ge 4 ] && [ "$VEM" -ge 2 ] && [ "$VCA" -ge 2 ]; then ok=1; break; fi
  done
  if [ "$ok" = "1" ]; then echo "  ✅ RUN $RUN OK (4/2/2)"; RUNS_OK=$((RUNS_OK+1)); else echo "  ❌ RUN $RUN FALHOU"; fi
done

echo ""
echo "════════ RESULTADO: $RUNS_OK/3 runs verdes ════════"
[ "$RUNS_OK" = "3" ] && echo "CA-12: 0 flake em 3 runs ✅" || echo "CA-12: NÃO atingiu 0 flake"
[ "$RUNS_OK" = "3" ]
