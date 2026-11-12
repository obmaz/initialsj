// 고정된 두 초기 반사음과 짧은 피드백만 사용한다. 구간 진입 중 버퍼·노드를 생성하지 않는다.
window.InitialSJEnvironmentAudio = class {
  constructor(context) {
    this.context = context;
    this.closed = false;
    this.last = null;
    this.input = context.createGain();
    this.wet = context.createGain();
    this.input.gain.value = 0;
    this.wet.gain.value = 0;
    this.input.connect(context.destination);
    this.wet.connect(context.destination);
    this.taps = [0, 1].map(() => {
      const delay = context.createDelay(0.25);
      const filter = context.createBiquadFilter();
      const feedback = context.createGain();
      filter.type = 'lowpass';
      filter.Q.value = 0.4;
      feedback.gain.value = 0;
      this.input.connect(delay).connect(filter);
      filter.connect(this.wet);
      filter.connect(feedback).connect(delay);
      return {delay, filter, feedback};
    });
  }
  update(active, amount, enclosure) {
    if (this.closed) return;
    const now = this.context.currentTime;
    const room = enclosure < .001 ? 0 : Math.max(0, Math.min(1, enclosure));
    const wet = amount < .0001 ? 0 : Math.max(0, Math.min(.22, amount));
    if (this.last && active === this.last.active && Math.abs(wet - this.last.wet) < .0001 &&
        Math.abs(room - this.last.room) < .001 && !(wet === 0 && this.last.wet !== 0) &&
        !(room === 0 && this.last.room !== 0)) return;
    this.last = {active, wet, room};
    this.input.gain.setTargetAtTime(active ? 1 : 0, now, 0.035);
    this.wet.gain.setTargetAtTime(active ? wet * .7 : 0, now, 0.035);
    for (const [index, tap] of this.taps.entries()) {
      tap.delay.delayTime.setTargetAtTime(index ? .045 + room * .055 : .025 + room * .035, now, .1);
      tap.filter.frequency.setTargetAtTime(3800 - room * 1500, now, .1);
      tap.feedback.gain.setTargetAtTime(active ? .12 + room * .12 : 0, now, .05);
    }
  }
  close() {
    if (this.closed) return;
    this.closed = true;
    this.input.disconnect();
    this.wet.disconnect();
    for (const tap of this.taps) {
      tap.delay.disconnect(); tap.filter.disconnect(); tap.feedback.disconnect();
    }
    this.taps = [];
    this.input = null;
    this.wet = null;
    this.context = null;
  }
};
