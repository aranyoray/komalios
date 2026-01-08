/**
 * Multilingual SEL Prompt Generator
 * Generates culturally appropriate prompts in multiple languages
 * Supports: English, Hindi, Bengali, Tamil
 */

export type Language = 'en' | 'hi' | 'bn' | 'ta';
export type AgeBand = '3-5' | '6-10' | '11-15';

export interface PromptConfig {
  age: number;
  readingLevel: 'beginner' | 'intermediate' | 'advanced';
  language: Language;
}

export class MultilingualSELPrompts {
  private templates = {
    en: {
      '3-5': [
        "Point to the happy face",
        "Can you share with your friend?",
        "Show me how you feel",
        "Let's take turns",
        "What makes you smile?"
      ],
      '6-10': [
        "How would this person feel?",
        "What could you say to help a friend?",
        "Name three feelings you know",
        "What should we do when we wait?",
        "Tell me about a time you were kind"
      ],
      '11-15': [
        "Describe a situation where empathy is important",
        "How can you resolve a disagreement with a friend?",
        "What strategies help you manage stress?",
        "Explain the difference between sympathy and empathy",
        "Discuss a time when you showed leadership"
      ]
    },
    hi: {
      '3-5': [
        "खुश चेहरे की ओर इशारा करो",
        "क्या तुम अपने दोस्त के साथ साझा कर सकते हो?",
        "मुझे दिखाओ कि तुम कैसा महसूस कर रहे हो",
        "चलो बारी-बारी से खेलते हैं",
        "क्या तुम्हें मुस्कुराता है?"
      ],
      '6-10': [
        "यह व्यक्ति कैसा महसूस करेगा?",
        "आप एक दोस्त की मदद के लिए क्या कह सकते हैं?",
        "तीन भावनाओं के नाम बताओ",
        "हमें इंतजार करते समय क्या करना चाहिए?",
        "मुझे एक समय के बारे में बताओ जब तुम दयालु थे"
      ],
      '11-15': [
        "एक स्थिति का वर्णन करें जहां सहानुभूति महत्वपूर्ण है",
        "आप किसी मित्र के साथ असहमति को कैसे हल कर सकते हैं?",
        "कौन सी रणनीतियाँ तनाव प्रबंधन में मदद करती हैं?",
        "दया और सहानुभूति में अंतर समझाइए",
        "एक समय पर चर्चा करें जब आपने नेतृत्व दिखाया"
      ]
    },
    bn: {
      '3-5': [
        "খুশি মুখের দিকে নির্দেশ করো",
        "তুমি কি তোমার বন্ধুর সাথে ভাগ করতে পারো?",
        "আমাকে দেখাও তুমি কেমন অনুভব করছো",
        "চলো পালা করে খেলি",
        "কি তোমাকে হাসায়?"
      ],
      '6-10': [
        "এই ব্যক্তি কেমন অনুভব করবে?",
        "বন্ধুকে সাহায্য করতে তুমি কি বলতে পারো?",
        "তিনটি অনুভূতির নাম বলো",
        "অপেক্ষা করার সময় আমাদের কি করা উচিত?",
        "আমাকে একটি সময়ের কথা বলো যখন তুমি দয়ালু ছিলে"
      ],
      '11-15': [
        "এমন একটি পরিস্থিতি বর্ণনা করো যেখানে সহানুভূতি গুরুত্বপূর্ণ",
        "তুমি কীভাবে বন্ধুর সাথে মতবিরোধ সমাধান করতে পারো?",
        "কোন কৌশলগুলি মানসিক চাপ পরিচালনায় সাহায্য করে?",
        "সহানুভূতি এবং সমবেদনার মধ্যে পার্থক্য ব্যাখ্যা করো",
        "এমন একটি সময় নিয়ে আলোচনা করো যখন তুমি নেতৃত্ব দেখিয়েছিলে"
      ]
    },
    ta: {
      '3-5': [
        "மகிழ்ச்சியான முகத்தை சுட்டிக்காட்டு",
        "உன் நண்பருடன் பகிர்ந்து கொள்ள முடியுமா?",
        "நீ எப்படி உணர்கிறாய் என்று காட்டு",
        "மாறி மாறி விளையாடலாம்",
        "எது உன்னை சிரிக்க வைக்கிறது?"
      ],
      '6-10': [
        "இந்த நபர் எப்படி உணர்வார்?",
        "நண்பருக்கு உதவ நீ என்ன சொல்லலாம்?",
        "மூன்று உணர்வுகளின் பெயரைச் சொல்",
        "காத்திருக்கும்போது நாம் என்ன செய்ய வேண்டும்?",
        "நீ அன்பாக இருந்த ஒரு நேரத்தைப் பற்றி சொல்"
      ],
      '11-15': [
        "பரிவு முக்கியமான ஒரு சூழ்நிலையை விவரி",
        "நண்பருடன் கருத்து வேறுபாட்டை எப்படி தீர்க்கலாம்?",
        "மன அழுத்தத்தை நிர்வகிக்க எந்த உத்திகள் உதவுகின்றன?",
        "இரக்கம் மற்றும் பரிவுக்கு இடையிலான வேறுபாட்டை விளக்கு",
        "நீ தலைமைத்துவம் காட்டிய ஒரு நேரத்தை விவாதி"
      ]
    }
  };

  generateSelPrompts(config: PromptConfig): string[] {
    const ageBand = this.getAgeBand(config.age);
    const templates = this.templates[config.language]?.[ageBand];

    if (!templates) {
      console.warn(`[MultilingualSELPrompts] No templates for ${config.language}/${ageBand}`);
      return this.templates.en[ageBand];
    }

    return templates;
  }

  private getAgeBand(age: number): AgeBand {
    if (age <= 5) return '3-5';
    if (age <= 10) return '6-10';
    return '11-15';
  }
}

/**
 * USAGE:
 * const generator = new MultilingualSELPrompts();
 * const prompts = generator.generateSelPrompts({
 *   age: 7,
 *   readingLevel: 'beginner',
 *   language: 'hi'
 * });
 * console.log(prompts); // Returns Hindi prompts for ages 6-10
 */
