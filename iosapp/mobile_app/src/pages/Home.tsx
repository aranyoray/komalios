import React, { useEffect, useRef, useState } from 'react';
import {
  IonContent,
  IonHeader,
  IonPage,
  IonTitle,
  IonToolbar,
  IonButton,
  IonIcon,
  IonGrid,
  IonRow,
  IonCol,
} from '@ionic/react';
import { shuffle, download } from 'ionicons/icons';
import { useAvatarStore } from '../stores/avatarStore';
import { CustomizerPanel } from '../components/CustomizerPanel';
import { CharacterSelector } from '../components/CharacterSelector';
import { AvatarRenderer } from '../utils/renderer';
import { AvatarExporter } from '../utils/export';
import './Home.css';

const Home: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rendererRef = useRef<AvatarRenderer | null>(null);
  const config = useAvatarStore((state) => state.config);
  const randomize = useAvatarStore((state) => state.randomize);
  const selectedCharacter = useAvatarStore((state) => state.selectedCharacter);
  const [isExporting, setIsExporting] = useState(false);

  useEffect(() => {
    if (!canvasRef.current) {
      console.warn('Canvas ref not available');
      return;
    }

    let isMounted = true;
    let rendererInstance: AvatarRenderer | null = null;

    const initRenderer = async () => {
      try {
        console.log('Initializing renderer...');
        const renderer = new AvatarRenderer();
        rendererInstance = renderer;
        await renderer.init(canvasRef.current!);
        if (isMounted && rendererInstance === renderer) {
          rendererRef.current = renderer;
          // Render without animation initially (default off)
          renderer.render(config, false);
          console.log('Renderer initialized successfully');
        } else if (rendererInstance === renderer) {
          // Component unmounted during init, clean up
          renderer.destroy();
        }
      } catch (error) {
        console.error('Failed to initialize renderer:', error);
        // Don't block the app if renderer fails - allow UI to still work
        if (rendererInstance) {
          try {
            rendererInstance.destroy();
          } catch (destroyError) {
            console.error('Error destroying failed renderer:', destroyError);
          }
        }
      }
    };

    // Small delay to ensure DOM is ready
    const timer = setTimeout(() => {
    initRenderer();
    }, 100);

    return () => {
      clearTimeout(timer);
      isMounted = false;
      if (rendererRef.current) {
        try {
          rendererRef.current.destroy();
        } catch (error) {
          console.error('Error destroying renderer:', error);
        }
        rendererRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    if (rendererRef.current) {
      // Only start animation if a character is selected
      const shouldAnimate = selectedCharacter !== null;
      // Pass the entire config object to render
      rendererRef.current.render(config, shouldAnimate);
    }
    // Deep dependency check - re-render on any config change
  }, [config, selectedCharacter]);

  const handleRandomize = () => {
    console.log('Randomize clicked');
    randomize();
    if (rendererRef.current) {
      rendererRef.current.animateRandomize();
    }
  };

  const handleExportAll = async () => {
    console.log('Export clicked');
    if (!rendererRef.current) {
      console.warn('Renderer not available for export');
      return;
    }
    setIsExporting(true);
    try {
      const app = rendererRef.current.getApp();
      if (app) {
        await AvatarExporter.exportAll(app, config);
      } else {
        console.warn('PIXI app not available');
      }
    } catch (error) {
      console.error('Export error:', error);
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar color="primary">
          <IonTitle>Avatar Customizer</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen scrollY={true}>
        <div className="home-container">
          <div className="avatar-section">
          {/* Character Selector */}
          <CharacterSelector />

          {/* Avatar Canvas */}
          <div className="canvas-container">
            <canvas ref={canvasRef} className="avatar-canvas" />
          </div>

          {/* Action Buttons */}
          <IonGrid>
            <IonRow>
              <IonCol size="6">
                <IonButton
                  expand="block"
                  color="secondary"
                  onClick={handleRandomize}
                  className="kid-button"
                >
                  <IonIcon icon={shuffle} slot="start" />
                  Randomize
                </IonButton>
              </IonCol>
              <IonCol size="6">
                <IonButton
                  expand="block"
                  color="accent"
                  onClick={handleExportAll}
                  disabled={isExporting}
                  className="kid-button"
                >
                  <IonIcon icon={download} slot="start" />
                  {isExporting ? 'Exporting...' : 'Export'}
                </IonButton>
              </IonCol>
            </IonRow>
          </IonGrid>
          </div>

          {/* Customizer Panel */}
          <div className="customizer-section">
          <CustomizerPanel />
          </div>
        </div>
      </IonContent>
    </IonPage>
  );
};

export default Home;

