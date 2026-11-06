// Check the exported shell before engine JS, during downloads, and after startup.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 const url=process.env.INITIALSJ_REVIEW_URL||'http://127.0.0.1:8787/new/';
 const output=process.env.INITIALSJ_LOADING_OUTPUT||path.resolve(__dirname,'../docs/loading');
 fs.mkdirSync(output,{recursive:true});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:720}});
  const errors=[];
  // Observe real JS-to-Godot orientation notifications without changing the callback.
  await page.addInitScript(()=>{
   window.__orientationEvents=[];
   let subscribe;
   Object.defineProperty(window,'initialsjObserveOrientation',{
    configurable:true,
    get:()=>subscribe,
    set:fn=>{subscribe=callback=>fn(callback?(portrait=>{window.__orientationEvents.push(portrait);callback(portrait)}):null)}
   });
  });
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  let releaseJS,releasePack;
  const jsGate=new Promise(resolve=>{releaseJS=resolve});
  const packGate=new Promise(resolve=>{releasePack=resolve});
  await page.route('**/index.js',async route=>{await jsGate;await route.continue()});
  await page.route('**/index.pck',async route=>{await packGate;await route.continue()});
  // Commit does not wait for the deliberately delayed blocking script.
  await page.goto(url,{waitUntil:'commit'});
  await page.waitForFunction(()=>document.querySelector('#status-splash')?.naturalWidth>1000);
  assert.equal(await page.evaluate(()=>typeof Engine),'undefined');
  assert(await page.locator('#status').isVisible(),'Branded art must appear before the engine JS downloads');
  assert.equal(await page.locator('#loading-label').textContent(),'LOADING YOUR NEXT DRIVE');
  await page.screenshot({path:path.join(output,'desktop.png')});
  for(const [name,width,height] of [['mobile',896,414],['wide',2340,1080]]){
   await page.setViewportSize({width,height});
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
   const card=await page.locator('#loading-card').boundingBox();
   assert(card.x>=0&&card.y>=0&&card.x+card.width<=width&&card.y+card.height<=height,'Loading card must stay inside the viewport');
   await page.screenshot({path:path.join(output,name+'.png')});
  }
  await page.setViewportSize({width:390,height:844});
  assert(await page.locator('#landscape-guide').isVisible(),'Portrait must show rotation guidance instead of a driving layout');
  await page.screenshot({path:path.join(output,'portrait.png')});
  await page.emulateMedia({reducedMotion:'reduce'});
  assert.equal(await page.locator('#status-progress').evaluate(n=>getComputedStyle(n).animationName),'none');
  await page.emulateMedia({reducedMotion:'no-preference'});
  await page.setViewportSize({width:1280,height:720});
  releaseJS();
  await page.waitForFunction(()=>document.querySelector('#status-progress')?.hasAttribute('value'),{},{timeout:90000});
  const progress=await page.locator('#status-progress').evaluate(n=>({value:n.value,max:n.max}));
  assert(progress.value>=0&&progress.value<=progress.max);
  assert(await page.locator('#status').isVisible(),'Loading screen must remain visible while game data is delayed');
  await page.screenshot({path:path.join(output,'progress.png')});
  releasePack();
  await page.waitForFunction(()=>typeof engine!=='undefined'&&!document.querySelector('#status'),{},{timeout:90000});
  assert.equal(await page.locator('#canvas').count(),1);
  assert.equal(await page.locator('#landscape-guide').isVisible(),false);
  await page.locator('#canvas').focus();
  await page.keyboard.press('Enter');
  // Give the first rendered game frames time to consume the start input.
  await page.waitForTimeout(1500);
  await page.setViewportSize({width:390,height:844});
  await page.waitForFunction(()=>window.__orientationEvents.at(-1)===true);
  assert(await page.locator('#landscape-guide').isVisible());
  await page.waitForTimeout(500);
  await page.setViewportSize({width:896,height:414});
  await page.waitForFunction(()=>window.__orientationEvents.at(-1)===false);
  assert.equal(await page.locator('#landscape-guide').isVisible(),false);
  await page.screenshot({path:path.join(output,'paused-after-rotation.png')});
  assert.deepEqual(errors,[]);
  await page.close();
  // A real failed download must leave a readable notice instead of a stuck bar.
  const failure=await browser.newPage({viewport:{width:896,height:414}});
  await failure.route('**/index.wasm',route=>route.abort('failed'));
  await failure.goto(url,{waitUntil:'domcontentloaded'});
  await failure.locator('#status-notice').waitFor({state:'visible',timeout:60000});
  assert((await failure.locator('#status-notice').textContent()).trim().length>0);
  assert.equal(await failure.locator('#loading-card').isVisible(),false);
  await failure.close();
  console.log(JSON.stringify({url,firstPaintBeforeEngine:true,landscapeViewports:3,portraitGuide:true,orientationCallback:true,progress,garageStarted:true,failureNotice:true,errors}));
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exit(1)});
