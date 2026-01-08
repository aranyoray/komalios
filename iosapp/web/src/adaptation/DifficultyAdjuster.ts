/**
 * Task Difficulty Auto-Adjuster
 *
 * Adapts task difficulty based on child performance
 * Implements guardrails to prevent sudden jumps
 */

export type DifficultyLevel = 'Easy' | 'Medium' | 'Hard' | 'Stretch';
export type TaskType = 'listening' | 'naming' | 'matching' | 'sequencing' | 'problem-solving';

export interface PerformanceMetrics {
  accuracyPercent: number;          // 0-100
  avgResponseLatency: number;       // ms
  emotionalStabilityIndex: number;  // 0-100
  disengagementEvents: number;
  vocabularyComplexityScore: number; // 0-100
}

export interface DifficultyRecommendation {
  difficulty: DifficultyLevel;
  nextTaskType: TaskType;
  reasoning: string;
  confidence: number;
}

export class DifficultyAdjuster {
  private currentDifficulty: DifficultyLevel = 'Easy';

  adjust(metrics: PerformanceMetrics): DifficultyRecommendation {
    const overallScore = this.calculateOverallScore(metrics);

    let newDifficulty: DifficultyLevel;

    // Decision logic
    if (overallScore >= 80 && metrics.accuracyPercent >= 85) {
      newDifficulty = this.increaseLevel(this.currentDifficulty);
    } else if (overallScore <= 40 || metrics.accuracyPercent <= 50) {
      newDifficulty = this.decreaseLevel(this.currentDifficulty);
    } else {
      newDifficulty = this.currentDifficulty;
    }

    // Guardrail: max one level change
    newDifficulty = this.enforceGuardrail(this.currentDifficulty, newDifficulty);

    const nextTask = this.selectNextTaskType(metrics, newDifficulty);
    const reasoning = this.explainDecision(metrics, newDifficulty);

    this.currentDifficulty = newDifficulty;

    return {
      difficulty: newDifficulty,
      nextTaskType: nextTask,
      reasoning,
      confidence: overallScore / 100
    };
  }

  private calculateOverallScore(m: PerformanceMetrics): number {
    return (
      m.accuracyPercent * 0.4 +
      (1 - Math.min(m.avgResponseLatency / 5000, 1)) * 100 * 0.2 +
      m.emotionalStabilityIndex * 0.2 +
      (1 - Math.min(m.disengagementEvents / 5, 1)) * 100 * 0.1 +
      m.vocabularyComplexityScore * 0.1
    );
  }

  private increaseLevel(current: DifficultyLevel): DifficultyLevel {
    const order: DifficultyLevel[] = ['Easy', 'Medium', 'Hard', 'Stretch'];
    const idx = order.indexOf(current);
    return order[Math.min(idx + 1, order.length - 1)];
  }

  private decreaseLevel(current: DifficultyLevel): DifficultyLevel {
    const order: DifficultyLevel[] = ['Easy', 'Medium', 'Hard', 'Stretch'];
    const idx = order.indexOf(current);
    return order[Math.max(idx - 1, 0)];
  }

  private enforceGuardrail(old: DifficultyLevel, proposed: DifficultyLevel): DifficultyLevel {
    const order: DifficultyLevel[] = ['Easy', 'Medium', 'Hard', 'Stretch'];
    const oldIdx = order.indexOf(old);
    const newIdx = order.indexOf(proposed);

    // Max jump of 1 level
    if (Math.abs(newIdx - oldIdx) > 1) {
      return order[oldIdx + Math.sign(newIdx - oldIdx)];
    }
    return proposed;
  }

  private selectNextTaskType(m: PerformanceMetrics, difficulty: DifficultyLevel): TaskType {
    if (m.avgResponseLatency > 3000) return 'listening';
    if (m.vocabularyComplexityScore < 50) return 'naming';
    if (m.accuracyPercent < 60) return 'matching';
    if (difficulty === 'Hard' || difficulty === 'Stretch') return 'sequencing';
    return 'problem-solving';
  }

  private explainDecision(m: PerformanceMetrics, difficulty: DifficultyLevel): string {
    if (m.accuracyPercent >= 85) {
      return `High accuracy (${m.accuracyPercent}%) suggests readiness for ${difficulty} tasks`;
    }
    if (m.accuracyPercent <= 50) {
      return `Lower accuracy (${m.accuracyPercent}%) indicates need for ${difficulty} support`;
    }
    return `Maintaining ${difficulty} based on steady performance`;
  }
}
