// Service worker dla Planera Trasy — pozwala zainstalować aplikację i działać offline.
const CACHE = "planer-trasy-v1";
const SHELL = [
  "planer-trasy.html",
  "manifest.json",
  "icon-192.png",
  "icon-512.png",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js",
  "https://cdnjs.cloudflare.com/ajax/libs/lz-string/1.5.0/lz-string.min.js"
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(() => {})));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});

self.addEventListener("fetch", e => {
  const url = e.request.url;
  // dane map/tras/adresów zawsze z sieci (nie cache'ujemy)
  if (/tile|nominatim|routing|router\.project|arcgisonline|basemaps\.cartocdn/.test(url)) return;
  // reszta: najpierw cache, potem sieć
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request).then(resp => {
      const cp = resp.clone();
      caches.open(CACHE).then(c => c.put(e.request, cp).catch(() => {}));
      return resp;
    }).catch(() => r))
  );
});
