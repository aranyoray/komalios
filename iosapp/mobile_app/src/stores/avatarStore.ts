import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { AvatarConfig, Character, AccessoryConfig, Expression } from '../types/avatar';
import { generateRandomConfig } from '../utils/randomizer';
import { getDefaultConfig } from '../utils/defaultConfig';

interface AvatarStore {
  // Current character
  selectedCharacter: Character | null;
  
  // Avatar configuration
  config: AvatarConfig;
  
  // Available options
  characters: Character[];
  hairStyles: string[];
  eyeShapes: string[];
  noseStyles: string[];
  earStyles: string[];
  faceShapes: string[];
  mouthStyles: string[];
  bodyStyles: string[];
  accessoryTypes: string[];
  expressions: string[];
  skinTones: string[];
  eyeColors: string[];
  hairColors: string[];
  
  // Actions
  selectCharacter: (character: Character) => void;
  updateGender: (gender: AvatarConfig['gender']) => void;
  updateHair: (style: string, color: string) => void;
  updateEyes: (shape: string, color: string, size?: 'small' | 'medium' | 'large') => void;
  updateNose: (style: string) => void;
  updateEars: (style: string) => void;
  updateFace: (shape: string, color: string) => void;
  updateMouth: (style: string, color: string) => void;
  updateBody: (style: string, color: string) => void;
  updateAccessories: (accessories: AccessoryConfig[]) => void;
  updateExpression: (expression: Expression) => void;
  randomize: () => void;
  reset: () => void;
  setConfig: (config: AvatarConfig) => void;
}

export const useAvatarStore = create<AvatarStore>()(
  persist(
    (set, get) => ({
      selectedCharacter: null,
      config: getDefaultConfig(),
      
      // Initialize with default options
      characters: [],
      hairStyles: [],
      eyeShapes: [],
      noseStyles: [],
      earStyles: [],
      faceShapes: [],
      mouthStyles: [],
      bodyStyles: [],
      accessoryTypes: [],
      expressions: ['happy', 'smile', 'excited', 'cool', 'wink', 'surprised', 'neutral', 'blushing'],
      skinTones: [
        '#FFDBAC', '#F1C27D', '#E0AC69', '#C68642', '#8D5524', '#654321', '#3D2817'
      ],
      eyeColors: [
        '#4A3728', '#3B82F6', '#10B981', '#8B5CF6', '#6B7280', '#F59E0B'
      ],
      hairColors: [
        '#2C1810', '#4A3728', '#8B4513', '#D2691E', '#FFD700', '#FF6B6B', '#9370DB', '#20B2AA'
      ],
      
      selectCharacter: (character) => {
        set({ 
          selectedCharacter: character,
          config: { ...getDefaultConfig(), characterId: character.id, gender: character.gender }
        });
      },
      
      updateGender: (gender) => {
        set((state) => ({
          config: { ...state.config, gender }
        }));
      },
      
      updateHair: (style, color) => {
        set((state) => ({
          config: { ...state.config, hair: { style, color } }
        }));
      },
      
      updateEyes: (shape, color, size = 'medium') => {
        set((state) => ({
          config: { ...state.config, eyes: { shape, color, size } }
        }));
      },
      
      updateNose: (style) => {
        set((state) => ({
          config: { ...state.config, nose: { style } }
        }));
      },
      
      updateEars: (style) => {
        set((state) => ({
          config: { ...state.config, ears: { style } }
        }));
      },
      
      updateFace: (shape, color) => {
        set((state) => ({
          config: { 
            ...state.config, 
            face: { 
              ...state.config.face, 
              shape, 
              color 
            } 
          }
        }));
      },
      
      updateMouth: (style, color) => {
        set((state) => ({
          config: { ...state.config, mouth: { style, color } }
        }));
      },
      
      updateBody: (style, color) => {
        set((state) => ({
          config: { ...state.config, body: { style, color } }
        }));
      },
      
      updateAccessories: (accessories) => {
        set((state) => ({
          config: { ...state.config, accessories }
        }));
      },
      
      updateExpression: (expression) => {
        set((state) => ({
          config: { ...state.config, expression }
        }));
      },
      
      randomize: () => {
        const randomConfig = generateRandomConfig(get().characters);
        set({ config: randomConfig });
      },
      
      reset: () => {
        set({ config: getDefaultConfig() });
      },
      
      setConfig: (config) => {
        set({ config });
      }
    }),
    {
      name: 'avatar-storage',
      partialize: (state) => ({ config: state.config, selectedCharacter: state.selectedCharacter })
    }
  )
);

