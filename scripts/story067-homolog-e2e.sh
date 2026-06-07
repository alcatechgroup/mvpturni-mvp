#!/usr/bin/env bash
# STORY-067 CA-7 — E2E de notificação dos eventos do TURNO em HOMOLOG, 3 cenários × 3 runs.
#
# Espelha a disciplina do ca12-homolog-e2e.sh (STORY-053): homolog usa Resend (não Mailpit),
# então a asserção de "recebeu e-mail" é via Cloud Logging (`notificacao.email.sent` no worker)
# com o label `tipo`. Recipientes ENTREGÁVEIS (Gmail) do Ca12EmailSmokeSeeder. Por run:
#   - cenário 1 (ciclo feliz, prof1):  aprovar → turno_confirmado; PIN check-in →
#     checkin_solicitado; validar → turno_ativo; PIN check-out → checkout_solicitado;
#     validar → turno_finalizado; captura+Pix (fake ~30s) → pix_enviado.
#   - cenário 2 (re-geração de PIN): prof1 re-gera o PIN de check-in antes de validar →
#     2º checkin_solicitado (idempotência por geração — CA-3 vivo).
#   - cenário 3 (cancelamento, prof2): aprovar → turno_confirmado; contratante cancela →
#     turno_cancelado (com motivo).
# `no_show_pro` NÃO entra no E2E (exige 2h de timeout do cron) — coberto por teste de feature.
# Habitualidade: profs são MEI e homolog acumula execuções → aprovação sempre com override:true
# (o carimbo só acontece quando há risco real — AprovarCandidaturaService).
#
# Uso: scripts/story067-homolog-e2e.sh   (sai !=0 se algum run falhar a asserção)
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
getj() { curl -sS -m 20 -b "$1" "${H[@]}" -o "$3" -w '%{http_code}' "$API$2"; }

jget() { python3 -c "import json,sys;d=json.load(open('$1'));print(d$2)" 2>/dev/null; }

echo "── login dos 3 usuários ──"
login "$CONTRATANTE" "$PASS" "$JC" || exit 1
login "$PROF1" "$PASS" "$J1" || exit 1
login "$PROF2" "$PASS" "$J2" || exit 1
echo "  ✓ contratante, prof1, prof2 logados"

getj "$JC" "/api/funcoes" /tmp/s67_func >/dev/null
FUNC=$(python3 -c "import json;d=json.load(open('/tmp/s67_func'));fs=d.get('data') or d.get('funcoes') or d; print(min(f['id'] for f in fs))")
echo "  funcao_id primária=$FUNC"

iso_in() { # +minutos → ISO UTC
  python3 -c "from datetime import datetime,timedelta,timezone;print((datetime.now(timezone.utc)+timedelta(minutes=$1)).strftime('%Y-%m-%dT%H:%M:00Z'))"
}

criar_vaga() { # jar di df valor obs outfile
  post "$1" "/api/vagas" "{\"funcao_id\":$FUNC,\"data_inicio\":\"$2\",\"data_fim\":\"$3\",\"valor\":$4,\"posicoes\":1,\"observacoes\":\"$5\"}" "$6"
}

RUNS_OK=0
for RUN in 1 2 3; do
  echo ""
  echo "════════ RUN $RUN ════════"
  WIN=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # data_inicio próxima (PIN de check-in abre 30 min antes — config/turno.php); runs não
  # conflitam: candidaturas saem de `pendente` no aprovar dentro do próprio run.
  DI=$(iso_in 10); DF=$(iso_in 130)

  # ── cenário 1+2: ciclo feliz com re-geração de PIN (prof1) ──
  criar_vaga "$JC" "$DI" "$DF" 200 "s67-full-r$RUN" /tmp/s67_vf >/dev/null
  VF=$(jget /tmp/s67_vf "['id']")
  [ -n "$VF" ] || { echo "  ✗ vaga full não criada"; continue; }

  post "$J1" "/api/vagas/$VF/candidaturas" "{}" /tmp/s67_c1 >/dev/null
  C1=$(jget /tmp/s67_c1 "['id']")
  code=$(post "$JC" "/api/candidaturas/$C1/aprovar" '{"override":true}' /tmp/s67_t1)
  T1=$(jget /tmp/s67_t1 "['turno']['id']")
  echo "  aprovar prof1 → $code turno=$T1"
  [ -n "$T1" ] || { echo "  ✗ aprovação full falhou"; continue; }

  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkin" '{"razao":"indisponivel"}' /tmp/s67_p1)
  PIN=$(jget /tmp/s67_p1 "['pin']")
  echo "  gerar PIN check-in → $code"
  # cenário 2: re-geração (2ª notificação checkin_solicitado — chave por geração)
  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkin" '{"razao":"indisponivel"}' /tmp/s67_p1b)
  PIN=$(jget /tmp/s67_p1b "['pin']")
  echo "  re-gerar PIN check-in → $code"

  code=$(post "$JC" "/api/turnos/$T1/validar-checkin" "{\"pin\":\"$PIN\"}" /tmp/s67_v1)
  echo "  validar check-in → $code ($(jget /tmp/s67_v1 "['estado']"))"

  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkout" '{"razao":"indisponivel"}' /tmp/s67_p2)
  PINOUT=$(jget /tmp/s67_p2 "['pin']")
  echo "  gerar PIN check-out → $code"
  code=$(post "$JC" "/api/turnos/$T1/validar-checkout" "{\"pin\":\"$PINOUT\"}" /tmp/s67_v2)
  echo "  validar check-out → $code ($(jget /tmp/s67_v2 "['estado']"))"

  # ── cenário 3: cancelamento antes do check-in (prof2) ──
  DI2=$(iso_in 15); DF2=$(iso_in 135)
  criar_vaga "$JC" "$DI2" "$DF2" 210 "s67-cancel-r$RUN" /tmp/s67_vc >/dev/null
  VC=$(jget /tmp/s67_vc "['id']")
  post "$J2" "/api/vagas/$VC/candidaturas" "{}" /tmp/s67_c2 >/dev/null
  C2=$(jget /tmp/s67_c2 "['id']")
  code=$(post "$JC" "/api/candidaturas/$C2/aprovar" '{"override":true}' /tmp/s67_t2)
  T2=$(jget /tmp/s67_t2 "['turno']['id']")
  echo "  aprovar prof2 → $code turno=$T2"
  code=$(post "$JC" "/api/turnos/$T2/cancelar" '{"motivo":"s67 e2e — cancelamento de teste"}' /tmp/s67_cc)
  echo "  cancelar turno prof2 → $code"

  echo "  aguardando worker + captura + Pix (asserção via Cloud Logging desde $WIN)…"
  ok=0
  for try in $(seq 1 18); do
    sleep 20
    COUNTS=$(gcloud logging read "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"$WORKER_JOB\" AND jsonPayload.message=\"notificacao.email.sent\" AND timestamp>=\"$WIN\"" \
      --project="$PROJ" --limit=200 --format='value(jsonPayload.context.tipo)' 2>/dev/null | sort | uniq -c)
    TC=$(echo "$COUNTS" | awk '/turno_confirmado/{print $1}'); TC=${TC:-0}
    CI=$(echo "$COUNTS" | awk '/checkin_solicitado/{print $1}'); CI=${CI:-0}
    TA=$(echo "$COUNTS" | awk '/turno_ativo/{print $1}'); TA=${TA:-0}
    CO=$(echo "$COUNTS" | awk '/checkout_solicitado/{print $1}'); CO=${CO:-0}
    TF=$(echo "$COUNTS" | awk '/turno_finalizado/{print $1}'); TF=${TF:-0}
    PX=$(echo "$COUNTS" | awk '/pix_enviado/{print $1}'); PX=${PX:-0}
    TX=$(echo "$COUNTS" | awk '/turno_cancelado/{print $1}'); TX=${TX:-0}
    echo "    try $try: confirmado=$TC checkin=$CI ativo=$TA checkout=$CO finalizado=$TF pix=$PX cancelado=$TX"
    if [ "$TC" -ge 2 ] && [ "$CI" -ge 2 ] && [ "$TA" -ge 1 ] && [ "$CO" -ge 1 ] \
       && [ "$TF" -ge 1 ] && [ "$PX" -ge 1 ] && [ "$TX" -ge 1 ]; then ok=1; break; fi
  done
  if [ "$ok" = "1" ]; then echo "  ✅ RUN $RUN OK (2/2/1/1/1/1/1)"; RUNS_OK=$((RUNS_OK+1)); else echo "  ❌ RUN $RUN FALHOU"; fi
done

echo ""
echo "════════ RESULTADO: $RUNS_OK/3 runs verdes ════════"
[ "$RUNS_OK" = "3" ] && echo "CA-7: 0 flake em 3 runs ✅" || echo "CA-7: NÃO atingiu 0 flake"
[ "$RUNS_OK" = "3" ]
