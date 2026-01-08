/**
 * Clinical-Lite Narrative Generators
 *
 * CRITICAL DISCLAIMER:
 * These functions generate NON-DIAGNOSTIC narratives for educational support only.
 * They are NOT clinical assessment tools and should NOT be used for diagnosis.
 * Always consult qualified healthcare professionals for clinical assessment.
 */

import { PriorityBand } from '../scoring/DomainScoring';

export type AgeBand = '3-5' | '6-10' | '11-15';
export type TrafficLightBand = 'green' | 'amber' | 'red';

/**
 * ============================================================================
 * PARENT NARRATIVE GENERATION
 * ============================================================================
 */

export interface SummaryData {
  domainScores: Record<string, number>;
  strengths: string[];
  supportAreas: string[];
  notableBehaviors: string[];
  sessionDuration: number;
  childName?: string;
}

export interface ParentNarrative {
  intro: string;
  strengthsParagraph: string;
  supportParagraph: string;
  nextStepsParagraph: string;
}

/**
 * Build parent-friendly narrative about child's session
 *
 * Language guidelines:
 * - Avoid clinical/diagnostic terms
 * - Use "seems to", "may benefit from", "shows signs of"
 * - Emphasize growth, effort, observable behaviors
 * - Keep positive and constructive tone
 *
 * @param data - Session summary data
 * @returns Structured narrative paragraphs
 */
export function buildParentNarrative(data: SummaryData): ParentNarrative {
  const childRef = data.childName || 'Your child';

  // INTRO
  const durationMin = Math.round(data.sessionDuration / 60000);
  const intro = `${childRef} completed a ${durationMin}-minute session with Komal today. ` +
               `During this time, we observed ${childRef.toLowerCase()} engaging with activities ` +
               `designed to support social-emotional learning.`;

  // STRENGTHS PARAGRAPH
  let strengthsParagraph = '';
  if (data.strengths.length > 0) {
    const strengthsList = data.strengths.slice(0, 3).join(', ').toLowerCase();
    strengthsParagraph = `${childRef} seems to find it easier to work with activities involving ` +
                        `${strengthsList}. These areas showed good engagement and performance during today's session. ` +
                        `It's great to see ${childRef.toLowerCase()} demonstrating these skills!`;
  } else {
    strengthsParagraph = `${childRef} participated actively in the session and showed effort across all activities.`;
  }

  // SUPPORT PARAGRAPH
  let supportParagraph = '';
  if (data.supportAreas.length > 0) {
    const supportList = data.supportAreas.slice(0, 3).join(', ').toLowerCase();
    supportParagraph = `${childRef} may benefit from more practice with ${supportList}. ` +
                      `These are developing skills that often need time and repetition to strengthen. ` +
                      `With continued practice and support, progress in these areas is very possible.`;
  } else {
    supportParagraph = `${childRef} appears to be developing skills across all areas we observed today.`;
  }

  // NEXT STEPS PARAGRAPH
  const nextStepsParagraph = `Moving forward, we recommend continuing regular practice sessions. ` +
                            `Focus on activities that build on ${childRef.toLowerCase()}'s strengths while ` +
                            `gently introducing challenges in areas that need more development. ` +
                            `Remember that progress happens at each child's own pace, and consistent, ` +
                            `positive engagement is key.`;

  return {
    intro,
    strengthsParagraph,
    supportParagraph,
    nextStepsParagraph
  };
}

/**
 * ============================================================================
 * TRAFFIC LIGHT INTERPRETATION BANDS
 * ============================================================================
 */

export interface DomainInterpretation {
  band: TrafficLightBand;
  explanation: string;
  suggestedAdultAction: string;
}

/**
 * Interpret domain score using traffic light metaphor
 *
 * Traffic Light Bands (age-adjusted):
 * - GREEN (>70): Skill appears strong for current age band
 * - AMBER (40-70): Developing, good target for practice
 * - RED (<40): Needs extra support and adult attention
 *
 * NON-MEDICAL: These are guidance bands for educational support.
 *
 * @param domainId - Domain identifier
 * @param score - Domain score (0-100)
 * @param ageBand - Child's age band
 * @returns Interpretation with explanation and action
 */
export function interpretDomain(
  domainId: string,
  score: number,
  ageBand: AgeBand
): DomainInterpretation {
  const domainNames: Record<string, string> = {
    'social-communication': 'Social Communication',
    'emotional-intelligence': 'Emotional Intelligence',
    'cognitive': 'Cognitive Development',
    'life-skills': 'Life Skills',
    'language': 'Language Development'
  };

  const domainName = domainNames[domainId] || domainId;

  // Determine band
  let band: TrafficLightBand;
  let explanation: string;
  let suggestedAdultAction: string;

  if (score >= 70) {
    // GREEN - Strength
    band = 'green';
    explanation = `${domainName} appears to be an area of strength. ` +
                 `Performance in this domain was good for the current age band. ` +
                 `Continue to nurture and build on this skill.`;

    suggestedAdultAction = `Celebrate this progress! Continue regular activities in this area and ` +
                          `look for opportunities to apply these skills in new situations.`;
  } else if (score >= 40) {
    // AMBER - Developing
    band = 'amber';
    explanation = `${domainName} is a developing skill area. ` +
                 `This is a good target for regular practice and support. ` +
                 `Many children benefit from focused attention in this area.`;

    suggestedAdultAction = `Incorporate daily practice activities related to ${domainName.toLowerCase()}. ` +
                          `${getSpecificPracticeIdea(domainId, ageBand)} ` +
                          `Be patient and celebrate small steps forward.`;
  } else {
    // RED - Needs Support
    band = 'red';
    explanation = `${domainName} may need extra support and attention. ` +
                 `This area showed some challenges during the session. ` +
                 `With consistent support and possibly professional guidance, improvement is very achievable.`;

    suggestedAdultAction = `Prioritize activities supporting ${domainName.toLowerCase()}. ` +
                          `${getSpecificPracticeIdea(domainId, ageBand)} ` +
                          `Consider consulting with educators or professionals who can provide ` +
                          `specialized strategies for this area.`;
  }

  return {
    band,
    explanation,
    suggestedAdultAction
  };
}

/**
 * Get domain-specific practice idea
 */
function getSpecificPracticeIdea(domainId: string, ageBand: AgeBand): string {
  const ideas: Record<string, Record<AgeBand, string>> = {
    'social-communication': {
      '3-5': 'Try simple turn-taking games with 2-3 turns each.',
      '6-10': 'Practice conversation skills during mealtimes by asking about their day.',
      '11-15': 'Encourage participation in small group activities or clubs.'
    },
    'emotional-intelligence': {
      '3-5': 'Name feelings throughout the day: "You look happy!" or "That made you frustrated."',
      '6-10': 'Use feeling charts or emotion cards to practice recognizing emotions.',
      '11-15': 'Discuss emotions in stories, movies, or real-life situations together.'
    },
    'cognitive': {
      '3-5': 'Play simple matching or sorting games with everyday objects.',
      '6-10': 'Incorporate problem-solving into daily routines: "How can we...?"',
      '11-15': 'Encourage planning activities like organizing their schoolwork or weekend plans.'
    },
    'life-skills': {
      '3-5': 'Practice self-care routines with step-by-step support.',
      '6-10': 'Give age-appropriate responsibilities like setting the table or sorting laundry.',
      '11-15': 'Involve them in household planning and decision-making.'
    },
    'language': {
      '3-5': 'Read picture books together and ask simple questions about the story.',
      '6-10': 'Have conversations about their interests and encourage them to explain things.',
      '11-15': 'Discuss current events or topics they care about, encouraging detailed responses.'
    }
  };

  return ideas[domainId]?.[ageBand] || 'Practice activities related to this skill regularly.';
}

/**
 * ============================================================================
 * CAREGIVER COACHING SUGGESTIONS
 * ============================================================================
 */

/**
 * Generate caregiver tips for specific subdomain
 *
 * Returns 2-3 concrete, everyday suggestions.
 * Language: simple, culturally neutral, explicitly not therapy advice.
 *
 * @param domainId - Domain identifier
 * @param subdomainId - Subdomain identifier
 * @param score - Current score (0-100)
 * @param ageBand - Child's age band
 * @returns Array of practical tips
 */
export function generateCaregiverTips(
  domainId: string,
  subdomainId: string,
  score: number,
  ageBand: AgeBand
): string[] {
  const tips: string[] = [];

  // Add disclaimer
  const disclaimer = 'NOTE: These are general support ideas, not therapy advice. ' +
                    'Consult professionals for personalized guidance.';

  // Domain-specific tips library
  const tipsByDomain: Record<string, Record<string, Record<AgeBand, string[]>>> = {
    'social-communication': {
      'joint-attention': {
        '3-5': [
          'Point to interesting things and say their name: "Look, a red bird!"',
          'Play with toys together, following your child\'s lead and joining their play',
          'Use simple games like peek-a-boo or rolling a ball back and forth'
        ],
        '6-10': [
          'During activities, occasionally say "Look at this!" and wait for them to look',
          'Point out things you\'re both seeing: "Did you see that?" Build shared experiences',
          'Play board games or activities that require watching each other\'s moves'
        ],
        '11-15': [
          'Share funny videos or memes and discuss them together',
          'Point out interesting things in the environment and ask their thoughts',
          'Work on projects together that require coordinating your attention'
        ]
      },
      'turn-taking': {
        '3-5': [
          'Practice "my turn, your turn" with very simple activities like stacking blocks',
          'Use songs with pauses where they can fill in words',
          'Play games with clear turns, like rolling a ball or passing a toy'
        ],
        '6-10': [
          'Play turn-based board games and explicitly say "my turn" and "your turn"',
          'Practice conversation turn-taking at dinner: everyone shares one thing from their day',
          'Use timers for fairness: "You get 2 minutes, then it\'s my turn"'
        ],
        '11-15': [
          'Discuss turn-taking in conversations: listening before responding',
          'Play strategy games that require waiting for the other person\'s move',
          'Model good turn-taking in discussions about topics they care about'
        ]
      }
    },
    'emotional-intelligence': {
      'emotion-recognition': {
        '3-5': [
          'Name your own emotions out loud: "I feel happy when..." or "That made me sad"',
          'Use simple emotion words throughout the day as they come up naturally',
          'Read books about feelings and point to pictures: "How is he feeling?"'
        ],
        '6-10': [
          'Practice identifying emotions in others: "How do you think she feels?"',
          'Use emotion wheels or charts to expand emotion vocabulary',
          'Discuss characters\' feelings in books, shows, or movies'
        ],
        '11-15': [
          'Have conversations about complex emotions: pride, disappointment, relief',
          'Discuss how the same situation can create different emotions for different people',
          'Ask them to reflect on their own emotional experiences'
        ]
      },
      'emotion-regulation': {
        '3-5': [
          'Teach simple calming strategies: deep breaths, counting to 5, asking for a hug',
          'Create a "calm down corner" with soft items and calming activities',
          'Model regulation: "I\'m feeling frustrated, so I\'m going to take some deep breaths"'
        ],
        '6-10': [
          'Introduce a feelings scale (1-5) and practice recognizing their level',
          'Teach multiple coping strategies and help them choose which works best when',
          'Practice problem-solving when they\'re calm: "Next time, what could you try?"'
        ],
        '11-15': [
          'Discuss stress management techniques and let them choose what appeals to them',
          'Encourage journaling or creative expression for processing emotions',
          'Respect their need for space while offering availability to talk'
        ]
      }
    }
  };

  // Get tips for specific subdomain
  const domainTips = tipsByDomain[domainId]?.[subdomainId]?.[ageBand];

  if (domainTips) {
    tips.push(...domainTips);
  } else {
    // Generic tips if specific ones not available
    tips.push(
      'Practice this skill in everyday situations when they arise naturally',
      'Be patient and celebrate small steps - development takes time',
      'Model the skill yourself and narrate what you\'re doing'
    );
  }

  tips.push(disclaimer);

  return tips;
}

/**
 * USAGE EXAMPLES:
 *
 * // 1. Generate parent narrative
 * const narrative = buildParentNarrative({
 *   domainScores: { 'social-communication': 65, 'emotional-intelligence': 75 },
 *   strengths: ['turn-taking', 'emotion recognition'],
 *   supportAreas: ['joint attention', 'problem-solving'],
 *   notableBehaviors: ['sought help appropriately', 'persisted on hard tasks'],
 *   sessionDuration: 900000,
 *   childName: 'Aria'
 * });
 *
 * console.log(narrative.intro);
 * console.log(narrative.strengthsParagraph);
 * console.log(narrative.supportParagraph);
 * console.log(narrative.nextStepsParagraph);
 *
 * // 2. Interpret domain with traffic light
 * const interpretation = interpretDomain('social-communication', 45, '6-10');
 * console.log(`Band: ${interpretation.band}`); // 'amber'
 * console.log(interpretation.explanation);
 * console.log(interpretation.suggestedAdultAction);
 *
 * // 3. Get caregiver tips
 * const tips = generateCaregiverTips(
 *   'social-communication',
 *   'joint-attention',
 *   55,
 *   '6-10'
 * );
 *
 * tips.forEach((tip, i) => {
 *   console.log(`${i + 1}. ${tip}`);
 * });
 */
