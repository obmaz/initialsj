// Exercise the actual browser mixer with deferred decode completions and live graph counts.
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const errors=[];
const listeners=new Map();
const events={addEventListener(type,callback){if(!listeners.has(callback))listeners.set(callback,new Set());listeners.get(callback).add(type)},removeEventListener(type,callback){const types=listeners.get(callback);if(types){types.delete(type);if(!types.size)listeners.delete(callback)}}};
const contexts=[];
class AudioContext {
 constructor(){this.state='running';this.currentTime=0;this.destination={};this.pending=[];this.live=new Set();this.connections=new Set();this.closes=0;contexts.push(this)}
 decodeAudioData(){return new Promise((resolve,reject)=>this.pending.push({resolve,reject}))}
 createBufferSource(){
  assert.notEqual(this.state,'closed','Late decodes must not rebuild a closed graph');
  const context=this;
  const source={buffer:null,loop:false,playbackRate:{value:1,setTargetAtTime(value){this.value=value}},connect(gain){context.connections.add(source);return gain},disconnect(){context.connections.delete(source)},start(){context.live.add(source)},stop(){assert(context.live.delete(source),'A source must stop exactly once')}};
  return source;
 }
 createGain(){const context=this;const gain={gain:{value:0,setTargetAtTime(value){this.value=value}},connect(target){context.connections.add(gain);return target},disconnect(){context.connections.delete(gain)}};return gain}
 createDelay(){const context=this;const node={delayTime:{value:0,setTargetAtTime(value){this.value=value}},connect(target){context.connections.add(node);return target},disconnect(){context.connections.delete(node)}};return node}
 createBiquadFilter(){const context=this;const node={type:'',frequency:{value:0,setTargetAtTime(value){this.value=value}},Q:{value:0},connect(target){context.connections.add(node);return target},disconnect(){context.connections.delete(node)}};return node}
 createStereoPanner(){const context=this;const pan={pan:{value:0,setTargetAtTime(value){this.value=value}},connect(target){context.connections.add(pan);return target},disconnect(){context.connections.delete(pan)}};return pan}
 close(){this.closes++;this.state='closed';return Promise.resolve()}
}
const window={...events};
vm.runInNewContext(fs.readFileSync('web/environment_audio.js','utf8')+'\n'+fs.readFileSync('web/file_audio.js','utf8'),{window,document:events,AudioContext,console:{error(...args){errors.push(args)}},atob:encoded=>Buffer.from(encoded,'base64').toString('binary')});
const files={};for(const id of ['a','b'])for(const voice of ['engine','coast','boost','drift'])files[id+'-'+voice]='QQ==';
for(const voice of ['gravel','wet'])files['surface-'+voice]='QQ==';
for(const voice of ['draft','pass'])files['traffic-'+voice]='QQ==';
(async()=>{
 const audio=new window.InitialSJFileAudio({...files});const context=contexts[0];
 const a=audio.setVehicle('a'),b=audio.setVehicle('b'),again=audio.setVehicle('a');
 assert.equal(context.pending.length,12,'Repeated visits must reuse the decoded-file promise');
 for(const pending of context.pending)pending.resolve({length:100});
 await Promise.all([a,b,again]);
 assert.equal(context.live.size,7,'A -> B -> A must leave exactly seven current loops');
 assert.equal(context.connections.size,23);
 for(let i=0;i<20;i++)await audio.setVehicle(i%2?'a':'b');
 assert.equal(context.live.size,7,'Repeated selection must not accumulate looping sources');
 assert.equal(context.connections.size,23,'Stopped sources and gains must disconnect');
 for(let i=0;i<100;i++)audio.updateEnvironment(true,.22,1);
 assert.equal(context.connections.size,23,'Changing acoustic regions must reuse the same graph');
 assert(Math.abs(audio.environment.taps[0].delay.delayTime.value-.06)<1e-9);
 assert(audio.environment.wet.gain.value>0);
 audio.update(true,1,1,0,1,0,1);
 audio.updateSpatial(true,.05,-.2,1.1,1,.07,-.8,1.15);
 assert.equal(context.live.size,8);assert.equal(context.connections.size,26);
 assert.equal(audio.passVoice.pan.pan.value,-.8);assert.equal(audio.voices.draft.pan.pan.value,-.2);
 const first=audio.passVoice;
 audio.updateSpatial(true,.05,.2,1.1,1,.07,.8,.9);
 assert.equal(audio.passVoice,first,'The same pass event must not allocate another source');
 assert.equal(first.pan.pan.value,.8);assert.equal(first.source.playbackRate.value,.9);
 for(let serial=2;serial<20;serial++)audio.updateSpatial(true,.05,.1,1,serial,.06,.7,1);
 assert.equal(context.live.size,8,'Repeated passes must replace, not accumulate, one-shots');
 const ended=audio.passVoice;context.live.delete(ended.source);ended.source.onended();
 assert.equal(audio.passVoice,null);assert.equal(context.live.size,7);assert.equal(context.connections.size,23);
 audio.updateSpatial(true,.05,0,1,21,.06,-.7,1);
 audio.updateSpatial(false,0,0,1,21,.06,-.7,1);
 assert.equal(audio.passVoice,null,'Pause and mute must stop a running pass');
 audio.updateSpatial(true,0,0,1,21,.06,-.7,1);
 assert.equal(audio.passVoice,null,'Resuming must not replay a pass heard before pause');
 audio.updateEnvironment(false,.22,1);
 assert.equal(audio.environment.input.gain.value,0);assert.equal(audio.environment.wet.gain.value,0);
 assert(audio.environment.taps.every(tap=>tap.feedback.gain.value===0));
 audio.close();audio.close();
 audio.update(true,1,1,1,1,1,1);
 assert.equal(audio.target.active,false,'A disposed mixer must ignore late updates');
 assert.equal(context.live.size,0);assert.equal(context.connections.size,0);assert.equal(context.closes,1);
 assert.equal(Object.keys(audio.decoded).length,0);assert.equal(Object.keys(audio.files).length,0);assert.equal(listeners.size,0);
 const pendingAudio=new window.InitialSJFileAudio({...files});const next=contexts[1];
 const request=pendingAudio.setVehicle('a');pendingAudio.close();
 for(const pending of next.pending)pending.resolve({length:100});
 await request;assert.equal(next.live.size,0);assert.equal(next.connections.size,0);assert.equal(listeners.size,0);
 const rejectedAudio=new window.InitialSJFileAudio({...files});const last=contexts[2];
 const rejected=rejectedAudio.setVehicle('a');rejectedAudio.close();
 for(const pending of last.pending)pending.reject(new Error('Decode cancelled on close'));
 await rejected;assert.equal(last.live.size,0);assert.equal(listeners.size,0);assert.deepEqual(errors,[]);
 console.log('Audio async A/B/A / repeated selection / graph disposal / late decode / listeners and buffer release: PASS');
})().catch(error=>{console.error(error);process.exitCode=1});
