/**
 * Emoji Web Customizer - Main Page
 * Required packages: react, next, react-colorful
 */

import React, { useState, useRef, useEffect } from 'react';
import Customizer from '../components/Customizer';

const EMOJI_SET = ['smile', 'big_smile', 'soft_smile', 'laughing', 'beaming',
                   'blushing', 'excited', 'curious', 'grateful', 'friendly_wink', 'caring_smile'];
const HAIR_STYLES = ['none', 'short', 'long', 'curly', 'spiky'];
const ACCESSORIES = ['none', 'bow', 'glasses', 'hat', 'headband'];
const SKIN_TONES = ['#FFE0BD', '#F5D0A9', '#E5BA8C', '#C9A06B', '#A67C52', '#8D5524'];
const HAIR_COLORS = ['#2C1810', '#4A3728', '#8B4513', '#D2691E', '#FFD700', '#FF6B6B', '#9370DB', '#20B2AA'];

export default function Home() {
  const [avatar, setAvatar] = useState({
    emoji: 'smile',
    skinColor: SKIN_TONES[0],
    hairStyle: 'short',
    hairColor: HAIR_COLORS[0],
    accessories: [], // Array to support multiple accessories
    accessoryColor: '#FF69B4', // Default color for accessories
  });
  const [isAnimating, setIsAnimating] = useState(false);
  const [accessibilityMode, setAccessibilityMode] = useState(false);
  const canvasRef = useRef(null);

  useEffect(() => {
    renderAvatar();
  }, [avatar]);

  const renderAvatar = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const size = canvas.width;
    const cx = size / 2;
    const cy = size / 2;
    // Reduced radius to 0.30 (from 0.35) to allow room for large accessories like hats
    const radius = size * 0.30;

    ctx.clearRect(0, 0, size, size);

    // Draw hair FIRST (so it appears behind the face)
    if (avatar.hairStyle !== 'none') {
      ctx.fillStyle = avatar.hairColor;
      
      if (avatar.hairStyle === 'short') {
        // Short Hair - Classic Emoji Style
        // Simple, rounded, clean cut suitable for kids
        
        // Base shape (Top)
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.2, radius * 0.95, Math.PI, 0);
        ctx.fill();
        
        // Sideburns/Sides - Simple rectangular/rounded drops
        ctx.beginPath();
        // Left
        ctx.moveTo(cx - radius * 0.95, cy - radius * 0.2);
        ctx.lineTo(cx - radius * 0.9, cy + radius * 0.2);
        ctx.quadraticCurveTo(cx - radius * 0.8, cy + radius * 0.25, cx - radius * 0.75, cy - radius * 0.2);
        ctx.fill();
        
        // Right
        ctx.beginPath();
        ctx.moveTo(cx + radius * 0.95, cy - radius * 0.2);
        ctx.lineTo(cx + radius * 0.9, cy + radius * 0.2);
        ctx.quadraticCurveTo(cx + radius * 0.8, cy + radius * 0.25, cx + radius * 0.75, cy - radius * 0.2);
        ctx.fill();

        // Bangs - Soft curved fringe
        ctx.beginPath();
        ctx.moveTo(cx - radius * 0.9, cy - radius * 0.4);
        ctx.quadraticCurveTo(cx, cy - radius * 0.2, cx + radius * 0.9, cy - radius * 0.4);
        ctx.quadraticCurveTo(cx, cy - radius * 0.6, cx - radius * 0.9, cy - radius * 0.4);
        ctx.fill();
        
      } else if (avatar.hairStyle === 'long') {
        // Long Hair - Detailed Flowing Style
        // Elegant, layered look with volume and shine
        
        // 1. Back Hair (Volume behind head)
        ctx.beginPath();
        ctx.moveTo(cx - radius * 0.8, cy);
        ctx.quadraticCurveTo(cx - radius * 1.3, cy + radius, cx - radius * 1.0, cy + radius * 1.5); // Left flow
        ctx.lineTo(cx + radius * 1.0, cy + radius * 1.5); // Bottom straight cut
        ctx.quadraticCurveTo(cx + radius * 1.3, cy + radius, cx + radius * 0.8, cy); // Right flow
        ctx.fill();
        
        // 2. Top Head (Smooth crown)
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.25, radius * 1.0, Math.PI, 0);
        ctx.fill();
        
        // 3. Side Panels (Face framing layers)
        // Left Side
        ctx.beginPath();
        ctx.moveTo(cx, cy - radius * 0.9); // Parting
        ctx.quadraticCurveTo(cx - radius * 0.6, cy - radius * 0.8, cx - radius * 0.95, cy - radius * 0.2);
        ctx.quadraticCurveTo(cx - radius * 1.1, cy + radius * 0.6, cx - radius * 0.7, cy + radius * 1.4);
        ctx.lineTo(cx - radius * 0.4, cy + radius * 1.4); // Thickness at bottom
        ctx.quadraticCurveTo(cx - radius * 0.8, cy + radius * 0.5, cx - radius * 0.6, cy); // Inner framing
        ctx.fill();

        // Right Side
        ctx.beginPath();
        ctx.moveTo(cx, cy - radius * 0.9); // Parting
        ctx.quadraticCurveTo(cx + radius * 0.6, cy - radius * 0.8, cx + radius * 0.95, cy - radius * 0.2);
        ctx.quadraticCurveTo(cx + radius * 1.1, cy + radius * 0.6, cx + radius * 0.7, cy + radius * 1.4);
        ctx.lineTo(cx + radius * 0.4, cy + radius * 1.4);
        ctx.quadraticCurveTo(cx + radius * 0.8, cy + radius * 0.5, cx + radius * 0.6, cy);
        ctx.fill();

        // 4. Detail Strands (for texture)
        ctx.strokeStyle = 'rgba(0,0,0,0.1)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(cx - radius * 0.8, cy + radius * 0.5);
        ctx.quadraticCurveTo(cx - radius * 0.9, cy + radius, cx - radius * 0.6, cy + radius * 1.3);
        ctx.stroke();
        
        ctx.beginPath();
        ctx.moveTo(cx + radius * 0.8, cy + radius * 0.5);
        ctx.quadraticCurveTo(cx + radius * 0.9, cy + radius, cx + radius * 0.6, cy + radius * 1.3);
        ctx.stroke();

        // 5. Shine (Glossy look)
        ctx.strokeStyle = 'rgba(255,255,255,0.2)';
        ctx.lineWidth = radius * 0.04;
        ctx.lineCap = 'round';
        // Halo shine on top
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.3, radius * 0.7, Math.PI * 1.2, Math.PI * 1.8);
        ctx.stroke();
        
      } else if (avatar.hairStyle === 'curly') {
        // Curly Hair - Detailed Afro/Coils
        // Voluminous with texture and defined curls
        
        // Helper to draw a coil/curl detail
        const drawCoil = (px, py, r) => {
            ctx.beginPath();
            ctx.arc(px, py, r, 0, Math.PI * 2);
            ctx.fill();
            // Inner detail line
            ctx.beginPath();
            ctx.strokeStyle = 'rgba(0,0,0,0.15)';
            ctx.lineWidth = r * 0.3;
            ctx.arc(px, py, r * 0.6, 0, Math.PI * 1.5);
            ctx.stroke();
        };

        // 1. Base Volume (Darker or solid background)
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.2, radius * 1.1, 0, Math.PI * 2);
        ctx.fill();
        
        // 2. Texture Layer - Multiple overlapping coils
        // Top area
        drawCoil(cx, cy - radius * 0.8, radius * 0.25);
        drawCoil(cx - radius * 0.5, cy - radius * 0.7, radius * 0.25);
        drawCoil(cx + radius * 0.5, cy - radius * 0.7, radius * 0.25);
        
        // Mid area
        drawCoil(cx - radius * 0.9, cy - radius * 0.3, radius * 0.22);
        drawCoil(cx + radius * 0.9, cy - radius * 0.3, radius * 0.22);
        drawCoil(cx - radius * 0.4, cy - radius * 1.0, radius * 0.22); // High top
        drawCoil(cx + radius * 0.4, cy - radius * 1.0, radius * 0.22);

        // Low area
        drawCoil(cx - radius * 1.0, cy + radius * 0.1, radius * 0.2);
        drawCoil(cx + radius * 1.0, cy + radius * 0.1, radius * 0.2);
        
        // Fill gaps with smaller circles
        ctx.beginPath();
        ctx.arc(cx - radius * 0.7, cy, radius * 0.15, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(cx + radius * 0.7, cy, radius * 0.15, 0, Math.PI * 2);
        ctx.fill();

        // 3. Face framing small curls (Forehead)
        ctx.fillStyle = avatar.hairColor; // Ensure color matches
        for(let i=0; i<5; i++) {
            const angle = Math.PI + (i/4)*Math.PI; // Semi-circle around top forehead
            const fx = cx + Math.cos(angle) * radius * 0.65;
            const fy = cy - radius * 0.2 + Math.sin(angle) * radius * 0.45;
            ctx.beginPath();
            ctx.arc(fx, fy, radius * 0.08, 0, Math.PI * 2);
            ctx.fill();
        }

        


        
        // Side volume curls (left and right)
        for (let i = 0; i < 6; i++) {
          const x = cx - radius * 0.75 + (i % 3) * radius * 0.15;
          const y = cy - radius * 0.15 + Math.floor(i / 3) * radius * 0.2;
          ctx.beginPath();
          ctx.arc(x, y, radius * 0.11, 0, Math.PI * 2);
          ctx.fill();
        }
        for (let i = 0; i < 6; i++) {
          const x = cx + radius * 0.75 - (i % 3) * radius * 0.15;
          const y = cy - radius * 0.15 + Math.floor(i / 3) * radius * 0.2;
          ctx.beginPath();
          ctx.arc(x, y, radius * 0.11, 0, Math.PI * 2);
          ctx.fill();
        }
      } else if (avatar.hairStyle === 'spiky') {
        // Spiky hair - Anime/Gelled style with defined spikes
        // Reference: Dynamic spikes radiating from top, with side flares
        
        const spikeColor = avatar.hairColor;
        ctx.fillStyle = spikeColor;
        
        // 1. Base Volume (behind spikes) to prevent gaps
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.2, radius * 0.9, Math.PI, 0); // Half circle top
        ctx.fill();

        // 2. Back/Top Spikes - The main silhouette
        const drawSpike = (angle, length, width, curvature = 0.2) => {
           const bx = cx + Math.cos(angle) * radius * 0.8; // Base center on head
           const by = cy - radius * 0.2 + Math.sin(angle) * radius * 0.8;
           
           const tx = cx + Math.cos(angle) * (radius * (0.8 + length)); // Tip
           const ty = cy - radius * 0.2 + Math.sin(angle) * (radius * (0.8 + length));
           
           // Perpendicular vector for width
           const dx = Math.cos(angle + Math.PI/2) * (radius * width);
           const dy = Math.sin(angle + Math.PI/2) * (radius * width);
           
           ctx.beginPath();
           ctx.moveTo(bx - dx, by - dy); // Left base
           
           // Curved path to tip
           ctx.quadraticCurveTo(
             bx + (tx-bx)*0.3 - dx*curvature, 
             by + (ty-by)*0.3 - dy*curvature, 
             tx, ty
           );
           
           // Curved path back to right base
           ctx.quadraticCurveTo(
             bx + (tx-bx)*0.3 + dx*curvature, 
             by + (ty-by)*0.3 + dy*curvature, 
             bx + dx, by + dy
           );
           
           ctx.fill();
        };

        // Radiate spikes from left ear to right ear
        // Angles: PI (left) to 0 (right), centered at -PI/2 (top)
        const spikes = [
            { angle: -Math.PI * 0.9, len: 0.2, w: 0.15 }, // Sideburn left
            { angle: -Math.PI * 0.8, len: 0.35, w: 0.15 },
            { angle: -Math.PI * 0.65, len: 0.5, w: 0.18 }, // Top left
            { angle: -Math.PI * 0.5, len: 0.6, w: 0.2 },  // Center top (highest)
            { angle: -Math.PI * 0.35, len: 0.5, w: 0.18 }, // Top right
            { angle: -Math.PI * 0.2, len: 0.35, w: 0.15 },
            { angle: -Math.PI * 0.1, len: 0.2, w: 0.15 }, // Sideburn right
        ];
        
        spikes.forEach(s => drawSpike(s.angle, s.len, s.w));

        // 3. Front Bangs/Fringe - Hanging down slightly
        // Smaller spikes over the forehead
        const bangs = [
            { x: -0.5, y: -0.6, len: 0.3, w: 0.15, dir: 0.2 },
            { x: -0.2, y: -0.65, len: 0.35, w: 0.16, dir: 0.1 },
            { x: 0.2, y: -0.65, len: 0.35, w: 0.16, dir: -0.1 },
            { x: 0.5, y: -0.6, len: 0.3, w: 0.15, dir: -0.2 },
        ];
        
        bangs.forEach(b => {
           const bx = cx + b.x * radius;
           const by = cy + b.y * radius;
           // Tip is down/outwards
           const tx = bx + b.dir * radius;
           const ty = by + b.len * radius;
           
           ctx.beginPath();
           ctx.moveTo(bx - radius * b.w, by);
           ctx.quadraticCurveTo(bx, by + b.len * radius * 0.5, tx, ty);
           ctx.quadraticCurveTo(bx + radius * b.w, by + b.len * radius * 0.3, bx + radius * b.w, by);
           ctx.fill();
        });
      }
    }

    // Face (drawn after hair so it appears on top)
    ctx.fillStyle = avatar.skinColor;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    // Eyes - different styles based on emoji (each expression unique)
    // Realistic eye design: white sclera with black cornea/iris
    const eyeSpacing = radius * 0.35;
    const eyeY = cy - radius * 0.1;
    ctx.fillStyle = '#2C1810';
    ctx.strokeStyle = '#2C1810';
    
    // Draw realistic eye: white sclera with black iris/pupil and eyebrow
    const drawRealisticEye = (x, y, eyeSize, expression = 'normal') => {
      // Draw eyebrow first (so it appears above the eye)
      // Eyebrows should match eye length with different shapes based on expression
      ctx.strokeStyle = '#2C1810';
      ctx.lineWidth = 2.5;
      const eyebrowY = y - eyeSize * 0.75; // More space from eye
      // Eye width is eyeSize * 0.85, make eyebrow equal to eye length
      const eyebrowLength = eyeSize * 0.85; // Equal to eye width
      const eyebrowSpan = 1.0; // Full span to match eye width
      
      if (expression === 'curious') {
        // Curious - Asymmetric thick eyebrows: left raised/arched, right flatter/straight (quizzical look)
        // Reference: thick, curved eyebrows - left raised/arched, right flatter/straight
        ctx.lineWidth = 3.5; // Thick eyebrows for curious
        // Left eyebrow (from viewer's perspective) - raised and arched
        if (x < cx) { // Left eye
          ctx.beginPath();
          ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.05);
          ctx.quadraticCurveTo(x, eyebrowY - eyeSize * 0.15, x + eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.08);
          ctx.stroke();
        } else { // Right eye - flatter, straighter
          ctx.beginPath();
          ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY);
          ctx.lineTo(x + eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.02);
          ctx.stroke();
        }
        ctx.lineWidth = 2.5; // Reset to default
      } else if (expression === 'excited') {
        // Excited - Distinct, curved eyebrows arched upwards (joyful/excited look)
        // Reference: distinct, curved eyebrows, medium brown, arched upwards emphasizing excitement
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.12);
        // Distinct arched curve - pronounced upward arch for excitement
        ctx.quadraticCurveTo(x - eyebrowLength * 0.2, eyebrowY - eyeSize * 0.25, x, eyebrowY - eyeSize * 0.28);
        ctx.quadraticCurveTo(x + eyebrowLength * 0.2, eyebrowY - eyeSize * 0.25, x + eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.12);
        ctx.stroke();
      } else if (expression === 'big_smile' || expression === 'happy') {
        // Big smile - Slightly raised, gently arched eyebrows (joyful, happy look)
        // Reference: eyebrows raised and gently arched to express joy
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.05);
        // Gently arched, raised eyebrows for big smile
        ctx.quadraticCurveTo(x, eyebrowY - eyeSize * 0.12, x + eyebrowLength * eyebrowSpan, eyebrowY - eyeSize * 0.05);
        ctx.stroke();
      } else if (expression === 'soft_smile' || expression === 'caring_smile') {
        // Soft/Caring smile - Gentle rounded eyebrows
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY);
        // Gentle rounded curve
        ctx.quadraticCurveTo(x - eyebrowLength * 0.2, eyebrowY - eyeSize * 0.06, x, eyebrowY - eyeSize * 0.08);
        ctx.quadraticCurveTo(x + eyebrowLength * 0.2, eyebrowY - eyeSize * 0.06, x + eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.stroke();
      } else if (expression === 'grateful') {
        // Grateful - Simple, gentle arched eyebrows (appreciative, friendly look)
        // Reference: gentle arch, not too raised or lowered, simple and clean
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY);
        // Gentle, simple arch - appreciative and friendly
        ctx.quadraticCurveTo(x, eyebrowY - eyeSize * 0.03, x + eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.stroke();
      } else {
        // Normal eyebrows - Smooth curved arch
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.quadraticCurveTo(x, eyebrowY - eyeSize * 0.05, x + eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.stroke();
      }
      
      // White sclera (the white part of the eye) - longer/wider eyes
      // For excited: almost round eyes
      if (expression === 'excited') {
        // Almost round eyes for excited expression
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.arc(x, y, eyeSize * 0.5, 0, Math.PI * 2);
        ctx.fill();
        // Eye outline
        ctx.strokeStyle = '#2C1810';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(x, y, eyeSize * 0.5, 0, Math.PI * 2);
        ctx.stroke();
      } else if (expression === 'big_smile' || expression === 'happy') {
        // Slightly squinted eyes for big smile (happy, joyful look)
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.ellipse(x, y + eyeSize * 0.05, eyeSize * 0.75, eyeSize * 0.35, 0, 0, Math.PI * 2);
        ctx.fill();
        // Eye outline
        ctx.strokeStyle = '#2C1810';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.ellipse(x, y + eyeSize * 0.05, eyeSize * 0.75, eyeSize * 0.35, 0, 0, Math.PI * 2);
        ctx.stroke();
      } else {
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.ellipse(x, y, eyeSize * 0.85, eyeSize * 0.4, 0, 0, Math.PI * 2);
        ctx.fill();
        // Eye outline
        ctx.strokeStyle = '#2C1810';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.ellipse(x, y, eyeSize * 0.85, eyeSize * 0.4, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      
      // Black cornea/iris (the colored part)
      // For excited: round pupils to match round eyes
      // For grateful: larger, more prominent pupils for expressive appreciation (reference shows large pupils)
      // For big smile: slightly smaller pupils due to squinting
      if (expression === 'excited') {
        // Round pupils for excited (matching round eyes)
        ctx.fillStyle = '#2C1810';
        ctx.beginPath();
        ctx.arc(x, y, eyeSize * 0.35, 0, Math.PI * 2);
        ctx.fill();
        // Eye highlight/shine on the iris
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.12, y - eyeSize * 0.1, eyeSize * 0.12, 0, Math.PI * 2);
        ctx.fill();
        // Small pupil highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.08, y - eyeSize * 0.08, eyeSize * 0.08, 0, Math.PI * 2);
        ctx.fill();
      } else if (expression === 'grateful') {
        ctx.fillStyle = '#2C1810';
        ctx.beginPath();
        ctx.ellipse(x, y, eyeSize * 0.4, eyeSize * 0.4, 0, 0, Math.PI * 2);
        ctx.fill();
        // Larger highlight for grateful eyes (more prominent)
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.18, y - eyeSize * 0.12, eyeSize * 0.18, 0, Math.PI * 2);
        ctx.fill();
        // Larger pupil highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.12, y - eyeSize * 0.1, eyeSize * 0.1, 0, Math.PI * 2);
        ctx.fill();
      } else if (expression === 'big_smile' || expression === 'happy') {
        // Slightly squinted pupils for big smile
        ctx.fillStyle = '#2C1810';
        ctx.beginPath();
        ctx.ellipse(x, y + eyeSize * 0.05, eyeSize * 0.3, eyeSize * 0.3, 0, 0, Math.PI * 2);
        ctx.fill();
        // Eye highlight/shine on the iris
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.12, y - eyeSize * 0.05 + eyeSize * 0.05, eyeSize * 0.12, 0, Math.PI * 2);
        ctx.fill();
        // Small pupil highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.08, y - eyeSize * 0.03 + eyeSize * 0.05, eyeSize * 0.08, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillStyle = '#2C1810';
        ctx.beginPath();
        ctx.arc(x, y, eyeSize * 0.35, 0, Math.PI * 2);
        ctx.fill();
        // Eye highlight/shine on the iris
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.15, y - eyeSize * 0.1, eyeSize * 0.15, 0, Math.PI * 2);
        ctx.fill();
        // Small pupil highlight
        ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
        ctx.beginPath();
        ctx.arc(x - eyeSize * 0.1, y - eyeSize * 0.08, eyeSize * 0.08, 0, Math.PI * 2);
        ctx.fill();
      }
    };
    
    // Draw realistic closed eye (for grateful, peaceful expressions) with eyebrow
    const drawRealisticClosedEye = (x, y, eyeSize, expression = 'peaceful') => {
      // Draw eyebrow first (so it appears above the eye)
      // Eyebrows should match eye length with different shapes
      ctx.strokeStyle = '#2C1810';
      ctx.lineWidth = 2.5;
      const eyebrowY = y - eyeSize * 0.75; // More space from eye
      // Eye width is eyeSize * 0.85, make eyebrow equal to eye length
      const eyebrowLength = eyeSize * 0.85; // Equal to eye width
      const eyebrowSpan = 1.0; // Full span to match eye width
      
      if (expression === 'grateful') {
        // Grateful - Gentle, slightly curved downward eyebrows (humble, peaceful, content look)
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY + eyeSize * 0.03);
        // Gentle, content curve - not too downward, showing peaceful appreciation
        ctx.quadraticCurveTo(x - eyebrowLength * 0.25, eyebrowY + eyeSize * 0.08, x, eyebrowY + eyeSize * 0.1);
        ctx.quadraticCurveTo(x + eyebrowLength * 0.25, eyebrowY + eyeSize * 0.08, x + eyebrowLength * eyebrowSpan, eyebrowY + eyeSize * 0.03);
        ctx.stroke();
      } else {
        // Normal eyebrows for peaceful - smooth curved arch
        ctx.beginPath();
        ctx.moveTo(x - eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.quadraticCurveTo(x, eyebrowY - eyeSize * 0.05, x + eyebrowLength * eyebrowSpan, eyebrowY);
        ctx.stroke();
      }
      
      // Draw white sclera base (slightly visible through closed lid) - more visible for grateful
      if (expression === 'grateful') {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
      } else {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
      }
      ctx.beginPath();
      ctx.ellipse(x, y, eyeSize * 0.6, eyeSize * 0.3, 0, 0, Math.PI * 2);
      ctx.fill();
      
      // Draw closed eyelid with realistic curve - more content/peaceful for grateful
      ctx.strokeStyle = '#2C1810';
      if (expression === 'grateful') {
        // Slightly more curved, content-looking closed eyes
        ctx.lineWidth = 2.8;
        ctx.beginPath();
        ctx.arc(x, y + eyeSize * 0.02, eyeSize * 0.52, 0, Math.PI);
        ctx.stroke();
      } else {
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(x, y, eyeSize * 0.5, 0, Math.PI);
        ctx.stroke();
      }
      
      // Add subtle eyelash effect
      ctx.lineWidth = 1;
      for (let i = 0; i < 5; i++) {
        const offset = (i - 2) * eyeSize * 0.15;
        ctx.beginPath();
        ctx.moveTo(x + offset, y);
        ctx.lineTo(x + offset - eyeSize * 0.05, y - eyeSize * 0.1);
        ctx.stroke();
      }
      
      // Add warm glow for grateful expression - enhanced
      if (expression === 'grateful') {
        // Soft warm glow around closed eyes
        ctx.fillStyle = 'rgba(255, 230, 200, 0.25)';
        ctx.beginPath();
        ctx.ellipse(x, y, eyeSize * 0.65, eyeSize * 0.4, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    };

    if (avatar.emoji === 'friendly_wink') {
      // Friendly wink - left eye open (realistic with eyebrow), right eye winking
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.12, 'normal');
      // Eyebrow for winking eye - playful, curved, equal to eye length
      ctx.strokeStyle = '#2C1810';
      ctx.lineWidth = 2.5;
      const eyebrowY = eyeY - radius * 0.09; // More space
      const eyeWidth = radius * 0.12 * 0.85; // Eye width
      const eyebrowLength = eyeWidth; // Equal to eye width
      const eyebrowSpan = 1.0;
      // Playful curved eyebrow
      ctx.beginPath();
      ctx.moveTo(cx + eyeSpacing - eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.quadraticCurveTo(cx + eyeSpacing, eyebrowY - radius * 0.04, cx + eyeSpacing + eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.stroke();
      // Winking eye - curved line
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY, radius * 0.13, 0, Math.PI);
      ctx.stroke();
      // Add small sparkle on winking eye
      ctx.fillStyle = '#FFD700';
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY - radius * 0.03, radius * 0.02, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#2C1810';
    } else if (avatar.emoji === 'laughing') {
      // Laughing - tightly closed eyes (very curved) with raised, curved eyebrows
      // Laughing - Rounded, raised eyebrows (joyful look), equal to eye length
      ctx.strokeStyle = '#2C1810';
      ctx.lineWidth = 2.5;
      const eyebrowY = eyeY - radius * 0.09; // More space
      const eyeWidth = radius * 0.13 * 0.85; // Eye width (approximate)
      const eyebrowLength = eyeWidth; // Equal to eye width
      const eyebrowSpan = 1.0;
      // Rounded curved eyebrows for laughing
      ctx.beginPath();
      ctx.moveTo(cx - eyeSpacing - eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.quadraticCurveTo(cx - eyeSpacing - eyebrowLength * 0.3, eyebrowY - radius * 0.05, cx - eyeSpacing, eyebrowY - radius * 0.06);
      ctx.quadraticCurveTo(cx - eyeSpacing + eyebrowLength * 0.3, eyebrowY - radius * 0.05, cx - eyeSpacing + eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx + eyeSpacing - eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.quadraticCurveTo(cx + eyeSpacing - eyebrowLength * 0.3, eyebrowY - radius * 0.05, cx + eyeSpacing, eyebrowY - radius * 0.06);
      ctx.quadraticCurveTo(cx + eyeSpacing + eyebrowLength * 0.3, eyebrowY - radius * 0.05, cx + eyeSpacing + eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.01);
      ctx.stroke();
      // Closed eyes
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY, radius * 0.13, 0, Math.PI);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY, radius * 0.13, 0, Math.PI);
      ctx.stroke();
    } else if (avatar.emoji === 'beaming') {
      // Beaming - radiant, bright closed eyes with upward curve (very happy, glowing) and eyebrows
      // Beaming - Rounded, raised eyebrows (radiant, joyful look), equal to eye length
      ctx.strokeStyle = '#2C1810';
      ctx.lineWidth = 2.5;
      const eyebrowY = eyeY - radius * 0.09; // More space
      const eyeWidth = radius * 0.12 * 0.85; // Eye width (approximate)
      const eyebrowLength = eyeWidth; // Equal to eye width
      const eyebrowSpan = 1.0;
      // Rounded arched eyebrows for beaming
      ctx.beginPath();
      ctx.moveTo(cx - eyeSpacing - eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.02);
      ctx.quadraticCurveTo(cx - eyeSpacing - eyebrowLength * 0.25, eyebrowY - radius * 0.06, cx - eyeSpacing, eyebrowY - radius * 0.08);
      ctx.quadraticCurveTo(cx - eyeSpacing + eyebrowLength * 0.25, eyebrowY - radius * 0.06, cx - eyeSpacing + eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.02);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(cx + eyeSpacing - eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.02);
      ctx.quadraticCurveTo(cx + eyeSpacing - eyebrowLength * 0.25, eyebrowY - radius * 0.06, cx + eyeSpacing, eyebrowY - radius * 0.08);
      ctx.quadraticCurveTo(cx + eyeSpacing + eyebrowLength * 0.25, eyebrowY - radius * 0.06, cx + eyeSpacing + eyebrowLength * eyebrowSpan, eyebrowY - radius * 0.02);
      ctx.stroke();
      // Closed eyes
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY - radius * 0.02, radius * 0.12, 0, Math.PI);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY - radius * 0.02, radius * 0.12, 0, Math.PI);
      ctx.stroke();
      // Add small sparkle effect for "beaming" radiance
      ctx.fillStyle = '#FFD700';
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY - radius * 0.05, radius * 0.02, 0, Math.PI * 2);
      ctx.arc(cx + eyeSpacing, eyeY - radius * 0.05, radius * 0.02, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#2C1810';
    } else if (avatar.emoji === 'excited') {
      // Excited - very wide open realistic eyes showing energy
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.14, 'excited');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.14, 'excited');
      // Sparkles for excitement
      ctx.fillStyle = '#FFD700';
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY - radius * 0.08, radius * 0.03, 0, Math.PI * 2);
      ctx.arc(cx + eyeSpacing, eyeY - radius * 0.08, radius * 0.03, 0, Math.PI * 2);
      // Additional sparkles
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing - radius * 0.05, eyeY + radius * 0.03, radius * 0.025, 0, Math.PI * 2);
      ctx.arc(cx + eyeSpacing + radius * 0.05, eyeY + radius * 0.03, radius * 0.025, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#2C1810';
    } else if (avatar.emoji === 'curious') {
      // Curious - realistic eyes with asymmetric thick eyebrows (left raised/arched, right flatter/straight)
      // Reference: eyes positioned symmetrically, thick eyebrows with asymmetric shape
      drawRealisticEye(cx - eyeSpacing, eyeY - radius * 0.05, radius * 0.12, 'curious');
      drawRealisticEye(cx + eyeSpacing, eyeY - radius * 0.05, radius * 0.12, 'curious');
    } else if (avatar.emoji === 'big_smile') {
      // Big smile - slightly squinted realistic happy eyes with raised eyebrows
      drawRealisticEye(cx - eyeSpacing, eyeY + radius * 0.02, radius * 0.12, 'big_smile');
      drawRealisticEye(cx + eyeSpacing, eyeY + radius * 0.02, radius * 0.12, 'big_smile');
      // Add expressive upward curve lines (smile lines/crinkles) around eyes for authentic happy expression
      ctx.lineWidth = 2;
      ctx.strokeStyle = 'rgba(139, 69, 19, 0.4)'; // Softer brown for smile lines
      ctx.beginPath();
      ctx.arc(cx - eyeSpacing, eyeY + radius * 0.08, radius * 0.08, 0, Math.PI);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx + eyeSpacing, eyeY + radius * 0.08, radius * 0.08, 0, Math.PI);
      ctx.stroke();
      ctx.strokeStyle = '#2C1810';
    } else if (avatar.emoji === 'soft_smile') {
      // Soft smile - gentle realistic eyes with gentle eyebrows
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.11, 'soft_smile');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.11, 'soft_smile');
    } else if (avatar.emoji === 'caring_smile') {
      // Caring smile - warm, kind realistic eyes showing compassion with gentle eyebrows
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.12, 'caring_smile');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.12, 'caring_smile');
      // Add soft warmth with slight pink tint around eyes
      ctx.fillStyle = 'rgba(255, 200, 200, 0.15)';
      ctx.beginPath();
      ctx.ellipse(cx - eyeSpacing, eyeY, radius * 0.15, radius * 0.1, 0, 0, Math.PI * 2);
      ctx.ellipse(cx + eyeSpacing, eyeY, radius * 0.15, radius * 0.1, 0, 0, Math.PI * 2);
      ctx.fill();
    } else if (avatar.emoji === 'grateful') {
      // Grateful - open realistic eyes with gentle, appreciative expression
      // Reference: large, expressive eyes with prominent pupils, looking straight ahead
      // Open eyes show genuine appreciation and friendliness
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.13, 'grateful');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.13, 'grateful');
    } else if (avatar.emoji === 'blushing') {
      // Blushing - realistic eyes (blush added later)
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.12, 'normal');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.12, 'normal');
    } else {
      // Default smile - standard happy realistic eyes
      drawRealisticEye(cx - eyeSpacing, eyeY, radius * 0.12, 'normal');
      drawRealisticEye(cx + eyeSpacing, eyeY, radius * 0.12, 'normal');
    }

    // Nose - Simple line nose
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#8B4513'; // Matches mouth color
    
    const noseY = cy + radius * 0.1;
    
    // Draw simple curved line nose
    if (avatar.emoji !== 'laughing' && avatar.emoji !== 'big_smile' && avatar.emoji !== 'beaming') {
        ctx.beginPath();
        // Small vertical curve
        ctx.arc(cx, noseY, radius * 0.08, Math.PI * 0.2, Math.PI * 0.8);
        ctx.stroke();
    }

    // Mouth - different shapes based on emoji (each expression unique)
    const mouthY = cy + radius * 0.3;
    ctx.strokeStyle = '#8B4513';
    ctx.lineWidth = 3;
    ctx.fillStyle = '#8B4513';

    if (avatar.emoji === 'laughing') {
      // Laughing - very wide open mouth with teeth
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.35, 0, Math.PI);
      ctx.stroke();
      // Teeth
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.3, 0, Math.PI);
      ctx.fill();
      ctx.strokeStyle = '#8B4513';
    } else if (avatar.emoji === 'beaming') {
      // Beaming - radiant, bright wide smile with visible teeth (glowing happiness)
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.32, 0, Math.PI);
      ctx.stroke();
      // Teeth for beaming radiance
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.27, 0, Math.PI);
      ctx.fill();
      // Add slight glow effect for "beaming"
      ctx.fillStyle = 'rgba(255, 255, 200, 0.3)';
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.3, 0, Math.PI);
      ctx.fill();
      ctx.strokeStyle = '#8B4513';
    } else if (avatar.emoji === 'big_smile') {
      // Big smile - wide, toothy grin extending towards cheeks
      // Reference: wide smile that extends towards cheeks, showing teeth
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.32, 0, Math.PI);
      ctx.stroke();
      // Teeth for big smile (wide, toothy grin)
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.28, 0, Math.PI);
      ctx.fill();
      // Add subtle inner highlight for depth
      ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
      ctx.beginPath();
      ctx.arc(cx, mouthY - radius * 0.02, radius * 0.24, 0, Math.PI);
      ctx.fill();
      ctx.strokeStyle = '#8B4513';
    } else if (avatar.emoji === 'excited') {
      // Excited - wide open inverted U-shape mouth (smaller size)
      // Reference: broad inverted U-shape, thick dark brown outline, white teeth at top inside mouth, deep dark red interior
      const excitedMouthY = mouthY + radius * 0.05;
      const mouthWidth = radius * 0.32; // Smaller wide mouth
      const mouthHeight = radius * 0.25; // Smaller tall mouth
      
      // Deep dark red interior (tongue/throat) - drawn first
      ctx.fillStyle = '#8B0000'; // Deep dark red
      ctx.beginPath();
      // Inverted U-shape for the mouth interior
      ctx.arc(cx, excitedMouthY, mouthWidth, 0, Math.PI);
      ctx.fill();
      
      // White teeth inside the mouth - positioned more down/inside
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      // Teeth positioned more inside/down in the mouth opening - small height strip
      ctx.ellipse(cx, excitedMouthY - mouthWidth * 0.05, mouthWidth * 0.7, radius * 0.04, 0, 0, Math.PI * 2);
      ctx.fill();
      
      // Thick dark brown outline defining the perimeter
      ctx.strokeStyle = '#654321'; // Dark brown
      ctx.lineWidth = 4; // Thick outline
      ctx.beginPath();
      // Inverted U-shape outline
      ctx.arc(cx, excitedMouthY, mouthWidth, 0, Math.PI);
      ctx.stroke();
      
      ctx.strokeStyle = '#8B4513'; // Reset to default
      ctx.lineWidth = 3; // Reset to default
    } else if (avatar.emoji === 'curious') {
      // Curious - simple, thin, straight horizontal line (closed mouth, thoughtful expression)
      // Reference: single, thin, straight horizontal line, positioned centrally
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(cx - radius * 0.15, mouthY);
      ctx.lineTo(cx + radius * 0.15, mouthY);
      ctx.stroke();
      ctx.lineWidth = 3; // Reset to default
      ctx.strokeStyle = '#8B4513';
    } else if (avatar.emoji === 'soft_smile') {
      // Soft smile - gentle, subtle curve
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.18, 0, Math.PI);
      ctx.stroke();
    } else if (avatar.emoji === 'caring_smile') {
      // Caring smile - warm, slightly wider than soft
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.22, 0, Math.PI);
      ctx.stroke();
    } else if (avatar.emoji === 'grateful') {
      // Grateful - simple, gentle upward-curved smile
      // Reference: simple black line, gentle curve, closed-mouth smile
      // Clean and friendly, showing appreciation
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.2, 0, Math.PI);
      ctx.stroke();
      ctx.strokeStyle = '#8B4513';
    } else if (avatar.emoji === 'friendly_wink') {
      // Friendly wink - medium smile
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.24, 0, Math.PI);
      ctx.stroke();
    } else if (avatar.emoji === 'blushing') {
      // Blushing - medium smile (blush added separately)
      ctx.beginPath();
      ctx.arc(cx, mouthY, radius * 0.23, 0, Math.PI);
      ctx.stroke();
    } else {
      // Default smile - standard happy smile
    ctx.beginPath();
    ctx.arc(cx, mouthY, radius * 0.25, 0, Math.PI);
    ctx.stroke();
    }

    // Blush (for blushing emoji)
    if (avatar.emoji === 'blushing') {
      ctx.fillStyle = '#FFB6C1';
      ctx.beginPath();
      ctx.ellipse(cx - radius * 0.5, cy + radius * 0.15, radius * 0.12, radius * 0.08, 0, 0, Math.PI * 2);
      ctx.ellipse(cx + radius * 0.5, cy + radius * 0.15, radius * 0.12, radius * 0.08, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    // Warm glow and blush for grateful expression (showing appreciation and warmth)
    if (avatar.emoji === 'grateful') {
      // Add a subtle warm aura around the face to show gratitude
      ctx.fillStyle = 'rgba(255, 240, 220, 0.18)';
      ctx.beginPath();
      ctx.arc(cx, cy, radius * 1.12, 0, Math.PI * 2);
      ctx.fill();
      // Add gentle blush cheeks for warmth and sincerity
      ctx.fillStyle = 'rgba(255, 200, 180, 0.25)';
        ctx.beginPath();
      ctx.ellipse(cx - radius * 0.5, cy + radius * 0.15, radius * 0.1, radius * 0.07, 0, 0, Math.PI * 2);
      ctx.ellipse(cx + radius * 0.5, cy + radius * 0.15, radius * 0.1, radius * 0.07, 0, 0, Math.PI * 2);
        ctx.fill();
    }

    // Accessories (drawn after face)
    // Draw accessories in order: hat/headband first (behind), then glasses, then bow (on top)
    // Backward compatibility: handle old 'accessory' property
    const accessoriesList = avatar.accessories || (avatar.accessory && avatar.accessory !== 'none' ? [avatar.accessory] : []);
    const sortedAccessories = [...accessoriesList].sort((a, b) => {
      const order = { 'hat': 1, 'headband': 2, 'glasses': 3, 'bow': 4 };
      return (order[a] || 5) - (order[b] || 5);
    });

    sortedAccessories.forEach(accessory => {
      if (accessory === 'bow') {
        ctx.fillStyle = avatar.accessoryColor;
        ctx.beginPath();
        // Left side of bow
        ctx.ellipse(cx - radius * 0.25, cy - radius * 0.95, radius * 0.15, radius * 0.1, -0.3, 0, Math.PI * 2);
        ctx.fill();
        // Right side of bow
        ctx.beginPath();
        ctx.ellipse(cx + radius * 0.25, cy - radius * 0.95, radius * 0.15, radius * 0.1, 0.3, 0, Math.PI * 2);
        ctx.fill();
        // Center knot
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.ellipse(cx, cy - radius * 0.95, radius * 0.08, radius * 0.05, 0, 0, Math.PI * 2);
        ctx.fill();
      } else if (accessory === 'glasses') {
        ctx.strokeStyle = avatar.accessoryColor || '#2C1810';
        ctx.fillStyle = 'rgba(200, 220, 255, 0.3)';
        ctx.lineWidth = 3;
        // Left lens
        ctx.beginPath();
        ctx.arc(cx - eyeSpacing, eyeY, radius * 0.18, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        // Right lens
        ctx.beginPath();
        ctx.arc(cx + eyeSpacing, eyeY, radius * 0.18, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        // Bridge
        ctx.beginPath();
        ctx.moveTo(cx - eyeSpacing + radius * 0.18, eyeY);
        ctx.lineTo(cx + eyeSpacing - radius * 0.18, eyeY);
        ctx.stroke();
      } else if (accessory === 'hat') {
        ctx.fillStyle = avatar.accessoryColor;
        // Hat brim - moved up more
        const brimCenterY = cy - radius * 0.85;
        const brimTopY = brimCenterY - radius * 0.15; // Top edge of brim
        ctx.beginPath();
        ctx.ellipse(cx, brimCenterY, radius * 1.0, radius * 0.15, 0, 0, Math.PI * 2);
        ctx.fill();
        // Hat crown - positioned to touch brim top (no gap)
        const crownCenterY = brimTopY; // Crown bottom touches brim top
        ctx.beginPath();
        ctx.arc(cx, crownCenterY, radius * 0.4, Math.PI, 0);
        ctx.fill();
        // Hat band - at the connection point
        ctx.fillStyle = '#2C1810';
        ctx.beginPath();
        ctx.ellipse(cx, crownCenterY, radius * 0.4, radius * 0.05, 0, 0, Math.PI * 2);
        ctx.fill();
      } else if (accessory === 'headband') {
        ctx.strokeStyle = avatar.accessoryColor;
        ctx.lineWidth = 8;
        ctx.beginPath();
        ctx.arc(cx, cy - radius * 0.3, radius * 0.9, Math.PI, 0);
        ctx.stroke();
        // Decorative knot in front
        ctx.fillStyle = avatar.accessoryColor;
        ctx.beginPath();
        ctx.ellipse(cx, cy - radius * 0.3, radius * 0.12, radius * 0.08, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    });
  };

  const handleExport = async () => {
    const canvas = canvasRef.current;
    const dataUrl = canvas.toDataURL('image/png');

    // Download PNG
    const link = document.createElement('a');
    link.download = 'my_avatar.png';
    link.href = dataUrl;
    link.click();

    // Download params JSON
    const paramsBlob = new Blob([JSON.stringify(avatar, null, 2)], { type: 'application/json' });
    const paramsUrl = URL.createObjectURL(paramsBlob);
    const paramsLink = document.createElement('a');
    paramsLink.download = 'avatar_params.json';
    paramsLink.href = paramsUrl;
    paramsLink.click();
  };

  // Helper function to convert HSL to Hex
  const hslToHex = (h, s, l) => {
    l /= 100;
    const a = s * Math.min(l, 1 - l) / 100;
    const f = n => {
      const k = (n + h / 30) % 12;
      const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
      return Math.round(255 * color).toString(16).padStart(2, '0');
    };
    return `#${f(0)}${f(8)}${f(4)}`;
  };

  const randomize = () => {
    // Randomly select 0-3 accessories (excluding 'none')
    const availableAccessories = ACCESSORIES.filter(acc => acc !== 'none');
    const numAccessories = Math.floor(Math.random() * 4); // 0 to 3 accessories
    const selectedAccessories = [];
    for (let i = 0; i < numAccessories; i++) {
      const randomAcc = availableAccessories[Math.floor(Math.random() * availableAccessories.length)];
      if (!selectedAccessories.includes(randomAcc)) {
        selectedAccessories.push(randomAcc);
      }
    }
    
    // Generate random HSL color and convert to hex for color picker
    const randomHue = Math.floor(Math.random() * 360);
    const randomAccessoryColor = hslToHex(randomHue, 70, 60);
    
    setAvatar({
      emoji: EMOJI_SET[Math.floor(Math.random() * EMOJI_SET.length)],
      skinColor: SKIN_TONES[Math.floor(Math.random() * SKIN_TONES.length)],
      hairStyle: HAIR_STYLES[Math.floor(Math.random() * HAIR_STYLES.length)],
      hairColor: HAIR_COLORS[Math.floor(Math.random() * HAIR_COLORS.length)],
      accessories: selectedAccessories,
      accessoryColor: randomAccessoryColor,
    });
  };

  return (
    <div style={{
      minHeight: '100vh',
      padding: '20px',
      fontFamily: 'system-ui, sans-serif',
      backgroundColor: '#f0f4f8'
    }}>
      <header style={{ textAlign: 'center', marginBottom: '20px' }}>
        <h1 style={{ color: '#4A90D9', fontSize: accessibilityMode ? '2.5rem' : '2rem' }}>
          Design your friend!
        </h1>
        <label style={{ fontSize: '0.9rem' }}>
          <input
            type="checkbox"
            checked={accessibilityMode}
            onChange={(e) => setAccessibilityMode(e.target.checked)}
          /> Large Text Mode
        </label>
      </header>

      <main style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: '20px',
        justifyContent: 'center'
      }}>
        {/* Preview Canvas */}
        <div style={{
          background: 'white',
          padding: '20px',
          borderRadius: '16px',
          boxShadow: '0 4px 6px rgba(0,0,0,0.1)'
        }}>
          <canvas
            ref={canvasRef}
            width={300}
            height={300}
            style={{ borderRadius: '8px', background: '#e8f4fc' }}
          />
          <div style={{ marginTop: '15px', display: 'flex', gap: '10px', justifyContent: 'center' }}>
            <button
              onClick={handleExport}
              style={{
                padding: accessibilityMode ? '15px 25px' : '10px 20px',
                fontSize: accessibilityMode ? '1.2rem' : '1rem',
                backgroundColor: '#4CAF50',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer'
              }}
            >
              Save Avatar
            </button>
            <button
              onClick={randomize}
              style={{
                padding: accessibilityMode ? '15px 25px' : '10px 20px',
                fontSize: accessibilityMode ? '1.2rem' : '1rem',
                backgroundColor: '#9C27B0',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer'
              }}
            >
              Randomize
            </button>
          </div>
        </div>

        {/* Customizer Panel */}
        <Customizer
          avatar={avatar}
          setAvatar={setAvatar}
          accessibilityMode={accessibilityMode}
          emojiSet={EMOJI_SET}
          hairStyles={HAIR_STYLES}
          accessories={ACCESSORIES}
          skinTones={SKIN_TONES}
          hairColors={HAIR_COLORS}
        />
      </main>

      <footer style={{ textAlign: 'center', marginTop: '30px', color: '#666', fontSize: '0.8rem' }}>
        <p>Safe for kids. No data collected without consent.</p>
      </footer>
    </div>
  );
}
