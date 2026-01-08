import { AvatarConfig, Character, Expression } from '../types/avatar';

const getRandomItem = <T>(array: T[]): T => {
  return array[Math.floor(Math.random() * array.length)];
};

const getRandomColor = (colors: string[]): string => {
  return getRandomItem(colors);
};

export const generateRandomConfig = (characters: Character[]): AvatarConfig => {
  // If characters available, pick random one
  const character = characters.length > 0 
    ? getRandomItem(characters) 
    : null;
  
  const hairStyles = [
    'straight_short', 'straight_long', 'wavy_medium', 'curly_short',
    'curly_long', 'braided', 'ponytail', 'bun', 'bangs_straight', 'bangs_curtain'
  ];
  
  const eyeShapes = ['round', 'almond', 'wide', 'narrow', 'asian', 'downturned'];
  const noseStyles = ['button', 'straight', 'wide', 'narrow', 'upturned'];
  const earStyles = ['normal', 'small', 'large', 'pointed'];
  const faceShapes = ['round', 'oval', 'heart', 'diamond', 'long'];
  const mouthStyles = ['smile', 'big_smile', 'neutral', 'pout', 'surprised'];
  const bodyStyles = ['casual', 'formal', 'sporty', 'dress'];
  const accessoryTypes = ['glasses', 'hat', 'headband', 'bow', 'earrings'];
  const expressions: Expression[] = ['happy', 'smile', 'excited', 'cool', 'wink', 'surprised', 'neutral', 'blushing'];
  
  const skinTones = [
    '#FFDBAC', '#F1C27D', '#E0AC69', '#C68642', '#8D5524', '#654321', '#3D2817'
  ];
  
  const eyeColors = [
    '#4A3728', '#3B82F6', '#10B981', '#8B5CF6', '#6B7280', '#F59E0B'
  ];
  
  const hairColors = [
    '#2C1810', '#4A3728', '#8B4513', '#D2691E', '#FFD700', '#FF6B6B', '#9370DB', '#20B2AA'
  ];
  
  const lipColors = [
    '#FF6B9D', '#FFB6C1', '#FF69B4', '#FF1493', '#C71585', '#FFC0CB'
  ];
  
  const bodyColors = [
    '#4ECDC4', '#FF6B9D', '#FFE66D', '#95E1D3', '#F38181', '#6C5CE7'
  ];
  
  // Random number of accessories (0-2)
  const numAccessories = Math.floor(Math.random() * 3);
  const accessories = Array.from({ length: numAccessories }, () => ({
    type: getRandomItem(accessoryTypes),
    color: getRandomColor(hairColors)
  }));
  
  return {
    characterId: character?.id || 'default',
    gender: character?.gender || getRandomItem(['male', 'female', 'neutral']),
    hair: {
      style: getRandomItem(hairStyles),
      color: getRandomColor(hairColors)
    },
    eyes: {
      shape: getRandomItem(eyeShapes),
      color: getRandomColor(eyeColors),
      size: getRandomItem(['small', 'medium', 'large'])
    },
    nose: {
      style: getRandomItem(noseStyles)
    },
    ears: {
      style: getRandomItem(earStyles)
    },
    face: {
      shape: getRandomItem(faceShapes),
      color: getRandomColor(skinTones),
      blush: Math.random() < 0.3,
      blushIntensity: 0.12 + Math.random() * 0.1
    },
    mouth: {
      style: getRandomItem(mouthStyles),
      color: getRandomColor(lipColors)
    },
    body: {
      style: getRandomItem(bodyStyles),
      color: getRandomColor(bodyColors)
    },
    accessories,
    expression: getRandomItem(expressions)
  };
};

