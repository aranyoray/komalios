import { AvatarConfig } from '../types/avatar';

export const getDefaultConfig = (): AvatarConfig => ({
  characterId: 'default',
  gender: 'neutral',
  hair: {
    style: 'straight_short',
    color: '#2C1810'
  },
  eyes: {
    shape: 'round',
    color: '#4A3728',
    size: 'medium'
  },
  nose: {
    style: 'button'
  },
  ears: {
    style: 'normal'
  },
  face: {
    shape: 'round',
    color: '#FFDBAC',
    blush: false,
    blushIntensity: 0.18
  },
  mouth: {
    style: 'smile',
    color: '#FF6B9D'
  },
  body: {
    style: 'casual',
    color: '#4ECDC4'
  },
  accessories: [],
  expression: 'happy'
});

