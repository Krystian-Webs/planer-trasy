// Service worker dla Planera Trasy — instalacja + offline, z automatyczną aktualizacją.
const CACHE = "planer-trasy-v5";
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
  const req = e.request;
  const url = req.url;
  // mapy / trasy / adresy / biblioteki 3D / dane wysokości — zawsze z sieci, nie cache'ujemy
  if (/tile|nominatim|routing|router\.project|arcgisonline|basemaps\.cartocdn|api\.open-meteo|unpkg\.com|elevation-tiles/.test(url)) return;

  const sameOrigin = url.startsWith(self.location.origin);
  if (sameOrigin) {
    // pliki aplikacji: NAJPIERW sieć (świeża wersja), cache jako zapas offline
    e.respondWith(
      fetch(req).then(resp => {
        const cp = resp.clone();
        caches.open(CACHE).then(c => c.put(req, cp).catch(() => {}));
        return resp;
      }).catch(() => caches.match(req))
    );
  } else {
    // biblioteki z CDN: najpierw cache (rzadko się zmieniają)
    e.respondWith(
      caches.match(req).then(r => r || fetch(req).then(resp => {
        const cp = resp.clone();
        caches.open(CACHE).then(c => c.put(req, cp).catch(() => {}));
        return resp;
      }).catch(() => r))
    );
  }
});
