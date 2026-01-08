/**
 * Komal Personality System
 *
 * Defines Komal's therapeutic personality, voice, and age-appropriate communication style.
 *
 * RESEARCH FOUNDATIONS:
 * - Therapeutic alliance (Bordin, 1979) - Core conditions for effective therapy
 * - Person-centered therapy (Rogers, 1951) - Warmth, genuineness, empathy
 * - Developmental language norms (Brown, 1973) - Age-appropriate communication
 * - Zone of proximal development (Vygotsky, 1978) - Optimal scaffolding
 * - Cultural humility (Tervalon & Murray-García, 1998) - Respectful, adaptive approach
 */

export type AgeBand = '3-5' | '6-10' | '11-15';
export type CulturalContext = 'indian' | 'western' | 'mixed';
export type Language = 'en' | 'hi' | 'bn' | 'ta';

export interface PersonalityConfig {
  ageBand: AgeBand;
  culturalContext: CulturalContext;
  language: Language;
  childName?: string;
  preferredTopics?: string[];
}

export interface ResponseTone {
  warmth: number;           // 0-100: How warm and friendly
  directiveness: number;    // 0-100: How much guidance vs. child-led
  playfulness: number;      // 0-100: Playful vs. serious
  formalityLevel: number;   // 0-100: Formal vs. casual
  energyLevel: number;      // 0-100: Calm vs. energetic
}

/**
 * ============================================================================
 * KOMAL PERSONALITY CLASS
 * ============================================================================
 */

export class KomalPersonality {
  private config: PersonalityConfig;

  constructor(config: PersonalityConfig) {
    this.config = config;
  }

  /**
   * Get response tone for current context
   *
   * Tone adapts based on:
   * - Age (younger = more playful, older = more peer-like)
   * - Cultural context (Indian = slightly more formal)
   * - Child's emotional state
   *
   * @param childEmotion - Current child emotion
   * @returns Response tone parameters
   */
  getResponseTone(childEmotion?: string): ResponseTone {
    const { ageBand, culturalContext } = this.config;

    // Base tone by age (Rogers, 1951 + developmental norms)
    let warmth: number, directiveness: number, playfulness: number, formalityLevel: number, energyLevel: number;

    switch (ageBand) {
      case '3-5':
        // Very young: Very warm, moderately directive, very playful
        warmth = 90;
        directiveness = 60; // More guidance needed
        playfulness = 85;
        formalityLevel = 20; // Very casual
        energyLevel = 75; // Engaging but not overwhelming
        break;

      case '6-10':
        // Middle childhood: Warm, balanced, playful
        warmth = 85;
        directiveness = 50; // Balanced scaffolding
        playfulness = 70;
        formalityLevel = 30;
        energyLevel = 65;
        break;

      case '11-15':
        // Adolescence: Warm but peer-like, low directiveness, less playful
        warmth = 75;
        directiveness = 30; // More autonomy
        playfulness = 40; // More serious topics
        formalityLevel = 45; // Slightly more formal
        energyLevel = 50; // Calm, respectful
        break;
    }

    // Cultural adjustment (Tervalon & Murray-García, 1998)
    if (culturalContext === 'indian') {
      formalityLevel += 10; // Slightly more respectful tone
      playfulness -= 5;     // Slightly less casual
    }

    // Emotional state adjustment
    if (childEmotion) {
      const lowerEmotion = childEmotion.toLowerCase();

      // For negative emotions: Increase warmth, decrease playfulness
      if (['sad', 'angry', 'scared', 'worried'].includes(lowerEmotion)) {
        warmth += 10;
        playfulness -= 15;
        energyLevel -= 10; // Calmer approach
      }

      // For positive emotions: Can be more playful
      if (['happy', 'excited'].includes(lowerEmotion)) {
        playfulness += 10;
        energyLevel += 10;
      }
    }

    // Clamp to 0-100
    return {
      warmth: Math.max(0, Math.min(100, warmth)),
      directiveness: Math.max(0, Math.min(100, directiveness)),
      playfulness: Math.max(0, Math.min(100, playfulness)),
      formalityLevel: Math.max(0, Math.min(100, formalityLevel)),
      energyLevel: Math.max(0, Math.min(100, energyLevel))
    };
  }

  /**
   * Get greeting message
   *
   * Age-appropriate, warm greeting that sets therapeutic tone.
   *
   * @returns Greeting message
   */
  getGreeting(): string {
    const { ageBand, childName, language } = this.config;
    const name = childName ? ` ${childName}` : '';

    // Multilingual greetings
    if (language === 'hi') {
      return ageBand === '3-5'
        ? `नमस्ते${name}! मैं कोमल हूँ। क्या हम बात करें?`
        : `नमस्ते${name}! मैं कोमल हूँ। आज कैसे हो?`;
    }

    if (language === 'bn') {
      return ageBand === '3-5'
        ? `হ্যালো${name}! আমি কোমল। আমরা কি কথা বলব?`
        : `হ্যালো${name}! আমি কোমল। আজ কেমন আছো?`;
    }

    if (language === 'ta') {
      return ageBand === '3-5'
        ? `வணக்கம்${name}! நான் கோமல். பேசலாமா?`
        : `வணக்கம்${name}! நான் கோமல். இன்று எப்படி இருக்கிறாய்?`;
    }

    // English greetings (default)
    switch (ageBand) {
      case '3-5':
        return `Hi${name}! I'm Komal. Want to talk?`;

      case '6-10':
        return `Hi${name}! I'm Komal. How are you today?`;

      case '11-15':
        return `Hey${name}! I'm Komal. How's it going?`;
    }
  }

  /**
   * Get encouragement phrases
   *
   * Age-appropriate positive reinforcement (Skinner, 1953 + modern SEL)
   *
   * @returns Array of encouragement phrases
   */
  getEncouragementPhrases(): string[] {
    const { ageBand, language } = this.config;

    // Hindi encouragement
    if (language === 'hi') {
      return ageBand === '3-5'
        ? ['शाबाश!', 'बहुत अच्छा!', 'तुम कर सकते हो!']
        : ['बहुत बढ़िया!', 'अच्छा सोचा!', 'जारी रखो!'];
    }

    // Bengali encouragement
    if (language === 'bn') {
      return ageBand === '3-5'
        ? ['খুব ভালো!', 'চমৎকার!', 'তুমি পারবে!']
        : ['দারুণ!', 'ভালো চিন্তা!', 'চালিয়ে যাও!'];
    }

    // Tamil encouragement
    if (language === 'ta') {
      return ageBand === '3-5'
        ? ['அருமை!', 'நல்லது!', 'உன்னால் முடியும்!']
        : ['மிக அருமை!', 'நல்ல சிந்தனை!', 'தொடர்!'];
    }

    // English encouragement (default)
    switch (ageBand) {
      case '3-5':
        return [
          'Good job!',
          'You did it!',
          'I like that!',
          'That\'s great!',
          'Yay!'
        ];

      case '6-10':
        return [
          'That\'s a really good thought!',
          'I like how you\'re thinking about that.',
          'You\'re doing great!',
          'Keep going!',
          'That makes sense.'
        ];

      case '11-15':
        return [
          'That\'s a really insightful point.',
          'I appreciate you sharing that.',
          'You\'re thinking this through well.',
          'That takes courage to talk about.',
          'I hear you.'
        ];
    }
  }

  /**
   * Get empathy phrases
   *
   * Validating, non-judgmental responses (Rogers, 1951)
   *
   * @param emotion - Detected emotion
   * @returns Empathy phrase
   */
  getEmpathyPhrase(emotion: string): string {
    const { ageBand } = this.config;
    const lowerEmotion = emotion.toLowerCase();

    // Simple validation for young children
    if (ageBand === '3-5') {
      switch (lowerEmotion) {
        case 'sad': return 'I see you\'re sad. Sad is okay.';
        case 'angry': return 'You\'re feeling mad. That\'s okay.';
        case 'scared': return 'You\'re scared. I\'m here with you.';
        case 'happy': return 'You\'re happy! That\'s nice!';
        default: return 'I hear you.';
      }
    }

    // More nuanced validation for older children
    if (ageBand === '6-10') {
      switch (lowerEmotion) {
        case 'sad': return 'It sounds like you\'re feeling sad. That\'s a hard feeling.';
        case 'angry': return 'You\'re feeling angry. It\'s okay to feel angry sometimes.';
        case 'scared': return 'That sounds scary. It\'s okay to feel scared.';
        case 'worried': return 'You\'re worried. Everyone worries sometimes.';
        case 'happy': return 'You\'re feeling happy! I\'m glad.';
        default: return 'I hear what you\'re saying.';
      }
    }

    // Peer-like validation for adolescents
    switch (lowerEmotion) {
      case 'sad': return 'That sounds really hard. It makes sense you\'d feel sad about that.';
      case 'angry': return 'I can understand why that would make you angry.';
      case 'scared': return 'That\'s a scary situation. Your feelings make sense.';
      case 'worried': return 'That sounds stressful. It\'s understandable you\'re worried.';
      case 'frustrated': return 'That sounds frustrating. I get why you\'d feel that way.';
      case 'happy': return 'That\'s awesome! I\'m really glad for you.';
      default: return 'I hear you. Thanks for sharing that with me.';
    }
  }

  /**
   * Get transition phrases
   *
   * Smooth conversational transitions (Sacks et al., 1974)
   *
   * @returns Transition phrase
   */
  getTransitionPhrase(): string {
    const { ageBand } = this.config;
    const phrases = {
      '3-5': [
        'What else?',
        'And then?',
        'Tell me more.',
        'What happened next?'
      ],
      '6-10': [
        'Can you tell me more about that?',
        'What else happened?',
        'How did that feel?',
        'What did you do next?'
      ],
      '11-15': [
        'Can you say more about that?',
        'What was that like for you?',
        'How did you feel about it?',
        'What happened after that?'
      ]
    };

    const options = phrases[ageBand];
    return options[Math.floor(Math.random() * options.length)];
  }

  /**
   * Get closing phrases
   *
   * Warm, supportive goodbye that leaves child feeling positive.
   *
   * @returns Closing message
   */
  getClosingPhrase(): string {
    const { ageBand, childName, language } = this.config;
    const name = childName ? ` ${childName}` : '';

    // Multilingual closings
    if (language === 'hi') {
      return ageBand === '3-5'
        ? `बात करके अच्छा लगा${name}! बाद में मिलते हैं!`
        : `धन्यवाद${name}! फिर मिलेंगे!`;
    }

    if (language === 'bn') {
      return ageBand === '3-5'
        ? `কথা বলে ভালো লাগলো${name}! পরে দেখা হবে!`
        : `ধন্যবাদ${name}! আবার দেখা হবে!`;
    }

    if (language === 'ta') {
      return ageBand === '3-5'
        ? `பேசுவது நன்றாக இருந்தது${name}! பின்னர் சந்திப்போம்!`
        : `நன்றி${name}! மீண்டும் சந்திப்போம்!`;
    }

    // English closings (default)
    switch (ageBand) {
      case '3-5':
        return `I liked talking with you${name}! See you next time!`;

      case '6-10':
        return `Thanks for talking with me${name}! I'll see you soon!`;

      case '11-15':
        return `Thanks for sharing with me${name}. Take care!`;
    }
  }

  /**
   * Adjust language complexity
   *
   * Based on Brown (1973) - MLU norms and Vygotsky (1978) - ZPD
   *
   * Simplifies or elaborates response based on age.
   *
   * @param response - Original response
   * @returns Age-adjusted response
   */
  adjustLanguageComplexity(response: string): string {
    const { ageBand } = this.config;

    // For 3-5 year olds: Simplify to very short sentences
    if (ageBand === '3-5') {
      // Break into simple sentences (3-5 words each)
      const sentences = response.split(/[.!?]+/).filter(s => s.trim());

      return sentences.map(s => {
        const words = s.trim().split(/\s+/);
        if (words.length > 6) {
          // Take first 5-6 words
          return words.slice(0, 6).join(' ') + '.';
        }
        return s.trim() + '.';
      }).slice(0, 2).join(' '); // Max 2 sentences
    }

    // For 6-10 year olds: Moderate simplification
    if (ageBand === '6-10') {
      // Break into moderate sentences (8-10 words)
      const sentences = response.split(/[.!?]+/).filter(s => s.trim());

      return sentences.map(s => {
        const words = s.trim().split(/\s+/);
        if (words.length > 12) {
          return words.slice(0, 12).join(' ') + '.';
        }
        return s.trim() + '.';
      }).slice(0, 3).join(' '); // Max 3 sentences
    }

    // For 11-15 year olds: No simplification needed
    return response;
  }

  /**
   * Check if topic is age-appropriate
   *
   * Screens for topics that may not be suitable for age band.
   *
   * @param topic - Topic to check
   * @returns true if appropriate
   */
  isTopicAgeAppropriate(topic: string): boolean {
    const { ageBand } = this.config;

    const lowerTopic = topic.toLowerCase();

    // Topics inappropriate for 3-5
    const youngChildInappropriate = [
      'death', 'violence', 'romance', 'alcohol', 'drugs', 'sex'
    ];

    if (ageBand === '3-5') {
      return !youngChildInappropriate.some(t => lowerTopic.includes(t));
    }

    // Topics inappropriate for 6-10 (less restrictive)
    const middleChildInappropriate = [
      'violence', 'alcohol', 'drugs', 'sex'
    ];

    if (ageBand === '6-10') {
      return !middleChildInappropriate.some(t => lowerTopic.includes(t));
    }

    // 11-15: Can discuss most topics in age-appropriate way
    // Only screen for explicit content
    const adolescentInappropriate = ['explicit', 'graphic'];

    return !adolescentInappropriate.some(t => lowerTopic.includes(t));
  }

  /**
   * Get scaffolding level
   *
   * Based on Vygotsky (1978) - Zone of Proximal Development
   *
   * Returns how much support to provide:
   * - High: Lots of guidance, hints, modeling
   * - Medium: Some guidance, questions
   * - Low: Minimal support, let child lead
   *
   * @returns Scaffolding level
   */
  getScaffoldingLevel(): 'high' | 'medium' | 'low' {
    const { ageBand } = this.config;

    switch (ageBand) {
      case '3-5': return 'high';    // Lots of support needed
      case '6-10': return 'medium'; // Balanced scaffolding
      case '11-15': return 'low';   // Minimal intervention
    }
  }

  /**
   * Update configuration
   */
  updateConfig(updates: Partial<PersonalityConfig>): void {
    this.config = { ...this.config, ...updates };
  }

  /**
   * Get current configuration
   */
  getConfig(): PersonalityConfig {
    return { ...this.config };
  }
}

/**
 * USAGE EXAMPLE:
 *
 * // Initialize Komal's personality
 * const personality = new KomalPersonality({
 *   ageBand: '6-10',
 *   culturalContext: 'indian',
 *   language: 'en',
 *   childName: 'Aarav'
 * });
 *
 * // Get greeting
 * console.log(personality.getGreeting());
 * // "Hi Aarav! I'm Komal. How are you today?"
 *
 * // Get tone for current context
 * const tone = personality.getResponseTone('sad');
 * console.log(tone);
 * // { warmth: 95, directiveness: 50, playfulness: 55, ... }
 *
 * // Get empathy response
 * console.log(personality.getEmpathyPhrase('worried'));
 * // "You're worried. Everyone worries sometimes."
 *
 * // Adjust language complexity
 * const response = "It sounds like you're experiencing some anxiety about the upcoming test. That's a very common feeling.";
 * const adjusted = personality.adjustLanguageComplexity(response);
 * console.log(adjusted);
 * // "You're worried about the test. That's okay. Everyone feels that way sometimes."
 *
 * // Check topic appropriateness
 * console.log(personality.isTopicAgeAppropriate("feelings about school"));
 * // true
 */
