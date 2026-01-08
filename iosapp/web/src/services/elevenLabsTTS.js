/**
 * ElevenLabs Text-to-Speech Service
 * 
 * Platform-specific behavior:
 * - WEB: Uses browser's window.speechSynthesis
 * - NATIVE (Android/iOS): Uses ElevenLabs SDK
 * 
 * SETUP INSTRUCTIONS:
 * 1. Get your ElevenLabs API key from https://elevenlabs.io/app/settings/api-keys
 * 2. Add to your .env file:
 *    VITE_ELEVENLABS_API_KEY=your_api_key_here
 * 3. Optionally configure voice ID:
 *    VITE_ELEVENLABS_VOICE_ID=your_voice_id
 * 
 * Based on: https://elevenlabs.io/docs/developers/guides/cookbooks/text-to-speech/quickstart
 */

import { Capacitor } from '@capacitor/core';
import { ElevenLabsClient } from '@elevenlabs/elevenlabs-js';

const ELEVENLABS_API_KEY = import.meta.env.VITE_ELEVENLABS_API_KEY;
const ELEVENLABS_VOICE_ID = import.meta.env.VITE_ELEVENLABS_VOICE_ID || 'JBFqnCBsd6RMkjVDRZzb';

let currentAudio = null;
let elevenlabsClient = null;

/**
 * Initialize ElevenLabs client
 */
const getElevenLabsClient = () => {
  if (!elevenlabsClient && ELEVENLABS_API_KEY) {
    elevenlabsClient = new ElevenLabsClient({
      apiKey: ELEVENLABS_API_KEY,
    });
  }
  return elevenlabsClient;
};

/**
 * Use browser's speechSynthesis API (for web platform)
 * Simple implementation matching what worked in Home.jsx
 */
const useSpeechSynthesis = (text, options = {}) => {
  if ('speechSynthesis' in window) {
    // Stop any currently playing speech before starting new one
    speechSynthesis.cancel();
    
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = options.rate || 0.9;
    speechSynthesis.speak(utterance);
    console.log('[ElevenLabsTTS] 🌐 Using browser speechSynthesis');
  }
};

/**
 * Generate speech using ElevenLabs SDK (following quickstart guide)
 * Reference: https://elevenlabs.io/docs/developers/guides/cookbooks/text-to-speech/quickstart
 */
const useElevenLabs = async (text, options = {}) => {
  // Stop any currently playing audio before starting new one
  if (currentAudio) {
    currentAudio.pause();
    currentAudio.currentTime = 0;
    currentAudio = null;
  }
  
  // Also stop any speechSynthesis that might be playing
  if ('speechSynthesis' in window) {
    speechSynthesis.cancel();
  }

  const client = getElevenLabsClient();
  if (!client) {
    throw new Error('ElevenLabs client not initialized');
  }

  const voiceId = options.voiceId || ELEVENLABS_VOICE_ID;

  // Simple SDK call following quickstart pattern
  const audio = await client.textToSpeech.convert(voiceId, {
    text: text,
    modelId: 'eleven_multilingual_v2',
    outputFormat: 'mp3_44100_128',
  });

  // Convert ReadableStream to Blob for browser playback
  const reader = audio.getReader();
  const chunks = [];

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
  }

  // Create blob from chunks and play
  const audioBlob = new Blob(chunks, { type: 'audio/mpeg' });
  const audioUrl = URL.createObjectURL(audioBlob);
  const audioElement = new Audio(audioUrl);
  
  currentAudio = audioElement;

  audioElement.onplay = () => {
    if (options.onStart) options.onStart();
  };

  audioElement.onended = () => {
    URL.revokeObjectURL(audioUrl);
    currentAudio = null;
    if (options.onEnd) options.onEnd();
  };

  audioElement.onerror = (error) => {
    URL.revokeObjectURL(audioUrl);
    currentAudio = null;
    throw error;
  };

  await audioElement.play();
  console.log('[ElevenLabsTTS] 📱 Playing ElevenLabs audio');
};

/**
 * Stop any currently playing audio
 */
export const stopCurrentAudio = () => {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio.currentTime = 0;
    currentAudio = null;
  }
  if ('speechSynthesis' in window) {
    speechSynthesis.cancel();
  }
};

/**
 * Speak text using platform-appropriate method
 * Simple implementation - Web uses speechSynthesis, Native uses ElevenLabs
 * Always stops any currently playing audio before starting new one
 */
export const speak = async (text, options = {}) => {
  if (!text || text.trim().length === 0) {
    return;
  }

  // Always stop any currently playing audio first
  stopCurrentAudio();

  // Web platform: use simple speechSynthesis (like original Home.jsx)
//   if (!Capacitor.isNativePlatform()) {
//     useSpeechSynthesis(text, options);
//     return;
//   }

  // Native platform: use ElevenLabs SDK
  if (!ELEVENLABS_API_KEY) {
    useSpeechSynthesis(text, options);
    return;
  }

  try {
    await useElevenLabs(text, options);
  } catch (error) {
    console.error('[ElevenLabsTTS] Error:', error);
    useSpeechSynthesis(text, options);
  }
};

