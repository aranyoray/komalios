import React from 'react';
import {
  IonItem,
  IonLabel,
  IonSelect,
  IonSelectOption,
  IonButton,
  IonGrid,
  IonRow,
  IonCol,
  IonCard,
  IonCardHeader,
  IonCardTitle,
  IonCardContent,
  IonIcon,
} from '@ionic/react';
import { close } from 'ionicons/icons';
import { useAvatarStore } from '../stores/avatarStore';
import { ColorPicker } from './ColorPicker';
import { AccessoryConfig } from '../types/avatar';

export const CustomizerPanel: React.FC = () => {
  const config = useAvatarStore((state) => state.config);
  const updateGender = useAvatarStore((state) => state.updateGender);
  const updateHair = useAvatarStore((state) => state.updateHair);
  const updateEyes = useAvatarStore((state) => state.updateEyes);
  const updateNose = useAvatarStore((state) => state.updateNose);
  const updateEars = useAvatarStore((state) => state.updateEars);
  const updateFace = useAvatarStore((state) => state.updateFace);
  const updateMouth = useAvatarStore((state) => state.updateMouth);
  const updateBody = useAvatarStore((state) => state.updateBody);
  const updateExpression = useAvatarStore((state) => state.updateExpression);
  const updateAccessories = useAvatarStore((state) => state.updateAccessories);

  const hairStyles = [
    'straight_short', 'straight_long', 'wavy_medium', 'curly_short',
    'curly_long', 'braided', 'ponytail', 'bun', 'bangs_straight', 'bangs_curtain'
  ];
  
  const eyeShapes = ['round', 'almond', 'wide', 'narrow', 'asian', 'downturned'];
  const noseStyles = ['button', 'straight', 'wide', 'narrow', 'upturned'];
  const earStyles = ['normal', 'small', 'large', 'pointed'];
  const faceShapes = ['round', 'oval', 'heart', 'diamond', 'long'];
  const mouthStyles = ['smile', 'big_smile', 'neutral', 'pout', 'surprised', 'laughing', 'excited'];
  const bodyStyles = ['casual', 'formal', 'sporty', 'dress'];
  const expressions = ['happy', 'smile', 'excited', 'cool', 'wink', 'surprised', 'neutral', 'blushing'];

  const skinTones = useAvatarStore((state) => state.skinTones);
  const eyeColors = useAvatarStore((state) => state.eyeColors);
  
  const accessoryTypes = ['glasses', 'hat', 'headband', 'bow', 'locket'];
  const accessoryColors = [
    '#000000', '#555555', '#8B4513', '#654321', '#FFD700', '#FF6B6B', 
    '#9370DB', '#20B2AA', '#FF69B4', '#4ECDC4', '#FFFFFF', '#C0C0C0'
  ];
  
  const handleAddAccessory = (type: string) => {
    const newAccessory: AccessoryConfig = {
      type,
      color: accessoryColors[0]
    };
    updateAccessories([...config.accessories, newAccessory]);
  };
  
  const handleRemoveAccessory = (index: number) => {
    const updated = config.accessories.filter((_, i) => i !== index);
    updateAccessories(updated);
  };
  
  const handleUpdateAccessoryColor = (index: number, color: string) => {
    const updated = config.accessories.map((acc, i) => 
      i === index ? { ...acc, color } : acc
    );
    updateAccessories(updated);
  };

  return (
    <IonCard>
      <IonCardHeader>
        <IonCardTitle>Design your friend</IonCardTitle>
      </IonCardHeader>
      <IonCardContent>
        <IonGrid>
          {/* Gender */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Gender"
                  value={config.gender}
                  onIonChange={(e) => updateGender(e.detail.value)}
                >
                  <IonSelectOption value="male">Male</IonSelectOption>
                  <IonSelectOption value="female">Female</IonSelectOption>
                  <IonSelectOption value="neutral">Neutral</IonSelectOption>
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Face Shape */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Face Shape"
                  value={config.face.shape}
                  onIonChange={(e) => updateFace(e.detail.value, config.face.color)}
                >
                  {faceShapes.map((shape) => (
                    <IonSelectOption key={shape} value={shape}>
                      {shape.charAt(0).toUpperCase() + shape.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Skin Tone */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Skin Tone</IonLabel>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', padding: '8px 0' }}>
                  {skinTones.map((tone) => (
                    <button
                      key={tone}
                      style={{
                        width: '40px',
                        height: '40px',
                        borderRadius: '50%',
                        backgroundColor: tone,
                        border: config.face.color === tone ? '3px solid #4A90D9' : '2px solid #ddd',
                        cursor: 'pointer',
                      }}
                      onClick={() => updateFace(config.face.shape, tone)}
                    />
                  ))}
                </div>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Hair Style */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Hair Style"
                  value={config.hair.style}
                  onIonChange={(e) => updateHair(e.detail.value, config.hair.color)}
                >
                  {hairStyles.map((style) => (
                    <IonSelectOption key={style} value={style}>
                      {style.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Hair Color */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Hair Color</IonLabel>
                <ColorPicker
                  color={config.hair.color}
                  onChange={(color) => updateHair(config.hair.style, color)}
                />
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Eye Shape */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Eye Shape"
                  value={config.eyes.shape}
                  onIonChange={(e) => updateEyes(e.detail.value, config.eyes.color, config.eyes.size)}
                >
                  {eyeShapes.map((shape) => (
                    <IonSelectOption key={shape} value={shape}>
                      {shape.charAt(0).toUpperCase() + shape.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Eye Color */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Eye Color</IonLabel>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', padding: '8px 0' }}>
                  {eyeColors.map((color) => (
                    <button
                      key={color}
                      style={{
                        width: '40px',
                        height: '40px',
                        borderRadius: '50%',
                        backgroundColor: color,
                        border: config.eyes.color === color ? '3px solid #4A90D9' : '2px solid #ddd',
                        cursor: 'pointer',
                      }}
                      onClick={() => updateEyes(config.eyes.shape, color, config.eyes.size)}
                    />
                  ))}
                </div>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Nose Style */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Nose Style"
                  value={config.nose.style}
                  onIonChange={(e) => updateNose(e.detail.value)}
                >
                  {noseStyles.map((style) => (
                    <IonSelectOption key={style} value={style}>
                      {style.charAt(0).toUpperCase() + style.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Ear Style */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Ear Style"
                  value={config.ears.style}
                  onIonChange={(e) => updateEars(e.detail.value)}
                >
                  {earStyles.map((style) => (
                    <IonSelectOption key={style} value={style}>
                      {style.charAt(0).toUpperCase() + style.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Mouth Style */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Mouth Style"
                  value={config.mouth.style}
                  onIonChange={(e) => updateMouth(e.detail.value, config.mouth.color)}
                >
                  {mouthStyles.map((style) => (
                    <IonSelectOption key={style} value={style}>
                      {style.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Mouth Color */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Mouth/Lip Color</IonLabel>
                <ColorPicker
                  color={config.mouth.color}
                  onChange={(color) => updateMouth(config.mouth.style, color)}
                />
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Body Style */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Body/Clothing Style"
                  value={config.body.style}
                  onIonChange={(e) => updateBody(e.detail.value, config.body.color)}
                >
                  {bodyStyles.map((style) => (
                    <IonSelectOption key={style} value={style}>
                      {style.charAt(0).toUpperCase() + style.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Body Color */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Body/Clothing Color</IonLabel>
                <ColorPicker
                  color={config.body.color}
                  onChange={(color) => updateBody(config.body.style, color)}
                />
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Expression */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonSelect
                  label="Expression"
                  value={config.expression}
                  onIonChange={(e) => updateExpression(e.detail.value)}
                >
                  {expressions.map((expr) => (
                    <IonSelectOption key={expr} value={expr}>
                      {expr.charAt(0).toUpperCase() + expr.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Accessories Section */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>
                  <h3>Accessories</h3>
                </IonLabel>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Add Accessory */}
          <IonRow>
            <IonCol>
              <IonItem>
                <IonLabel>Add Accessory</IonLabel>
                <IonSelect
                  placeholder="Select accessory type"
                  onIonChange={(e) => {
                    if (e.detail.value) {
                      handleAddAccessory(e.detail.value);
                    }
                  }}
                >
                  {accessoryTypes.map((type) => (
                    <IonSelectOption key={type} value={type}>
                      {type.charAt(0).toUpperCase() + type.slice(1)}
                    </IonSelectOption>
                  ))}
                </IonSelect>
              </IonItem>
            </IonCol>
          </IonRow>

          {/* Current Accessories */}
          {config.accessories.map((accessory, index) => (
            <React.Fragment key={index}>
              <IonRow>
                <IonCol size="8">
                  <IonItem>
                    <IonLabel>
                      <strong>{accessory.type.charAt(0).toUpperCase() + accessory.type.slice(1)}</strong>
                    </IonLabel>
                  </IonItem>
                </IonCol>
                <IonCol size="4">
                  <IonButton
                    fill="clear"
                    size="small"
                    onClick={() => handleRemoveAccessory(index)}
                  >
                    <IonIcon icon={close} />
                  </IonButton>
                </IonCol>
              </IonRow>
              <IonRow>
                <IonCol>
                  <IonItem>
                    <IonLabel>Color</IonLabel>
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', padding: '8px 0' }}>
                      {accessoryColors.map((color) => (
                        <button
                          key={color}
                          style={{
                            width: '35px',
                            height: '35px',
                            borderRadius: '50%',
                            backgroundColor: color,
                            border: accessory.color === color ? '3px solid #4A90D9' : '2px solid #ddd',
                            cursor: 'pointer',
                          }}
                          onClick={() => handleUpdateAccessoryColor(index, color)}
                        />
                      ))}
                    </div>
                  </IonItem>
                </IonCol>
              </IonRow>
            </React.Fragment>
          ))}
        </IonGrid>
      </IonCardContent>
    </IonCard>
  );
};

