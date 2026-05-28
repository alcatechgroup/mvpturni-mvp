<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Turni · Backoffice</title>
    <style>
        :root { --chrome: #15233B; --page: #F7F4EC; --text: #0F1B2D; --text-muted: #42504A; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--page); color: var(--text); display: grid; grid-template-columns: 260px 1fr; min-height: 100vh; }
        .sidebar { background: var(--chrome); color: #ECEDE5; padding: 24px 20px; display: flex; flex-direction: column; }
        .logo { font-family: 'Bebas Neue', 'Impact', sans-serif; font-size: 22px; letter-spacing: 2px; }
        .logo .i { color: #00A868; }
        .tag { font-size: 10px; letter-spacing: 1.5px; text-transform: uppercase; opacity: 0.55; margin-top: 4px; }
        .logout-btn { margin-top: auto; background: transparent; border: 1px solid rgba(255,255,255,.16); color: rgba(236,237,229,.75); border-radius: 999px; padding: 10px; font-size: 13px; cursor: pointer; width: 100%; }
        .main { padding: 40px; }
        .greeting { font-size: 28px; font-weight: 600; }
        .sub { font-size: 14px; color: var(--text-muted); margin-top: 8px; }
    </style>
</head>
<body>
    <aside class="sidebar">
        <div class="logo">TURN<span class="i">I</span>.</div>
        <div class="tag">Backoffice</div>
        <form method="POST" action="/logout" style="margin-top: auto;">
            @csrf
            <button type="submit" class="logout-btn">Sair</button>
        </form>
    </aside>
    <main class="main">
        <h1 class="greeting">Bem-vindo, {{ auth()->user()->name }}.</h1>
        <p class="sub">Backoffice Turni — STORY-016 (placeholder). As telas operacionais chegam nas próximas estórias.</p>
    </main>
</body>
</html>
