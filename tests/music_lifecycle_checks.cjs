// 실제 웹 어댑터의 자동재생 거부·곡 교체·백그라운드·해제를 검사한다.
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function events() {
  const listeners = new Map();
  return {listeners, addEventListener(name, listener) {if (!listeners.has(name)) listeners.set(name, new Set()); listeners.get(name).add(listener);},
    removeEventListener(name, listener) {listeners.get(name)?.delete(listener);},
    emit(name) {for (const listener of listeners.get(name) || []) listener();}};
}
(async () => {
  const window = events(), document = {...events(), hidden: false};
  const urls = new Set(), released = [];
  const plays = [];
  class Audio {
    constructor() {this.paused = true; this.currentTime = 0;}
    load() {}
    removeAttribute() {this.src = '';}
    pause() {this.paused = true;}
    play() {return new Promise((resolve, reject) => {plays.push({resolve: () => {this.paused = false; resolve();}, reject});});}
  }
  vm.runInNewContext(fs.readFileSync('web/background_music.js', 'utf8'), {window, document, Audio, Uint8Array, Blob,
    atob: value => Buffer.from(value, 'base64').toString('binary'),
    URL: {createObjectURL() {const url = 'blob:' + (urls.size + released.length); urls.add(url); return url;},
      revokeObjectURL(url) {assert(urls.delete(url)); released.push(url);}}});
  const music = new window.InitialSJMusic();
  music.setTrack('T2dnUw==');
  assert.equal(plays.length, 0);
  music.update(true, .18);
  plays[0].reject(Object.assign(new Error('gesture'), {name: 'NotAllowedError'}));
  await new Promise(setImmediate);
  for (let i = 0; i < 60; i++) music.update(true, .18);
  assert.equal(plays.length, 1, '자동재생 거부 후 매 틱 재시도하지 않는다');
  document.emit('pointerdown');
  plays[1].resolve(); await new Promise(setImmediate);
  music.audio.currentTime = 42;
  music.update(false, 0);
  assert(music.audio.paused);
  assert.equal(music.audio.currentTime, 42);
  music.update(true, .18);
  music.setTrack('T2dnUw==');
  assert.equal(urls.size, 1, '곡을 바꿀 때 이전 URL을 해제한다');
  plays[2].reject(Object.assign(new Error('old'), {name: 'NotAllowedError'}));
  await new Promise(setImmediate);
  assert.equal(music.blocked, false, '이전 play 거부가 새 곡의 상태를 덮지 않는다');
  document.hidden = true; document.emit('visibilitychange');
  music.update(true, .18);
  assert(music.audio.paused);
  const count = plays.length;
  music.close(); music.close();
  assert.equal(urls.size, 0);
  for (const target of [window, document]) for (const listeners of target.listeners.values()) assert.equal(listeners.size, 0);
  music.update(true, 1);
  assert.equal(plays.length, count);
  console.log('음악 자동재생 잠금 / 이전 요청 격리 / 한 미디어·URL 수명 / 가시성·리스너 해제: PASS');
})().catch(error => {console.error(error); process.exitCode = 1;});
