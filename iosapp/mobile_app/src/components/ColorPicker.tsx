import React from 'react';
import { HexColorPicker } from 'react-colorful';

interface ColorPickerProps {
  color: string;
  onChange: (color: string) => void;
}

export const ColorPicker: React.FC<ColorPickerProps> = ({ color, onChange }) => {
  return (
    <div style={{ padding: '16px' }}>
      <HexColorPicker color={color} onChange={onChange} />
      <div style={{ marginTop: '12px', textAlign: 'center' }}>
        <input
          type="text"
          value={color}
          onChange={(e) => onChange(e.target.value)}
          style={{
            padding: '8px',
            borderRadius: '8px',
            border: '2px solid #ddd',
            fontSize: '14px',
            width: '100px',
            textAlign: 'center',
          }}
        />
      </div>
    </div>
  );
};

