/**
 * Conversation Analyzer
 *
 * Extracts SEL domain metrics from chat conversations with Komal.
 * Computes scores for social communication, language, emotional intelligence, etc.
 *
 * RESEARCH FOUNDATIONS:
 * - Turn-taking analysis (Sacks et al., 1974) - Conversational structure
 * - MLU (Mean Length of Utterance) - Language development metric (Brown, 1973)
 * - Emotion vocabulary (Izard, 1971) - Emotional intelligence indicator
 * - Topic maintenance (Mentis, 1994) - Social communication skill
 * - Question asking (Chouinard, 2007) - Cognitive curiosity marker
 */

import { Message } from './komalChatbot';
import { logEvent } from '../security/DataPolicyEnforcement';

export interface ConversationMetrics {
  // Social Communication domain
  socialCommunication: {
    turnTakingScore: number;        // 0-100: How well child alternates turns
    topicMaintenanceScore: number;  // 0-100: Stays on topic
    initiationScore: number;        // 0-100: Starts new topics
    responseRelevance: number;      // 0-100: Responses match context
  };

  // Language domain
  language: {
    vocabularyComplexity: number;   // 0-100: Word diversity
    sentenceComplexity: number;     // 0-100: MLU-based
    fluencyScore: number;           // 0-100: Natural flow
    questionAskingScore: number;    // 0-100: Curiosity/engagement
  };

  // Emotional Intelligence domain
  emotionalIntelligence: {
    emotionVocabularyScore: number; // 0-100: Uses emotion words
    emotionRegulationScore: number; // 0-100: Discusses coping strategies
    empathyIndicators: number;      // 0-100: Considers others' feelings
  };

  // Cognitive domain
  cognitive: {
    problemSolvingScore: number;    // 0-100: Discusses solutions
    abstractThinkingScore: number;  // 0-100: Uses abstract concepts
    selfReflectionScore: number;    // 0-100: Thinks about own thoughts
  };

  // Engagement metrics
  engagement: {
    messageCount: number;
    averageMessageLength: number;
    conversationDuration: number;   // Seconds
    engagementScore: number;        // 0-100: Overall engagement
  };
}

/**
 * Analyze conversation for SEL domain metrics
 *
 * Processes conversation history to extract behavioral indicators
 * across multiple SEL domains.
 *
 * @param messages - Conversation history
 * @param childAge - Child's age (affects scoring normalization)
 * @returns Computed metrics across all domains
 */
export function analyzeConversation(
  messages: Message[],
  childAge: number
): ConversationMetrics {
  // Filter child messages only (user role)
  const childMessages = messages.filter(m => m.role === 'user');
  const komalMessages = messages.filter(m => m.role === 'assistant');

  if (childMessages.length === 0) {
    return getEmptyMetrics();
  }

  // Compute each domain
  const socialCommunication = analyzeSocialCommunication(messages, childMessages, komalMessages);
  const language = analyzeLanguage(childMessages, childAge);
  const emotionalIntelligence = analyzeEmotionalIntelligence(childMessages);
  const cognitive = analyzeCognitive(childMessages);
  const engagement = analyzeEngagement(childMessages, messages);

  // Log metrics (safely, without raw content)
  logEvent({
    type: 'conversation_analyzed',
    payload: {
      messageCount: childMessages.length,
      socialScore: socialCommunication.turnTakingScore,
      languageScore: language.vocabularyComplexity,
      emotionScore: emotionalIntelligence.emotionVocabularyScore
    }
  });

  return {
    socialCommunication,
    language,
    emotionalIntelligence,
    cognitive,
    engagement
  };
}

/**
 * ============================================================================
 * SOCIAL COMMUNICATION ANALYSIS
 * ============================================================================
 */

function analyzeSocialCommunication(
  allMessages: Message[],
  childMessages: Message[],
  komalMessages: Message[]
): ConversationMetrics['socialCommunication'] {
  // Turn-taking score (Sacks et al., 1974)
  // Good turn-taking = alternating smoothly, not dominating or withdrawing
  const turnTakingScore = computeTurnTakingScore(allMessages);

  // Topic maintenance (Mentis, 1994)
  // Measures semantic coherence between consecutive child messages
  const topicMaintenanceScore = computeTopicMaintenance(childMessages);

  // Initiation (Wetherby & Prutting, 1984)
  // Does child start new topics or only respond?
  const initiationScore = computeInitiationScore(childMessages, komalMessages);

  // Response relevance (Grice's maxims, 1975)
  // Do responses relate to Komal's questions/statements?
  const responseRelevance = computeResponseRelevance(allMessages);

  return {
    turnTakingScore,
    topicMaintenanceScore,
    initiationScore,
    responseRelevance
  };
}

/**
 * Compute turn-taking score
 *
 * Based on Sacks et al. (1974) - Conversational turn structure
 *
 * Good turn-taking indicators:
 * - Alternating pattern (not long monologues)
 * - Consistent message lengths (not one-word responses)
 * - Regular timing (not very long gaps)
 *
 * @param messages - All messages (alternating child/Komal)
 * @returns Score 0-100
 */
function computeTurnTakingScore(messages: Message[]): number {
  if (messages.length < 4) return 50; // Too few to judge

  // Check alternation (should alternate user/assistant)
  let alternationCount = 0;
  for (let i = 1; i < messages.length; i++) {
    if (messages[i].role !== messages[i - 1].role) {
      alternationCount++;
    }
  }
  const alternationRatio = alternationCount / (messages.length - 1);

  // Check message length consistency (CV of message lengths)
  const childMessages = messages.filter(m => m.role === 'user');
  const lengths = childMessages.map(m => m.content.length);
  const avgLength = lengths.reduce((sum, l) => sum + l, 0) / lengths.length;
  const variance = lengths.reduce((sum, l) => sum + Math.pow(l - avgLength, 2), 0) / lengths.length;
  const cv = Math.sqrt(variance) / avgLength;

  // Score components
  const alternationScore = alternationRatio * 100; // Perfect alternation = 100
  const consistencyScore = Math.max(0, 100 - cv * 100); // Low CV = consistent

  // Weighted average
  const score = alternationScore * 0.6 + consistencyScore * 0.4;

  return Math.round(Math.max(0, Math.min(100, score)));
}

/**
 * Compute topic maintenance score
 *
 * Based on Mentis (1994) - Topic manipulation in discourse
 *
 * Measures semantic overlap between consecutive child messages.
 * Uses simple keyword overlap (production-safe, no ML needed).
 *
 * @param childMessages - Child's messages only
 * @returns Score 0-100
 */
function computeTopicMaintenance(childMessages: Message[]): number {
  if (childMessages.length < 2) return 50;

  let overlapCount = 0;
  let totalPairs = 0;

  for (let i = 1; i < childMessages.length; i++) {
    const prev = childMessages[i - 1].content.toLowerCase().split(/\s+/);
    const curr = childMessages[i].content.toLowerCase().split(/\s+/);

    // Remove stopwords
    const prevWords = new Set(prev.filter(w => w.length > 3));
    const currWords = new Set(curr.filter(w => w.length > 3));

    // Check for keyword overlap
    const overlap = [...prevWords].filter(w => currWords.has(w)).length;

    if (overlap > 0) overlapCount++;
    totalPairs++;
  }

  const maintenanceRatio = totalPairs > 0 ? overlapCount / totalPairs : 0;
  return Math.round(maintenanceRatio * 100);
}

/**
 * Compute initiation score
 *
 * Based on Wetherby & Prutting (1984) - Profiles of communicative functions
 *
 * Measures proactive communication:
 * - Do child messages introduce new topics?
 * - Or only respond to Komal's questions?
 *
 * Heuristic: Messages starting with statements (not answers) = initiation
 *
 * @param childMessages - Child's messages
 * @param komalMessages - Komal's messages
 * @returns Score 0-100
 */
function computeInitiationScore(childMessages: Message[], komalMessages: Message[]): number {
  if (childMessages.length === 0) return 0;

  let initiations = 0;

  for (let i = 0; i < childMessages.length; i++) {
    const childMsg = childMessages[i].content.toLowerCase();

    // Check if previous Komal message was a question
    const prevKomalMsg = komalMessages[i - 1]?.content.toLowerCase() || '';
    const komalAskedQuestion = prevKomalMsg.includes('?');

    // If Komal didn't ask question, child is initiating
    if (!komalAskedQuestion) {
      initiations++;
    } else {
      // Even if Komal asked, check if child's response goes beyond answer
      // Long, elaborative responses = more proactive
      if (childMsg.split(/\s+/).length > 8) {
        initiations += 0.5; // Partial credit for elaboration
      }
    }
  }

  const initiationRatio = initiations / childMessages.length;
  return Math.round(Math.min(100, initiationRatio * 100));
}

/**
 * Compute response relevance
 *
 * Based on Grice's maxims (1975) - Cooperative principle in conversation
 *
 * Simple heuristic: Relevant responses contain keywords from question.
 * More sophisticated: Could use semantic similarity, but keeping token-efficient.
 *
 * @param messages - All messages
 * @returns Score 0-100
 */
function computeResponseRelevance(messages: Message[]): number {
  if (messages.length < 2) return 50;

  let relevantCount = 0;
  let totalResponses = 0;

  for (let i = 1; i < messages.length; i++) {
    if (messages[i].role === 'user' && messages[i - 1].role === 'assistant') {
      const komalMsg = messages[i - 1].content.toLowerCase();
      const childMsg = messages[i].content.toLowerCase();

      // Extract keywords from Komal's message
      const komalKeywords = komalMsg.split(/\s+/).filter(w => w.length > 4);

      // Check if child's response contains any keywords
      const hasKeywordOverlap = komalKeywords.some(keyword =>
        childMsg.includes(keyword.slice(0, -2)) // Stem matching
      );

      // Also accept if child provides substantive response (not just "yes" or "no")
      const isSubstantive = childMsg.split(/\s+/).length > 2;

      if (hasKeywordOverlap || isSubstantive) {
        relevantCount++;
      }

      totalResponses++;
    }
  }

  const relevanceRatio = totalResponses > 0 ? relevantCount / totalResponses : 0;
  return Math.round(relevanceRatio * 100);
}

/**
 * ============================================================================
 * LANGUAGE ANALYSIS
 * ============================================================================
 */

function analyzeLanguage(
  childMessages: Message[],
  childAge: number
): ConversationMetrics['language'] {
  // Vocabulary complexity (Type-Token Ratio)
  const vocabularyComplexity = computeVocabularyComplexity(childMessages);

  // Sentence complexity (MLU - Mean Length of Utterance, Brown 1973)
  const sentenceComplexity = computeMLU(childMessages, childAge);

  // Fluency (natural flow without excessive fillers)
  const fluencyScore = computeFluency(childMessages);

  // Question asking (Chouinard, 2007 - children's questions as learning tool)
  const questionAskingScore = computeQuestionAsking(childMessages);

  return {
    vocabularyComplexity,
    sentenceComplexity,
    fluencyScore,
    questionAskingScore
  };
}

/**
 * Compute vocabulary complexity using Type-Token Ratio (TTR)
 *
 * TTR = (unique words / total words) * 100
 * Higher TTR = more diverse vocabulary
 *
 * Normalized for age (younger children naturally have lower TTR)
 */
function computeVocabularyComplexity(childMessages: Message[]): number {
  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');
  const words = allText.split(/\s+/).filter(w => w.length > 0);

  if (words.length === 0) return 0;

  const uniqueWords = new Set(words);
  const ttr = uniqueWords.size / words.length;

  // TTR typically ranges 0.4-0.8 for children
  // Map to 0-100 scale
  const score = (ttr - 0.3) / 0.5 * 100; // 0.3 = low, 0.8 = high

  return Math.round(Math.max(0, Math.min(100, score)));
}

/**
 * Compute Mean Length of Utterance (MLU)
 *
 * Based on Brown (1973) - Language development metric
 *
 * MLU = average words per message
 * Normalized by age:
 * - Age 3-5: MLU 3-5 expected
 * - Age 6-10: MLU 5-8 expected
 * - Age 11-15: MLU 8-12 expected
 */
function computeMLU(childMessages: Message[], childAge: number): number {
  if (childMessages.length === 0) return 0;

  const wordCounts = childMessages.map(m => m.content.split(/\s+/).length);
  const mlu = wordCounts.reduce((sum, c) => sum + c, 0) / wordCounts.length;

  // Age-based norms
  let expectedMin: number, expectedMax: number;
  if (childAge <= 5) {
    expectedMin = 3;
    expectedMax = 5;
  } else if (childAge <= 10) {
    expectedMin = 5;
    expectedMax = 8;
  } else {
    expectedMin = 8;
    expectedMax = 12;
  }

  // Normalize to 0-100 scale
  const score = ((mlu - expectedMin) / (expectedMax - expectedMin)) * 100;

  return Math.round(Math.max(0, Math.min(100, score)));
}

/**
 * Compute fluency score
 *
 * Measures natural flow vs. excessive fillers ("um", "uh", "like")
 */
function computeFluency(childMessages: Message[]): number {
  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');
  const words = allText.split(/\s+/);

  if (words.length === 0) return 0;

  const fillers = ['um', 'uh', 'like', 'you know', 'i mean', 'sort of', 'kind of'];
  let fillerCount = 0;

  words.forEach(word => {
    if (fillers.includes(word)) fillerCount++;
  });

  const fillerRatio = fillerCount / words.length;

  // Lower filler ratio = higher fluency
  const score = (1 - fillerRatio) * 100;

  return Math.round(Math.max(0, Math.min(100, score)));
}

/**
 * Compute question asking score
 *
 * Based on Chouinard (2007) - Children's questions as learning mechanism
 *
 * More questions = more curiosity and engagement
 */
function computeQuestionAsking(childMessages: Message[]): number {
  if (childMessages.length === 0) return 0;

  const questionCount = childMessages.filter(m => m.content.includes('?')).length;
  const questionRatio = questionCount / childMessages.length;

  // Normalize: 30%+ questions = high score
  const score = Math.min(1, questionRatio / 0.3) * 100;

  return Math.round(score);
}

/**
 * ============================================================================
 * EMOTIONAL INTELLIGENCE ANALYSIS
 * ============================================================================
 */

function analyzeEmotionalIntelligence(
  childMessages: Message[]
): ConversationMetrics['emotionalIntelligence'] {
  // Emotion vocabulary (Izard, 1971)
  const emotionVocabularyScore = computeEmotionVocabulary(childMessages);

  // Emotion regulation (Gross, 1998)
  const emotionRegulationScore = computeEmotionRegulation(childMessages);

  // Empathy (Eisenberg, 2000)
  const empathyIndicators = computeEmpathy(childMessages);

  return {
    emotionVocabularyScore,
    emotionRegulationScore,
    empathyIndicators
  };
}

/**
 * Compute emotion vocabulary score
 *
 * Based on Izard (1971) - Differential emotions theory
 *
 * Counts unique emotion words used by child
 */
function computeEmotionVocabulary(childMessages: Message[]): number {
  const emotionWords = [
    'happy', 'sad', 'angry', 'scared', 'worried', 'excited', 'proud',
    'frustrated', 'disappointed', 'surprised', 'confused', 'calm',
    'nervous', 'embarrassed', 'jealous', 'guilty', 'ashamed', 'hopeful',
    'grateful', 'loved', 'lonely', 'bored', 'curious'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');
  const usedEmotions = new Set<string>();

  emotionWords.forEach(emotion => {
    if (allText.includes(emotion)) {
      usedEmotions.add(emotion);
    }
  });

  // Score based on unique emotion words
  // 5+ unique emotions = excellent
  const score = Math.min(1, usedEmotions.size / 5) * 100;

  return Math.round(score);
}

/**
 * Compute emotion regulation score
 *
 * Based on Gross (1998) - Emotion regulation strategies
 *
 * Looks for regulation keywords: "calm down", "take breath", "count to 10", etc.
 */
function computeEmotionRegulation(childMessages: Message[]): number {
  const regulationPhrases = [
    'calm down', 'take breath', 'count to', 'feel better', 'talk about',
    'ask for help', 'take break', 'try again', 'think about', 'remember'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');

  let regulationCount = 0;
  regulationPhrases.forEach(phrase => {
    if (allText.includes(phrase)) regulationCount++;
  });

  // Score based on regulation strategy mentions
  const score = Math.min(1, regulationCount / 3) * 100;

  return Math.round(score);
}

/**
 * Compute empathy indicators
 *
 * Based on Eisenberg (2000) - Empathy development
 *
 * Looks for perspective-taking language: "they feel", "he/she was", etc.
 */
function computeEmpathy(childMessages: Message[]): number {
  const empathyPatterns = [
    'they feel', 'he feels', 'she feels', 'their', 'his', 'her',
    'they were', 'he was', 'she was', 'sad because', 'happy because',
    'wanted to', 'needed', 'likes', 'doesn\'t like'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');

  let empathyCount = 0;
  empathyPatterns.forEach(pattern => {
    if (allText.includes(pattern)) empathyCount++;
  });

  // Score based on perspective-taking language
  const score = Math.min(1, empathyCount / 4) * 100;

  return Math.round(score);
}

/**
 * ============================================================================
 * COGNITIVE ANALYSIS
 * ============================================================================
 */

function analyzeCognitive(
  childMessages: Message[]
): ConversationMetrics['cognitive'] {
  // Problem solving
  const problemSolvingScore = computeProblemSolving(childMessages);

  // Abstract thinking
  const abstractThinkingScore = computeAbstractThinking(childMessages);

  // Self-reflection (metacognition)
  const selfReflectionScore = computeSelfReflection(childMessages);

  return {
    problemSolvingScore,
    abstractThinkingScore,
    selfReflectionScore
  };
}

function computeProblemSolving(childMessages: Message[]): number {
  const problemSolvingPhrases = [
    'i could', 'i can', 'i will', 'i should', 'maybe', 'what if',
    'try to', 'figure out', 'solve', 'fix', 'help', 'plan'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');

  let count = 0;
  problemSolvingPhrases.forEach(phrase => {
    if (allText.includes(phrase)) count++;
  });

  const score = Math.min(1, count / 3) * 100;
  return Math.round(score);
}

function computeAbstractThinking(childMessages: Message[]): number {
  const abstractWords = [
    'because', 'reason', 'think', 'believe', 'idea', 'imagine',
    'suppose', 'wonder', 'understand', 'mean', 'always', 'never', 'sometimes'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');

  let count = 0;
  abstractWords.forEach(word => {
    if (allText.includes(word)) count++;
  });

  const score = Math.min(1, count / 4) * 100;
  return Math.round(score);
}

function computeSelfReflection(childMessages: Message[]): number {
  const reflectionPhrases = [
    'i think', 'i feel', 'i know', 'i realize', 'i notice',
    'i remember', 'i learned', 'i understand', 'i wonder'
  ];

  const allText = childMessages.map(m => m.content.toLowerCase()).join(' ');

  let count = 0;
  reflectionPhrases.forEach(phrase => {
    if (allText.includes(phrase)) count++;
  });

  const score = Math.min(1, count / 3) * 100;
  return Math.round(score);
}

/**
 * ============================================================================
 * ENGAGEMENT ANALYSIS
 * ============================================================================
 */

function analyzeEngagement(
  childMessages: Message[],
  allMessages: Message[]
): ConversationMetrics['engagement'] {
  const messageCount = childMessages.length;

  const avgLength = messageCount > 0
    ? childMessages.reduce((sum, m) => sum + m.content.length, 0) / messageCount
    : 0;

  const duration = allMessages.length > 0
    ? (allMessages[allMessages.length - 1].timestamp - allMessages[0].timestamp) / 1000
    : 0;

  // Engagement score combines:
  // - Message count (more = engaged)
  // - Average length (longer = engaged)
  // - Conversation duration (longer = sustained)
  const countScore = Math.min(100, messageCount * 10); // 10+ messages = 100
  const lengthScore = Math.min(100, avgLength / 2); // 200 chars = 100
  const durationScore = Math.min(100, duration / 3); // 300s (5min) = 100

  const engagementScore = Math.round(
    countScore * 0.4 + lengthScore * 0.3 + durationScore * 0.3
  );

  return {
    messageCount,
    averageMessageLength: Math.round(avgLength),
    conversationDuration: Math.round(duration),
    engagementScore
  };
}

/**
 * Get empty metrics (default)
 */
function getEmptyMetrics(): ConversationMetrics {
  return {
    socialCommunication: {
      turnTakingScore: 0,
      topicMaintenanceScore: 0,
      initiationScore: 0,
      responseRelevance: 0
    },
    language: {
      vocabularyComplexity: 0,
      sentenceComplexity: 0,
      fluencyScore: 0,
      questionAskingScore: 0
    },
    emotionalIntelligence: {
      emotionVocabularyScore: 0,
      emotionRegulationScore: 0,
      empathyIndicators: 0
    },
    cognitive: {
      problemSolvingScore: 0,
      abstractThinkingScore: 0,
      selfReflectionScore: 0
    },
    engagement: {
      messageCount: 0,
      averageMessageLength: 0,
      conversationDuration: 0,
      engagementScore: 0
    }
  };
}

/**
 * USAGE EXAMPLE:
 *
 * // After conversation with Komal
 * const metrics = analyzeConversation(conversationHistory, childAge);
 *
 * console.log('Social Communication:', metrics.socialCommunication);
 * // { turnTakingScore: 85, topicMaintenanceScore: 72, ... }
 *
 * console.log('Language:', metrics.language);
 * // { vocabularyComplexity: 68, sentenceComplexity: 75, ... }
 *
 * console.log('Emotional Intelligence:', metrics.emotionalIntelligence);
 * // { emotionVocabularyScore: 80, emotionRegulationScore: 55, ... }
 *
 * // Feed into subdomain scoring system
 * sessionData.chatMetrics = metrics;
 * const subdomainScores = computeSubdomainScores(sessionData, childAge);
 */
