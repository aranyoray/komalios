/**
 * 3D Animoji Avatar Component - Cute Raccoon Character
 * 
 * Inspired by jeelizWeboji raccoon - optimized for mobile
 * A friendly raccoon character that talks to children
 */

import React, { useRef, useMemo } from 'react';
import { Canvas, useFrame, invalidate } from '@react-three/fiber';
import * as THREE from 'three';

// Shared materials - created once for performance
let materialsCache = null;

function getMaterials() {
  if (!materialsCache) {
    // Raccoon colors
    materialsCache = {
      furMain: new THREE.MeshBasicMaterial({ color: '#8B9A8B' }), // Grey-green fur
      furDark: new THREE.MeshBasicMaterial({ color: '#4A5548' }), // Dark grey
      furLight: new THREE.MeshBasicMaterial({ color: '#C8D4C8' }), // Light grey/cream
      eyeMask: new THREE.MeshBasicMaterial({ color: '#2D2D2D' }), // Black mask
      eyeWhite: new THREE.MeshBasicMaterial({ color: '#FFFFFF' }),
      pupil: new THREE.MeshBasicMaterial({ color: '#1A1A1A' }),
      eyeShine: new THREE.MeshBasicMaterial({ color: '#FFFFFF' }),
      nose: new THREE.MeshBasicMaterial({ color: '#2D2D2D' }), // Black nose
      innerEar: new THREE.MeshBasicMaterial({ color: '#FFB5B5' }), // Pink inner ear
      mouth: new THREE.MeshBasicMaterial({ color: '#1A1A1A' }),
      tongue: new THREE.MeshBasicMaterial({ color: '#FF8B8B' }),
      cheek: new THREE.MeshBasicMaterial({ color: '#FFD0D0', transparent: true, opacity: 0.4 }),
    };
  }
  return materialsCache;
}

/**
 * Cute Raccoon Face
 */
function RaccoonFace({ isTalking }) {
  const groupRef = useRef();
  const mouthRef = useRef();
  const tongueRef = useRef();
  const leftEyeRef = useRef();
  const rightEyeRef = useRef();
  const leftEarRef = useRef();
  const rightEarRef = useRef();
  
  const blinkState = useRef({ nextBlink: 2, isBlinking: false });
  const mats = useMemo(() => getMaterials(), []);

  useFrame((state, delta) => {
    if (!groupRef.current) return;
    
    const time = state.clock.elapsedTime;
    
    // Cute idle bobbing
    groupRef.current.rotation.y = Math.sin(time * 0.6) * 0.08;
    groupRef.current.rotation.x = Math.sin(time * 0.4) * 0.03;
    groupRef.current.position.y = Math.sin(time * 1.2) * 0.02;
    
    // Ear wiggle
    if (leftEarRef.current && rightEarRef.current) {
      leftEarRef.current.rotation.z = 0.3 + Math.sin(time * 2) * 0.05;
      rightEarRef.current.rotation.z = -0.3 + Math.sin(time * 2 + 1) * 0.05;
    }
    
    // Talking animation
    if (isTalking && mouthRef.current) {
      const mouthOpen = (Math.sin(time * 15) + 1) * 0.1 + 
                        (Math.sin(time * 10) + 1) * 0.08 +
                        (Math.sin(time * 20) + 1) * 0.04;
      
      mouthRef.current.scale.y = 1 + mouthOpen * 2.5;
      mouthRef.current.position.y = -0.28 - mouthOpen * 0.08;
      
      // Show tongue when mouth is open enough
      if (tongueRef.current) {
        tongueRef.current.visible = mouthOpen > 0.12;
        tongueRef.current.position.y = -0.32 - mouthOpen * 0.1;
      }
      
      // Extra bounce when talking
      groupRef.current.rotation.z = Math.sin(time * 3) * 0.02;
      groupRef.current.position.y += Math.sin(time * 6) * 0.01;
    } else if (mouthRef.current) {
      mouthRef.current.scale.y = 1;
      mouthRef.current.position.y = -0.28;
      if (tongueRef.current) tongueRef.current.visible = false;
      groupRef.current.rotation.z = 0;
    }
    
    // Natural blinking
    blinkState.current.nextBlink -= delta;
    if (blinkState.current.nextBlink <= 0 && !blinkState.current.isBlinking) {
      blinkState.current.isBlinking = true;
      if (leftEyeRef.current) leftEyeRef.current.scale.y = 0.1;
      if (rightEyeRef.current) rightEyeRef.current.scale.y = 0.1;
      
      setTimeout(() => {
        if (leftEyeRef.current) leftEyeRef.current.scale.y = 1;
        if (rightEyeRef.current) rightEyeRef.current.scale.y = 1;
        blinkState.current.isBlinking = false;
        blinkState.current.nextBlink = 1.5 + Math.random() * 2.5;
        invalidate();
      }, 100);
    }
    
    if (isTalking) invalidate();
  });

  return (
    <group ref={groupRef}>
      {/* Main head - round and cute */}
      <mesh material={mats.furMain}>
        <sphereGeometry args={[0.7, 24, 18]} />
      </mesh>
      
      {/* Lighter face/muzzle area */}
      <mesh position={[0, -0.1, 0.45]} scale={[0.8, 0.7, 0.5]} material={mats.furLight}>
        <sphereGeometry args={[0.45, 18, 14]} />
      </mesh>
      
      {/* Forehead lighter patch */}
      <mesh position={[0, 0.35, 0.4]} scale={[0.4, 0.3, 0.3]} material={mats.furLight}>
        <sphereGeometry args={[0.35, 14, 10]} />
      </mesh>
      
      {/* Eye masks (raccoon signature) */}
      <mesh position={[-0.25, 0.12, 0.48]} scale={[1.3, 0.9, 0.5]} material={mats.eyeMask}>
        <sphereGeometry args={[0.18, 14, 12]} />
      </mesh>
      <mesh position={[0.25, 0.12, 0.48]} scale={[1.3, 0.9, 0.5]} material={mats.eyeMask}>
        <sphereGeometry args={[0.18, 14, 12]} />
      </mesh>
      
      {/* Left Eye */}
      <group position={[-0.22, 0.14, 0.55]}>
        <mesh material={mats.eyeWhite}>
          <sphereGeometry args={[0.12, 14, 12]} />
        </mesh>
        <mesh ref={leftEyeRef} position={[0.02, 0, 0.08]} material={mats.pupil}>
          <sphereGeometry args={[0.07, 12, 10]} />
        </mesh>
        <mesh position={[0.04, 0.03, 0.11]} material={mats.eyeShine}>
          <sphereGeometry args={[0.025, 8, 6]} />
        </mesh>
      </group>
      
      {/* Right Eye */}
      <group position={[0.22, 0.14, 0.55]}>
        <mesh material={mats.eyeWhite}>
          <sphereGeometry args={[0.12, 14, 12]} />
        </mesh>
        <mesh ref={rightEyeRef} position={[-0.02, 0, 0.08]} material={mats.pupil}>
          <sphereGeometry args={[0.07, 12, 10]} />
        </mesh>
        <mesh position={[0.0, 0.03, 0.11]} material={mats.eyeShine}>
          <sphereGeometry args={[0.025, 8, 6]} />
        </mesh>
      </group>
      
      {/* Cute rosy cheeks */}
      <mesh position={[-0.38, -0.05, 0.4]} material={mats.cheek}>
        <sphereGeometry args={[0.1, 10, 8]} />
      </mesh>
      <mesh position={[0.38, -0.05, 0.4]} material={mats.cheek}>
        <sphereGeometry args={[0.1, 10, 8]} />
      </mesh>
      
      {/* Nose - black and shiny */}
      <mesh position={[0, -0.08, 0.68]} material={mats.nose}>
        <sphereGeometry args={[0.09, 12, 10]} />
      </mesh>
      
      {/* Nose highlight */}
      <mesh position={[0.02, -0.05, 0.76]} material={mats.eyeShine}>
        <sphereGeometry args={[0.02, 6, 6]} />
      </mesh>
      
      {/* Mouth */}
      <mesh ref={mouthRef} position={[0, -0.28, 0.55]} material={mats.mouth}>
        <capsuleGeometry args={[0.06, 0.12, 8, 12]} />
      </mesh>
      
      {/* Tongue (visible when talking) */}
      <mesh ref={tongueRef} position={[0, -0.32, 0.58]} visible={false} material={mats.tongue}>
        <sphereGeometry args={[0.05, 10, 8]} />
      </mesh>
      
      {/* Left Ear */}
      <group ref={leftEarRef} position={[-0.45, 0.5, 0]} rotation={[0, 0, 0.3]}>
        <mesh material={mats.furDark}>
          <coneGeometry args={[0.18, 0.35, 12]} />
        </mesh>
        <mesh position={[0, -0.02, 0.05]} scale={[0.6, 0.7, 0.5]} material={mats.innerEar}>
          <coneGeometry args={[0.15, 0.25, 10]} />
        </mesh>
      </group>
      
      {/* Right Ear */}
      <group ref={rightEarRef} position={[0.45, 0.5, 0]} rotation={[0, 0, -0.3]}>
        <mesh material={mats.furDark}>
          <coneGeometry args={[0.18, 0.35, 12]} />
        </mesh>
        <mesh position={[0, -0.02, 0.05]} scale={[0.6, 0.7, 0.5]} material={mats.innerEar}>
          <coneGeometry args={[0.15, 0.25, 10]} />
        </mesh>
      </group>
      
      {/* Whisker dots */}
      {[-1, 1].map(side => (
        <group key={side} position={[side * 0.18, -0.12, 0.62]}>
          <mesh position={[0, 0.02, 0]} material={mats.furDark}>
            <sphereGeometry args={[0.015, 6, 6]} />
          </mesh>
          <mesh position={[side * 0.03, 0, 0]} material={mats.furDark}>
            <sphereGeometry args={[0.015, 6, 6]} />
          </mesh>
          <mesh position={[side * 0.06, -0.02, 0]} material={mats.furDark}>
            <sphereGeometry args={[0.015, 6, 6]} />
          </mesh>
        </group>
      ))}
    </group>
  );
}

/**
 * Main Animoji3D component - Cute Raccoon
 */
export default function Animoji3D({ 
  isTalking = false, 
  emotion = 'neutral',
  size = 280,
  style = {}
}) {
  return (
    <div style={{ 
      width: size, 
      height: size, 
      borderRadius: '50%',
      overflow: 'hidden',
      background: 'linear-gradient(145deg, #E8F5E9 0%, #C8E6C9 50%, #A5D6A7 100%)',
      boxShadow: '0 8px 32px rgba(76, 175, 80, 0.2)',
      ...style
    }}>
      <Canvas
        camera={{ position: [0, 0, 2.0], fov: 45 }}
        frameloop="demand"
        dpr={[1, 1.5]}
        gl={{ 
          antialias: true,
          alpha: true,
          powerPreference: 'low-power',
          preserveDrawingBuffer: false,
        }}
        style={{ background: 'transparent' }}
        onCreated={({ invalidate }) => {
          invalidate();
          const animate = () => {
            invalidate();
            requestAnimationFrame(animate);
          };
          animate();
        }}
      >
        <ambientLight intensity={1.3} />
        <RaccoonFace isTalking={isTalking} />
      </Canvas>
    </div>
  );
}
