#!/usr/bin/env bash
# STORY-085 — smoke MANUAL da avaliação recíproca em HOMOLOG (sem UI ainda — 087/088 trazem as
# telas). Usa a massa do AvaliacaoSeeder: par dedicado profissional.avaliacao / contratante.avaliacao
# com 3 turnos já avaliados (score/nível/depoimentos) + 1 turno PENDENTE.
#
# O que faz (read-only + 1 escrita reversível por re-seed):
#   1. loga como contratante.avaliacao (Sanctum SPA stateful: csrf-cookie → /login);
#   2. GET /api/perfil/{profissional} → mostra score/nível/XP/xp_proximo_nivel + depoimentos
#      (nominais sobre o profissional);
#   3. GET /api/perfil/{contratante} (logado como o profissional) → depoimentos ANÔNIMOS (LGPD);
#   4. acha o turno finalizado PENDENTE (sem avaliação do contratante) e envia 5★ + comentário;
#   5. re-GET do perfil do profissional → score/XP recomputados (motor síncrono).
#
# Uso: scripts/story085-homolog-smoke.sh
set -uo pipefail

API="https://api.homolog.turni.com.br"
ORIG="https://app.homolog.turni.com.br"
PASS="${ADMIN_SEED_PASSWORD:-turni-dev}"
EMP="contratante.avaliacao@turni.local"
PRO="profissional.avaliacao@turni.local"

H=(-H "Origin: $ORIG" -H "Referer: $ORIG/" -H "Accept: application/json")
JE=$(mktemp); JP=$(mktemp)
trap 'rm -f "$JE" "$JP" /tmp/s85_*' EXIT

xsrf() { awk '/XSRF-TOKEN/{print $7}' "$1" | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))"; }

login() { # email pass jar
  curl -sS -m 15 -c "$3" -o /dev/null "${H[@]}" "$API/sanctum/csrf-cookie"
  local code
  code=$(curl -sS -m 20 -b "$3" -c "$3" -o /dev/null -w '%{http_code}' "${H[@]}" \
    -H "X-XSRF-TOKEN: $(xsrf "$3")" -H "Content-Type: application/json" \
    -X POST "$API/login" -d "{\"email\":\"$1\",\"password\":\"$2\"}")
  [ "$code" = "200" ] || { echo "  ✗ login $1 → HTTP $code"; return 1; }
  echo "  ✓ login $1"
}
getj() { curl -sS -m 20 -b "$1" "${H[@]}" -o "$3" -w '%{http_code}' "$API$2"; }
post() { curl -sS -m 25 -b "$1" -c "$1" "${H[@]}" -H "X-XSRF-TOKEN: $(xsrf "$1")" \
    -H "Content-Type: application/json" -o "$4" -w '%{http_code}' -X POST "$API$2" -d "$3"; }
me() { curl -sS -m 15 -b "$1" "${H[@]}" "$API/api/user" | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])"; }

echo "── login do par de avaliação ──"
login "$EMP" "$PASS" "$JE" || exit 1
login "$PRO" "$PASS" "$JP" || exit 1
EMP_ID=$(me "$JE"); PRO_ID=$(me "$JP")
echo "  contratante=$EMP_ID  profissional=$PRO_ID"

echo "── perfil do profissional (nominal: estabelecimento nos depoimentos) ──"
getj "$JE" "/api/perfil/$PRO_ID" /tmp/s85_pro >/dev/null
python3 - "$PRO_ID" <<'PY'
import json,sys
d=json.load(open('/tmp/s85_pro'))
print(f"  score={d['score']} nivel={d['nivel']} turnos={d['turnos_realizados']} selo_novo={d['selo_novo']}")
for x in d['depoimentos']:
    print(f"    {x['estrelas']}★  «{x['comentario']}»  — {x['autor_nome']}")
PY

echo "── perfil do contratante (anônimo: depoimentos sem nome do profissional — LGPD) ──"
getj "$JP" "/api/perfil/$EMP_ID" /tmp/s85_emp >/dev/null
python3 - <<'PY'
import json
d=json.load(open('/tmp/s85_emp'))
print(f"  papel={d['papel']} score={d['score']}")
for x in d['depoimentos']:
    print(f"    {x['estrelas']}★  «{x['comentario']}»  — autor_nome={x['autor_nome']}")
PY

echo "── acha o turno finalizado PENDENTE e avalia ao vivo (contratante → profissional) ──"
getj "$JE" "/api/contratante/turnos" /tmp/s85_turnos >/dev/null
# Tenta avaliar cada turno; o pendente devolve 201, os já avaliados 409.
ALVO=$(python3 - <<'PY'
import json
d=json.load(open('/tmp/s85_turnos'))
ids=[]
def walk(o):
    if isinstance(o,dict):
        if 'id' in o and o.get('status') in ('finalizado','finalizado_ajustado'): ids.append(o['id'])
        for v in o.values(): walk(v)
    elif isinstance(o,list):
        for v in o: walk(v)
walk(d)
print('\n'.join(dict.fromkeys(ids)))
PY
)
DONE=0
for T in $ALVO; do
  CODE=$(post "$JE" "/api/turnos/$T/avaliar" '{"estrelas":5,"comentario":"Avaliação ao vivo via smoke STORY-085."}' /tmp/s85_av)
  if [ "$CODE" = "201" ]; then echo "  ✓ avaliado turno $T (HTTP 201)"; DONE=1; break;
  elif [ "$CODE" = "409" ]; then echo "  · turno $T já avaliado (409) — tentando o próximo";
  else echo "  ? turno $T → HTTP $CODE"; fi
done
[ "$DONE" = "1" ] || echo "  (nenhum turno pendente — re-rode o seed se já avaliou tudo)"

echo "── perfil do profissional DEPOIS (score/XP recomputados pelo motor) ──"
getj "$JE" "/api/perfil/$PRO_ID" /tmp/s85_pro2 >/dev/null
python3 - <<'PY'
import json
d=json.load(open('/tmp/s85_pro2'))
print(f"  score={d['score']} nivel={d['nivel']} turnos={d['turnos_realizados']} total_avaliacoes={d['total_avaliacoes']}")
PY
echo "✓ smoke concluído."
