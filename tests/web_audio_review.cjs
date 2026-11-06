// Requires Playwright and a local Web export server; records real browser audio.
const {chromium}=require('playwright'); const fs=require('fs'); const path=require('path');
const {startTour}=require('./browser_helpers.cjs');
const outputDir=path.resolve(__dirname,'../build/reports/web-audio');
fs.mkdirSync(outputDir,{recursive:true});
const output=path.join(outputDir,'initialsj-file-audio-web.webm');
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
  await p.goto(process.env.INITIALSJ_REVIEW_URL||'http://127.0.0.1:8787/');
  await p.waitForFunction(()=>typeof engine!=='undefined'&&!document.querySelector('#status'),{},{timeout:60000});
  await p.screenshot({path:path.join(outputDir,'file-audio-menu.png')});
  await startTour(p);
  await p.keyboard.down('w');
  // Home -> garage -> race; recording a silent garage must never count as a pass.
  await p.waitForFunction(()=>window.initialsjFileAudio?.target.active&&window.initialsjFileAudio.target.engine>0.15,{},{timeout:60000});
  await p.evaluate(()=>{for(const context of raceContexts){if(context!==raceAudio){const bridge=raceAudio.createMediaStreamSource(context.capture.stream);bridge.connect(raceAudio.capture)}}window.chunks=[];window.recorder=new MediaRecorder(raceAudio.capture.stream,{mimeType:'audio/webm;codecs=opus'});recorder.ondataavailable=e=>chunks.push(e.data);recorder.start();window.recordingStart=raceAudio.currentTime});
  await p.evaluate(()=>{window.audioRates=[];window.rateTimer=setInterval(()=>{const voice=initialsjFileAudio.voices.engine;if(voice)audioRates.push(voice.source.playbackRate.value)},100)});
  await p.waitForTimeout(35000);await p.keyboard.down('s');await p.waitForTimeout(1000);await p.keyboard.up('s');await p.waitForTimeout(6000);
  await p.keyboard.down('ArrowLeft');await p.keyboard.down('Space');await p.waitForTimeout(3000);await p.keyboard.up('Space');await p.keyboard.up('ArrowLeft');
  await p.keyboard.up('w');
  const active=await p.evaluate(()=>({target:{...initialsjFileAudio.target},engineGain:initialsjFileAudio.voices.engine.gain.gain.value,minimumRate:Math.min(...audioRates),maximumRate:Math.max(...audioRates),seconds:raceAudio.currentTime-recordingStart}));
  if(!active.target.active||active.engineGain<0.01||active.maximumRate-active.minimumRate<0.03)throw Error('Actual driving audio and changing engine pitch are required');
  await p.keyboard.press('v');
  await p.waitForFunction(()=>!window.initialsjFileAudio.target.active);
  await p.waitForTimeout(500);
  const muted=await p.evaluate(()=>{clearInterval(rateTimer);return Object.values(initialsjFileAudio.voices).every(v=>v.gain.gain.value<0.001)});
  if(!muted)throw Error('Muting must silence both imported loop gains');
  const base64=await p.evaluate(()=>new Promise(resolve=>{recorder.onstop=()=>{const r=new FileReader;r.onload=()=>resolve(r.result.split(',')[1]);r.readAsDataURL(new Blob(chunks,{type:'audio/webm'}))};recorder.stop()}));
  fs.writeFileSync(output,Buffer.from(base64,'base64'));
  await p.screenshot({path:path.join(outputDir,'file-audio-race.png')});
  console.log(JSON.stringify({url:p.url(),errors,active,muted,audioBytes:Buffer.from(base64,'base64').length,audioState:await p.evaluate(()=>raceAudio.state),sources:await p.evaluate(()=>raceSources.map(s=>({loop:s.loop,duration:s.buffer?.duration,rate:s.playbackRate.value})))}));
  const loopSources=await p.evaluate(()=>raceSources.filter(s=>s.buffer?.duration>2).map(s=>s.loop));
  if(errors.length||loopSources.length!==2||loopSources.some(loop=>!loop))process.exitCode=1;
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exit(1)});
