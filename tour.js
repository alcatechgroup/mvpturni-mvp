/* ════════════════════════════════════════════════════════════════
   TURNI · Demo Tour · navegação automática com legendas
   Funciona em index.html (landing) e app.html (plataforma)
   Estado persistido em localStorage para sobreviver às navegações
   ════════════════════════════════════════════════════════════════ */

(function(){
  'use strict';

  const STATE_KEY = 'turni_tour_state';
  const PAGE = location.pathname.includes('app.html') ? 'app' : 'index';

  // ─── DEFINIÇÃO DOS STEPS DO TOUR INVESTIDOR (15 min) ───
  const STEPS = [
    // BLOCO 1 · Tese visual da landing (3 min)
    { page:'index', kind:'caption', text:'A <b>TURN<span class="di">I</span><span class="de">.</span></b> é a infraestrutura que faltava para o food service brasileiro encontrar gente em horas.', sub:'Vamos navegar pela plataforma como se você fosse um usuário real.', wait:5500 },
    { page:'index', kind:'scroll', target:'.hero-diagonal-stage, .hero-stage, header', wait:1500 },
    { page:'index', kind:'caption', text:'No alto temos o <b>empresário</b> ↗ e na base o <b>profissional</b> ↘. Eles se encontram no centro, no símbolo da TURN<span class="di">I</span><span class="de">.</span>', sub:'A landing é construída como dois lados de uma mesma equação.', wait:5000 },
    { page:'index', kind:'scroll', target:'#manifesto, .sobre-manifesto', wait:1800 },
    { page:'index', kind:'caption', text:'Nosso <b>manifesto</b>: o que rejeitamos vs o que defendemos. <b>Match IA · PIN Bilateral · Pix em 15min</b> não é slogan — é compromisso.', wait:5000 },
    { page:'index', kind:'scroll', target:'#quem-turnifica, .apoio-row, footer', wait:1800 },
    { page:'index', kind:'caption', text:'<b>Stone, Pagar.me e Grupo Noiz</b> já no ecossistema. Não é prospecção · é parceria validada.', wait:4500 },
    { page:'index', kind:'scrollTop', wait:1200 },

    // BLOCO 2 · Pré-cadastro contratante (2 min)
    { page:'index', kind:'caption', text:'Vamos cadastrar um <b>contratante novo</b>. Imagine o dono de um bar pequeno chegando à plataforma.', wait:3500 },
    { page:'index', kind:'navigate', url:'app.html#/cadastro/emp', wait:1500 },
    { page:'app', kind:'caption', text:'Formulário de pré-cadastro do contratante. <b>2 minutos · grátis · sem contrato</b>.', wait:3500 },
    { page:'app', kind:'type', target:'#f_nome', text:'Felipe Demo', delay:60 },
    { page:'app', kind:'type', target:'#f_estab', text:'Bar do Demo · Itaim', delay:50 },
    { page:'app', kind:'type', target:'#f_email', text:'demo@bardodemo.com.br', delay:40 },
    { page:'app', kind:'type', target:'#f_wpp', text:'(11) 99999-0000', delay:50 },
    { page:'app', kind:'select', target:'#f_tipo', value:'Bar' },
    { page:'app', kind:'type', target:'#f_cidade', text:'São Paulo', delay:50 },
    { page:'app', kind:'caption', text:'Em produção, esse cadastro entra na <b>fila de aprovação humana</b> com checks anti-fraude e validação de CNPJ.', wait:4000 },
    { page:'app', kind:'click', target:'#cadastroForm button[type="submit"]', wait:2000 },

    // BLOCO 3 · Pré-cadastro trabalhador (1.5 min)
    { page:'app', kind:'caption', text:'Agora um <b>trabalhador</b>. A tese aqui é radical: trabalhar deixa de ser submissão e vira <b class="accent-orange">escolha</b>.', wait:4500 },
    { page:'app', kind:'navigate', url:'app.html#/cadastro/wkr', wait:1500 },
    { page:'app', kind:'type', target:'#f_nome', text:'Marina Demo Souza', delay:60 },
    { page:'app', kind:'type', target:'#f_email', text:'marina.demo@gmail.com', delay:40 },
    { page:'app', kind:'type', target:'#f_wpp', text:'(11) 99999-1111', delay:50 },
    { page:'app', kind:'select', target:'#f_funcao', value:'Bartender' },
    { page:'app', kind:'type', target:'#f_cidade', text:'São Paulo', delay:50 },
    { page:'app', kind:'check', target:'input[name="f_mei"][value="sim"]' },
    { page:'app', kind:'caption', text:'<b>MEI obrigatório</b> · contrato B2B PJ↔PJ. Essa é a tese jurídica que nos protege da reclassificação trabalhista.', wait:4500 },
    { page:'app', kind:'click', target:'#cadastroForm button[type="submit"]', wait:2000 },

    // BLOCO 4 · Login admin · curadoria humana (1.5 min)
    { page:'app', kind:'caption', text:'Os 2 cadastros entraram na fila. Agora vamos para o <b>painel do admin</b> para aprovar.', wait:3500 },
    { page:'app', kind:'navigate', url:'app.html#/login', wait:1500 },
    { page:'app', kind:'type', target:'#loginEmail', text:'rodolfo@turni.app', delay:55 },
    { page:'app', kind:'type', target:'#loginPwd', text:'••••••••', delay:40 },
    { page:'app', kind:'click', target:'#loginForm button[type="submit"]', wait:2200 },
    { page:'app', kind:'navigate', url:'app.html#/admin/aprovacoes', wait:1500 },
    { page:'app', kind:'caption', text:'Fila de aprovação. <b>Cada liberação grava aprovadoPor + aprovadoEm</b> · trilha de auditoria completa para compliance trabalhista.', wait:4500 },
    { page:'app', kind:'clickFirst', target:'.btn-mini.approve', wait:2000 },
    { page:'app', kind:'caption', text:'Liberado em 1 clique. O profissional cai em uma tela de boas-vindas no próximo login e completa o cadastro com foto, raio, preço e Pix.', wait:5000 },

    // BLOCO 5 · Contratante real abre vaga (3 min)
    { page:'app', kind:'caption', text:'Vou agora logar como <b>Roberto da Pizza da Mooca</b>. 7ª melhor pizzaria do Brasil pela Folha 2024 · piloto real da operação.', wait:4500 },
    { page:'app', kind:'navigate', url:'app.html#/login', wait:1500 },
    { page:'app', kind:'type', target:'#loginEmail', text:'roberto@apizzadamooca.com.br', delay:45 },
    { page:'app', kind:'type', target:'#loginPwd', text:'••••••••', delay:40 },
    { page:'app', kind:'click', target:'#loginForm button[type="submit"]', wait:2500 },
    { page:'app', kind:'caption', text:'Início é <b>IDENTIDADE da casa</b> · não operação. Logo, endereço, segmento, plano. <b>"A casa em movimento"</b> mostra a escala dos próximos turnos.', wait:5500 },
    { page:'app', kind:'navigate', url:'app.html#/contratante/vagas', wait:2000 },
    { page:'app', kind:'caption', text:'Vagas é onde a operação acontece. Cada card tem o ícone <b>duplicar</b> · vaga recorrente em 1 clique.', wait:4500 },
    { page:'app', kind:'navigate', url:'app.html#/contratante/vagas/nova', wait:2000 },
    { page:'app', kind:'caption', text:'Nova vaga em <b>3 passos</b>. A plataforma sugere o valor médio das suas últimas vagas dessa função.', wait:4500 },
    { page:'app', kind:'select', target:'#f-funcao', value:'Garçom' },
    { page:'app', kind:'type', target:'#f-valorHora', text:'35', delay:80, clear:true, optional:true },
    { page:'app', kind:'caption', text:'Vaga publicada. Sai para o feed de centenas de profissionais habilitados <b>em tempo real</b>.', wait:4000 },

    // BLOCO 6 · Trabalhador pega o turno (3.5 min)
    { page:'app', kind:'caption', text:'Agora o lado dele · <b>Carlos · Garçom Elite · 127 turnos sem ocorrência</b>.', wait:4000 },
    { page:'app', kind:'navigate', url:'app.html#/login', wait:1500 },
    { page:'app', kind:'type', target:'#loginEmail', text:'carlos.silva@gmail.com', delay:45 },
    { page:'app', kind:'type', target:'#loginPwd', text:'••••••••', delay:40 },
    { page:'app', kind:'click', target:'#loginForm button[type="submit"]', wait:2500 },
    { page:'app', kind:'caption', text:'Início do trabalhador é o <b>crachá TURN<span class="di">I</span><span class="de">.</span></b> · sua reputação. <b>4.9★ · 127 turnos · Elite</b>. Não é currículo · é histórico vivo na rede.', wait:5500 },
    { page:'app', kind:'navigate', url:'app.html#/profissional/feed', wait:2000 },
    { page:'app', kind:'caption', text:'Feed em <b>listagem zebrada compacta</b> · otimizado para celular simples. Cada linha mostra match%, valor, distância em segundos.', wait:5000 },
    { page:'app', kind:'caption', text:'O <b>match%</b> não é caixa-preta. Clica e mostra a fórmula: função, distância, score, nível, preço. <b>Transparência do algoritmo</b> = base de confiança.', wait:5500 },
    { page:'app', kind:'caption', text:'Para finalizar: <b>quando Carlos chegar no local</b>, ele gera PIN. Roberto valida (geofence 100m). Cronômetro bilateral. Check-out gera novo PIN. Pix em 15 min via Pagar.me. <b>Feedback bilateral obrigatório</b> libera a próxima candidatura.', wait:7000 },
    { page:'app', kind:'end' }
  ];

  // ─── ESTADO ───
  function loadState(){
    try{ return JSON.parse(localStorage.getItem(STATE_KEY)) || null; }catch(e){ return null; }
  }
  function saveState(s){
    try{ localStorage.setItem(STATE_KEY, JSON.stringify(s)); }catch(e){}
  }
  function clearState(){
    try{ localStorage.removeItem(STATE_KEY); }catch(e){}
  }

  // ─── DOM HELPERS ───
  function $(sel, root){ return (root||document).querySelector(sel); }
  function $$(sel, root){ return Array.from((root||document).querySelectorAll(sel)); }
  function waitForEl(selector, timeout){
    timeout = timeout || 5000;
    return new Promise((resolve) => {
      const start = Date.now();
      const tick = () => {
        const el = $(selector);
        if(el) return resolve(el);
        if(Date.now() - start > timeout) return resolve(null);
        requestAnimationFrame(tick);
      };
      tick();
    });
  }
  function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }

  // ─── UI BUILDER ───
  function buildBar(){
    if(document.getElementById('tourBar')) return;
    const bar = document.createElement('div');
    bar.className = 'tour-bar';
    bar.id = 'tourBar';
    bar.innerHTML = `
      <div class="tour-meta">
        <span class="tour-meta-logo">TURN<span class="di">I</span><span class="de">.</span></span>
        <span class="tour-meta-rec">REC</span>
        <span class="tour-meta-tag">DEMO GUIADA · 15 MIN</span>
        <span class="tour-meta-step">PASSO <b id="tourStepIdx">1</b> / <b id="tourStepTotal">${STEPS.length}</b></span>
      </div>
      <div class="tour-progress"><div class="tour-progress-fill" id="tourProgressFill"></div></div>
      <div class="tour-content">
        <div>
          <div class="tour-caption" id="tourCaption">Iniciando…</div>
          <div class="tour-subcaption" id="tourSubCaption"></div>
        </div>
        <div class="tour-controls">
          <button class="tour-btn" id="tourPrev" title="Anterior">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M15 18l-6-6 6-6"/></svg>
          </button>
          <button class="tour-btn tour-btn-primary" id="tourPause" title="Pausar/Continuar">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" id="tourPauseIc"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>
            <span id="tourPauseLbl">Pausar</span>
          </button>
          <button class="tour-btn" id="tourNext" title="Próximo">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M9 18l6-6-6-6"/></svg>
          </button>
          <button class="tour-btn tour-btn-exit" id="tourExit" title="Sair">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M18 6L6 18M6 6l12 12"/></svg>
          </button>
        </div>
      </div>
    `;
    document.body.appendChild(bar);

    // Cursor virtual
    const cursor = document.createElement('div');
    cursor.className = 'tour-cursor';
    cursor.id = 'tourCursor';
    document.body.appendChild(cursor);

    // Bindings
    $('#tourPrev').addEventListener('click', () => Tour.prev());
    $('#tourNext').addEventListener('click', () => Tour.skip());
    $('#tourPause').addEventListener('click', () => Tour.togglePause());
    $('#tourExit').addEventListener('click', () => {
      if(confirm('Encerrar a demo guiada?')) Tour.exit();
    });

    setTimeout(() => bar.classList.add('show'), 50);
  }

  function buildSplash(){
    return new Promise((resolve) => {
      const splash = document.createElement('div');
      splash.className = 'tour-splash';
      splash.id = 'tourSplash';
      splash.innerHTML = `
        <div class="tour-splash-logo">TURN<span class="di">I</span><span class="de">.</span></div>
        <div class="tour-splash-tag">demo guiada · 15 minutos</div>
        <div class="tour-splash-count" id="tourCount">3</div>
      `;
      document.body.appendChild(splash);
      let n = 3;
      const tickEl = $('#tourCount');
      const t = setInterval(() => {
        n--;
        if(n <= 0){
          clearInterval(t);
          splash.style.transition = 'opacity .35s';
          splash.style.opacity = '0';
          setTimeout(() => { splash.remove(); resolve(); }, 350);
        } else {
          tickEl.textContent = n;
          tickEl.style.animation = 'none';
          requestAnimationFrame(() => tickEl.style.animation = 'tour-count-pulse 1s ease-in-out');
        }
      }, 1000);
    });
  }

  function buildEnd(){
    const end = document.createElement('div');
    end.className = 'tour-end';
    end.innerHTML = `
      <div class="tour-end-logo">TURN<span class="di">I</span><span class="de">.</span></div>
      <h2 class="tour-end-h">Match IA · PIN Bilateral · Pix em 15min</h2>
      <p class="tour-end-d">Você acabou de ver o ciclo completo: pré-cadastros · curadoria humana · contratante abrindo vaga · trabalhador dando match. Stone, Pagar.me e Grupo Noiz já no ecossistema. Pronto para escalar.</p>
      <div class="tour-end-actions">
        <button class="tour-end-btn" onclick="Tour.restart()">↻ Rever a demo</button>
        <button class="tour-end-btn primary" onclick="Tour.exit()">Explorar livre <svg viewBox='0 0 24 24' fill='none' stroke='currentColor'><path d='M5 12h14M13 5l7 7-7 7'/></svg></button>
      </div>
    `;
    document.body.appendChild(end);
    saveState(null);
    clearState();
    document.body.classList.remove('tour-active');
  }

  // ─── ATUALIZAÇÃO DE UI ───
  function setCaption(html, sub){
    const cap = $('#tourCaption');
    const subEl = $('#tourSubCaption');
    if(cap){
      cap.style.opacity = '0';
      setTimeout(() => {
        cap.innerHTML = html;
        cap.style.animation = 'none';
        requestAnimationFrame(() => {
          cap.style.opacity = '';
          cap.style.animation = 'tour-caption-in .45s ease-out';
          if(window.lucide) try{ lucide.createIcons(); }catch(e){}
        });
      }, 220);
    }
    if(subEl) subEl.textContent = sub || '';
  }
  function setStep(idx){
    const idxEl = $('#tourStepIdx');
    const fill = $('#tourProgressFill');
    if(idxEl) idxEl.textContent = idx + 1;
    if(fill) fill.style.width = (((idx + 1) / STEPS.length) * 100) + '%';
  }

  // ─── CURSOR VIRTUAL ───
  function moveCursorTo(el){
    if(!el) return Promise.resolve();
    const cursor = $('#tourCursor');
    if(!cursor) return Promise.resolve();
    const r = el.getBoundingClientRect();
    const x = r.left + r.width/2 - 4;
    const y = r.top + r.height/2 - 4;
    cursor.style.transform = `translate3d(${x}px,${y}px,0)`;
    cursor.classList.add('show');
    return sleep(580);
  }
  function clickCursorPulse(){
    const cursor = $('#tourCursor');
    if(!cursor) return;
    cursor.classList.remove('click');
    void cursor.offsetWidth; // reflow
    cursor.classList.add('click');
    setTimeout(() => cursor.classList.remove('click'), 600);
  }
  function hideCursor(){
    const cursor = $('#tourCursor');
    if(cursor) cursor.classList.remove('show');
  }

  // ─── EXECUÇÃO DE STEPS ───
  let _state = null;
  let _executing = false;
  let _abort = false;

  async function execStep(step, idx){
    setStep(idx);
    if(step.kind === 'caption'){
      setCaption(step.text, step.sub);
      await sleep(step.wait || 4000);
      return;
    }
    if(step.kind === 'scrollTop'){
      window.scrollTo({ top:0, behavior:'smooth' });
      await sleep(step.wait || 1000);
      return;
    }
    if(step.kind === 'scroll'){
      const el = await waitForEl(step.target, 3000);
      if(el){
        el.scrollIntoView({ behavior:'smooth', block:'start' });
        // Compensação para a barra do tour
        await sleep(700);
        window.scrollBy({ top:-180, behavior:'smooth' });
      }
      await sleep(step.wait || 1500);
      return;
    }
    if(step.kind === 'navigate'){
      // Salva estado antes de navegar
      _state.step = idx + 1;
      saveState(_state);
      // Se mudar de arquivo (index→app), carrega URL · senão muda hash
      if(step.url.startsWith('app.html') && PAGE === 'index'){
        location.href = step.url;
        return new Promise(() => {}); // pendura · página vai recarregar
      }
      // Mudança apenas de hash dentro do mesmo arquivo
      const hash = step.url.replace(/.*#/, '#');
      if(location.hash !== hash){
        location.hash = hash;
      }
      await sleep(step.wait || 1200);
      return;
    }
    if(step.kind === 'click' || step.kind === 'clickFirst'){
      const el = await waitForEl(step.target, 5000);
      if(el){
        await moveCursorTo(el);
        clickCursorPulse();
        await sleep(120);
        // dispatcha click programaticamente
        el.click();
      }
      hideCursor();
      await sleep(step.wait || 1200);
      return;
    }
    if(step.kind === 'type'){
      const el = await waitForEl(step.target, 5000);
      if(!el){ if(step.optional) return; await sleep(800); return; }
      await moveCursorTo(el);
      el.focus();
      if(step.clear) el.value = '';
      const txt = step.text || '';
      const delay = step.delay || 50;
      for(let i = 0; i < txt.length; i++){
        if(_abort) return;
        el.value += txt.charAt(i);
        el.dispatchEvent(new Event('input', { bubbles:true }));
        await sleep(delay);
      }
      el.dispatchEvent(new Event('change', { bubbles:true }));
      await sleep(step.wait || 250);
      return;
    }
    if(step.kind === 'select'){
      const el = await waitForEl(step.target, 5000);
      if(el){
        el.value = step.value;
        el.dispatchEvent(new Event('change', { bubbles:true }));
        await moveCursorTo(el);
      }
      await sleep(step.wait || 600);
      return;
    }
    if(step.kind === 'check'){
      const el = await waitForEl(step.target, 5000);
      if(el){
        el.checked = true;
        el.dispatchEvent(new Event('change', { bubbles:true }));
        await moveCursorTo(el);
      }
      await sleep(step.wait || 600);
      return;
    }
    if(step.kind === 'wait'){
      await sleep(step.wait || 1000);
      return;
    }
    if(step.kind === 'end'){
      buildEnd();
      return new Promise(() => {}); // pausa
    }
    // fallback
    await sleep(800);
  }

  async function run(fromIdx){
    if(_executing) return;
    _executing = true;
    document.body.classList.add('tour-active');
    buildBar();
    let i = fromIdx || 0;
    while(i < STEPS.length){
      if(_abort) break;
      _state.step = i;
      saveState(_state);
      const step = STEPS[i];
      // Pula steps de outras páginas
      if(step.page && step.page !== PAGE){
        i++; continue;
      }
      try{
        await execStep(step, i);
      }catch(err){
        console.warn('[Tour] step erro · pulando', err);
      }
      // Pausa explícita
      while(_state && _state.paused){
        await sleep(300);
      }
      i++;
    }
    _executing = false;
  }

  // ─── API PÚBLICA ───
  window.Tour = {
    start(){
      // Reset banco para garantir demo limpa
      try{
        if(typeof DB !== 'undefined' && typeof DB.reset === 'function'){
          DB.reset();
        }
        if(typeof Session !== 'undefined' && typeof Session.clear === 'function'){
          Session.clear();
        }
      }catch(e){}
      _state = { active:true, step:0, paused:false, startedAt:Date.now() };
      saveState(_state);
      // Splash + start
      buildSplash().then(() => run(0));
    },
    resume(){
      const s = loadState();
      if(!s || !s.active) return;
      _state = s;
      run(s.step || 0);
    },
    skip(){
      _abort = true;
      setTimeout(() => {
        _abort = false;
        const s = loadState();
        if(!s) return;
        s.step = (s.step || 0) + 1;
        saveState(s);
        _state = s;
        run(s.step);
      }, 100);
    },
    prev(){
      _abort = true;
      setTimeout(() => {
        _abort = false;
        const s = loadState();
        if(!s) return;
        s.step = Math.max(0, (s.step || 0) - 1);
        saveState(s);
        _state = s;
        run(s.step);
      }, 100);
    },
    togglePause(){
      if(!_state) return;
      _state.paused = !_state.paused;
      saveState(_state);
      const ic = $('#tourPauseIc');
      const lbl = $('#tourPauseLbl');
      if(_state.paused){
        if(ic) ic.innerHTML = '<polygon points="5 3 19 12 5 21"/>';
        if(lbl) lbl.textContent = 'Continuar';
      } else {
        if(ic) ic.innerHTML = '<rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/>';
        if(lbl) lbl.textContent = 'Pausar';
      }
    },
    exit(){
      _abort = true;
      _state = null;
      clearState();
      const bar = $('#tourBar');
      if(bar){ bar.classList.remove('show'); setTimeout(() => bar.remove(), 450); }
      const cur = $('#tourCursor');
      if(cur) cur.remove();
      const splash = $('#tourSplash');
      if(splash) splash.remove();
      const end = document.querySelector('.tour-end');
      if(end) end.remove();
      document.body.classList.remove('tour-active');
      // Volta para a landing
      if(PAGE !== 'index') location.href = 'index.html';
    },
    restart(){
      const end = document.querySelector('.tour-end');
      if(end) end.remove();
      this.exit();
      // Pequeno delay para a transição da landing carregar
      setTimeout(() => {
        if(PAGE === 'index') this.start();
        else location.href = 'index.html?tour=1';
      }, 400);
    }
  };

  // Botão flutuante para iniciar tour · só na landing
  function buildFAB(){
    if(PAGE !== 'index') return;
    if(document.getElementById('tourFAB')) return;
    const fab = document.createElement('button');
    fab.className = 'tour-fab';
    fab.id = 'tourFAB';
    fab.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polygon points="5 3 19 12 5 21"/></svg>
      Demo guiada · 15min
    `;
    fab.addEventListener('click', () => Tour.start());
    document.body.appendChild(fab);
  }

  // ─── BOOTSTRAP ───
  function init(){
    buildFAB();
    const s = loadState();
    if(s && s.active){
      // Retoma se foi navegação durante tour
      _state = s;
      // Aguarda tudo carregar antes de continuar
      setTimeout(() => Tour.resume(), 400);
    }
    // Suporte a ?tour=1 na URL (auto-start)
    if(/[?&]tour=1/.test(location.search)){
      setTimeout(() => Tour.start(), 600);
    }
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
