// 엔진 다운로드 전에 현재 워커의 제어를 확인하고 실제 오프라인 저장 완료를 조회한다.
window.initialsjOffline = (function () {
  let controlPromise = null;
  let preparation = null;
  let startPromise = Promise.resolve();
  function rpc(worker, type, timeoutMs = 120000) {
    return new Promise((resolve, reject) => {
      const channel = new MessageChannel();
      const timer = setTimeout(() => { channel.port1.close(); reject(new Error('오프라인 준비 시간이 초과되었습니다.')); }, timeoutMs);
      channel.port1.onmessage = event => {
        clearTimeout(timer); channel.port1.close();
        if (event.data && event.data.ok) resolve(event.data);
        else reject(new Error(event.data?.error || '오프라인 준비에 실패했습니다.'));
      };
      try { worker.postMessage({type}, [channel.port2]); }
      catch (error) { clearTimeout(timer); channel.port1.close(); reject(error); }
    });
  }
  function control() {
    if (controlPromise) return controlPromise;
    controlPromise = new Promise((resolve, reject) => {
      if (!('serviceWorker' in navigator) || !GODOT_CONFIG.serviceWorker) { reject(new Error('이 브라우저에서는 오프라인 설치를 사용할 수 없습니다.')); return; }
      let finished = false;
      let registration = null;
      const timer = setTimeout(() => finish(null, new Error('서비스 워커를 시작하지 못했습니다.')), 10000);
      function cleanup() {
        clearTimeout(timer);
        navigator.serviceWorker.removeEventListener('controllerchange', changed);
        if (registration) registration.removeEventListener('updatefound', changed);
      }
      async function changed() {
        const worker = navigator.serviceWorker.controller;
        if (!worker || finished) return;
        try {
          const version = await rpc(worker, 'initialsj-version', 2000);
          // 셸과 워커는 내보낼 때 같은 내용 버전을 받는다.
          if (version.version === window.INITIALSJ_OFFLINE_VERSION) finish(worker);
        } catch (_) { /* 이전 워커가 아직 교체되는 중이면 다음 제어 변경을 기다린다. */ }
      }
      function finish(worker, error) {
        if (finished) return;
        finished = true; cleanup();
        if (error) reject(error); else resolve(worker);
      }
      navigator.serviceWorker.addEventListener('controllerchange', changed);
      engine.installServiceWorker().then(result => {
        if (finished) return;
        registration = result;
        if (!registration) { finish(null, new Error('서비스 워커 등록을 확인하지 못했습니다.')); return; }
        registration.addEventListener('updatefound', changed);
        changed();
      }, error => finish(null, error));
    }).catch(error => { controlPromise = null; throw error; });
    return controlPromise;
  }
  return {
    // 첫 본체 다운로드가 현재 워커를 통과하도록 엔진보다 먼저 시작한다.
    control,
    gameStarting(promise) { startPromise = promise; },
    prepare() {
      if (preparation) return preparation;
      preparation = (async () => {
        const worker = await control();
        await startPromise; // 엔진 다운로드와 본체 요청을 중복하지 않는다.
        return rpc(worker, 'initialsj-ensure-offline');
      })().catch(error => { preparation = null; throw error; });
      return preparation;
    },
  };
}());
