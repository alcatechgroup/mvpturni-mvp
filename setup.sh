#!/bin/bash
# TURNI · script de setup inicial do repo + Firebase
# Rodar 1x na pasta deploy/ depois de descompactar

set -e

echo "🚀 TURNI · setup inicial do repo + Firebase"
echo ""

# 1. Git init + remote
if [ ! -d ".git" ]; then
  git init
  git branch -M main
  git remote add origin https://github.com/alcatechgroup/mvpturni.git
  echo "✓ Git inicializado · remote alcatechgroup/mvpturni adicionado"
fi

# 2. Add + commit
git add .
git commit -m "feat: TURNI MVP demo navegável v1 · landing + app + tour 15min" || true
echo "✓ Commit criado"

# 3. Push
echo ""
echo "📤 Fazendo push para GitHub..."
git push -u origin main
echo "✓ Push concluído"
echo ""

# 4. Firebase
echo "🔥 Configurando Firebase Hosting..."
if ! command -v firebase &> /dev/null; then
  echo "Instalando Firebase CLI..."
  npm install -g firebase-tools
fi

firebase login --no-localhost
firebase use --add mvpturni
firebase deploy --only hosting

echo ""
echo "✅ Deploy completo!"
echo "🌐 URL: https://mvpturni.web.app"
echo ""
echo "Para deploy automático em cada push:"
echo "1. firebase init hosting:github (cria service account)"
echo "2. Adiciona FIREBASE_SERVICE_ACCOUNT no GitHub Secrets"
echo "3. A partir daí, todo push para main faz deploy automático"
