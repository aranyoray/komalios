/**
 * Gemini API Service
 * 
 * Provides integration with Google Gemini 1.5 Flash/Pro models.
 * Uses BudgetedApiClient for cost control and usage tracking.
 */

import { BudgetedApiClient, DEFAULT_BUDGET } from '../api/BudgetedApiClient';

const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY;
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

export type GeminiModel = 'gemini-1.5-flash' | 'gemini-1.5-pro';

export interface GeminiResponse {
  candidates: Array<{
    content: {
      parts: Array<{ text: string }>;
      role: string;
    };
    finishReason: string;
    index: number;
    safetyRatings: Array<{
      category: string;
      probability: string;
    }>;
  }>;
  usageMetadata: {
    promptTokenCount: number;
    candidatesTokenCount: number;
    totalTokenCount: number;
  };
}

export class GeminiService {
  private apiClient: BudgetedApiClient;
  private model: GeminiModel;

  constructor(model: GeminiModel = 'gemini-1.5-flash', budgetConfig = DEFAULT_BUDGET) {
    this.apiClient = new BudgetedApiClient(budgetConfig);
    this.model = model;
  }

  /**
   * Generate content using Gemini
   * 
   * @param prompt - The user prompt
   * @param systemInstruction - Optional system instructions
   * @returns The generated text response
   */
  async generateContent(prompt: string, systemInstruction?: string): Promise<string> {
    if (!GEMINI_API_KEY) {
      console.warn('[GeminiService] API key not found. Please set VITE_GEMINI_API_KEY.');
      throw new Error('Gemini API key missing');
    }

    const endpoint = `${GEMINI_API_URL}/${this.model}:generateContent?key=${GEMINI_API_KEY}`;
    
    const payload = {
      contents: [
        {
          parts: [{ text: prompt }]
        }
      ],
      ...(systemInstruction && {
        system_instruction: {
          parts: [{ text: systemInstruction }]
        }
      }),
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      }
    };

    // Estimate tokens (roughly 4 chars per token for safety)
    const estimatedTokens = Math.ceil((prompt.length + (systemInstruction?.length || 0)) / 4) + 1024;

    try {
      const response = await this.apiClient.call<GeminiResponse>(
        endpoint,
        payload,
        estimatedTokens,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          }
        }
      );

      if (response.candidates && response.candidates.length > 0) {
        return response.candidates[0].content.parts[0].text;
      }

      throw new Error('No candidates returned from Gemini');
    } catch (error) {
      console.error('[GeminiService] Error generating content:', error);
      throw error;
    }
  }

  /**
   * Get structured JSON from Gemini
   * Useful for report generation or data analysis
   */
  async generateStructuredJSON<T>(prompt: string, systemInstruction?: string): Promise<T> {
    const jsonPrompt = `${prompt}\n\nReturn ONLY a valid JSON object. No markdown, no backticks, no explanations.`;
    const responseText = await this.generateContent(jsonPrompt, systemInstruction);
    
    try {
      // Remove any markdown code blocks if the model ignored instructions
      const cleanedText = responseText.replace(/```json/g, '').replace(/```/g, '').trim();
      return JSON.parse(cleanedText) as T;
    } catch (error) {
      console.error('[GeminiService] Failed to parse JSON response:', responseText);
      throw new Error('Invalid JSON response from Gemini');
    }
  }

  /**
   * Get current usage stats
   */
  getUsage() {
    return this.apiClient.getUsage();
  }
}

// Export a default instance
export const geminiFlash = new GeminiService('gemini-1.5-flash');
export const geminiPro = new GeminiService('gemini-1.5-pro');

