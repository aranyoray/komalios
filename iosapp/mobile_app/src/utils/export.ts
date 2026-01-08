import { saveAs } from 'file-saver';
import { AvatarConfig } from '../types/avatar';
import * as PIXI from 'pixi.js';
import html2canvas from 'html2canvas';

export class AvatarExporter {
  // Export as PNG using PixiJS
  static async exportPNG(app: PIXI.Application, filename: string = 'avatar.png') {
    if (!app) return;
    
    try {
      const canvas = app.renderer.extract.canvas(app.stage);
      if (!canvas) {
        throw new Error('Failed to extract canvas');
      }
      
      // Use toBlob if available, otherwise use toDataURL
      if (typeof canvas.toBlob === 'function') {
        canvas.toBlob((blob) => {
          if (blob) {
            saveAs(blob, filename);
          }
        }, 'image/png');
      } else if (typeof canvas.toDataURL === 'function') {
        // Fallback: convert data URL to blob
        const dataUrl = canvas.toDataURL('image/png');
        const response = await fetch(dataUrl);
        const blob = await response.blob();
        saveAs(blob, filename);
      } else {
        throw new Error('Canvas export methods not available');
      }
    } catch (error) {
      console.error('Error exporting PNG:', error);
      // Fallback to html2canvas
      try {
        const canvasElement = app.view as HTMLCanvasElement;
        if (canvasElement) {
          const canvas = await html2canvas(canvasElement);
          if (typeof canvas.toBlob === 'function') {
            canvas.toBlob((blob) => {
              if (blob) {
                saveAs(blob, filename);
              }
            });
          } else if (typeof canvas.toDataURL === 'function') {
            const dataUrl = canvas.toDataURL('image/png');
            const response = await fetch(dataUrl);
            const blob = await response.blob();
            saveAs(blob, filename);
          }
        }
      } catch (fallbackError) {
        console.error('Fallback export also failed:', fallbackError);
      }
    }
  }
  
  // Export as JSON
  static exportJSON(config: AvatarConfig, filename: string = 'avatar.json') {
    const json = JSON.stringify(config, null, 2);
    const blob = new Blob([json], { type: 'application/json' });
    saveAs(blob, filename);
  }
  
  // Export both PNG and JSON
  static async exportAll(app: PIXI.Application, config: AvatarConfig) {
    await this.exportPNG(app, 'my-avatar.png');
    this.exportJSON(config, 'my-avatar.json');
  }
}

