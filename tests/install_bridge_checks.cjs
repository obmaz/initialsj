// Exercise browser install events with a minimal DOM, without a browser dependency.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const shell = fs.readFileSync('web/coast-rush-shell.html', 'utf8');
const start = shell.indexOf('(function () {', shell.indexOf('// Installation'));
const code = shell.slice(start, shell.indexOf('}());', start) + 5);
function harness(ua = 'Chrome', standalone = false, fullscreen = false) {
  const listeners = {};
  const nodes = {};
  for (const id of ['install-dialog','install-message','install-confirm','install-close']) {
    nodes[id] = {open:false, hidden:true, textContent:'', addEventListener(type, fn) {this[type]=fn;}, showModal(){this.open=true;}, close(){this.open=false;}};
  }
  let prepared = 0;
  const window = {addEventListener(type,fn){listeners[type]=fn;}, matchMedia(query){return {matches:query.includes('standalone') ? standalone : fullscreen};},initialsjOffline:{prepare(){prepared++;return Promise.resolve();}}};
  const context = {window, navigator:{userAgent:ua,maxTouchPoints:0,serviceWorker:{}}, document:{getElementById:id=>nodes[id]}, engine:{installServiceWorker(){prepared++; return Promise.resolve();}}, GODOT_CONFIG:{serviceWorker:'index.service.worker.js'}};
  vm.runInNewContext(code, context);
  return {window,nodes,listeners,prepared:()=>prepared};
}
(async () => {
  const h = harness();
  await h.window.initialsjInstallGame();
  assert(h.nodes['install-dialog'].open);
  assert.equal(h.prepared(),1);
  let prompts=0, prevented=false;
  h.listeners.beforeinstallprompt({preventDefault(){prevented=true;}, prompt(){prompts++;return Promise.resolve();},userChoice:Promise.resolve({outcome:'accepted'})});
  assert(prevented && !h.nodes['install-confirm'].hidden);
  await h.window.initialsjInstallGame();
  assert.equal(prompts,1);
  assert(!h.nodes['install-dialog'].open);
  assert.equal(h.prepared(),1);
  h.listeners.appinstalled();
  assert(h.nodes['install-confirm'].hidden);
  for (const [ua, expected] of [['iPhone Safari','홈 화면'],['Firefox','Chrome'],['Macintosh Safari','Dock']]) {
    const q = harness(ua);
    await q.window.initialsjInstallGame();
    assert(q.nodes['install-message'].textContent.includes(expected));
  }
  const installed = harness('Chrome',true);
  await installed.window.initialsjInstallGame();
  assert(installed.nodes['install-message'].textContent.includes('이미 앱'));
  const fullscreen = harness('Chrome', false, true);
  await fullscreen.window.initialsjInstallGame();
  assert(fullscreen.nodes['install-message'].textContent.includes('이미 앱'));
  console.log('Install prompt / fallback instructions / standalone / single preparation: PASS');
})().catch(error=>{console.error(error);process.exitCode=1;});
