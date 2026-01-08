/**
 * Ethical Guardrails for Child-Safe AI
 * Ensures all generated content is safe for children ages 3-15
 */

import { ErrorBus } from '../core/ErrorBus';

export interface SessionState {
  childAge: number;
  topic: string;
  language: string;
}

export class EthicalGuardrails {
  private tabooWords = new Set([
    // Add age-inappropriate words here
    'violence', 'weapon', 'drugs', 'alcohol'
  ]);

  private safeSELTopics = new Set([
    'emotions', 'feelings', 'friends', 'sharing', 'kindness',
    'listening', 'helping', 'patience', 'turn-taking', 'cooperation'
  ]);

  /**
   * Generate safe reply with multiple guardrails
   *
   * Guardrails:
   * 1. Age-appropriate language
   * 2. Only safe SEL topics
   * 3. Filter taboo words
   * 4. Use deterministic templates if low confidence
   * 5. Log safety events
   */
  generateSafeReply(userMessage: string, context: SessionState): string {
    // Guardrail 1: Check for taboo words
    if (this.containsTabooWords(userMessage)) {
      this.logSafetyEvent('taboo-words-detected', userMessage);
      return this.getSafetyFallback(context.childAge);
    }

    // Guardrail 2: Ensure topic is safe
    if (!this.isSafeTopic(context.topic)) {
      this.logSafetyEvent('unsafe-topic', context.topic);
      return this.getRedirectPrompt(context.childAge);
    }

    // Guardrail 3: Age-appropriate response
    const reply = this.generateAgeAppropriateReply(userMessage, context);

    // Guardrail 4: Final safety check
    if (this.containsTabooWords(reply)) {
      this.logSafetyEvent('generated-unsafe-content', reply);
      return this.getSafetyFallback(context.childAge);
    }

    return reply;
  }

  private containsTabooWords(text: string): boolean {
    const lower = text.toLowerCase();
    for (const word of this.tabooWords) {
      if (lower.includes(word)) return true;
    }
    return false;
  }

  private isSafeTopic(topic: string): boolean {
    return this.safeSELTopics.has(topic.toLowerCase());
  }

  private generateAgeAppropriateReply(message: string, context: SessionState): string {
    // Deterministic templates for safety
    if (context.childAge < 6) {
      return "That's great! Can you show me how you feel?";
    } else if (context.childAge < 10) {
      return "I understand. Can you tell me more about that?";
    } else {
      return "Interesting! What made you think of that?";
    }
  }

  private getSafetyFallback(age: number): string {
    if (age < 6) return "Let's try something fun!";
    return "Let's talk about something else.";
  }

  private getRedirectPrompt(age: number): string {
    if (age < 6) return "Can you tell me how you're feeling today?";
    return "Let's talk about your feelings. How are you doing?";
  }

  private logSafetyEvent(type: string, content: string): void {
    ErrorBus.report({
      code: 'SAFETY_GUARDRAIL_TRIGGERED',
      message: `Safety guardrail triggered: ${type}`,
      severity: 'warn',
      context: { type, contentLength: content.length }
    });
  }
}
