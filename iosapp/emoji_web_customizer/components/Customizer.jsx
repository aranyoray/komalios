/**
 * Customizer Component - Modular customization controls
 * Required packages: react, react-colorful
 */

import React, { useState, useEffect, useRef } from 'react';

// Hair preview canvas component
function HairPreviewCanvas({ style, skinColor, hairColor, isSelected }) {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    const size = 60;
    const cx = size / 2;
    const cy = size / 2;
    const r = size * 0.35;
    
    ctx.clearRect(0, 0, size, size);
    
    // Draw hair first (if not none)
    if (style !== 'none') {
      ctx.fillStyle = hairColor;
      if (style === 'short') {
        // Short hair preview - Simple round
        ctx.beginPath();
        ctx.arc(cx, cy - r * 0.3, r * 0.95, Math.PI, 0);
        ctx.fill();
        // Bangs
        ctx.beginPath();
        ctx.moveTo(cx - r * 0.9, cy - r * 0.3);
        ctx.quadraticCurveTo(cx, cy - r * 0.1, cx + r * 0.9, cy - r * 0.3);
        ctx.fill();
        
      } else if (style === 'long') {
        // Long hair preview - Detailed
        // Back
        ctx.beginPath();
        ctx.moveTo(cx - r * 0.8, cy);
        ctx.quadraticCurveTo(cx - r * 1.2, cy + r, cx + r * 1.2, cy + r);
        ctx.quadraticCurveTo(cx + r * 0.8, cy, cx + r * 0.8, cy);
        ctx.fill();
        
        // Top
        ctx.beginPath();
        ctx.arc(cx, cy - r * 0.2, r * 1.0, Math.PI, 0);
        ctx.fill();
        
        // Side panels
        ctx.beginPath();
        ctx.moveTo(cx, cy - r * 0.9);
        ctx.quadraticCurveTo(cx - r * 0.9, cy, cx - r * 0.8, cy + r * 0.8); // Left down
        ctx.quadraticCurveTo(cx - r * 0.5, cy + r * 0.5, cx - r * 0.5, cy - r * 0.2); // Inner
        ctx.fill();
        
        ctx.beginPath();
        ctx.moveTo(cx, cy - r * 0.9);
        ctx.quadraticCurveTo(cx + r * 0.9, cy, cx + r * 0.8, cy + r * 0.8); // Right down
        ctx.quadraticCurveTo(cx + r * 0.5, cy + r * 0.5, cx + r * 0.5, cy - r * 0.2); // Inner
        ctx.fill();
        
        // Face mask
        ctx.fillStyle = skinColor;
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.7, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = hairColor;

      } else if (style === 'curly') {
        // Curly preview - Coils
        // Base
        ctx.beginPath();
        ctx.arc(cx, cy - r * 0.2, r * 1.1, 0, Math.PI * 2);
        ctx.fill();
        
        // Coils details
        const drawPreviewCoil = (px, py, s) => {
            ctx.beginPath();
            ctx.arc(px, py, s, 0, Math.PI * 2);
            ctx.fill();
            ctx.beginPath();
            ctx.strokeStyle = 'rgba(0,0,0,0.1)'; // Subtle detail
            ctx.lineWidth = 1;
            ctx.arc(px, py, s * 0.6, 0, Math.PI * 1.5);
            ctx.stroke();
        };
        
        drawPreviewCoil(cx, cy - r * 0.8, r * 0.25);
        drawPreviewCoil(cx - r * 0.5, cy - r * 0.7, r * 0.25);
        drawPreviewCoil(cx + r * 0.5, cy - r * 0.7, r * 0.25);
        drawPreviewCoil(cx - r * 0.9, cy - r * 0.3, r * 0.22);
        drawPreviewCoil(cx + r * 0.9, cy - r * 0.3, r * 0.22);
        drawPreviewCoil(cx - r * 1.0, cy + r * 0.1, r * 0.2);
        drawPreviewCoil(cx + r * 1.0, cy + r * 0.1, r * 0.2);
        
        // Face mask check - ensure curls don't cover too much face or just fit around
        // Since it's an afro style, it goes behind mostly, but some overlap is fine

        // Spiky preview - Chunky
        const spikeColor = hairColor;
        ctx.fillStyle = spikeColor;
        
        ctx.beginPath();
        ctx.arc(cx, cy - r * 0.1, r * 0.8, Math.PI, 0); 
        ctx.fill();

        const drawPreviewSpike = (ang, len, w) => {
            const bx = cx + Math.cos(ang) * r * 0.7;
            const by = cy - r * 0.1 + Math.sin(ang) * r * 0.7;
            const tx = cx + Math.cos(ang) * r * (0.7 + len);
            const ty = cy - r * 0.1 + Math.sin(ang) * r * (0.7 + len);
            
            const dx = Math.cos(ang + Math.PI/2) * (r * w);
            const dy = Math.sin(ang + Math.PI/2) * (r * w);
            
            ctx.beginPath();
            ctx.moveTo(bx - dx, by - dy);
            ctx.quadraticCurveTo(tx, ty, bx + dx, by + dy);
            ctx.fill();
        };
        
        drawPreviewSpike(-2.6, 0.3, 0.2);
        drawPreviewSpike(-2.1, 0.4, 0.2);
        drawPreviewSpike(-1.57, 0.5, 0.25);
        drawPreviewSpike(-1.0, 0.4, 0.2);
        drawPreviewSpike(-0.5, 0.3, 0.2);
        
        ctx.beginPath();
        ctx.moveTo(cx - r*0.6, cy - r*0.3);
        ctx.quadraticCurveTo(cx, cy - r*0.1, cx + r*0.6, cy - r*0.3);
        ctx.fill();

      }
    }
    
    // Draw face
    ctx.fillStyle = skinColor;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
  }, [style, skinColor, hairColor]);

  return (
    <canvas
      ref={canvasRef}
      width={60}
      height={60}
      style={{
        borderRadius: '50%',
        backgroundColor: '#f0f0f0',
        border: isSelected ? '2px solid #4A90D9' : '1px solid #ddd',
        marginBottom: '6px'
      }}
    />
  );
}

export default function Customizer({
  avatar,
  setAvatar,
  accessibilityMode,
  emojiSet,
  hairStyles,
  accessories,
  skinTones,
  hairColors
}) {
  const [savedPresets, setSavedPresets] = useState([]);

  const updateAvatar = (key, value) => {
    setAvatar(prev => ({ ...prev, [key]: value }));
  };

  const savePreset = () => {
    const name = prompt('Name your preset:');
    if (name) {
      setSavedPresets(prev => [...prev, { name, avatar: { ...avatar } }]);
    }
  };

  const loadPreset = (preset) => {
    setAvatar(preset.avatar);
  };

  const sectionStyle = {
    marginBottom: '15px',
  };

  const labelStyle = {
    display: 'block',
    marginBottom: '8px',
    fontWeight: 'bold',
    fontSize: accessibilityMode ? '1.2rem' : '1rem',
    color: '#333'
  };

  const buttonGridStyle = {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(60px, 1fr))',
    gap: '8px'
  };

  const colorButtonStyle = (color, isSelected) => ({
    width: accessibilityMode ? '50px' : '40px',
    height: accessibilityMode ? '50px' : '40px',
    borderRadius: '50%',
    backgroundColor: color,
    border: isSelected ? '3px solid #4A90D9' : '2px solid #ddd',
    cursor: 'pointer',
    transition: 'transform 0.2s',
  });

  const optionButtonStyle = (isSelected) => ({
    padding: accessibilityMode ? '12px 16px' : '8px 12px',
    fontSize: accessibilityMode ? '1rem' : '0.85rem',
    borderRadius: '8px',
    border: isSelected ? '2px solid #4A90D9' : '2px solid #ddd',
    backgroundColor: isSelected ? '#e3f2fd' : 'white',
    cursor: 'pointer',
    transition: 'all 0.2s',
  });

  return (
    <div style={{
      background: 'white',
      padding: '20px',
      borderRadius: '16px',
      boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
      width: '320px'
    }}>
      <h2 style={{ marginTop: 0, color: '#4A90D9', fontSize: accessibilityMode ? '1.5rem' : '1.2rem' }}>
        Customize
      </h2>

      {/* Emoji Selection */}
      <div style={sectionStyle}>
        <label style={labelStyle}>Expression</label>
        <select
          value={avatar.emoji}
          onChange={(e) => updateAvatar('emoji', e.target.value)}
          style={{
            width: '100%',
            padding: accessibilityMode ? '12px' : '8px',
            fontSize: accessibilityMode ? '1.1rem' : '1rem',
            borderRadius: '8px',
            border: '2px solid #ddd'
          }}
        >
          {emojiSet.map(emoji => (
            <option key={emoji} value={emoji}>
              {emoji.replace(/_/g, ' ')}
            </option>
          ))}
        </select>
      </div>

      {/* Skin Tone */}
      <div style={sectionStyle}>
        <label style={labelStyle}>Skin Tone</label>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {skinTones.map(color => (
            <button
              key={color}
              style={colorButtonStyle(color, avatar.skinColor === color)}
              onClick={() => updateAvatar('skinColor', color)}
              aria-label={`Skin tone ${color}`}
            />
          ))}
        </div>
      </div>

      {/* Hair Style - Snapchat-style visual preview */}
      <div style={sectionStyle}>
        <label style={labelStyle}>Hair Style</label>
        <div style={{
          display: 'flex',
          gap: '10px',
          overflowX: 'auto',
          padding: '10px 0',
          scrollbarWidth: 'thin',
          scrollbarColor: '#ccc transparent'
        }}>
          {hairStyles.map(style => {
            const isSelected = avatar.hairStyle === style;
            return (
              <div
              key={style}
              onClick={() => updateAvatar('hairStyle', style)}
                style={{
                  minWidth: '80px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  cursor: 'pointer',
                  padding: '8px',
                  borderRadius: '12px',
                  backgroundColor: isSelected ? '#e3f2fd' : 'transparent',
                  border: isSelected ? '2px solid #4A90D9' : '2px solid transparent',
                  transition: 'all 0.2s'
                }}
              >
                {/* Visual preview canvas */}
                <HairPreviewCanvas
                  style={style}
                  skinColor={avatar.skinColor}
                  hairColor={avatar.hairColor}
                  isSelected={isSelected}
                />
                <span style={{
                  fontSize: '0.75rem',
                  color: isSelected ? '#4A90D9' : '#666',
                  fontWeight: isSelected ? 'bold' : 'normal',
                  textTransform: 'capitalize'
                }}>
              {style}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Hair Color */}
      {avatar.hairStyle !== 'none' && (
        <div style={sectionStyle}>
          <label style={labelStyle}>Hair Color</label>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            {hairColors.map(color => (
              <button
                key={color}
                style={colorButtonStyle(color, avatar.hairColor === color)}
                onClick={() => updateAvatar('hairColor', color)}
                aria-label={`Hair color ${color}`}
              />
            ))}
          </div>
        </div>
      )}

      {/* Accessories - Multiple Selection */}
      <div style={sectionStyle}>
        <label style={labelStyle}>Accessories (Select Multiple)</label>
        <div style={buttonGridStyle}>
          {accessories.filter(acc => acc !== 'none').map(acc => {
            const isSelected = avatar.accessories && avatar.accessories.includes(acc);
            return (
            <button
              key={acc}
                style={optionButtonStyle(isSelected)}
                onClick={() => {
                  const currentAccessories = avatar.accessories || [];
                  if (isSelected) {
                    // Remove accessory
                    updateAvatar('accessories', currentAccessories.filter(a => a !== acc));
                  } else {
                    // Add accessory
                    updateAvatar('accessories', [...currentAccessories, acc]);
                  }
                }}
            >
              {acc}
            </button>
            );
          })}
        </div>
        {avatar.accessories && avatar.accessories.length > 0 && (
          <div style={{ marginTop: '8px', fontSize: '0.85rem', color: '#666' }}>
            Selected: {avatar.accessories.join(', ')}
          </div>
        )}
      </div>

      {/* Accessory Color */}
      {avatar.accessories && avatar.accessories.length > 0 && (
        <div style={sectionStyle}>
          <label style={labelStyle}>Accessory Color</label>
          <input
            type="color"
            value={avatar.accessoryColor}
            onChange={(e) => updateAvatar('accessoryColor', e.target.value)}
            style={{
              width: '100%',
              height: accessibilityMode ? '50px' : '40px',
              borderRadius: '8px',
              border: 'none',
              cursor: 'pointer'
            }}
          />
        </div>
      )}

      {/* Presets */}
      <div style={{ ...sectionStyle, borderTop: '1px solid #eee', paddingTop: '15px' }}>
        <button
          onClick={savePreset}
          style={{
            width: '100%',
            padding: accessibilityMode ? '12px' : '10px',
            fontSize: accessibilityMode ? '1rem' : '0.9rem',
            backgroundColor: '#FF9800',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            marginBottom: '10px'
          }}
        >
          Save Preset
        </button>

        {savedPresets.length > 0 && (
          <div>
            <label style={{ ...labelStyle, fontSize: '0.9rem' }}>Saved Presets</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
              {savedPresets.map((preset, idx) => (
                <button
                  key={idx}
                  onClick={() => loadPreset(preset)}
                  style={{
                    padding: '6px 12px',
                    fontSize: '0.85rem',
                    borderRadius: '6px',
                    border: '1px solid #ddd',
                    backgroundColor: '#f5f5f5',
                    cursor: 'pointer'
                  }}
                >
                  {preset.name}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
