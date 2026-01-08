/**
 * Touch Behavior Classifier - Fine Motor Control Proxy
 * Analyzes touch patterns to assess motor control and behavior
 */

export interface TouchEvent {
  x: number;
  y: number;
  pressure?: number;
  timestamp: number;
  targetHit: boolean;
}

export interface TouchBehaviorIndices {
  fineMotorControl: number;    // 0-100
  impulsivity: number;          // 0-100
  explorationVsGoalDirected: number; // 0-100, 0=exploration, 100=goal-directed
  frustrationMarkers: number;   // 0-100
}

export class TouchBehaviorClassifier {
  classify(touches: TouchEvent[]): TouchBehaviorIndices {
    if (touches.length === 0) {
      return {
        fineMotorControl: 50,
        impulsivity: 50,
        explorationVsGoalDirected: 50,
        frustrationMarkers: 50
      };
    }

    const fineMotorControl = this.assessMotorControl(touches);
    const impulsivity = this.assessImpulsivity(touches);
    const explorationVsGoalDirected = this.assessGoalDirection(touches);
    const frustrationMarkers = this.detectFrustration(touches);

    return { fineMotorControl, impulsivity, explorationVsGoalDirected, frustrationMarkers };
  }

  // Formula: Accuracy % + (1 - avg_distance_from_target/max_distance) * 100
  private assessMotorControl(touches: TouchEvent[]): number {
    const hitRate = touches.filter(t => t.targetHit).length / touches.length;
    return Math.round(hitRate * 100);
  }

  // Formula: (rapid_taps / total_taps) * 100, where rapid = < 200ms apart
  private assessImpulsivity(touches: TouchEvent[]): number {
    let rapidTaps = 0;
    for (let i = 1; i < touches.length; i++) {
      if (touches[i].timestamp - touches[i - 1].timestamp < 200) rapidTaps++;
    }
    return Math.round((rapidTaps / touches.length) * 100);
  }

  // Formula: (hits / total) * 100
  private assessGoalDirection(touches: TouchEvent[]): number {
    const hits = touches.filter(t => t.targetHit).length;
    return Math.round((hits / touches.length) * 100);
  }

  // Formula: (repeated_same_spot_taps / total) * 100
  private detectFrustration(touches: TouchEvent[]): number {
    let frustrationTaps = 0;
    for (let i = 1; i < touches.length; i++) {
      const dx = touches[i].x - touches[i - 1].x;
      const dy = touches[i].y - touches[i - 1].y;
      const distance = Math.sqrt(dx * dx + dy * dy);
      const timeDiff = touches[i].timestamp - touches[i - 1].timestamp;

      // Same spot, rapid tapping = frustration marker
      if (distance < 50 && timeDiff < 300) frustrationTaps++;
    }
    return Math.round((frustrationTaps / touches.length) * 100);
  }
}
