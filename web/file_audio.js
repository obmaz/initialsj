// 선택 차량의 네 루프·노면 두 루프·후류 루프는 렌더 틱과 무관하게 반복한다.
// web-loops.json의 근접 통과 WAV는 최대 한 단발 보이스로만 패닝·재생한다.
// 선택 순번과 종료 상태로 늦게 끝난 디코딩이 음향 그래프를 다시 만들지 못하게 한다.
window.InitialSJFileAudio = class {
  constructor(files) {
    this.files = files;
    this.context = new AudioContext({latencyHint: 'interactive'});
    this.decoded = {};
    this.voices = {};
    this.vehicle = null;
    this.closed = false;
    this.revision = 0;
    this.ready = Promise.resolve();
    this.target = {active: false, pitch: 1, engine: 0, boost: 0, boostPitch: 1, drift: 0, driftPitch: 1, coast: 0, gravel: 0, wet: 0, roadPitch: 1};
    this.spatial = {active: false, draft: 0, draftPan: 0, draftPitch: 1, serial: -1, level: 0, pan: 0, pitch: 1};
    this.passVoice = null;
    this.passBuffer = null;
    this.unlock = () => { if (!this.closed && this.context.state === 'suspended') this.context.resume(); };
    document.addEventListener('pointerdown', this.unlock, {passive: true});
    document.addEventListener('keydown', this.unlock);
    this.silence = () => { this.target.active = false; this.stopPass(); this.apply(); };
    this.visibility = () => { if (document.hidden) this.silence(); };
    window.addEventListener('blur', this.silence);
    document.addEventListener('visibilitychange', this.visibility);
  }
  decode(name) {
    if (!this.decoded[name]) {
      const encoded = this.files[name];
      if (!encoded) return Promise.reject(new Error('Missing loop ' + name));
      const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
      this.decoded[name] = this.context.decodeAudioData(bytes.buffer);
    }
    return this.decoded[name];
  }
  stopVoices() {
    for (const voice of Object.values(this.voices)) {
      voice.source.stop();
      voice.source.disconnect();
      voice.gain.disconnect();
      if (voice.pan) voice.pan.disconnect();
    }
    this.voices = {};
    this.stopPass();
  }
  setVehicle(id) {
    if (this.closed || id === this.vehicle) return this.ready;
    const revision = ++this.revision;
    this.vehicle = id;
    this.stopVoices();
    this.ready = Promise.all(['engine', 'coast', 'boost', 'drift', 'gravel', 'wet', 'draft', 'pass'].map(async name => {
      const group = name === 'draft' || name === 'pass' ? 'traffic' : (name === 'gravel' || name === 'wet' ? 'surface' : id);
      const buffer = await this.decode(group + '-' + name);
      // A -> B -> A can finish an older A decode after the new A request.
      // Only the latest request may create looping sources.
      if (this.closed || this.revision !== revision) return;
      if (name === 'pass') { this.passBuffer = buffer; return; }
      const source = this.context.createBufferSource();
      const gain = this.context.createGain();
      source.buffer = buffer;
      source.loop = true;
      gain.gain.value = 0;
      const pan = name === 'draft' ? this.context.createStereoPanner() : null;
      source.connect(gain);
      if (pan) gain.connect(pan).connect(this.context.destination);
      else gain.connect(this.context.destination);
      source.start();
      this.voices[name] = {source, gain, pan};
    })).then(() => this.apply()).catch(error => {
      if (!this.closed && this.revision === revision) console.error('Initial SJ file audio:', error);
    });
    return this.ready;
  }
  update(active, pitch, engine, boost, boostPitch, drift, driftPitch, coast = 0, gravel = 0, wet = 0, roadPitch = 1) {
    if (this.closed) return;
    this.target = {active, pitch, engine, boost, boostPitch, drift, driftPitch, coast, gravel, wet, roadPitch};
    this.apply();
  }
  updateSpatial(active, draft, draftPan, draftPitch, serial, level, pan, pitch) {
    if (this.closed) return;
    const changed = serial !== this.spatial.serial;
    this.spatial = {active, draft, draftPan, draftPitch, serial, level, pan, pitch};
    if (!active || level <= 0) this.stopPass();
    else if (changed && this.passBuffer && this.target.active) this.playPass(level, pan, pitch);
    this.apply();
  }
  releasePass(voice) {
    voice.source.onended = null;
    voice.source.disconnect(); voice.gain.disconnect(); voice.pan.disconnect();
    if (this.passVoice === voice) this.passVoice = null;
  }
  stopPass() {
    const voice = this.passVoice;
    if (!voice) return;
    voice.source.onended = null;
    voice.source.stop();
    this.releasePass(voice);
  }
  playPass(level, direction, pitch) {
    this.stopPass();
    const source = this.context.createBufferSource();
    const gain = this.context.createGain();
    const pan = this.context.createStereoPanner();
    source.buffer = this.passBuffer;
    source.playbackRate.value = pitch;
    gain.gain.value = level;
    pan.pan.value = direction;
    source.connect(gain).connect(pan).connect(this.context.destination);
    const voice = {source, gain, pan};
    source.onended = () => this.releasePass(voice);
    this.passVoice = voice;
    source.start();
  }
  apply() {
    if (this.closed) return;
    const now = this.context.currentTime;
    const goals = {
      engine: [this.target.engine, this.target.pitch],
      coast: [this.target.coast, this.target.pitch],
      gravel: [this.target.gravel, this.target.roadPitch],
      wet: [this.target.wet, this.target.roadPitch],
      boost: [this.target.boost, this.target.boostPitch],
      drift: [this.target.drift, this.target.driftPitch],
      draft: [this.spatial.draft, this.spatial.draftPitch],
    };
    for (const [name, voice] of Object.entries(this.voices)) {
      const [level, rate] = goals[name];
      const active = this.target.active && (name !== 'draft' || this.spatial.active);
      voice.gain.gain.setTargetAtTime(active ? level : 0, now, 0.035);
      voice.source.playbackRate.setTargetAtTime(rate, now, 0.08);
      if (voice.pan) voice.pan.pan.setTargetAtTime(this.spatial.draftPan, now, 0.04);
    }
    if (!this.target.active) this.stopPass();
    if (this.passVoice) {
      this.passVoice.pan.pan.setTargetAtTime(this.spatial.pan, now, 0.025);
      this.passVoice.source.playbackRate.setTargetAtTime(this.spatial.pitch, now, 0.025);
    }
  }
  close() {
    if (this.closed) return;
    this.closed = true;
    this.revision++;
    document.removeEventListener('pointerdown', this.unlock);
    document.removeEventListener('keydown', this.unlock);
    window.removeEventListener('blur', this.silence);
    document.removeEventListener('visibilitychange', this.visibility);
    this.stopVoices();
    this.files = {};
    this.decoded = {};
    this.passBuffer = null;
    this.vehicle = null;
    this.target.active = false;
    this.ready = Promise.resolve();
    this.context.close();
  }
};
