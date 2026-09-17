// Service Worker для поддержки PWA и офлайн-режима мобильного приложения
const CACHE_NAME = 'rii-schedule-pwa-v4';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/app.js',
  '/manifest.json',
  '/favicon.png',
  '/favicon-32x32.png',
  '/apple-touch-icon.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  // Обрабатываем только GET-запросы
  if (event.request.method !== 'GET') {
    return;
  }

  let url;
  try {
    url = new URL(event.request.url);
  } catch (e) {
    return;
  }

  // Игнорируем внешние запросы (Cloudflare Insights, аналитика, сторонние CDN)
  if (url.origin !== self.location.origin) {
    return;
  }

  // Не кэшируем и не перехватываем сенсорный киоск и ТВ-табло через Service Worker
  const isKioskOrTv = url.hostname.includes('kiosk') || 
                       url.hostname.includes('tv') || 
                       url.pathname.includes('kiosk') || 
                       url.pathname.includes('tv');
  if (isKioskOrTv) {
    return;
  }

  // Для API запросов: Network-First (свежие данные с сервера, при отсутствии связи - кэш)
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone)).catch(() => {});
          }
          return response;
        })
        .catch(async () => {
          const cached = await caches.match(event.request);
          if (cached) return cached;
          return new Response(JSON.stringify({ error: 'offline', message: 'Нет подключения к сети' }), {
            status: 503,
            headers: { 'Content-Type': 'application/json; charset=utf-8' }
          });
        })
    );
    return;
  }

  // Для статических файлов: Network-First с fallback на кэш
  event.respondWith(
    fetch(event.request)
      .then(networkResponse => {
        if (networkResponse && networkResponse.status === 200) {
          const clone = networkResponse.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone)).catch(() => {});
        }
        return networkResponse;
      })
      .catch(async () => {
        const cachedResponse = await caches.match(event.request);
        if (cachedResponse) return cachedResponse;
        return new Response('Офлайн режим: ресурс недоступен', {
          status: 503,
          headers: { 'Content-Type': 'text/plain; charset=utf-8' }
        });
      })
  );
});
