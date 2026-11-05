// Requires Playwright and a local Web export server; records real browser audio.
const {chromium}=require('playwright'); const fs=require('fs'); const path=require('path'); const os=require('os');
const output=path.join(os.tmpdir(),'initialsj-file-audio-web.webm');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader','--use-angle=swiftshader']});
 try{
  const p=await b.newPage({viewport:{width:1280,height:720}});const errors=[];
  p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  await p.addInitScript(()=>{
   const Native=window.AudioContext;const connect=AudioNode.prototype.connect;
   window.AudioContext=class extends Native{constructor(...args){super(...args);this.capture=this.createMediaStreamDestination();window.raceAudio=this;window.raceContexts=window.raceContexts||[];window.raceContexts.push(this);window.raceSources=[];const make=this.createBufferSource.bind(this);this.createBufferSource=()=>{const s=make();raceSources.push(s);return s};}};
   AudioNode.prototype.connect=function(target,...args){if(window.raceAudio&&target===window.raceAudio.destination)connect.call(this,window.raceAudio.capture);return connect.call(this,target,...args)};
  });
  await p.goto(process.env.INITIALSJ_REVIEW_URL||'http://127.0.0.1:8787/new/');
  await p.waitForFunction(()=>typeof engine!=='undefined'&&!document.querySelector('#status'),{},{timeout:60000});
  await p.screenshot({path:path.join(os.tmpdir(),'file-audio-menu.png')});
  await p.evaluate(()=>{for(const context of raceContexts){if(context!==raceAudio){const bridge=raceAudio.createMediaStreamSource(context.capture.stream);bridge.connect(raceAudio.capture)}}window.chunks=[];window.recorder=new MediaRecorder(raceAudio.capture.stream,{mimeType:'audio/webm;codecs=opus'});recorder.ondataavailable=e=>chunks.push(e.data);recorder.start()});
  await p.locator('#canvas').focus();await p.keyboard.press('Enter');
  await p.waitForTimeout(35000);await p.keyboard.down('Shift');await p.waitForTimeout(7000);await p.keyboard.up('Shift');
  await p.keyboard.down('ArrowLeft');await p.keyboard.down('Space');await p.waitForTimeout(3000);await p.keyboard.up('Space');await p.keyboard.up('ArrowLeft');
  await p.keyboard.press('v');await p.waitForTimeout(1500);
  const base64=await p.evaluate(()=>new Promise(resolve=>{recorder.onstop=()=>{const r=new FileReader;r.onload=()=>resolve(r.result.split(',')[1]);r.readAsDataURL(new Blob(chunks,{type:'audio/webm'}))};recorder.stop()}));
  fs.writeFileSync(output,Buffer.from(base64,'base64'));
  await p.screenshot({path:path.join(os.tmpdir(),'file-audio-race.png')});
  console.log(JSON.stringify({url:p.url(),errors,audioBytes:Buffer.from(base64,'base64').length,audioState:await p.evaluate(()=>raceAudio.state),sources:await p.evaluate(()=>raceSources.map(s=>({loop:s.loop,duration:s.buffer?.duration,rate:s.playbackRate.value})))}));
  const loopSources=await p.evaluate(()=>raceSources.filter(s=>s.buffer?.duration>2).map(s=>s.loop));
  if(errors.length||loopSources.length!==2||loopSources.some(loop=>!loop))process.exitCode=1;
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
