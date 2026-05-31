#!/usr/bin/env bash
# STORY-023 — teste manual local do completar-cadastro (sem frontend ainda).
# Fala direto com a API (localhost:8001) fazendo o handshake CSRF do Sanctum.
#
# Uso:
#   scripts/test-completar-cadastro.sh preview     # renderiza o contrato (não persiste) — default
#   scripts/test-completar-cadastro.sh completar   # ASSINA: gera o aceite e vira 'ativo' (one-shot)
#   scripts/test-completar-cadastro.sh reset        # volta o usuário de teste para 'await_cadastro'
#
# Usuário de teste: profissional.teste@turni.local / Senha@Teste10  (PF, await_cadastro)

set -euo pipefail
BASE="${BASE:-http://localhost:8001}"
EMAIL="completar.pf@turni.local"
PASS="turni-dev"
J="$(mktemp)"
ACTION="${1:-preview}"

dec() { python3 -c "import urllib.parse,sys;print(urllib.parse.unquote(sys.argv[1]))" "$1"; }
tok() { grep XSRF-TOKEN "$J" | tail -1 | awk '{print $7}'; }
api() { curl -s -c "$J" -b "$J" -H "Origin: $BASE" -H "X-XSRF-TOKEN: $(dec "$(tok)")" -H "Accept: application/json" "$@"; }

reset_user() {
  ( cd "$(dirname "$0")/.." && \
    docker compose exec -T postgres psql -U turni -d turni -c "
      ALTER TABLE aceites_eletronicos DISABLE TRIGGER prevent_aceite_eletronico_mutation;
      DELETE FROM aceites_eletronicos WHERE user_id = (SELECT id FROM users WHERE email='$EMAIL');
      ALTER TABLE aceites_eletronicos ENABLE TRIGGER prevent_aceite_eletronico_mutation;" >/dev/null && \
    docker compose exec -T api php artisan tinker --execute='
      use App\Models\User; use App\Models\ProfissionalProfile;
      $u=User::where("email","'"$EMAIL"'")->first();
      $u->forceFill(["status"=>"liberado","welcome_seen_at"=>now(),"cadastro_completed_at"=>null])->save();
      ProfissionalProfile::where("user_id",$u->id)->update(["documento_encrypted"=>null,"documento_tipo"=>null,"documento_hash"=>null,"chave_pix_encrypted"=>null,"raio_max_km"=>null,"preco_hora"=>null,"bio"=>null,"funcoes_secundarias"=>null,"documento_comprobatorio_path"=>null]);
      echo "reset OK funnel=".$u->fresh()->funnelState().PHP_EOL;' )
}

if [ "$ACTION" = "reset" ]; then reset_user; exit 0; fi

echo "== 1) CSRF =="; curl -s -c "$J" -b "$J" -H "Origin: $BASE" "$BASE/sanctum/csrf-cookie" -o /dev/null -w "http %{http_code}\n"
echo "== 2) Login ($EMAIL) =="
api -H "Content-Type: application/json" -X POST "$BASE/api/login" -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}"; echo

if [ "$ACTION" = "completar" ]; then
  printf '%%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%%%EOF\n' > /tmp/turni_doc.pdf
  echo "== 3) Completar (ASSINA o contrato) =="
  api -X POST "$BASE/api/usuarios/me/completar-cadastro" \
    -F 'documento=529.982.247-25' -F 'raio_max_km=30' -F 'preco_hora=45.5' \
    -F 'chave_pix=diego.pix@turni.com.br' -F 'bio=Garcom de eventos' \
    -F 'documento_comprobatorio=@/tmp/turni_doc.pdf;type=application/pdf' -w "\nhttp %{http_code}\n"
  echo "Dica: rode 'scripts/test-completar-cadastro.sh reset' para testar de novo."
else
  echo "== 3) Preview do contrato (NÃO persiste) =="
  api -H "Content-Type: application/json" -X POST "$BASE/api/usuarios/me/completar-cadastro/preview" \
    -d '{"documento":"529.982.247-25","raio_max_km":30,"preco_hora":45.5,"chave_pix":"diego.pix@turni.com.br"}' \
    -o /tmp/turni_preview.json -w "http %{http_code}\n"
  echo "--- contrato renderizado (início) ---"
  python3 -c "import json;print('\n'.join(json.load(open('/tmp/turni_preview.json'))['conteudo_renderizado'].splitlines()[:20]))"
fi
