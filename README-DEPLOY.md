# TURNI MVP · Deploy Firebase Hosting

Passo-a-passo para subir a demo navegável em `turni-demo.web.app` (ou domínio próprio) via GitHub + Firebase Hosting.

## Pré-requisitos
- Node.js 18+ instalado
- Conta no GitHub
- Conta Google (para Firebase, free tier Spark é suficiente)

## 1. Criar repositório GitHub

```bash
# Na pasta deploy/
git init
git add .
git commit -m "feat: TURNI MVP demo navegável v1"
gh repo create turni-demo --public --source=. --push
# OU manualmente: criar repo turni-demo no github.com e fazer push
```

## 2. Instalar Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

## 3. Inicializar Firebase no projeto

```bash
cd deploy/
firebase init hosting
```

Quando perguntar:
- **Use an existing project / Create a new project** → criar novo (ex: `turni-mvp-demo`)
- **Public directory** → `.` (ponto)
- **Single-page app** → **Yes**
- **Overwrite index.html** → **No** (mantém o nosso)

## 4. Deploy

```bash
firebase deploy
```

Saída esperada:
```
✔  Deploy complete!
Hosting URL: https://turni-mvp-demo.web.app
```

## 5. Domínio próprio (opcional)

No console Firebase → Hosting → Add custom domain → seguir DNS verification. Se você tem `turni.com.br` ou `turni.app`, aponta CNAME para `turni-mvp-demo.web.app`.

## Estrutura dos arquivos

```
deploy/
├── index.html              ← landing standalone com tour inline
├── app.html                ← MVP da plataforma (login, contratante, trabalhador, admin)
├── tour.css                ← (já inline em index.html, mantido p/ referência)
├── tour.js                 ← (já inline em index.html, mantido p/ referência)
├── manifest.json           ← PWA manifest
├── sw.js                   ← Service Worker
├── firebase.json           ← config hosting + cache headers
├── .gitignore              ← arquivos ignorados pelo git
└── img/                    ← imagens otimizadas (105MB → 6.8MB)
```

## Cache headers (já configurados em `firebase.json`)
- Imagens/fontes: 30 dias
- HTML/JSON: 5 minutos (para hot fixes)
- CSS/JS: 1 hora

## Atualização de imagens

Se precisar atualizar uma imagem:
1. Coloque a versão original em `img/`
2. Otimize (max 1600px, quality 82): `convert input.png -resize 1600x1600\> -quality 82 -strip output.jpg`
3. `firebase deploy`

## Custos esperados
- **Free tier Spark:** 10GB storage, 360MB/dia transferência. Suficiente para 100-200 visitantes/dia.
- Acima disso: **Blaze (pay-as-you-go)** ~$0.026/GB transferred. Tipicamente $1-5/mês para tráfego de demo investidor.

## Roteiros de demo
Veja `ROTEIROS-DEMO-OFICIAIS.md` para os 5 fluxos navegáveis e o roteiro integrado de 15 min.

## Personas do seed (logins)
Veja `TURNI_MVP_Acessos.html` para a tabela completa.
- **Admin:** rodolfo@turni.app
- **Contratante:** roberto@apizzadamooca.com.br
- **Trabalhador:** carlos.silva@gmail.com
- Senha: qualquer texto · a demo não valida senha
