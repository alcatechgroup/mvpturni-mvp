<!DOCTYPE html>
<html lang="pt-BR" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Turni · Backoffice — Entrar</title>
    <meta name="robots" content="noindex,nofollow">
    <style>
        /* Tokens DDR-001 admin (azul-navy) — tema claro */
        :root {
            --page: #F7F4EC; --surface: #FFFFFF;
            --border: #E0DDD3; --text: #0F1B2D; --text-muted: #42504A;
            --accent: #2A4D8F; --on-accent: #FFFFFF; --accent-hover: #21407A;
            --chrome: #15233B;
            --error: #B83A3A; --error-soft: #FBE2E2;
            --radius-md: 12px; --radius-lg: 16px; --radius-full: 999px;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', -apple-system, sans-serif; background: var(--page); color: var(--text); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: 40px; width: 100%; max-width: 420px; box-shadow: 0 1px 2px rgba(15,27,45,.04), 0 8px 24px rgba(15,27,45,.06); }
        .logo { font-family: 'Bebas Neue', 'Impact', sans-serif; font-size: 24px; letter-spacing: 2px; color: var(--text); }
        .logo .i { color: #00A868; }
        .tag { font-family: monospace; font-size: 10px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--text-muted); margin-top: 4px; }
        .divider { border: none; border-top: 1px solid var(--border); margin: 20px 0; }
        label { display: block; font-size: 14px; font-weight: 500; margin-bottom: 6px; }
        input { width: 100%; padding: 12px 16px; border: 1px solid var(--border); border-radius: var(--radius-md); font-size: 14px; background: var(--surface); color: var(--text); outline: none; transition: border-color 0.15s; }
        input:focus { border-color: var(--accent); }
        .field { margin-bottom: 16px; }
        .btn { width: 100%; padding: 14px; background: var(--accent); color: var(--on-accent); border: none; border-radius: var(--radius-full); font-size: 14px; font-weight: 500; cursor: pointer; margin-top: 8px; transition: background 0.15s; }
        .btn:hover { background: var(--accent-hover); }
        .error { background: var(--error-soft); border: 1px solid var(--error); border-radius: var(--radius-md); padding: 12px 16px; font-size: 13px; color: var(--text); margin-bottom: 16px; display: flex; align-items: flex-start; gap: 8px; }
        .error-icon { color: var(--error); flex-shrink: 0; font-size: 16px; }
        a.forgot { font-size: 13px; color: var(--accent); text-decoration: none; display: inline-block; margin-top: 8px; }
        a.forgot:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="card" data-testid="screen-login-backoffice">
        <div class="logo">TURN<span class="i">I</span>.</div>
        <div class="tag">Backoffice</div>
        <hr class="divider">

        @if ($errors->any())
            <div class="error" role="alert" aria-live="polite" data-testid="banner-error">
                <span class="error-icon" aria-hidden="true">●</span>
                <span>{{ $errors->first() }}</span>
            </div>
        @endif

        <form method="POST" action="/login">
            @csrf
            <div class="field">
                <label for="email">E-mail</label>
                <input type="email" id="email" name="email" value="{{ old('email') }}"
                    autocomplete="email" required data-testid="input-email"
                    aria-describedby="{{ $errors->has('email') ? 'email-error' : '' }}">
            </div>
            <div class="field">
                <label for="password">Senha</label>
                <input type="password" id="password" name="password"
                    autocomplete="current-password" required data-testid="input-password">
            </div>
            <button type="submit" class="btn" data-testid="btn-submit-login">Entrar</button>
        </form>
        <a href="/esqueci-minha-senha" class="forgot">Esqueci minha senha</a>
    </div>
</body>
</html>
