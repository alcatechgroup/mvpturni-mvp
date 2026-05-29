<!DOCTYPE html>
<html lang="pt-BR" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>{{ $title ?? 'Turni · Backoffice' }}</title>
    @livewireStyles
    <style>
        /* Tokens DDR-001 admin (azul-navy) — claro + escuro (preview-backoffice.html) */
        :root, [data-theme="light"]{
            --page:#F7F4EC; --surface:#FFFFFF; --sunken:#F0EDE3; --muted-s:#E8E5DB;
            --border:#E0DDD3; --border-strong:#C8C5BB;
            --text:#0F1B2D; --text-muted:#42504A; --text-subtle:#6F7C72;
            --shadow:0 1px 2px rgba(15,27,45,.04),0 8px 24px rgba(15,27,45,.06);
            --success:#2D7A4F; --success-soft:#E2F0E5;
            --warning:#9A6E25; --warning-soft:#FBEED1;
            --error:#B83A3A; --error-soft:#FBE2E2;
            --info:#4A6FA5; --info-soft:#E0E9F5;
            --sem-on:#FFFFFF;
            --accent:#2A4D8F; --on-accent:#FFFFFF; --accent-soft:#E4EAF6; --accent-hover:#21407A; --chrome:#15233B;
            --main-tint:transparent;
        }
        [data-theme="dark"]{
            --page:#0B1018; --surface:#141B26; --sunken:#1B2433; --muted-s:#26303F;
            --border:#24324A; --border-strong:#34466A;
            --text:#ECEDE5; --text-muted:#AFB8C6; --text-subtle:#8893A3;
            --shadow:0 1px 2px rgba(0,0,0,.3),0 8px 24px rgba(0,0,0,.35);
            --success:#5FA37C; --success-soft:rgba(95,163,124,.16);
            --warning:#D4A95C; --warning-soft:rgba(212,169,92,.16);
            --error:#D85A5A; --error-soft:rgba(216,90,90,.16);
            --info:#6A8FCC; --info-soft:rgba(106,143,204,.16);
            --sem-on:#0E1626;
            --accent:#5B8DEF; --on-accent:#0E1626; --accent-soft:rgba(91,141,239,.18); --accent-hover:#74A0F2; --chrome:#122039;
            --main-tint:radial-gradient(900px 500px at 100% 0,rgba(91,141,239,.12),transparent 60%);
        }
        *{box-sizing:border-box;margin:0;padding:0}
        body{font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:var(--page);color:var(--text);line-height:1.5}
        .mono{font-family:'JetBrains Mono',ui-monospace,monospace}
        a{color:inherit}

        .shell{display:grid;grid-template-columns:260px 1fr;min-height:100vh}
        .sidebar{background:var(--chrome);color:#ECEDE5;display:flex;flex-direction:column;border-right:1px solid rgba(255,255,255,.08)}
        .sb-head{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08)}
        .sb-logo{font-family:'Bebas Neue','Impact',sans-serif;font-weight:700;letter-spacing:2px;font-size:22px}.sb-logo .i{color:#00A868}
        .sb-tag{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:rgba(236,237,229,.55);margin-top:6px}
        .sb-user{display:flex;align-items:center;gap:10px;padding:14px 20px;border-bottom:1px solid rgba(255,255,255,.08)}
        .sb-av{width:36px;height:36px;border-radius:999px;background:var(--accent);color:var(--on-accent);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:14px}
        .sb-uname{font-size:14px;font-weight:500}.sb-urole{font-family:'JetBrains Mono',monospace;font-size:10px;color:rgba(236,237,229,.6);margin-top:2px}
        .sb-sec{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:rgba(236,237,229,.45);padding:18px 20px 6px}
        .sb-item{display:flex;align-items:center;gap:12px;margin:0 12px 2px;padding:10px 14px;border-radius:10px;color:rgba(236,237,229,.85);font-size:14px;font-weight:500;cursor:pointer;text-decoration:none}
        .sb-item:hover{background:rgba(255,255,255,.06)}
        .sb-item.active{background:rgba(91,141,239,.30);color:#fff}
        .sb-item .ic{width:16px;height:16px;border-radius:5px;background:currentColor;opacity:.55;flex-shrink:0}
        .sb-item.active .ic{opacity:1}
        .sb-count{margin-left:auto;font-family:'JetBrains Mono',monospace;font-size:11px;background:rgba(255,255,255,.1);padding:2px 8px;border-radius:999px}
        .sb-item.active .sb-count{background:var(--accent);color:#fff}
        .sb-foot{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);display:flex;flex-direction:column;gap:8px}
        .logout{width:100%;border:1px solid rgba(255,255,255,.16);background:transparent;color:rgba(236,237,229,.75);border-radius:999px;padding:9px;font-size:13px;cursor:pointer}
        .logout:hover{background:rgba(255,255,255,.08);color:#fff}
        .theme-toggle{width:100%;border:1px solid rgba(255,255,255,.16);background:transparent;color:rgba(236,237,229,.55);border-radius:999px;padding:7px;font-size:11px;cursor:pointer;font-family:'JetBrains Mono',monospace;letter-spacing:.5px;text-transform:uppercase}

        .main{padding:28px 40px 64px;background-image:var(--main-tint);position:relative}
        .crumb{font-family:'JetBrains Mono',monospace;font-size:11px;letter-spacing:1.5px;text-transform:uppercase;color:var(--text-subtle)}
        .main-h{font-size:28px;font-weight:600;letter-spacing:-.4px;margin-top:6px}
        .main-d{font-size:14px;color:var(--text-muted);margin-top:4px;margin-bottom:22px}

        .stats{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:20px}
        .stat{background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:16px 18px;box-shadow:var(--shadow)}
        .stat .k{font-family:'JetBrains Mono',monospace;font-size:11px;letter-spacing:1px;text-transform:uppercase;color:var(--text-subtle)}
        .stat .v{font-size:28px;font-weight:600;margin-top:6px;letter-spacing:-.5px}
        .stat .sub{font-size:12px;color:var(--text-muted);margin-top:4px}

        .feedback{display:flex;align-items:center;gap:10px;border-radius:12px;padding:12px 16px;margin-bottom:18px;font-size:13px;background:var(--info-soft);color:var(--text)}
        .feedback .ic{width:18px;height:18px;border-radius:999px;background:var(--info);flex-shrink:0;display:flex;align-items:center;justify-content:center;color:#fff;font-size:12px;font-weight:700}

        .filters{display:flex;gap:18px;align-items:center;margin-bottom:16px;flex-wrap:wrap}
        .seg{display:inline-flex;background:var(--surface);border:1px solid var(--border);border-radius:999px;padding:3px}
        .seg button{border:none;background:transparent;color:var(--text-muted);font-size:13px;font-weight:500;padding:7px 14px;border-radius:999px;cursor:pointer;font-family:inherit}
        .seg button.on{background:var(--accent);color:var(--on-accent)}
        .flabel{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--text-subtle)}

        .panel{background:var(--surface);border:1px solid var(--border);border-radius:16px;box-shadow:var(--shadow);overflow:hidden}
        .panel-h{display:flex;align-items:center;justify-content:space-between;padding:14px 20px;border-bottom:1px solid var(--border)}
        .panel-h h3{font-size:16px;font-weight:600}
        .panel-h .res{font-size:13px;color:var(--text-subtle)}
        table{width:100%;border-collapse:collapse;font-size:14px}
        th{text-align:left;font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--text-subtle);font-weight:500;padding:11px 20px;border-bottom:1px solid var(--border)}
        td{padding:12px 20px;border-bottom:1px solid var(--border);color:var(--text);vertical-align:middle}
        tbody tr:last-child td{border-bottom:0}
        tbody tr:hover td{background:var(--sunken)}
        .cell-id{display:flex;align-items:center;gap:12px}
        .av{width:40px;height:40px;border-radius:999px;flex-shrink:0;background:var(--accent-soft);color:var(--accent);display:flex;align-items:center;justify-content:center;font-weight:600;font-size:15px;object-fit:cover;overflow:hidden}
        .av img{width:100%;height:100%;object-fit:cover;border-radius:999px}
        .cell-name{font-weight:500}.cell-sub{font-size:12px;color:var(--text-subtle);margin-top:2px}
        .chip{display:inline-flex;align-items:center;gap:6px;border-radius:999px;padding:4px 11px;font-size:12px;font-weight:500}
        .chip .ic{width:8px;height:8px;border-radius:2px}
        .sla-ok{background:var(--success-soft);color:var(--text)} .sla-ok .ic{background:var(--success);border-radius:999px}
        .sla-warn{background:var(--warning-soft);color:var(--text)} .sla-warn .ic{background:var(--warning);clip-path:polygon(50% 0,100% 100%,0 100%)}
        .sla-late{background:var(--error-soft);color:var(--text)} .sla-late .ic{background:var(--error)}
        td.right{text-align:right}

        .btn{border-radius:999px;padding:8px 16px;font-family:inherit;font-size:13px;font-weight:500;cursor:pointer;border:1px solid transparent;display:inline-flex;align-items:center;gap:8px}
        .btn-outline{background:transparent;color:var(--text);border-color:var(--border-strong)} .btn-outline:hover{border-color:var(--text-muted)}
        .btn-success{background:var(--success);color:var(--sem-on)}
        .btn-danger{background:transparent;color:var(--error);border-color:var(--error)} .btn-danger:hover{background:var(--error-soft)}
        .btn-block{width:100%;justify-content:center;padding:12px}
        .btn-solid-danger{background:var(--error);color:#fff}
        .btn-solid-success{background:var(--success);color:var(--sem-on)}
        .btn-ghost{background:transparent;color:var(--text);border-color:var(--border-strong)}

        .pager{display:flex;align-items:center;gap:10px;justify-content:center;margin-top:18px;font-size:13px;color:var(--text-muted)}
        .pager nav{display:flex;gap:8px;align-items:center}
        .pager a,.pager span[aria-current]{display:inline-flex;background:var(--surface);border:1px solid var(--border);border-radius:999px;padding:6px 12px;font-size:13px;text-decoration:none;color:var(--text)}
        .pager [aria-current]{background:var(--accent);color:var(--on-accent);border-color:transparent}

        .sk{height:14px;border-radius:6px;background:var(--muted-s)}
        @keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}} .sk{animation:pulse 1.4s ease-in-out infinite}

        .empty{text-align:center;padding:56px 24px}
        .empty .mark{width:56px;height:56px;border-radius:999px;background:var(--success-soft);color:var(--success);display:flex;align-items:center;justify-content:center;font-size:26px;margin:0 auto 14px}
        .empty .mark.neutral{background:var(--sunken);color:var(--text-subtle)}
        .empty h4{font-size:18px;font-weight:600}
        .empty p{font-size:14px;color:var(--text-muted);margin:8px auto 16px;max-width:380px}

        .scrim{position:fixed;inset:0;background:rgba(15,27,45,.45);z-index:60}
        .drawer{position:fixed;top:0;right:0;bottom:0;width:520px;max-width:100%;background:var(--surface);border-left:1px solid var(--border);box-shadow:var(--shadow);z-index:61;display:flex;flex-direction:column}
        .dw-h{display:flex;align-items:center;justify-content:space-between;padding:18px 22px;border-bottom:1px solid var(--border)}
        .dw-h h3{font-size:16px;font-weight:600}
        .dw-close{background:transparent;border:none;font-size:20px;color:var(--text-muted);cursor:pointer;line-height:1;padding:4px}
        .dw-body{padding:22px;overflow:auto;flex:1}
        .dw-id{display:flex;gap:16px;align-items:center;margin-bottom:6px}
        .dw-id .av{width:84px;height:84px;font-size:30px}
        .dw-id .nm{font-size:20px;font-weight:600}
        .dw-id .ro{font-size:13px;color:var(--text-muted);margin-top:2px}
        .kv{display:grid;grid-template-columns:140px 1fr;gap:10px 14px;font-size:14px;padding:16px 0;border-top:1px solid var(--border);margin-top:14px}
        .kv dt{color:var(--text-subtle);font-size:13px}.kv dd{color:var(--text);word-break:break-word}
        .kv a{color:var(--accent);text-decoration:none}.kv a:hover{text-decoration:underline}
        .dw-foot{padding:18px 22px;border-top:1px solid var(--border);display:flex;flex-direction:column;gap:10px}

        .dlg-scrim{position:fixed;inset:0;background:rgba(15,27,45,.5);z-index:70;display:flex;align-items:center;justify-content:center;padding:20px}
        .dlg{background:var(--surface);border-radius:16px;box-shadow:var(--shadow);max-width:420px;width:100%;padding:24px}
        .dlg h4{font-size:18px;font-weight:600}
        .dlg p{font-size:14px;color:var(--text-muted);margin:10px 0 20px}
        .dlg-actions{display:flex;gap:10px;justify-content:flex-end}
        .dlg .btn{padding:10px 18px}

        .toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);z-index:90;background:var(--text);color:var(--page);padding:13px 18px;border-radius:12px;font-size:14px;box-shadow:var(--shadow);display:flex;align-items:center;gap:10px;max-width:90%}
        .toast.err{background:var(--error);color:#fff}
        .toast .dot{width:8px;height:8px;border-radius:999px;background:var(--success);flex-shrink:0}
        .toast.err .dot{background:#fff}

        .narrow-warn{display:none;background:var(--warning-soft);color:var(--text);padding:10px 16px;font-size:13px;text-align:center;border-radius:10px;margin-bottom:16px}
        @media(max-width:1023px){
            .shell{grid-template-columns:1fr}.sidebar{display:none}
            .stats{grid-template-columns:1fr}.narrow-warn{display:block}.main{padding:20px}
            .drawer{width:100%}
        }
        /* STORY-020 — editor de templates */
        .btn-primary{background:var(--accent);color:var(--on-accent)} .btn-primary:hover{background:var(--accent-hover)}
        .back{display:inline-block;font-size:13px;color:var(--accent);text-decoration:none;margin:8px 0 2px} .back:hover{text-decoration:underline}
        .head-row{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-top:6px;margin-bottom:18px}
        .t-name{font-weight:500} .t-sub{font-size:12px;color:var(--text-subtle);margin-top:3px}
        .chip.active{background:var(--accent-soft);color:var(--accent)} .chip.active .ic{background:var(--accent);border-radius:999px}
        .chip.hist{background:var(--sunken);color:var(--text-subtle)} .chip.hist .ic{background:var(--text-subtle);border-radius:999px}
        .doc{padding:22px 24px;font-size:14px;color:var(--text);overflow-wrap:anywhere}
        .doc h1{font-size:20px;margin:6px 0 10px;font-weight:600}
        .doc h2{font-size:17px;margin:18px 0 8px;font-weight:600}
        .doc h3{font-size:15px;margin:14px 0 6px;font-weight:600}
        .doc p{margin:8px 0;color:var(--text-muted)}
        .doc ul,.doc ol{margin:8px 0 8px 22px;color:var(--text-muted)}
        .doc li{margin:4px 0}
        .doc strong{color:var(--text)}
        .doc hr{border:0;border-top:1px solid var(--border);margin:16px 0}
        .ph{font-family:'JetBrains Mono',monospace;font-size:12px;background:var(--accent-soft);color:var(--accent);border-radius:6px;padding:1px 6px;white-space:nowrap}
        .ph-bad{background:var(--error-soft);color:var(--error)}
        .hist-row{display:flex;align-items:center;gap:14px;padding:14px 20px;border-bottom:1px solid var(--border);flex-wrap:wrap}
        .hist-row:last-child{border-bottom:0}
        .hist-meta{flex:1;min-width:160px;font-size:13px;color:var(--text-muted)} .hist-meta .v{font-weight:600;color:var(--text)}
        .hist-doc{flex-basis:100%;background:var(--sunken);border-radius:12px;margin-top:6px}
        .editor-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:14px}
        .pane{background:var(--surface);border:1px solid var(--border);border-radius:14px;box-shadow:var(--shadow);display:flex;flex-direction:column;min-height:440px;overflow:hidden}
        .pane-h{font-family:'JetBrains Mono',monospace;font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--text-subtle);padding:12px 16px;border-bottom:1px solid var(--border)}
        .pane textarea{flex:1;border:0;background:var(--sunken);color:var(--text);padding:16px;font-family:'JetBrains Mono',monospace;font-size:13px;line-height:1.6;resize:none;outline:none}
        .pane textarea:focus{box-shadow:inset 0 0 0 2px var(--accent)}
        .pane .preview{flex:1;overflow:auto}
        .help{display:flex;gap:10px;align-items:flex-start;background:var(--info-soft);border-radius:12px;padding:12px 16px;font-size:13px;color:var(--text);margin-bottom:14px}
        .help .ic{width:18px;height:18px;border-radius:999px;background:var(--info);color:#fff;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700}
        .help a{color:var(--accent)}
        .editor-foot{display:flex;justify-content:space-between;align-items:center;gap:12px}
        .banner{display:flex;gap:10px;align-items:flex-start;border-radius:12px;padding:12px 16px;font-size:13px;margin-bottom:14px}
        .banner.err{background:var(--error-soft);color:var(--text)} .banner.warn{background:var(--warning-soft);color:var(--text)}
        .banner .ic{width:18px;height:18px;border-radius:999px;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:#fff}
        .banner.err .ic{background:var(--error)} .banner.warn .ic{background:var(--warning)}
        .ph-list{list-style:none;font-family:'JetBrains Mono',monospace;font-size:12px;color:var(--text-muted);columns:2;gap:18px;margin:0;padding:0}
        .ph-list li{margin:3px 0}
        .btn[disabled]{opacity:.5;cursor:not-allowed}
        @media(max-width:1023px){.editor-grid{grid-template-columns:1fr}}
        [x-cloak]{display:none!important}
        .hidden{display:none!important}
        .sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
    </style>
</head>
<body>
    <div class="shell">
        <aside class="sidebar">
            <div class="sb-head">
                <div class="sb-logo">TURN<span class="i">I</span>.</div>
                <div class="sb-tag">Backoffice</div>
            </div>
            <div class="sb-user">
                <div class="sb-av">{{ mb_strtoupper(mb_substr(auth()->user()->name ?? '?', 0, 1)) }}</div>
                <div>
                    <div class="sb-uname">{{ auth()->user()->name ?? '—' }}</div>
                    <div class="sb-urole">Admin</div>
                </div>
            </div>
            <div class="sb-sec">Operação</div>
            <a href="{{ route('dashboard') }}" class="sb-item {{ request()->routeIs('dashboard') ? 'active' : '' }}" wire:navigate>
                <span class="ic"></span> Visão geral
            </a>
            <a href="{{ route('aprovacoes') }}" class="sb-item {{ request()->routeIs('aprovacoes') ? 'active' : '' }}" wire:navigate data-testid="nav-aprovacoes">
                <span class="ic"></span> Cadastros pendentes
            </a>
            <div class="sb-sec">Cadastro</div>
            <a href="{{ route('templates.catalogo') }}" class="sb-item {{ request()->routeIs('templates.*') ? 'active' : '' }}" wire:navigate data-testid="nav-templates">
                <span class="ic"></span> Templates contratuais
            </a>
            <div class="sb-foot">
                <button type="button" class="theme-toggle" onclick="toggleTheme()">Alternar tema</button>
                <form method="POST" action="/logout">@csrf<button type="submit" class="logout">Sair</button></form>
            </div>
        </aside>
        <main class="main">
            {{ $slot }}
        </main>
    </div>

    @livewireScripts
    <script>
        function initTheme(){const s=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';document.documentElement.setAttribute('data-theme',localStorage.getItem('turni-bo-theme')||s);}
        function toggleTheme(){const n=document.documentElement.getAttribute('data-theme')==='light'?'dark':'light';document.documentElement.setAttribute('data-theme',n);localStorage.setItem('turni-bo-theme',n);}
        initTheme();
    </script>
</body>
</html>
