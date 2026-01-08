import React from 'react';
import { IonItem, IonSelect, IonSelectOption } from '@ionic/react';
import { useAvatarStore } from '../stores/avatarStore';

export const CharacterSelector: React.FC = () => {
  const selectedCharacter = useAvatarStore((state) => state.selectedCharacter);
  const selectCharacter = useAvatarStore((state) => state.selectCharacter);
  
  // Default characters
  const defaultCharacters = [
    { id: 'default', name: 'Default Character', gender: 'neutral' as const, preview: '' },
    { id: 'character1', name: 'Character 1', gender: 'male' as const, preview: '' },
    { id: 'character2', name: 'Character 2', gender: 'female' as const, preview: '' },
  ];

  return (
    <IonItem>
      <IonSelect
        label="Select Character"
        value={selectedCharacter?.id || 'default'}
        onIonChange={(e) => {
          const character = defaultCharacters.find(c => c.id === e.detail.value);
          if (character) {
            selectCharacter(character);
          }
        }}
      >
        {defaultCharacters.map((character) => (
          <IonSelectOption key={character.id} value={character.id}>
            {character.name}
          </IonSelectOption>
        ))}
      </IonSelect>
    </IonItem>
  );
};

