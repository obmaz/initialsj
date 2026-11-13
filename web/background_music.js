// 긴 음악은 미디어 요소 한 개로 압축 상태에서 재생한다. 엔진 음향 그래프와 공유하지 않는다.
window.InitialSJMusic = class {
  constructor() {
    this.audio = new Audio();
    this.audio.preload = 'auto';
    this.audio.volume = 0;
    this.url = null;
    this.active = false;
    this.ended = false;
    this.closed = false;
    this.blocked = false;
    this.pending = false;
    this.revision = 0;
    this.audio.onended = () => { this.ended = true; };
    this.unlock = () => { this.blocked = false; this.play(); };
    this.visibility = () => { if (document.hidden) this.audio.pause(); else this.play(); };
    this.blur = () => { this.active = false; this.audio.pause(); };
    document.addEventListener('pointerdown', this.unlock, {passive: true});
    document.addEventListener('keydown', this.unlock);
    document.addEventListener('visibilitychange', this.visibility);
    window.addEventListener('blur', this.blur);
  }
  clearTrack() {
    this.revision++;
    this.pending = false;
    this.audio.pause();
    this.audio.removeAttribute('src');
    this.audio.load();
    if (this.url) URL.revokeObjectURL(this.url);
    this.url = null;
    this.ended = false;
    this.blocked = false;
  }
  setTrack(encoded) {
    if (this.closed) return;
    this.clearTrack();
    const bytes = Uint8Array.from(atob(encoded), value => value.charCodeAt(0));
    this.url = URL.createObjectURL(new Blob([bytes], {type: 'audio/ogg'}));
    this.audio.src = this.url;
    this.audio.load();
    this.play();
  }
  play() {
    if (this.closed || !this.active || !this.url || this.ended || this.blocked || this.pending || document.hidden || !this.audio.paused) return;
    const revision = this.revision;
    this.pending = true;
    this.audio.play().catch(error => {
      if (this.closed || revision !== this.revision || error.name === 'AbortError') return;
      // 사용자 동작을 기다린다. 매 프레임 play()를 재시도하지 않는다.
      this.blocked = true;
    }).finally(() => { if (revision === this.revision) this.pending = false; });
  }
  update(active, gain) {
    if (this.closed) return;
    this.active = active;
    this.audio.volume = Math.max(0, Math.min(1, gain));
    if (!active || document.hidden) this.audio.pause();
    else this.play();
  }
  close() {
    if (this.closed) return;
    this.closed = true;
    this.active = false;
    this.clearTrack();
    this.audio.onended = null;
    document.removeEventListener('pointerdown', this.unlock);
    document.removeEventListener('keydown', this.unlock);
    document.removeEventListener('visibilitychange', this.visibility);
    window.removeEventListener('blur', this.blur);
  }
};
