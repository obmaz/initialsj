// The previous Flutter app registered a service worker at the collection root.
// Retire only that worker; the two games must not share a root cache.
if ('serviceWorker' in navigator) {
  const root = new URL('./', location.href);
  navigator.serviceWorker.getRegistrations().then(registrations => {
    for (const registration of registrations) {
      const script = registration.active?.scriptURL || registration.waiting?.scriptURL;
      if (registration.scope === root.href && script === new URL('flutter_service_worker.js', root).href) {
        registration.update().catch(() => {});
      }
    }
  }).catch(() => {});
}
