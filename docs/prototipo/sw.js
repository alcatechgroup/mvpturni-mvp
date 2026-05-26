// TURNI · Service Worker básico
// Estratégia: cache-first para assets estáticos, network-first para HTML
const CACHE = 'turni-v1';
const ASSETS = [
  './app.html',
  './index.html',
  './manifest.json'
];

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS).catch(() => {}))
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // Apenas requests HTTP same-origin
  if(e.request.method !== 'GET' || url.origin !== self.location.origin) return;

  // HTML: network-first com fallback ao cache (mantém atualizado)
  if(e.request.mode === 'navigate' || url.pathname.endsWith('.html')){
    e.respondWith(
      fetch(e.request)
        .then(r => {
          const copy = r.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy));
          return r;
        })
        .catch(() => caches.match(e.request))
    );
    return;
  }

  // Assets estáticos (img, fonts, css, js): cache-first
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request).then(r => {
      if(r.ok && r.type === 'basic'){
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
      }
      return r;
    }).catch(() => cached))
  );
});
