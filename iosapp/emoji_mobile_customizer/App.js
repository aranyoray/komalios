/**
 * Emoji Mobile Customizer - Main App
 * Required packages: expo, react-native, react-native-canvas
 */

import React, { useState, useRef, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Alert,
  Switch,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import Canvas from 'react-native-canvas';
import * as MediaLibrary from 'expo-media-library';
import * as FileSystem from 'expo-file-system';
import CustomizerNative from './components/CustomizerNative';

const EMOJI_SET = ['smile', 'big_smile', 'soft_smile', 'laughing', 'beaming',
                   'blushing', 'excited', 'curious', 'grateful', 'friendly_wink', 'caring_smile'];
const HAIR_STYLES = ['none', 'short', 'long', 'curly', 'spiky'];
const ACCESSORIES = ['none', 'bow', 'glasses', 'hat', 'headband'];
const SKIN_TONES = ['#FFE0BD', '#F5D0A9', '#E5BA8C', '#C9A06B', '#A67C52', '#8D5524'];
const HAIR_COLORS = ['#2C1810', '#4A3728', '#8B4513', '#D2691E', '#FFD700', '#FF6B6B', '#9370DB', '#20B2AA'];

export default function App() {
  const [avatar, setAvatar] = useState({
    emoji: 'smile',
    skinColor: SKIN_TONES[0],
    hairStyle: 'short',
    hairColor: HAIR_COLORS[0],
    accessory: 'none',
    accessoryColor: '#FF69B4',
  });
  const [accessibilityMode, setAccessibilityMode] = useState(false);
  const canvasRef = useRef(null);

  const handleCanvas = (canvas) => {
    if (canvas) {
      canvasRef.current = canvas;
      canvas.width = 300;
      canvas.height = 300;
      renderAvatar(canvas);
    }
  };

  useEffect(() => {
    if (canvasRef.current) {
      renderAvatar(canvasRef.current);
    }
  }, [avatar]);

  const renderAvatar = async (canvas) => {
    const ctx = canvas.getContext('2d');
    const size = canvas.width;
    const cx = size / 2;
    const cy = size / 2;
    const radius = size * 0.35;

    // Clear
    ctx.fillStyle = '#e8f4fc';
    ctx.fillRect(0, 0, size, size);

    // Face
    ctx.fillStyle = avatar.skinColor;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    // Eyes
    const eyeSpacing = radius * 0.35;
    const eyeY = cy - radius * 0.1;
    ctx.fillStyle = '#2C1810';

    if (avatar.emoji === 'friendly_wink') {
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY, radius * 0.08, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY, radius * 0.12, 0, Math.PI);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY, radius * 0.08, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY, radius * 0.08, 0, Math.PI * 2);
      ctx.fill();
    }

    // Mouth
    const mouthY = cy + radius * 0.3;
    ctx.strokeStyle = '#8B4513';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(cx, mouthY, radius * 0.25, 0, Math.PI);
    ctx.stroke();

    // Hair
    if (avatar.hairStyle !== 'none') {
      ctx.fillStyle = avatar.hairColor;
      if (avatar.hairStyle === 'short') {
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.3, radius * 0.9, Math.PI, 0);
        ctx.fill();
      } else if (avatar.hairStyle === 'long') {
        ctx.beginPath();
        ctx.ellipse(cx, cy - radius * 0.2, radius * 1.1, radius * 1.0, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = avatar.skinColor;
        ctx.beginPath();
        ctx.arc(cx, cy, radius * 0.9, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Accessory
    if (avatar.accessory === 'bow') {
      ctx.fillStyle = avatar.accessoryColor;
      ctx.beginPath();
      ctx.moveTo(cx - radius * 0.3, cy - radius);
      ctx.lineTo(cx, cy - radius * 1.15);
      ctx.lineTo(cx + radius * 0.3, cy - radius);
      ctx.closePath();
      ctx.fill();
    }
  };

  const handleExport = async () => {
    try {
      const { status } = await MediaLibrary.requestPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission needed', 'Please allow access to save your avatar');
        return;
      }

      // Export params as JSON
      const paramsPath = FileSystem.documentDirectory + 'avatar_params.json';
      await FileSystem.writeAsStringAsync(paramsPath, JSON.stringify(avatar, null, 2));

      Alert.alert('Saved!', 'Avatar parameters saved to device');
    } catch (error) {
      Alert.alert('Error', 'Failed to save avatar');
    }
  };

  const randomize = () => {
    setAvatar({
      emoji: EMOJI_SET[Math.floor(Math.random() * EMOJI_SET.length)],
      skinColor: SKIN_TONES[Math.floor(Math.random() * SKIN_TONES.length)],
      hairStyle: HAIR_STYLES[Math.floor(Math.random() * HAIR_STYLES.length)],
      hairColor: HAIR_COLORS[Math.floor(Math.random() * HAIR_COLORS.length)],
      accessory: ACCESSORIES[Math.floor(Math.random() * ACCESSORIES.length)],
      accessoryColor: `hsl(${Math.random() * 360}, 70%, 60%)`,
    });
  };

  return (
    <View style={styles.container}>
      <StatusBar style="auto" />

      <View style={styles.header}>
        <Text style={[styles.title, accessibilityMode && styles.titleLarge]}>
          Create Your Avatar!
        </Text>
        <View style={styles.accessibilityToggle}>
          <Text style={styles.toggleLabel}>Large Mode</Text>
          <Switch
            value={accessibilityMode}
            onValueChange={setAccessibilityMode}
            trackColor={{ true: '#4A90D9' }}
          />
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.canvasContainer}>
          <Canvas ref={handleCanvas} style={styles.canvas} />
          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={[styles.button, styles.saveButton, accessibilityMode && styles.buttonLarge]}
              onPress={handleExport}
            >
              <Text style={styles.buttonText}>Save</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.button, styles.randomButton, accessibilityMode && styles.buttonLarge]}
              onPress={randomize}
            >
              <Text style={styles.buttonText}>Random</Text>
            </TouchableOpacity>
          </View>
        </View>

        <CustomizerNative
          avatar={avatar}
          setAvatar={setAvatar}
          accessibilityMode={accessibilityMode}
          emojiSet={EMOJI_SET}
          hairStyles={HAIR_STYLES}
          accessories={ACCESSORIES}
          skinTones={SKIN_TONES}
          hairColors={HAIR_COLORS}
        />
      </ScrollView>

      <Text style={styles.footer}>Safe for kids. No data collected.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f0f4f8',
    paddingTop: 50,
  },
  header: {
    alignItems: 'center',
    marginBottom: 10,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#4A90D9',
  },
  titleLarge: {
    fontSize: 32,
  },
  accessibilityToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  toggleLabel: {
    marginRight: 8,
    fontSize: 14,
  },
  content: {
    alignItems: 'center',
    paddingHorizontal: 20,
  },
  canvasContainer: {
    backgroundColor: 'white',
    borderRadius: 16,
    padding: 20,
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  canvas: {
    width: 300,
    height: 300,
    borderRadius: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 15,
    gap: 10,
  },
  button: {
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  buttonLarge: {
    paddingVertical: 15,
    paddingHorizontal: 25,
  },
  saveButton: {
    backgroundColor: '#4CAF50',
  },
  randomButton: {
    backgroundColor: '#9C27B0',
  },
  buttonText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 16,
  },
  footer: {
    textAlign: 'center',
    color: '#666',
    fontSize: 12,
    paddingVertical: 15,
  },
});
