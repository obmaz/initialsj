// Exercise the actual shell bridge, including a strict transient-activation model.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const shell = fs.readFileSync('web/coast-rush-shell.html','utf8');
const start = shell.indexOf('(function () {',shell.indexOf('// Fullscreen controls'));
assert(start >= 0);
const code = shell.slice(start,shell.indexOf('}());',start)+5);
function harness({supported=true,webkit=false,installed=false,standalone=false,ios=false,reject=false,deferred=false}={}) {
  let activated = false, fullscreen = false, requested = 0, exited = 0, resolveRequest;
  const listeners = {};
  const root = {classList:{toggle(){}}};
  const control = {hidden:true,disabled:false,style:{},attributes:{},listeners:{},setAttribute(key,value){this.attributes[key]=value;},addEventListener(type,fn){this.listeners[type]=fn;}};
  const notice = {hidden:true,textContent:''};
  const canvas = {bounds:{left:12,top:20,width:896,height:414},getBoundingClientRect(){return this.bounds;},focus(){}};
  const document = {documentElement:root,get fullscreenElement(){return !webkit && fullscreen ? root : null;},get webkitFullscreenElement(){return webkit && fullscreen ? root : null;},getElementById(id){return {'canvas':canvas,'fullscreen-control':control,'fullscreen-notice':notice}[id];},addEventListener(type,fn){listeners[type]=fn;}};
  if(supported) {
    root[webkit?'webkitRequestFullscreen':'requestFullscreen'] = function(options) {
      assert.equal(this,root);
      assert.equal(options.navigationUI,'hide');
      requested++;
      if (!activated || reject) return Promise.reject(new Error('NotAllowedError'));
      if (deferred) return new Promise(resolve=>{resolveRequest=()=>{fullscreen=true;resolve();};});
      fullscreen = true;
      return Promise.resolve();
    };
    document[webkit?'webkitExitFullscreen':'exitFullscreen'] = function() {assert.equal(this,document);exited++;fullscreen=false;return Promise.resolve();};
  }
  const media = {
    '(display-mode: fullscreen)':{matches:installed,addEventListener(){}},
    '(display-mode: standalone)':{matches:standalone,addEventListener(){}}
  };
  const window = {matchMedia(query){return media[query];},addEventListener(type,fn){listeners[type]=fn;}};
  vm.runInNewContext(code,{window,document,navigator:{standalone:ios},setTimeout(){return 1;},clearTimeout(){}});
  return {window,document,control,notice,canvas,listeners,requested:()=>requested,exited:()=>exited,resolveRequest:()=>resolveRequest(),browserSetDom(value){fullscreen=value;listeners.fullscreenchange();},click(){activated=true;control.listeners.click({preventDefault(){},stopPropagation(){}});activated=false;}};
}
async function settled(){await new Promise(resolve=>setImmediate(resolve));}
(async()=>{
  for(const webkit of [false,true]) {
    const h=harness({webkit});
    assert.equal(h.requested(),0,'Startup must not request fullscreen without a gesture');
    const changes=[];
    h.window.initialsjObserveFullscreen((active,dom)=>changes.push([active,dom]));
    h.window.initialsjFullscreenControl(true,0.2,0.5,0.4,0.1);
    assert(!h.control.hidden);
    assert(Math.abs(parseFloat(h.control.style.left)-191.2)<0.0001);
    assert(Math.abs(parseFloat(h.control.style.top)-227)<0.0001);
    assert(Math.abs(parseFloat(h.control.style.width)-358.4)<0.0001);
    assert(Math.abs(parseFloat(h.control.style.height)-41.4)<0.0001);
    assert.equal(h.window.initialsjFullscreenLabel(),'ENTER FULLSCREEN');
    h.click(); await settled();
    assert(h.window.initialsjIsFullscreen());
    assert.equal(h.window.initialsjFullscreenLabel(),'EXIT FULLSCREEN');
    assert.equal(h.requested(),1,'The DOM click must retain transient activation');
    h.click(); await settled();
    assert(!h.window.initialsjIsFullscreen());
    assert.equal(h.exited(),1);
    assert.deepEqual(changes,[[false,false],[true,true],[false,false]],'Entry and browser exit must reach the game once each');
    h.window.initialsjObserveFullscreen(null);
    h.canvas.bounds.width=1280;
    h.listeners.resize();
    assert.equal(h.control.style.width,'512px');
    h.window.initialsjFullscreenControl(false,0,0,0,0);
    assert(h.control.hidden,'The invisible hit target must disappear outside settings');
  }
  {
    const h=harness({deferred:true});
    h.click();h.click();
    assert.equal(h.requested(),1,'Repeated taps must not issue competing fullscreen requests');
    assert(h.control.disabled);
    h.resolveRequest();await settled();
    assert(!h.control.disabled);
  }
  {
    const h=harness({installed:true});
    assert(h.window.initialsjIsFullscreen());
    assert.equal(h.window.initialsjFullscreenLabel(),'FULLSCREEN / APP');
    h.click();await settled();
    assert.equal(h.requested(),0,'Installed fullscreen must rely on the manifest, not an automatic API request');
    assert(!h.notice.hidden && h.notice.textContent.includes('설치된 게임'));
  }
  {
    const h=harness({installed:true});
    const changes=[];
    h.window.initialsjObserveFullscreen((active,dom)=>changes.push([active,dom]));
    h.browserSetDom(true);
    h.browserSetDom(false);
    assert.deepEqual(changes,[[true,false],[true,true],[true,false]],'PWA API exit must be observable even if the app display remains fullscreen');
  }
  for(const ios of [false,true]) {
    const h=harness({supported:false,ios});
    h.click();await settled();
    assert(!h.notice.hidden && h.notice.textContent.includes(ios?'상태 막대':'지원하지'));
    assert(!h.control.disabled);
    if(ios)assert.equal(h.window.initialsjFullscreenLabel(),'APP DISPLAY');
  }
  {
    const h=harness({reject:true});
    h.click();await settled();
    assert(!h.notice.hidden && h.notice.textContent.includes('전환할 수'));
    assert(!h.control.disabled);
  }
  {
    const h=harness();
    await h.window.initialsjToggleFullscreen();
    assert(!h.window.initialsjIsFullscreen(),'A callback without activation must not claim success');
    assert(!h.notice.hidden);
  }
  assert(fs.readFileSync('export_presets.cfg','utf8').includes('progressive_web_app/display=0'));
  console.log('Fullscreen trusted click / exit / WebKit / PWA launch / unsupported / denied / geometry: PASS');
})().catch(error=>{console.error(error);process.exitCode=1;});
