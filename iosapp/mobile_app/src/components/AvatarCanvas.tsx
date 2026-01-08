import React, { useEffect, useRef } from 'react';
import { AvatarRenderer } from '../utils/renderer';
import { useAvatarStore } from '../stores/avatarStore';

interface AvatarCanvasProps {
  renderer?: AvatarRenderer;
}

export const AvatarCanvas: React.FC<AvatarCanvasProps> = ({ renderer }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const config = useAvatarStore((state) => state.config);

  useEffect(() => {
    if (!canvasRef.current || !renderer) return;
    renderer.render(config);
  }, [config, renderer]);

  return <canvas ref={canvasRef} className="avatar-canvas" />;
};

