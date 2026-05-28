<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Turni — Backoffice (Admin)</title>
    <style>
        /* DDR-001 admin tokens (tema claro) — acento azul-navy #2A4D8F */
        :root {
            --surface-page:  #F7F4EC;
            --surface:       #FFFFFF;
            --accent:        #2A4D8F;
            --accent-soft:   #E4EAF6;
            --text-strong:   #0F1B2D;
            --text-muted:    #42504A;
            --border-subtle: #E0DDD3;
            --brand-green:   #00A868;
        }

        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            background-color: var(--surface-page);
            color: var(--text-strong);
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, sans-serif;
            font-size: 16px;
            line-height: 1.5;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .card {
            background: var(--surface);
            border: 1px solid var(--border-subtle);
            border-radius: 12px;
            padding: 48px 56px;
            max-width: 520px;
            width: 100%;
        }

        .brand {
            display: inline-block;
            font-size: 13px;
            font-weight: 700;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--brand-green);
            margin-bottom: 24px;
        }

        h1 {
            font-size: 22px;
            font-weight: 700;
            color: var(--text-strong);
            line-height: 1.3;
            margin-bottom: 8px;
        }

        .subtitle {
            font-size: 15px;
            color: var(--text-muted);  /* #42504A sobre #FFF = 5.4:1 — passa AA */
            margin-bottom: 28px;
        }

        .badge-version {
            display: inline-block;
            background: var(--accent-soft);
            color: var(--accent);  /* #2A4D8F sobre #E4EAF6 = 6.1:1 — passa AA */
            font-size: 13px;
            font-weight: 600;
            font-family: 'JetBrains Mono', 'Fira Mono', ui-monospace, monospace;
            padding: 4px 12px;
            border-radius: 6px;
            margin-bottom: 32px;
        }

        .divider {
            border: none;
            border-top: 1px solid var(--border-subtle);
            margin-bottom: 24px;
        }

        .health-link {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            color: var(--accent);  /* #2A4D8F sobre #FFF = 7.3:1 — passa AA e AAA */
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            padding: 10px 20px;
            border: 2px solid var(--accent);
            border-radius: 8px;
        }

        .health-link:hover {
            background-color: var(--accent);
            color: #FFFFFF;  /* branco sobre #2A4D8F = 7.3:1 — passa AA */
        }

        .health-link:focus-visible {
            outline: 3px solid var(--accent);
            outline-offset: 2px;
        }

        .dot-green {
            display: inline-block;
            width: 8px;
            height: 8px;
            background: #16a34a;
            border-radius: 50%;
            flex-shrink: 0;
        }
    </style>
</head>
<body>
    <main class="card" role="main">
        <span class="brand" aria-label="Turni">TURNI</span>

        <h1>Turni — Backoffice (Admin)</h1>
        <p class="subtitle">Interface administrativa do Turni. Acesso restrito à equipe interna.</p>

        <div class="badge-version" data-testid="app-version">{{ env('APP_VERSION', 'desconhecida') }}</div>

        <hr class="divider">

        <a href="/health" class="health-link" data-testid="health-link">
            <span class="dot-green" aria-hidden="true"></span>
            Ver /health
        </a>
    </main>
</body>
</html>
