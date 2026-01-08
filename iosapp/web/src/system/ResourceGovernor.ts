/**
 * Resource Governor - CPU/Battery/Memory Management
 * Monitors system resources and adjusts processing dynamically
 */

export type PowerMode = 'Normal' | 'LowPower';

export class ResourceGovernor {
  private mode: PowerMode = 'Normal';
  private cpuThreshold = 70; // percent
  private batteryThreshold = 20; // percent
  private checkInterval: NodeJS.Timeout | null = null;

  async init(): Promise<void> {
    this.checkInterval = setInterval(() => this.checkResources(), 5000);
  }

  private async checkResources(): Promise<void> {
    try {
      const battery = await (navigator as any).getBattery?.();
      const batteryLevel = battery?.level * 100 || 100;

      if (batteryLevel < this.batteryThreshold) {
        this.enterLowPowerMode();
      } else if (batteryLevel > this.batteryThreshold + 10 && this.mode === 'LowPower') {
        this.leaveLowPowerMode();
      }
    } catch {}
  }

  shouldProcess(sensorType: 'eye' | 'face' | 'audio'): boolean {
    if (this.mode === 'LowPower') {
      return sensorType === 'eye' && Math.random() < 0.5; // Sample 50% in low power
    }
    return true;
  }

  enterLowPowerMode(): void {
    this.mode = 'LowPower';
    console.log('[ResourceGovernor] Entering low power mode');
  }

  leaveLowPowerMode(): void {
    this.mode = 'Normal';
    console.log('[ResourceGovernor] Leaving low power mode');
  }

  getMode(): PowerMode {
    return this.mode;
  }

  destroy(): void {
    if (this.checkInterval) clearInterval(this.checkInterval);
  }
}
