export type Gender = 'male' | 'female' | 'neutral';
export type Expression = 'happy' | 'smile' | 'excited' | 'cool' | 'wink' | 'surprised' | 'neutral' | 'blushing';

export interface HairConfig {
  style: string;
  color: string;
}

export interface EyeConfig {
  shape: string;
  color: string;
  size: 'small' | 'medium' | 'large';
}

export interface FaceConfig {
  shape: string;
  color: string;
  blush?: boolean;
  blushIntensity?: number;
}

export interface MouthConfig {
  style: string;
  color: string;
}

export interface BodyConfig {
  style: string;
  color: string;
}

export interface AccessoryConfig {
  type: string;
  color: string;
}

export interface AvatarConfig {
  characterId: string;
  gender: Gender;
  hair: HairConfig;
  eyes: EyeConfig;
  nose: { style: string };
  ears: { style: string };
  face: FaceConfig;
  mouth: MouthConfig;
  body: BodyConfig;
  accessories: AccessoryConfig[];
  expression: Expression;
}

export interface Character {
  id: string;
  name: string;
  gender: Gender;
  preview: string;
}

