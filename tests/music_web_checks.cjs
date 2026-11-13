// 실행 중인 Web export에서 실제 미디어·차량 카드·설정·모드 전환을 확인한다.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const output = path.resolve(__dirname, '../build/reports/background-music');
(async () => {
  fs.mkdirSync(output, {recursive: true});
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true, ignoreDefaultArgs: ['--mute-audio'],
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-angle=swiftshader']});
  try {
    const page = await browser.newPage({viewport: {width: 896, height: 414}, hasTouch: true});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {if (message.type() === 'error') {errors.push(message.text()); console.error('Browser:',message.text());}});
    const url = new URL(process.env.INITIALSJ_TEST_URL || 'http://127.0.0.1:8794/');
    url.searchParams.set('diagnostics', '1');
    await page.goto(url.toString());
    await page.waitForFunction(() => typeof initialsjReadDiagnostics === 'function' && !document.querySelector('#status'), null, {timeout: 120000});
    const state = () => page.evaluate(() => new Promise(resolve => initialsjReadDiagnostics(text => resolve(JSON.parse(text)))));
    async function waitSnapshot(predicate, timeout = 120000) {
      const deadline = Date.now() + timeout;
      while (Date.now() < deadline) {
        const snapshot = await state();
        if (predicate(snapshot)) return snapshot;
        await page.waitForTimeout(100);
      }
      throw new Error('게임 상태 대기 초과: ' + JSON.stringify(await state()));
    }
    async function waitState(expected) {
      return waitSnapshot(snapshot => snapshot.state === expected && !snapshot.transition_busy);
    }
    async function tap(rect) {
      const snapshot = await state();
      const x = (rect.x + rect.width / 2) * snapshot.ui_scale + snapshot.ui_offset.x;
      const y = (rect.y + rect.height / 2) * snapshot.ui_scale + snapshot.ui_offset.y;
      const t = snapshot.screen_transform;
      await page.touchscreen.tap(t[0] * x + t[2] * y + t[4], t[1] * x + t[3] * y + t[5]);
    }
    await waitState('menu');
    assert.equal((await state()).music_enabled, true);
    await page.locator('#canvas').focus();
    await page.keyboard.press('Tab'); await waitState('settings');
    await tap((await state()).targets.settings_music);
    await waitSnapshot(snapshot => !snapshot.music_enabled);
    await page.screenshot({path: path.join(output, 'settings-music.png')});
    await tap((await state()).targets.settings_music);
    await waitSnapshot(snapshot => snapshot.music_enabled);
    await tap({x:350,y:288,width:580,height:80});
    await page.waitForTimeout(250);
    await tap({x:350,y:288,width:580,height:80});
    await page.waitForTimeout(250);
    await page.keyboard.press('Escape'); await waitState('menu');
    await page.keyboard.press('Enter'); await waitState('ready');
    await tap((await state()).targets.garage_previous);
    await waitSnapshot(snapshot => snapshot.selected_vehicle === 4);
    await page.waitForTimeout(600);
    console.log(JSON.stringify({stage:'garage',snapshot:await state(),errors}));
    await page.screenshot({path: path.join(output, 'garage-redcar.png')});
    await tap((await state()).targets.garage_start);
    await page.waitForTimeout(4000);
    console.log(JSON.stringify({stage:'start',snapshot:await state(),music:await page.evaluate(()=>({active:initialsjMusic.active,blocked:initialsjMusic.blocked,src:initialsjMusic.audio.src,paused:initialsjMusic.audio.paused,time:initialsjMusic.audio.currentTime,error:initialsjMusic.audio.error?.message})),errors}));
    await page.waitForFunction(() => window.initialsjMusic?.audio.currentTime > 1 && !initialsjMusic.audio.paused, null, {timeout: 360000});
    const tourDuration = await page.evaluate(() => initialsjMusic.audio.duration);
    assert(tourDuration > 30);
    // 실제 디코딩된 음악에 신호가 있는지 확인한다. 게임 상태를 변경하는 테스트 API는 쓰지 않는다.
    const signal = await page.evaluate(async () => {
      window.musicCapture = new AudioContext();
      const source = musicCapture.createMediaElementSource(initialsjMusic.audio);
      const analyser = musicCapture.createAnalyser(); source.connect(analyser); analyser.connect(musicCapture.destination);
      await musicCapture.resume();
      let rms = 0;
      for (let i = 0; i < 20 && rms <= .00001; i++) {
        await new Promise(resolve => setTimeout(resolve, 100));
        const samples = new Float32Array(analyser.fftSize); analyser.getFloatTimeDomainData(samples);
        rms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
      }
      return {rms,context:musicCapture.state,volume:initialsjMusic.audio.volume,paused:initialsjMusic.audio.paused,time:initialsjMusic.audio.currentTime,active:initialsjMusic.active,muted:initialsjMusic.audio.muted};
    });
    console.log(JSON.stringify({stage:'signal',signal}));
    assert(signal.rms > .00001, '실제 음악 신호가 있어야 한다');
    await page.keyboard.press('Escape'); await waitState('paused');
    await page.waitForFunction(() => initialsjMusic.audio.paused);
    const position = await page.evaluate(() => initialsjMusic.audio.currentTime);
    await page.keyboard.press('Escape');
    await page.waitForFunction(position => !initialsjMusic.audio.paused && initialsjMusic.audio.currentTime > position + .2, position);
    await page.keyboard.press('Escape'); await waitState('paused');
    await tap({x: 390, y: 578, width: 500, height: 78}); await waitState('menu');
    await page.waitForFunction(() => initialsjMusic.url === null && initialsjMusic.audio.paused);
    await page.keyboard.press('c'); await waitState('courses');
    await page.keyboard.press('2'); await waitState('ready');
    await tap((await state()).targets.garage_start);
    await page.waitForFunction(() => initialsjMusic.audio.currentTime > 1 && !initialsjMusic.audio.paused, null, {timeout: 120000});
    const trackDuration = await page.evaluate(() => initialsjMusic.audio.duration);
    assert(trackDuration > 30);
    await page.keyboard.press('Escape'); await waitState('paused');
    await page.screenshot({path: path.join(output, 'track-music.png')});
    assert.deepEqual(errors, []);
    console.log(JSON.stringify({result: 'PASS',tourDuration,trackDuration,signal,pausedPosition: position,errors}));
  } finally {await browser.close();}
})().catch(error => {console.error(error); process.exitCode = 1;});
