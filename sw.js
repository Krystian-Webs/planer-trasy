const CACHE = "planer-trasy-v44";
const SHELL = [
  "./",
  "index.html",
  "manifest.json",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js",
  "https://cdnjs.cloudflare.com/ajax/libs/lz-string/1.5.0/lz-string.min.js"
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL).catch(() => {})));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = req.url;

  // Nigdy nie przechwytuj: kafli map, geokodowania, routingu, wysokosci, Firebase, Maplibre itd.
  if (/tile|nominatim|routing|router\.project|arcgisonline|basemaps\.cartocdn|api\.open-meteo|unpkg\.com|elevation-tiles|firebase|gstatic\.com\/firebasejs/.test(url)) return;

  // Nasze pliki (index.html, manifest, sw, ikony) -> NAJPIERW SIEC.
  // Dzieki temu swiezy kod zawsze wygrywa, a cache sluzy tylko jako awaryjne zrodlo offline.
  if (url.startsWith(self.location.origin)) {
    e.respondWith(
      fetch(req).then(resp => {
        const cp = resp.clone();
        caches.open(CACHE).then(c => c.put(req, cp).catch(() => {}));
        return resp;
      }).catch(() => caches.match(req))
    );
    return;
  }

  // Zewnetrzne biblioteki z CDN (Leaflet, lz-string) -> NAJPIERW CACHE (dla trybu offline PWA).
  e.respondWith(
    caches.match(req).then(hit => {
      if (hit) return hit;
      return fetch(req).then(resp => {
        const cp = resp.clone();
        caches.open(CACHE).then(c => c.put(req, cp).catch(() => {}));
        return resp;
      });
    })
  );
});
