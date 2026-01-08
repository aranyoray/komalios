/**
 * ChatGPT API Integration for Generating Insightful Highlights
 * Uses OpenAI API to create parent-friendly summaries from session data
 */

const OPENAI_API_KEY = import.meta.env.VITE_OPENAI_API_KEY;
const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';

/**
 * Generate 2-3 key highlights for concise report
 */
export async function generateConciseHighlights(sessionData, domainScores) {
  if (!OPENAI_API_KEY) {
    console.warn('[ChatGPT] API key not configured, using fallback highlights');
    return generateFallbackHighlights(domainScores);
  }

  try {
    // Prepare context for ChatGPT
    const context = formatSessionContext(sessionData, domainScores);

    const prompt = `You are a child development specialist creating a brief daily summary for parents about their child's therapeutic session.

Based on this session data:
${context}

Generate exactly 2-3 bullet points highlighting:
1. One strength or positive moment
2. One area that showed progress or effort
3. (Optional) One gentle suggestion for home practice

Keep each bullet to 1-2 sentences, use warm and encouraging language, and avoid jargon. Focus on specific observations rather than numbers.

Format as a JSON array of strings, for example:
["Great job maintaining focus during the matching game! Your child stayed engaged for the full activity.", "Showed persistence when tasks got tricky, trying multiple approaches before asking for help.", "Practice taking turns during family game time to build on today's turn-taking skills."]`;

    const response = await fetch(OPENAI_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are an expert child development specialist who creates warm, encouraging, parent-friendly reports.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 300
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content;

    // Parse JSON response
    try {
      const highlights = JSON.parse(content);
      return highlights.slice(0, 3); // Ensure max 3
    } catch {
      // If not valid JSON, split by newlines
      return content.split('\n').filter(line => line.trim()).slice(0, 3);
    }
  } catch (error) {
    console.error('[ChatGPT] Error generating highlights:', error);
    return generateFallbackHighlights(domainScores);
  }
}

/**
 * Generate detailed insights for subdomain in extended report
 */
export async function generateSubdomainInsights(subdomainData, historicalData) {
  if (!OPENAI_API_KEY) {
    return generateFallbackSubdomainInsight(subdomainData);
  }

  try {
    const context = formatSubdomainContext(subdomainData, historicalData);

    const prompt = `As a child development specialist, provide a brief insight about this specific skill area:

${context}

Write 1-2 sentences explaining what this means for the child's development and one practical tip for supporting this skill at home.

Keep it parent-friendly, encouraging, and actionable.`;

    const response = await fetch(OPENAI_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a child development expert creating actionable insights for parents.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 150
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    return data.choices[0].message.content.trim();
  } catch (error) {
    console.error('[ChatGPT] Error generating subdomain insight:', error);
    return generateFallbackSubdomainInsight(subdomainData);
  }
}

/**
 * Format session context for ChatGPT
 */
function formatSessionContext(sessionData, domainScores) {
  let context = '';

  // Session basics
  context += `Session Duration: ${Math.round((sessionData.duration || 900) / 60)} minutes\n`;
  context += `Tasks Completed: ${sessionData.tasksCompleted || 0} of ${sessionData.tasksTotal || 0}\n\n`;

  // Domain scores
  context += 'Domain Scores (0-100):\n';
  for (const [id, domain] of Object.entries(domainScores)) {
    context += `- ${domain.name}: ${domain.overallScore}\n`;
  }
  context += '\n';

  // Key metrics
  if (sessionData.eyeTracking) {
    context += `Attention Score: ${sessionData.eyeTracking.attentionScore || 0}/100\n`;
  }
  if (sessionData.touchTracking) {
    context += `Task Accuracy: ${Math.round((sessionData.touchTracking.patterns?.accurateTouches || 0) / Math.max(1, sessionData.touchTracking.totalTaps || 1) * 100)}%\n`;
  }
  if (sessionData.voiceTracking) {
    context += `Vocal Participation: ${(sessionData.voiceTracking.vocalActivity || 0) > 0.3 ? 'Active' : 'Limited'}\n`;
  }

  // Correlation patterns
  if (sessionData.correlations?.patternSummary) {
    context += `\nBehavioral Patterns:\n`;
    sessionData.correlations.patternSummary.insights?.forEach(insight => {
      context += `- ${insight.category}: ${insight.metric} = ${insight.value}\n`;
    });
  }

  return context;
}

/**
 * Format subdomain context
 */
function formatSubdomainContext(subdomainData, historicalData) {
  let context = `Skill Area: ${subdomainData.name}\n`;
  context += `Current Score: ${subdomainData.score}/100\n`;

  if (historicalData && historicalData.length > 0) {
    const trend = historicalData[historicalData.length - 1] > historicalData[0]
      ? 'improving'
      : historicalData[historicalData.length - 1] < historicalData[0]
      ? 'declining'
      : 'stable';
    context += `Trend: ${trend}\n`;
  }

  // Include metric details
  if (subdomainData.metrics) {
    context += '\nKey Metrics:\n';
    for (const [id, metric] of Object.entries(subdomainData.metrics)) {
      context += `- ${metric.name}: ${metric.score}/100\n`;
      if (metric.raw) {
        context += `  Raw data: ${JSON.stringify(metric.raw)}\n`;
      }
    }
  }

  return context;
}

/**
 * Fallback highlights when API unavailable
 */
function generateFallbackHighlights(domainScores) {
  const highlights = [];

  // Find strongest domain
  let maxScore = 0;
  let strongestDomain = null;
  for (const domain of Object.values(domainScores)) {
    if (domain.overallScore > maxScore) {
      maxScore = domain.overallScore;
      strongestDomain = domain;
    }
  }

  if (strongestDomain && maxScore >= 70) {
    highlights.push(
      `Strong performance in ${strongestDomain.name} (${maxScore}/100) - showing excellent progress in this area.`
    );
  }

  // Find area for growth
  let minScore = 100;
  let growthDomain = null;
  for (const domain of Object.values(domainScores)) {
    if (domain.overallScore < minScore) {
      minScore = domain.overallScore;
      growthDomain = domain;
    }
  }

  if (growthDomain && minScore < 70) {
    highlights.push(
      `${growthDomain.name} showing developing skills (${minScore}/100) - continued practice will help build confidence.`
    );
  }

  // General encouragement
  highlights.push(
    'Great effort throughout the session! Consistent practice is building important skills.'
  );

  return highlights.slice(0, 3);
}

/**
 * Fallback subdomain insight
 */
function generateFallbackSubdomainInsight(subdomainData) {
  const score = subdomainData.score;

  if (score >= 75) {
    return `${subdomainData.name} is developing well. Continue current activities to maintain this strong foundation.`;
  } else if (score >= 50) {
    return `${subdomainData.name} is showing progress. Regular practice with similar activities will help strengthen these skills.`;
  } else {
    return `${subdomainData.name} is an area to focus on. Consider working with specialists for targeted support in this skill area.`;
  }
}

export default {
  generateConciseHighlights,
  generateSubdomainInsights
};
