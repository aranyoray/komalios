/**
 * Komal Therapeutic Chatbot
 *
 * Research-based therapeutic chatbot for children aged 3-15.
 * Implements multiple evidence-based therapeutic techniques.
 *
 * RESEARCH FOUNDATIONS:
 * - Rogerian client-centered therapy (Rogers, 1951) - reflective listening, unconditional positive regard
 * - CBT for children (Kendall, 2012) - emotion identification, thought challenging
 * - Play therapy principles (Axline, 1947) - child-led, non-directive approach
 * - Social stories method (Gray & Garand, 1993) - structured narrative for social learning
 * - Emotion coaching (Gottman et al., 1996) - validating emotions, problem-solving
 * - Scaffolding/ZPD (Vygotsky, 1978) - just-right challenge level
 */

import { ErrorBus } from '../core/ErrorBus';
import { logEvent } from '../security/DataPolicyEnforcement';
import { geminiFlash, GeminiService } from '../services/geminiService';

export type TherapeuticTechnique =
  | 'rogerian_reflection'      // Rogers (1951): Reflect feelings, show empathy
  | 'emotion_coaching'         // Gottman et al. (1996): Validate emotion + problem-solve
  | 'cbt_thought_challenge'    // Kendall (2012): Identify and reframe thoughts
  | 'social_story'             // Gray & Garand (1993): Teach social skills via narrative
  | 'open_ended_exploration'   // Axline (1947): Child-led, non-directive
  | 'scaffolded_question'      // Vygotsky (1978): Guide toward ZPD
  | 'validation_affirmation';  // General positive reinforcement

export type ConversationContext = {
  childAge: number;
  ageBand: '3-5' | '6-10' | '11-15';
  conversationHistory: Message[];
  currentTopic?: string;
  detectedEmotion?: string;
  targetDomain?: string; // Which SEL domain to focus on
  sessionGoals?: string[];
};

export type Message = {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  technique?: TherapeuticTechnique; // Which technique was used (for tracking)
};

export type KomalResponse = {
  message: string;
  technique: TherapeuticTechnique;
  reasoning: string; // Why this technique was chosen
  domainRelevance: string[]; // Which SEL domains this addresses
};

/**
 * ============================================================================
 * MAIN CHATBOT CLASS
 * ============================================================================
 */

export class KomalChatbot {
  private gemini: GeminiService;
  private conversationContext: ConversationContext;

  constructor(
    context: ConversationContext
  ) {
    // Use the optimized Gemini 1.5 Flash service
    this.gemini = geminiFlash;
    this.conversationContext = context;
  }

  /**
   * Generate Komal's response to child's message
   *
   * Technique selection strategy:
   * 1. If strong emotion detected → emotion_coaching (Gottman)
   * 2. If negative self-talk → cbt_thought_challenge (Kendall)
   * 3. If social situation → social_story (Gray)
   * 4. If confusion/struggle → scaffolded_question (Vygotsky)
   * 5. Default → rogerian_reflection (Rogers)
   *
   * @param userMessage - Child's message
   * @returns Komal's therapeutic response
   */
  async generateResponse(userMessage: string): Promise<KomalResponse> {
    try {
      // Add user message to history
      this.conversationContext.conversationHistory.push({
        role: 'user',
        content: userMessage,
        timestamp: Date.now()
      });

      // 1. Analyze message to select technique
      const analysis = this.analyzeMessage(userMessage);
      const technique = this.selectTechnique(analysis);

      // 2. Build therapeutic prompt
      const systemPrompt = this.buildSystemPrompt(technique);
      
      // Include history in the user prompt for Gemini
      const historyText = this.getRecentHistory(10)
        .map(msg => `${msg.role === 'user' ? 'Child' : 'Komal'}: ${msg.content}`)
        .join('\n');
      
      const userPrompt = `${this.buildUserPrompt(userMessage, analysis)}\n\nRecent conversation history:\n${historyText}`;

      // 3. Call Gemini API (optimized for speed and empathy)
      const responseMessage = await this.gemini.generateContent(userPrompt, systemPrompt);

      // 4. Log response
      const response: KomalResponse = {
        message: responseMessage,
        technique,
        reasoning: analysis.reasoning,
        domainRelevance: analysis.domainRelevance
      };

      // Add to conversation history
      this.conversationContext.conversationHistory.push({
        role: 'assistant',
        content: responseMessage,
        timestamp: Date.now(),
        technique
      });

      // Safe logging (no raw child speech)
      logEvent({
        type: 'komal_response',
        payload: {
          technique,
          domainRelevance: analysis.domainRelevance,
          messageLength: responseMessage.length
        }
      });

      return response;

    } catch (error) {
      ErrorBus.report({
        code: 'KOMAL_RESPONSE_ERROR',
        message: 'Failed to generate Komal response',
        severity: 'error',
        context: { error: (error as Error).message }
      });

      // Fallback response
      return {
        message: "I'm here with you. Can you tell me more about how you're feeling?",
        technique: 'rogerian_reflection',
        reasoning: 'Fallback response due to error',
        domainRelevance: ['emotional-intelligence']
      };
    }
  }

  /**
   * Analyze message for therapeutic cues
   *
   * Detects:
   * - Emotion words (happy, sad, angry, scared, etc.)
   * - Negative self-talk ("I can't", "I'm bad at")
   * - Social situations (friends, sharing, turn-taking)
   * - Cognitive confusion (question marks, "I don't understand")
   *
   * @param message - Child's message
   * @returns Analysis with detected cues
   */
  private analyzeMessage(message: string): {
    hasEmotion: boolean;
    emotionType?: 'positive' | 'negative' | 'mixed';
    hasNegativeSelfTalk: boolean;
    hasSocialContent: boolean;
    hasConfusion: boolean;
    reasoning: string;
    domainRelevance: string[];
  } {
    const lowerMsg = message.toLowerCase();

    // Emotion detection
    const positiveEmotions = ['happy', 'excited', 'proud', 'glad', 'love', 'good', 'great', 'fun'];
    const negativeEmotions = ['sad', 'angry', 'mad', 'scared', 'worried', 'upset', 'frustrated', 'bad', 'hate'];

    const hasPositive = positiveEmotions.some(e => lowerMsg.includes(e));
    const hasNegative = negativeEmotions.some(e => lowerMsg.includes(e));

    let emotionType: 'positive' | 'negative' | 'mixed' | undefined;
    if (hasPositive && hasNegative) emotionType = 'mixed';
    else if (hasPositive) emotionType = 'positive';
    else if (hasNegative) emotionType = 'negative';

    // Negative self-talk detection (Beck, 1976 - cognitive distortions)
    const negativeSelfTalkPatterns = [
      "i can't", "i'm bad", "i'm not good", "i always", "i never",
      "nobody likes", "everyone hates", "i'm dumb", "i'm stupid"
    ];
    const hasNegativeSelfTalk = negativeSelfTalkPatterns.some(p => lowerMsg.includes(p));

    // Social content (Trevarthen, 2001 - social communication)
    const socialKeywords = ['friend', 'share', 'turn', 'play', 'talk', 'help', 'together', 'alone'];
    const hasSocialContent = socialKeywords.some(k => lowerMsg.includes(k));

    // Confusion markers
    const hasConfusion = lowerMsg.includes('?') ||
                         lowerMsg.includes("don't know") ||
                         lowerMsg.includes("don't understand");

    // Determine domain relevance
    const domainRelevance: string[] = [];
    if (hasPositive || hasNegative) domainRelevance.push('emotional-intelligence');
    if (hasSocialContent) domainRelevance.push('social-communication');
    if (hasNegativeSelfTalk) domainRelevance.push('cognitive');
    if (domainRelevance.length === 0) domainRelevance.push('language');

    // Reasoning
    let reasoning = 'Message analysis: ';
    if (emotionType) reasoning += `emotion=${emotionType}, `;
    if (hasNegativeSelfTalk) reasoning += 'negative self-talk detected, ';
    if (hasSocialContent) reasoning += 'social content, ';
    if (hasConfusion) reasoning += 'confusion markers';

    return {
      hasEmotion: emotionType !== undefined,
      emotionType,
      hasNegativeSelfTalk,
      hasSocialContent,
      hasConfusion,
      reasoning,
      domainRelevance
    };
  }

  /**
   * Select therapeutic technique based on message analysis
   *
   * Priority order (research-based):
   * 1. Strong negative emotion → emotion_coaching (Gottman et al., 1996)
   * 2. Negative self-talk → cbt_thought_challenge (Kendall, 2012)
   * 3. Social content → social_story (Gray & Garand, 1993)
   * 4. Confusion → scaffolded_question (Vygotsky, 1978)
   * 5. Positive emotion → validation_affirmation
   * 6. Default → rogerian_reflection (Rogers, 1951)
   *
   * @param analysis - Message analysis
   * @returns Selected technique
   */
  private selectTechnique(analysis: ReturnType<typeof this.analyzeMessage>): TherapeuticTechnique {
    // Priority 1: Emotion coaching for negative emotions (Gottman et al., 1996)
    if (analysis.hasEmotion && analysis.emotionType === 'negative') {
      return 'emotion_coaching';
    }

    // Priority 2: CBT for negative self-talk (Kendall, 2012)
    if (analysis.hasNegativeSelfTalk) {
      return 'cbt_thought_challenge';
    }

    // Priority 3: Social stories for social situations (Gray & Garand, 1993)
    if (analysis.hasSocialContent) {
      return 'social_story';
    }

    // Priority 4: Scaffolding for confusion (Vygotsky, 1978)
    if (analysis.hasConfusion) {
      return 'scaffolded_question';
    }

    // Priority 5: Affirmation for positive emotions
    if (analysis.hasEmotion && analysis.emotionType === 'positive') {
      return 'validation_affirmation';
    }

    // Default: Rogerian reflection (Rogers, 1951)
    return 'rogerian_reflection';
  }

  /**
   * Build system prompt for selected technique
   *
   * Each technique has research-based guidelines:
   * - Rogerian: Reflect feelings, show unconditional positive regard
   * - Emotion coaching: Name emotion, validate, then problem-solve
   * - CBT: Identify thought, challenge, reframe
   * - Social story: Describe situation, perspective, appropriate response
   * - Scaffolding: Ask guiding questions toward solution
   *
   * @param technique - Selected therapeutic technique
   * @returns System prompt for ChatGPT
   */
  private buildSystemPrompt(technique: TherapeuticTechnique): string {
    const { ageBand, targetDomain } = this.conversationContext;

    // Age-appropriate language guidelines
    const ageGuidelines = {
      '3-5': 'Use very simple words (3-5 words per sentence). Concrete examples. Avoid abstract concepts.',
      '6-10': 'Use simple language (5-10 words per sentence). Some abstract concepts OK with examples.',
      '11-15': 'Use age-appropriate language. Can discuss abstract ideas and emotions.'
    };

    const basePrompt = `You are Komal, a warm, supportive, and patient therapeutic companion for children. Your role is to help children develop social-emotional skills through conversation.

Age: ${this.conversationContext.childAge} years (${ageBand} band)
Language guidelines: ${ageGuidelines[ageBand]}

Core principles:
- Child-centered: Follow the child's lead, interests, and pace
- Non-judgmental: Accept all feelings and thoughts without criticism
- Validating: Acknowledge emotions before problem-solving
- Culturally sensitive: Respect diverse backgrounds and experiences
- Safe: Never diagnose, give medical advice, or replace professional help

Current focus domain: ${targetDomain || 'general SEL development'}
`;

    // Technique-specific prompts
    switch (technique) {
      case 'rogerian_reflection':
        // Rogers (1951): Reflect feelings, show empathy, unconditional positive regard
        return basePrompt + `
Technique: Rogerian Reflection (Rogers, 1951)
Approach:
1. Listen deeply to what the child is expressing
2. Reflect back the emotion you hear ("It sounds like you're feeling...")
3. Show unconditional positive regard (no judgment)
4. Let the child lead the conversation
5. Use brief reflections (1-2 sentences)

Example:
Child: "I didn't want to go to school today."
Komal: "It sounds like school felt hard today. Sometimes we don't feel like doing things, and that's okay."
`;

      case 'emotion_coaching':
        // Gottman et al. (1996): Name, validate, then guide toward regulation
        return basePrompt + `
Technique: Emotion Coaching (Gottman et al., 1996)
Steps:
1. Name the emotion: Help child label what they're feeling
2. Validate: "It's okay to feel [emotion]. Everyone feels this sometimes."
3. Set gentle limits if needed: "Even when we're mad, we don't hit."
4. Problem-solve together: "What could help you feel better?"

Example:
Child: "I'm so mad at my brother!"
Komal: "You're feeling really angry right now. It's okay to feel angry. What happened with your brother?"
`;

      case 'cbt_thought_challenge':
        // Kendall (2012): Identify thought, challenge, reframe
        return basePrompt + `
Technique: CBT Thought Challenge (Kendall, 2012)
Steps:
1. Identify the thought: "What are you thinking about yourself/situation?"
2. Challenge gently: "Is that always true? Can we think of times when it wasn't true?"
3. Reframe: Help child find a more balanced thought
4. Keep it age-appropriate: Use concrete examples

Example:
Child: "I'm bad at everything."
Komal: "You're thinking you're bad at everything. Hmm... Can you think of one thing you did well today? Even something small?"
`;

      case 'social_story':
        // Gray & Garand (1993): Structured narrative for social learning
        return basePrompt + `
Technique: Social Story (Gray & Garand, 1993)
Structure:
1. Describe the situation: "Sometimes when we play with friends..."
2. Perspective: "Other kids might feel... when we..."
3. Directive: "We can try... next time"
4. Keep it brief and positive

Example:
Child: "Nobody wanted to play with me."
Komal: "Sometimes at playtime, kids are already in a game. When that happens, we can ask 'Can I join?' If they say no, we can find something else fun to do. Next time, you could try asking someone new!"
`;

      case 'scaffolded_question':
        // Vygotsky (1978): Guide child toward zone of proximal development
        return basePrompt + `
Technique: Scaffolded Question (Vygotsky, 1978)
Approach:
1. Ask guiding questions to help child think through problem
2. Don't give answer directly - guide discovery
3. Break complex problems into smaller steps
4. Provide hints if child is stuck

Example:
Child: "I don't know what to do."
Komal: "Let's think together. What's the first small thing you could try? Even a tiny step?"
`;

      case 'validation_affirmation':
        return basePrompt + `
Technique: Validation & Affirmation
Approach:
1. Celebrate positive emotions and achievements
2. Reflect back child's pride/joy
3. Encourage continued effort
4. Keep it genuine and specific

Example:
Child: "I did it!"
Komal: "You did it! I can hear how proud you are. You worked really hard on that!"
`;

      case 'open_ended_exploration':
        // Axline (1947): Child-led, non-directive play therapy
        return basePrompt + `
Technique: Open-Ended Exploration (Axline, 1947)
Approach:
1. Follow child's lead completely
2. Ask open questions: "Tell me more...", "What happened next?"
3. No agenda - let child explore freely
4. Show interest without directing

Example:
Child: "I like dinosaurs."
Komal: "Dinosaurs! Tell me more about the dinosaurs you like."
`;
    }
  }

  /**
   * Build user prompt with context
   */
  private buildUserPrompt(userMessage: string, analysis: ReturnType<typeof this.analyzeMessage>): string {
    return `Child's message: "${userMessage}"

Detected themes: ${analysis.reasoning}
Relevant SEL domains: ${analysis.domainRelevance.join(', ')}

Respond as Komal using the specified therapeutic technique. Keep response brief (1-3 sentences max), warm, and age-appropriate.`;
  }

  /**
   * Get recent conversation history (token-efficient)
   */
  private getRecentHistory(count: number): Array<{ role: 'user' | 'assistant', content: string }> {
    const history = this.conversationContext.conversationHistory;
    const recent = history.slice(-count * 2); // Get last N exchanges (user + assistant)

    return recent.map(msg => ({
      role: msg.role,
      content: msg.content
    }));
  }

  /**
   * Get conversation statistics
   */
  getConversationStats(): {
    totalMessages: number;
    techniqueBreakdown: Record<TherapeuticTechnique, number>;
    averageResponseLength: number;
  } {
    const history = this.conversationContext.conversationHistory;
    const assistantMessages = history.filter(m => m.role === 'assistant');

    const techniqueBreakdown: Record<string, number> = {};
    assistantMessages.forEach(msg => {
      if (msg.technique) {
        techniqueBreakdown[msg.technique] = (techniqueBreakdown[msg.technique] || 0) + 1;
      }
    });

    const avgLength = assistantMessages.length > 0
      ? assistantMessages.reduce((sum, m) => sum + m.content.length, 0) / assistantMessages.length
      : 0;

    return {
      totalMessages: history.length,
      techniqueBreakdown: techniqueBreakdown as Record<TherapeuticTechnique, number>,
      averageResponseLength: Math.round(avgLength)
    };
  }
}

/**
 * USAGE EXAMPLE:
 *
 * // Initialize Komal chatbot
 * const komal = new KomalChatbot({
 *   childAge: 7,
 *   ageBand: '6-10',
 *   conversationHistory: [],
 *   targetDomain: 'emotional-intelligence'
 * });
 *
 * // Child sends message
 * const response = await komal.generateResponse("I'm really mad at my friend");
 * console.log(response.message); // Komal's therapeutic response
 * console.log(response.technique); // 'emotion_coaching'
 * console.log(response.reasoning); // Why this technique was chosen
 *
 * // Get statistics
 * const stats = komal.getConversationStats();
 * console.log(stats.techniqueBreakdown);
 * // { emotion_coaching: 3, rogerian_reflection: 2, ... }
 */
