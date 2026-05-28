<!DOCTYPE html>
<html lang="pt-BR" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Turni · Backoffice — Acesso negado</title>
    <meta name="robots" content="noindex,nofollow">
    <style>
        :root {
            --page: #F7F4EC; --surface: #FFFFFF; --border: #E0DDD3;
            --text: #0F1B2D; --text-muted: #42504A; --accent: #2A4D8F;
            --on-accent: #FFFFFF; --accent-hover: #21407A;
            --radius-md: 12px; --radius-lg: 16px; --radius-full: 999px;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--page); color: var(--text); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 40px; width: 100%; max-width: 460px; text-align: center; box-shadow: 0 1px 2px rgba(15,27,45,.04), 0 8px 24px rgba(15,27,45,.06); }
        .logo { font-family: 'Bebas Neue', 'Impact', sans-serif; font-size: 24px; letter-spacing: 2px; color: var(--text); }
        .logo .i { color: #00A868; }
        .code { font-size: 13px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--text-muted); margin-top: 24px; }
        h1 { font-size: 22px; margin-top: 8px; }
        p { font-size: 14px; color: var(--text-muted); margin-top: 12px; line-height: 1.5; }
        a.btn { display: inline-block; margin-top: 28px; padding: 12px 28px; background: var(--accent); color: var(--on-accent); border-radius: var(--radius-full); font-size: 14px; font-weight: 500; text-decoration: none; }
        a.btn:hover { background: var(--accent-hover); }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">TURN<span class="i">I</span>.</div>
        <div class="code">403 · Acesso negado</div>
        <h1>Área restrita a administradores</h1>
        <p>Esta conta não tem permissão para acessar o Backoffice. Se você é
           profissional ou contratante, use o aplicativo do Turni.</p>
        <a class="btn" href="/login">Voltar ao login</a>
    </div>
</body>
</html>
