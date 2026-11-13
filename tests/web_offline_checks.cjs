// 실제 관리 워커의 캐시·오류·루트 URL 계약을 브라우저 없이 검사한다.
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const scope='https://example.test/initialsj/';
const config={version:'test',index:'index.html',offline:'index.offline.html',coreFiles:['index.html','index.offline.html'],engineFiles:['index.wasm','index.pck'],isolation:true};
const handlers={},entries=new Map(),deleted=[];
const key=value=>typeof value==='string'?new URL(value,scope).href:value.url;
const cache={
  async match(value){if(readBlocked)throw Error("read blocked");return entries.get(key(value))?.clone()},
  async put(value,response){if(!response.ok)throw Error('invalid response');entries.set(key(value),new Response(await response.arrayBuffer(),{status:response.status,headers:response.headers}))},
  async addAll(files){for(const file of files)await this.put(file,new Response(file.endsWith('offline.html')?'OFFLINE':'INDEX'))},
};
let requests=0,fail=false,offline=false,claimed=0,storageBlocked=false,readBlocked=false;
const fetch=async request=>{
  requests++;
  if(offline)throw Error('offline');
  if(fail){fail=false;return new Response('unavailable',{status:503})}
  return new Response('NETWORK');
};
const caches={open:async()=>{if(storageBlocked)throw Error("storage blocked");return cache},keys:async()=>['initialsj-offline:/initialsj/:old','other-application'],delete:async name=>{deleted.push(name)}};
const self={registration:{scope},addEventListener(type,handler){handlers[type]=handler},skipWaiting:async()=>{},clients:{claim:async()=>{claimed++},get:async()=>({url:scope})}};
const source=fs.readFileSync('web/offline_worker.js.in','utf8').replace('__INITIALSJ_OFFLINE_CONFIG__',JSON.stringify(config));
vm.runInNewContext(source,{self,caches,fetch,URL,Request,Response,Headers,Map,Set,Promise,Error});
async function lifecycle(type){const waits=[];handlers[type]({waitUntil(p){waits.push(p)}});await Promise.all(waits)}
async function request(name,{mode='cors',method='GET'}={}){
  const waits=[];
  let response;
  const req={url:new URL(name,scope).href,method,mode};
  handlers.fetch({request:req,respondWith(p){response=p},waitUntil(p){waits.push(p)}});
  if(!response)return null;
  const result=await response;
  await Promise.all(waits);
  return result;
}
(async()=>{
  await lifecycle('install');
  assert.equal(entries.size,2,'설치 단계에서 대용량 본체를 중복 다운로드하지 않는다');
  await lifecycle('activate');
  assert.equal(claimed,1);
  assert.deepEqual(deleted,['initialsj-offline:/initialsj/:old']);
  fail=true;
  assert.equal((await request('index.pck')).status,503);
  assert(!entries.has(scope+'index.pck'));
  assert.equal((await request('index.pck')).status,200);
  assert.equal((await request('index.pck')).status,200);
  assert.equal(requests,2,'503 이후 재시도하고 정상 응답만 캐시한다');
  await request('index.wasm');
  offline=true;
  for(const name of ['', 'index.html','index.html?diagnostics=1']) {
    const result=await request(name,{mode:'navigate'});
    assert.equal(await result.text(),'INDEX');
    assert.equal(result.headers.get('Cross-Origin-Opener-Policy'),'same-origin');
  }
  entries.delete(scope+'index.wasm');
  assert.equal(await(await request('',{mode:'navigate'})).text(),'OFFLINE');
  assert.equal(await request('https://external.test/index.pck'),null);
  assert.equal(await request('index.pck',{method:'POST'}),null);
  offline=false;
  storageBlocked=true;
  assert.equal(await(await request('',{mode:'navigate'})).text(),'NETWORK');
  storageBlocked=false;
  readBlocked=true;
  assert.equal(await(await request('',{mode:'navigate'})).text(),'NETWORK');
  assert.equal(await(await request('index.pck')).text(),'NETWORK');
  // 등록이 제한시간 뒤에 끝나도 해제한 제어 리스너를 다시 붙이지 않는다.
  let lateResolve,timeoutControl,added=0,removed=0;
  const registration={addEventListener(){added++},removeEventListener(){removed++}};
  const window={INITIALSJ_OFFLINE_VERSION:'test'};
  const serviceWorker={controller:null,addEventListener(){},removeEventListener(){}};
  vm.runInNewContext(fs.readFileSync('web/offline_bridge.js','utf8'),{
    window,navigator:{serviceWorker},GODOT_CONFIG:{serviceWorker:'worker.js'},
    engine:{installServiceWorker:()=>new Promise(resolve=>{lateResolve=resolve})},
    MessageChannel,Promise,Error,setTimeout(fn){timeoutControl=fn;return 1},clearTimeout(){},
  });
  const controlling=window.initialsjOffline.control();
  const rejected=assert.rejects(controlling,/서비스 워커/);
  timeoutControl();
  await rejected;
  lateResolve(registration);
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(added,0);
  assert.equal(removed,0);
  console.log('관리 워커 최초 저장 / 503 복구 / scope 캐시 정리 / root·index 오프라인 / 격리 헤더: PASS');
})().catch(error=>{console.error(error);process.exitCode=1});
