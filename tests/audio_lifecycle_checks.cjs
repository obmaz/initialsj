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
  const source={buffer:null,loop:false,playbackRate:{setTargetAtTime(){}},connect(gain){context.connections.add(source);return gain},disconnect(){context.connections.delete(source)},start(){context.live.add(source)},stop(){assert(context.live.delete(source),'A source must stop exactly once')}};
  return source;
 }
 createGain(){const context=this;const gain={gain:{value:0,setTargetAtTime(){}},connect(){context.connections.add(gain);return gain},disconnect(){context.connections.delete(gain)}};return gain}
 close(){this.closes++;this.state='closed';return Promise.resolve()}
}
const window={...events};
vm.runInNewContext(fs.readFileSync('web/file_audio.js','utf8'),{window,document:events,AudioContext,console:{error(...args){errors.push(args)}},atob:encoded=>Buffer.from(encoded,'base64').toString('binary')});
const files={};for(const id of ['a','b'])for(const voice of ['engine','boost','drift'])files[id+'-'+voice]='QQ==';
(async()=>{
 const audio=new window.InitialSJFileAudio({...files});const context=contexts[0];
 const a=audio.setVehicle('a'),b=audio.setVehicle('b'),again=audio.setVehicle('a');
 assert.equal(context.pending.length,6,'Repeated visits must reuse the decoded-file promise');
 for(const pending of context.pending)pending.resolve({length:100});
 await Promise.all([a,b,again]);
 assert.equal(context.live.size,3,'A -> B -> A must leave exactly three current loops');
 assert.equal(context.connections.size,6);
 for(let i=0;i<20;i++)await audio.setVehicle(i%2?'a':'b');
 assert.equal(context.live.size,3,'Repeated selection must not accumulate looping sources');
 assert.equal(context.connections.size,6,'Stopped sources and gains must disconnect');
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
