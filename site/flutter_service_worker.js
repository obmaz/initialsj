// Retirement worker for the old Flutter deployment at /initialsj/.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']) {
      await caches.delete(name);
    }
    await self.clients.claim();
    const root = new URL(self.registration.scope);
    const clients = await self.clients.matchAll({type: 'window'});
    for (const client of clients) {
      if (new URL(client.url).pathname === root.pathname || new URL(client.url).pathname === root.pathname + 'index.html') {
        // Navigation waits for activation to finish, so do not await it here.
        client.navigate(root.href).catch(() => {});
      }
    }
    await self.registration.unregister();
  })());
});
