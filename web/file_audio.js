// AudioBufferSourceNode.loop keeps OGG playback independent of render/physics
// cadence. Encoded loops are loaded from assets/audio/web-loops.json, keyed
// "<vehicle id>-engine|boost|drift". Only the selected vehicle's three loops
// are decoded and playing (setVehicle); see docs/VEHICLE_AUDIO.md.
window.InitialSJFileAudio = class {
  constructor(files) {
    this.files = files;
    this.context = new AudioContext({latencyHint: 'interactive'});
    this.decoded = {};
    this.voices = {};
    this.vehicle = null;
    this.closed = false;
    this.ready = Promise.resolve();
    this.target = {active: false, pitch: 1, engine: 0, boost: 0, boostPitch: 1, drift: 0, driftPitch: 1};
    this.unlock = () => { if (!this.closed && this.context.state === 'suspended') this.context.resume(); };
    document.addEventListener('pointerdown', this.unlock, {passive: true});
    document.addEventListener('keydown', this.unlock);
    this.silence = () => { this.target.active = false; this.apply(); };
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
      voice.gain.disconnect();
    }
    this.voices = {};
  }
  setVehicle(id) {
    if (this.closed || id === this.vehicle) return this.ready;
    this.vehicle = id;
    this.stopVoices();
    this.ready = Promise.all(['engine', 'boost', 'drift'].map(async name => {
      const buffer = await this.decode(id + '-' + name);
      if (this.closed || this.vehicle !== id) return;
      const source = this.context.createBufferSource();
      const gain = this.context.createGain();
      source.buffer = buffer;
      source.loop = true;
      gain.gain.value = 0;
      source.connect(gain).connect(this.context.destination);
      source.start();
      this.voices[name] = {source, gain};
    })).then(() => this.apply()).catch(error => console.error('Initial SJ file audio:', error));
    return this.ready;
  }
  update(active, pitch, engine, boost, boostPitch, drift, driftPitch) {
    this.target = {active, pitch, engine, boost, boostPitch, drift, driftPitch};
    this.apply();
  }
  apply() {
    if (this.closed) return;
    const now = this.context.currentTime;
    const goals = {
      engine: [this.target.engine, this.target.pitch],
      boost: [this.target.boost, this.target.boostPitch],
      drift: [this.target.drift, this.target.driftPitch],
    };
    for (const [name, voice] of Object.entries(this.voices)) {
      const [level, rate] = goals[name];
      voice.gain.gain.setTargetAtTime(this.target.active ? level : 0, now, 0.035);
      voice.source.playbackRate.setTargetAtTime(rate, now, 0.08);
    }
  }
  close() {
    this.closed = true;
    document.removeEventListener('pointerdown', this.unlock);
    document.removeEventListener('keydown', this.unlock);
    window.removeEventListener('blur', this.silence);
    document.removeEventListener('visibilitychange', this.visibility);
    for (const voice of Object.values(this.voices)) voice.source.stop();
    this.context.close();
  }
};
