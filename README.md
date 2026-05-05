# TURNI · MVP Demo

Plataforma de hospitalidade on-demand · **Match IA · PIN Bilateral · Pix em 15min**

## 🚀 Demo ao vivo
https://mvpturni.web.app

## 📁 Estrutura

```
.
├── index.html              # Landing standalone com tour guiado inline (56 passos · 15min)
├── app.html                # MVP da plataforma · login multi-persona · admin/contratante/trabalhador
├── tour.css                # Estilos do tour (já inline em index.html · backup)
├── tour.js                 # Lógica do tour (já inline em index.html · backup)
├── manifest.json           # PWA manifest
├── sw.js                   # Service Worker · offline support
├── firebase.json           # Hosting config + cache headers
├── img/                    # Imagens otimizadas (32 arquivos · 6.8MB)
├── README-DEPLOY.md        # Passo-a-passo de deploy
└── .github/workflows/      # CI/CD · auto-deploy Firebase a cada push
```

## 🎬 Demo guiada · 15 min

Acesse a landing → clique no botão verde **"▶ Demo guiada · 15min"** no canto inferior direito.

O tour navega automaticamente pela plataforma com legendas estilo screencast, simulando um usuário real:
1. **Tese visual** (3 min) — landing, manifesto, parceiros Stone/Pagar.me/Noiz
2. **Pré-cadastros** (2 min) — contratante + trabalhador
3. **Curadoria admin** (1.5 min) — Rodolfo aprova
4. **Contratante abre vaga** (3 min) — Roberto da Pizza da Mooca
5. **Trabalhador candidata** (4 min) — Carlos Garçom Elite
6. **Encerramento** com summary

## 🔑 Personas para login

Senha: **qualquer texto** · a demo não valida.

| Tipo | Persona | E-mail |
|------|---------|--------|
| Admin | Rodolfo Nascimento | `rodolfo@turni.app` |
| Contratante | Roberto · Pizza da Mooca | `roberto@apizzadamooca.com.br` |
| Trabalhador | Carlos · Garçom Elite | `carlos.silva@gmail.com` |

Lista completa em `TURNI_MVP_Acessos.html` (não publicado).

## 🛠 Stack técnica
- **Frontend:** HTML/CSS/JS vanilla · zero dependências de build
- **Hosting:** Firebase Hosting · CDN global · HTTPS
- **CI/CD:** GitHub Actions · auto-deploy on push to main
- **PWA:** Service Worker + manifest.json · installable

## 📚 Documentação interna
- `ROTEIROS-DEMO-OFICIAIS.md` · 5 fluxos navegáveis + roteiro integrado 15min
- `ANALISE-MVP-MAIO26.md` · Análise War Room · 15 marcos × 2 personas
- `README-DEPLOY.md` · Passo-a-passo Firebase

---
Operada pelo **Grupo Alcatech.ia** em parceria com **Grupo Noiz · Pagar.me · Stone**
