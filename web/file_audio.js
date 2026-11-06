// AudioBufferSourceNode.loop keeps OGG playback independent of render/physics
// cadence. Encoded recordings are loaded from assets/audio/web-loops.json.
window.InitialSJFileAudio = class {
  constructor(files) {
    this.context = new AudioContext({latencyHint: 'interactive'});
    this.voices = {};
    this.closed = false;
    this.target = {active: false, pitch: 1, engine: 0, tires: 0};
    this.unlock = () => { if (!this.closed && this.context.state === 'suspended') this.context.resume(); };
    document.addEventListener('pointerdown', this.unlock, {passive: true});
    document.addEventListener('keydown', this.unlock);
    this.silence = () => { this.target.active = false; this.apply(); };
    this.visibility = () => { if (document.hidden) this.silence(); };
    window.addEventListener('blur', this.silence);
    document.addEventListener('visibilitychange', this.visibility);
    this.ready = Promise.all(Object.entries(files).map(async ([name, encoded]) => {
      const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
      const buffer = await this.context.decodeAudioData(bytes.buffer);
      if (this.closed) return;
      const source = this.context.createBufferSource();
      const gain = this.context.createGain();
      source.buffer = buffer;
      source.loop = true;
      gain.gain.value = 0;
      source.connect(gain).connect(this.context.destination);
      source.start();
      this.voices[name] = {source, gain};
    })).then(() => this.apply()).catch(error => console.error('Initial SJ file audio:', error));
  }
  update(active, pitch, engine, tires) {
    this.target = {active, pitch, engine, tires};
    this.apply();
  }
  apply() {
    if (this.closed) return;
    const now = this.context.currentTime;
    for (const [name, voice] of Object.entries(this.voices)) {
      voice.gain.gain.setTargetAtTime(this.target.active ? this.target[name] : 0, now, 0.035);
      voice.source.playbackRate.setTargetAtTime(name === 'engine' ? this.target.pitch : 1, now, 0.08);
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
