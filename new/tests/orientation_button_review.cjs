// Exercise the real portrait button with supported, missing and rejected browser APIs.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const url=process.env.INITIALSJ_REVIEW_URL||'http://127.0.0.1:8787/new/';
 const reports=[];
 try{
  for(const mode of ['supported','unsupported','rejected_lock','rejected_fullscreen']){
   const page=await browser.newPage({viewport:{width:390,height:844}});
   const errors=[];
   page.on('pageerror',e=>errors.push(String(e)));
   await page.exposeFunction('requestLandscapeViewport',()=>page.setViewportSize({width:896,height:414}));
   // The orientation UI must work even before the heavy game runtime is ready.
   await page.route('**/index.js',route=>route.fulfill({contentType:'application/javascript',body:'window.Engine=class {static getMissingFeatures(){return []}startGame(){return new Promise(()=>{})}};'}));
   await page.goto(url,{waitUntil:'domcontentloaded'});
   await page.evaluate(mode=>{
    window.__calls=[];
    let fullscreen=false;
    Object.defineProperty(document,'fullscreenElement',{configurable:true,get:()=>fullscreen?document.documentElement:null});
    Object.defineProperty(document.documentElement,'requestFullscreen',{configurable:true,value:mode==='unsupported'?undefined:async()=>{
     window.__calls.push('fullscreen');
     if(mode==='rejected_fullscreen')throw new DOMException('Denied','NotAllowedError');
     fullscreen=true;
    }});
    Object.defineProperty(document,'exitFullscreen',{configurable:true,value:async()=>{window.__calls.push('exit');fullscreen=false}});
    Object.defineProperty(screen.orientation,'lock',{configurable:true,value:mode==='unsupported'?undefined:async orientation=>{
     window.__calls.push('lock:'+orientation);
     if(mode==='rejected_lock')throw new DOMException('Unsupported','NotSupportedError');
     await window.requestLandscapeViewport();
    }});
   },mode);
   assert(await page.locator('#landscape-guide').isVisible());
   await page.locator('#landscape-start').click();
   await page.waitForFunction(()=>!document.querySelector('#landscape-start').disabled);
   const calls=await page.evaluate(()=>window.__calls);
   if(mode==='supported'||mode==='rejected_fullscreen'){
    assert.deepEqual(calls,['fullscreen','lock:landscape']);
    assert.equal(await page.locator('#landscape-guide').isVisible(),false);
   }else{
    assert(await page.locator('#landscape-guide').isVisible());
    assert((await page.locator('#landscape-status').textContent()).includes('직접'));
    if(mode==='unsupported')assert.deepEqual(calls,[]);
    else assert.deepEqual(calls,['fullscreen','lock:landscape','exit']);
   }
   assert.deepEqual(errors,[]);
   reports.push({mode,calls,errors});
   await page.close();
  }
  console.log(JSON.stringify({url,reports}));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
