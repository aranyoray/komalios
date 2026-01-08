/**
 * AI Insights Service
 * 
 * Generates parent-friendly insights and reports using Gemini AI.
 * Falls back to rule-based templates if Gemini is unavailable.
 */

import { geminiFlash } from './geminiService';

/**
 * Generate key session highlights for parents (Concise Report)
 */
export async function generateConciseHighlights(sessionData, domainScores) {
  try {
    const context = formatSessionContext(sessionData, domainScores);
    
    const systemInstruction = `You are an expert child development specialist. 
Your goal is to provide warm, encouraging, and actionable highlights for parents based on their child's therapy session data.
Avoid clinical jargon. Focus on strengths and progress.`;

    const prompt = `Based on this session data, generate 3 clear, parent-friendly highlights:
${context}

Format the response as a JSON array of strings. Each string should be 1-2 sentences.
Include:
1. One strength or positive moment.
2. One area that showed progress or effort.
3. One gentle suggestion for home practice.

Example: ["Great job maintaining focus!", "Showed persistence when tasks got tricky.", "Tip: Practice taking turns during family game time."]`;

    const highlights = await geminiFlash.generateStructuredJSON(prompt, systemInstruction);
    return highlights.slice(0, 3);
  } catch (error) {
    console.warn('[AIInsights] Gemini failed to generate highlights, using fallback', error);
    return generateFallbackHighlights(domainScores);
  }
}

/**
 * Generate detailed insights for subdomain (Extended Report)
 */
export async function generateSubdomainInsights(subdomainData, historicalData) {
  try {
    const context = formatSubdomainContext(subdomainData, historicalData);

    const systemInstruction = `You are a child development expert creating actionable insights for parents.`;

    const prompt = `As a child development specialist, provide a brief insight about this specific skill area:
${context}

Write 1-2 sentences explaining what this means for the child's development and one practical tip for supporting this skill at home.
Keep it parent-friendly, encouraging, and actionable.`;

    return await geminiFlash.generateContent(prompt, systemInstruction);
  } catch (error) {
    console.warn('[AIInsights] Gemini failed to generate subdomain insights, using fallback', error);
    return generateFallbackSubdomainInsight(subdomainData);
  }
}

/**
 * Generate a warm session summary ("What This Means")
 */
export async function generateSessionSummary(sessionData, domainScores) {
  try {
    const context = formatSessionContext(sessionData, domainScores);
    
    const systemInstruction = `You are an expert child development specialist. 
Your goal is to provide a warm, 1-2 sentence summary for parents explaining what their child's performance means.
Use "Your child" or the child's name if provided. Focus on growth and confidence.`;

    const prompt = `Based on this session data, write a warm "What This Means" summary:
${context}

Keep it brief (1-2 sentences).`;

    return await geminiFlash.generateContent(prompt, systemInstruction);
  } catch (error) {
    console.warn('[AIInsights] Gemini failed to generate session summary, using fallback', error);
    return null; // Let the UI handle fallback
  }
}

/**
 * Format session context for AI
 */
function formatSessionContext(sessionData, domainScores) {
  let context = `Session Duration: ${Math.round((sessionData.duration || 900) / 60)} minutes\n`;
  context += `Tasks Completed: ${sessionData.tasksCompleted || 0} of ${sessionData.tasksTotal || 0}\n\n`;

  context += 'Domain Scores (0-100):\n';
  for (const [id, domain] of Object.entries(domainScores)) {
    context += `- ${domain.name}: ${domain.overallScore}\n`;
  }
  context += '\n';

  if (sessionData.eyeTracking) {
    context += `Attention Score: ${sessionData.eyeTracking.attentionScore || 0}/100\n`;
  }
  if (sessionData.touchTracking) {
    context += `Task Accuracy: ${Math.round((sessionData.touchTracking.patterns?.accurateTouches || 0) / Math.max(1, sessionData.touchTracking.totalTaps || 1) * 100)}%\n`;
  }
  
  return context;
}

/**
 * Format subdomain context for AI
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

  if (subdomainData.metrics) {
    context += '\nKey Metrics:\n';
    for (const [id, metric] of Object.entries(subdomainData.metrics)) {
      context += `- ${metric.name}: ${metric.score}/100\n`;
    }
  }

  return context;
}

/**
 * Fallback highlights when API unavailable
 */
function generateFallbackHighlights(domainScores) {
  const highlights = [];
  let maxScore = 0;
  let strongestDomain = null;
  
  for (const domain of Object.values(domainScores)) {
    if (domain.overallScore > maxScore) {
      maxScore = domain.overallScore;
      strongestDomain = domain;
    }
  }

  if (strongestDomain && maxScore >= 70) {
    highlights.push(`Strong performance in ${strongestDomain.name} - showing excellent progress.`);
  }

  highlights.push('Great effort throughout the session today!');
  highlights.push('Consistent practice is building important skills.');

  return highlights.slice(0, 3);
}

/**
 * Fallback subdomain insight
 */
function generateFallbackSubdomainInsight(subdomainData) {
  const score = subdomainData.score;
  if (score >= 75) {
    return `${subdomainData.name} is developing well. Continue current activities to maintain this foundation.`;
  } else if (score >= 50) {
    return `${subdomainData.name} is showing progress. Regular practice will help strengthen these skills.`;
  } else {
    return `${subdomainData.name} is an area for focused practice. Consider working on similar tasks daily.`;
  }
}
