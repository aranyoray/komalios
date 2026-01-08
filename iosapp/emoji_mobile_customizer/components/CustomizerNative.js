/**
 * CustomizerNative - Mobile customization controls
 * Touch-friendly interface for avatar customization
 */

import React from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
} from 'react-native';

export default function CustomizerNative({
  avatar,
  setAvatar,
  accessibilityMode,
  emojiSet,
  hairStyles,
  accessories,
  skinTones,
  hairColors,
}) {
  const updateAvatar = (key, value) => {
    setAvatar(prev => ({ ...prev, [key]: value }));
  };

  const buttonSize = accessibilityMode ? 50 : 40;

  return (
    <View style={[styles.container, accessibilityMode && styles.containerLarge]}>
      <Text style={[styles.title, accessibilityMode && styles.titleLarge]}>
        Customize
      </Text>

      {/* Expression */}
      <View style={styles.section}>
        <Text style={[styles.label, accessibilityMode && styles.labelLarge]}>
          Expression
        </Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={styles.optionRow}>
            {emojiSet.map(emoji => (
              <TouchableOpacity
                key={emoji}
                style={[
                  styles.optionButton,
                  avatar.emoji === emoji && styles.optionSelected,
                  { minWidth: accessibilityMode ? 100 : 80 }
                ]}
                onPress={() => updateAvatar('emoji', emoji)}
              >
                <Text style={[
                  styles.optionText,
                  accessibilityMode && styles.optionTextLarge,
                  avatar.emoji === emoji && styles.optionTextSelected
                ]}>
                  {emoji.replace(/_/g, ' ')}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </ScrollView>
      </View>

      {/* Skin Tone */}
      <View style={styles.section}>
        <Text style={[styles.label, accessibilityMode && styles.labelLarge]}>
          Skin Tone
        </Text>
        <View style={styles.colorRow}>
          {skinTones.map(color => (
            <TouchableOpacity
              key={color}
              style={[
                styles.colorButton,
                { backgroundColor: color, width: buttonSize, height: buttonSize },
                avatar.skinColor === color && styles.colorSelected
              ]}
              onPress={() => updateAvatar('skinColor', color)}
            />
          ))}
        </View>
      </View>

      {/* Hair Style */}
      <View style={styles.section}>
        <Text style={[styles.label, accessibilityMode && styles.labelLarge]}>
          Hair Style
        </Text>
        <View style={styles.optionGrid}>
          {hairStyles.map(style => (
            <TouchableOpacity
              key={style}
              style={[
                styles.optionButton,
                avatar.hairStyle === style && styles.optionSelected,
                accessibilityMode && styles.optionButtonLarge
              ]}
              onPress={() => updateAvatar('hairStyle', style)}
            >
              <Text style={[
                styles.optionText,
                accessibilityMode && styles.optionTextLarge,
                avatar.hairStyle === style && styles.optionTextSelected
              ]}>
                {style}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Hair Color */}
      {avatar.hairStyle !== 'none' && (
        <View style={styles.section}>
          <Text style={[styles.label, accessibilityMode && styles.labelLarge]}>
            Hair Color
          </Text>
          <View style={styles.colorRow}>
            {hairColors.map(color => (
              <TouchableOpacity
                key={color}
                style={[
                  styles.colorButton,
                  { backgroundColor: color, width: buttonSize, height: buttonSize },
                  avatar.hairColor === color && styles.colorSelected
                ]}
                onPress={() => updateAvatar('hairColor', color)}
              />
            ))}
          </View>
        </View>
      )}

      {/* Accessories */}
      <View style={styles.section}>
        <Text style={[styles.label, accessibilityMode && styles.labelLarge]}>
          Accessory
        </Text>
        <View style={styles.optionGrid}>
          {accessories.map(acc => (
            <TouchableOpacity
              key={acc}
              style={[
                styles.optionButton,
                avatar.accessory === acc && styles.optionSelected,
                accessibilityMode && styles.optionButtonLarge
              ]}
              onPress={() => updateAvatar('accessory', acc)}
            >
              <Text style={[
                styles.optionText,
                accessibilityMode && styles.optionTextLarge,
                avatar.accessory === acc && styles.optionTextSelected
              ]}>
                {acc}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 20,
    width: '100%',
    maxWidth: 350,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    marginBottom: 20,
  },
  containerLarge: {
    padding: 25,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#4A90D9',
    marginBottom: 15,
  },
  titleLarge: {
    fontSize: 26,
  },
  section: {
    marginBottom: 15,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  labelLarge: {
    fontSize: 18,
  },
  colorRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  colorButton: {
    borderRadius: 25,
    borderWidth: 2,
    borderColor: '#ddd',
  },
  colorSelected: {
    borderColor: '#4A90D9',
    borderWidth: 3,
  },
  optionRow: {
    flexDirection: 'row',
    gap: 8,
  },
  optionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  optionButton: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#ddd',
    backgroundColor: 'white',
  },
  optionButtonLarge: {
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  optionSelected: {
    borderColor: '#4A90D9',
    backgroundColor: '#e3f2fd',
  },
  optionText: {
    fontSize: 13,
    color: '#333',
  },
  optionTextLarge: {
    fontSize: 16,
  },
  optionTextSelected: {
    fontWeight: '600',
  },
});
