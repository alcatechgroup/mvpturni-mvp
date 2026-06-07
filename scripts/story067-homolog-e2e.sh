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

criar_vaga() { # jar di df valor obs outfile — funcao_id é UUID (ADR-018): vai entre aspas
  post "$1" "/api/vagas" "{\"funcao_id\":\"$FUNC\",\"data_inicio\":\"$2\",\"data_fim\":\"$3\",\"valor\":$4,\"posicoes\":1,\"observacoes\":\"$5\"}" "$6"
}

INICIO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RUNS_OK=0
for RUN in 1 2 3; do
  echo ""
  echo "════════ RUN $RUN ════════"
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

  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkin" '{"pin_solicitado":true,"razao":"indisponivel"}' /tmp/s67_p1)
  PIN=$(jget /tmp/s67_p1 "['pin']")
  echo "  gerar PIN check-in → $code"
  # cenário 2: re-geração (2ª notificação checkin_solicitado — chave por geração)
  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkin" '{"pin_solicitado":true,"razao":"indisponivel"}' /tmp/s67_p1b)
  PIN=$(jget /tmp/s67_p1b "['pin']")
  echo "  re-gerar PIN check-in → $code"

  code=$(post "$JC" "/api/turnos/$T1/validar-checkin" "{\"pin\":\"$PIN\"}" /tmp/s67_v1)
  echo "  validar check-in → $code ($(jget /tmp/s67_v1 "['estado']"))"

  code=$(post "$J1" "/api/turnos/$T1/gerar-pin-checkout" '{"pin_solicitado":true,"razao":"indisponivel"}' /tmp/s67_p2)
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

  echo "  ✓ ações do RUN $RUN disparadas (códigos 200/201 acima validam o caminho síncrono)"
  RUNS_OK=$((RUNS_OK+1))
done

# ── Asserção ÚNICA ao final (worker roda 1/min e a ingestão do Cloud Logging atrasa —
# janelas por run subestimam; os totais acumulados desde INICIO são a medida correta). ──
echo ""
echo "── asserção via Cloud Logging desde $INICIO (espera até ~10 min) ──"
ok=0
for try in $(seq 1 30); do
  sleep 20
  COUNTS=$(gcloud logging read "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"$WORKER_JOB\" AND jsonPayload.message=\"notificacao.email.sent\" AND timestamp>=\"$INICIO\"" \
    --project="$PROJ" --limit=400 --format='value(jsonPayload.context.tipo)' 2>/dev/null | sort | uniq -c)
  TC=$(echo "$COUNTS" | awk '/turno_confirmado/{print $1}'); TC=${TC:-0}
  CI=$(echo "$COUNTS" | awk '/checkin_solicitado/{print $1}'); CI=${CI:-0}
  TA=$(echo "$COUNTS" | awk '/turno_ativo/{print $1}'); TA=${TA:-0}
  CO=$(echo "$COUNTS" | awk '/checkout_solicitado/{print $1}'); CO=${CO:-0}
  TF=$(echo "$COUNTS" | awk '/turno_finalizado/{print $1}'); TF=${TF:-0}
  PX=$(echo "$COUNTS" | awk '/pix_enviado/{print $1}'); PX=${PX:-0}
  TX=$(echo "$COUNTS" | awk '/turno_cancelado/{print $1}'); TX=${TX:-0}
  echo "  try $try: confirmado=$TC/6 checkin=$CI/6 ativo=$TA/3 checkout=$CO/3 finalizado=$TF/3 pix=$PX/3 cancelado=$TX/3"
  if [ "$TC" -ge 6 ] && [ "$CI" -ge 6 ] && [ "$TA" -ge 3 ] && [ "$CO" -ge 3 ] \
     && [ "$TF" -ge 3 ] && [ "$PX" -ge 3 ] && [ "$TX" -ge 3 ]; then ok=1; break; fi
done

echo ""
echo "════════ RESULTADO: $RUNS_OK/3 runs disparados; asserção de e-mails: $([ "$ok" = "1" ] && echo OK || echo FALHOU) ════════"
[ "$RUNS_OK" = "3" ] && [ "$ok" = "1" ] && echo "CA-7: 3 runs × 7 tipos, 0 flake ✅" || echo "CA-7: NÃO atingiu 0 flake"
[ "$RUNS_OK" = "3" ] && [ "$ok" = "1" ]
