/**
 * Tactical Audio Synthesizer & Haptic Feedback Engine
 * Synthesizes pure Web Audio tones (zero external audio files needed)
 */

class AlertAudioService {
  private audioCtx: AudioContext | null = null;
  private isMuted: boolean = false;

  constructor() {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('mesh_audio_muted');
      this.isMuted = saved === 'true';
    }
  }

  private getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.audioCtx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        this.audioCtx = new AudioCtx();
      }
    }
    if (this.audioCtx && this.audioCtx.state === 'suspended') {
      this.audioCtx.resume().catch(() => {});
    }
    return this.audioCtx;
  }

  public getMuted(): boolean {
    return this.isMuted;
  }

  public setMuted(muted: boolean): void {
    this.isMuted = muted;
    if (typeof window !== 'undefined') {
      localStorage.setItem('mesh_audio_muted', muted ? 'true' : 'false');
    }
  }

  public toggleMuted(): boolean {
    this.setMuted(!this.isMuted);
    if (!this.isMuted) {
      this.playClick();
    }
    return this.isMuted;
  }

  /**
   * Vibrate device if supported
   */
  public vibrate(pattern: number | number[]): void {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      try {
        navigator.vibrate(pattern);
      } catch (e) {}
    }
  }

  /**
   * High-priority Emergency SOS siren (assertive dual-tone alternating alert)
   */
  public playSosAlarm(): void {
    this.vibrate([300, 100, 300, 100, 400]);
    if (this.isMuted) return;

    const ctx = this.getContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sawtooth';
      gain.gain.setValueAtTime(0.25, now);

      // Alternating 880Hz / 587Hz siren cycles for 1.8 seconds
      for (let i = 0; i < 4; i++) {
        const step = now + i * 0.45;
        osc.frequency.setValueAtTime(880, step);
        osc.frequency.setValueAtTime(587, step + 0.22);
      }

      gain.gain.setValueAtTime(0.25, now + 1.7);
      gain.gain.linearRampToValueAtTime(0.001, now + 1.8);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 1.8);
    } catch (e) {
      console.warn('[Audio] Failed to play SOS alarm:', e);
    }
  }

  /**
   * Incoming tactical message chime (crisp double-tone harmonic chirp)
   */
  public playMessageChime(): void {
    this.vibrate([60, 40, 60]);
    if (this.isMuted) return;

    const ctx = this.getContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      gain.gain.setValueAtTime(0.18, now);

      osc.frequency.setValueAtTime(659.25, now); // E5
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.12);

      osc.frequency.setValueAtTime(880.0, now + 0.14); // A5
      gain.gain.setValueAtTime(0.22, now + 0.14);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.38);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.4);
    } catch (e) {}
  }

  /**
   * Mesh Uplink Acquired Chime (ascending tactical arpeggio: C5 -> E5 -> G5)
   */
  public playConnectChime(): void {
    this.vibrate([100, 50, 150]);
    if (this.isMuted) return;

    const ctx = this.getContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'triangle';
      gain.gain.setValueAtTime(0.2, now);

      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.setValueAtTime(659.25, now + 0.1); // E5
      osc.frequency.setValueAtTime(783.99, now + 0.2); // G5
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.45);
    } catch (e) {}
  }

  /**
   * MPU6050 Impact / Fall detection alarm
   */
  public playImpactAlert(): void {
    this.vibrate([200, 100, 200, 100, 500]);
    if (this.isMuted) return;

    const ctx = this.getContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'square';
      gain.gain.setValueAtTime(0.2, now);
      osc.frequency.setValueAtTime(1046.5, now); // C6
      osc.frequency.setValueAtTime(440.0, now + 0.15); // A4
      osc.frequency.setValueAtTime(1046.5, now + 0.3); // C6
      gain.gain.linearRampToValueAtTime(0.001, now + 0.6);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.6);
    } catch (e) {}
  }

  /**
   * Subtle tactile feedback click
   */
  public playClick(): void {
    this.vibrate(20);
    if (this.isMuted) return;

    const ctx = this.getContext();
    if (!ctx) return;

    try {
      const now = ctx.currentTime;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(1200, now);
      gain.gain.setValueAtTime(0.05, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.04);
    } catch (e) {}
  }
}

export const alertAudioService = new AlertAudioService();
