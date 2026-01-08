import * as PIXI from 'pixi.js';
import { AvatarConfig } from '../types/avatar';
import { gsap } from 'gsap';

export class AvatarRenderer {
  private app: PIXI.Application | null = null;
  private container: PIXI.Container | null = null;
  private animator: AvatarAnimator | null = null;
  
  async init(canvasElement: HTMLCanvasElement) {
    try {
      // PixiJS v8: Create Application first, then init
      this.app = new PIXI.Application();
      await this.app.init({
        canvas: canvasElement,
        width: 512,
        height: 512,
        background: 0xf8f9fa,
        antialias: true,
        resolution: window.devicePixelRatio || 2,
        autoDensity: true,
      });
      
      if (!this.app) {
        throw new Error('Failed to create PIXI Application');
      }
      
      this.container = new PIXI.Container();
      this.app.stage.addChild(this.container);
      
      this.animator = new AvatarAnimator(this.container);
      
      return this.app;
    } catch (error) {
      console.error('PIXI Application initialization failed:', error);
      throw error;
    }
  }
  
  render(config: AvatarConfig, startAnimation: boolean = false) {
    if (!this.container || !this.app) return;
    
    // Stop animations before clearing to prevent memory leaks
    this.animator?.stop();
    
    // Clear previous
    this.container.removeChildren();
    
    // Calculate human proportions
    const proportions = this.calculateProportions();
    
    // Render in layers (back to front)
    this.renderBody(config, proportions);
    this.renderHairBack(config, proportions); // Hair back should be behind neck
    this.renderNeck(config, proportions); // Neck should be in front of hair back
    this.renderFaceShape(config, proportions);
    this.renderEars(config, proportions);
    this.renderEyes(config, proportions);
    this.renderEyebrows(config, proportions);
    this.renderNose(config, proportions);
    this.renderMouth(config, proportions);
    // Add expression-based facial effects (blush, etc.)
    this.renderExpressionEffects(config, proportions);
    this.renderHairFront(config, proportions);
    this.renderAccessories(config, proportions);
    
    // Start idle animation only if requested (when character is selected)
    if (startAnimation) {
      setTimeout(() => {
        if (this.animator && this.container) {
          this.animator.startIdle();
        }
      }, 100);
    }
  }
  
  startAnimation() {
    if (this.animator && this.container) {
      this.animator.startIdle();
    }
  }
  
  stopAnimation() {
    this.animator?.stop();
  }
  
  private calculateProportions() {
    // Human-like realistic proportions
    const headWidth = 190; 
    const headHeight = 230; // Slightly elongated for more realistic head shape
    
    return {
      headWidth,
      headHeight,
      centerX: 256,
      centerY: 200,
      eyeSpacing: headWidth * 0.46, // Wider spacing (~87px)
      eyeSize: headWidth * 0.095, // Smaller, realistic eyes (~18px base radius)
      noseWidth: headWidth * 0.18, // Balanced nose width
      mouthWidth: headWidth * 0.38, // Balanced mouth width
      foreheadHeight: headHeight * 0.35, 
      midFaceHeight: headHeight * 0.3,
      lowerFaceHeight: headHeight * 0.35,
      neckWidth: headWidth * 0.55, // Realistic neck width
      neckHeight: 55, // Realistic neck length
    };
  }
  
  private renderNeck(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const neck = new PIXI.Graphics();
    const skinColor = parseInt(config.face.color.replace('#', '0x'));
    
    // Draw neck with shadow under chin - wider and shorter
    neck.roundRect(
      proportions.centerX - proportions.neckWidth / 2,
      proportions.centerY + proportions.headHeight / 2 - 25, // Start higher up (tucked under chin)
      proportions.neckWidth,
      proportions.neckHeight + 30,
      15
    ).fill(skinColor);
    
    // Removed neck shadow ellipse for cleaner look
    this.container.addChild(neck);
  }
  
  private renderBody(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const body = new PIXI.Graphics();
    const color = parseInt(config.body.color.replace('#', '0x'));
    
    // More realistic shoulders and torso
    const shoulderWidth = proportions.headWidth * 2.2;
    const shoulderY = proportions.centerY + proportions.headHeight / 2 + proportions.neckHeight - 10;
    
    // Render different clothing styles
    switch (config.body.style) {
      case 'casual':
        this.renderCasualClothing(body, color, proportions, shoulderWidth, shoulderY);
        break;
      case 'formal':
        this.renderFormalClothing(body, color, proportions, shoulderWidth, shoulderY);
        break;
      case 'sporty':
        this.renderSportyClothing(body, color, proportions, shoulderWidth, shoulderY);
        break;
      case 'dress':
        this.renderDressClothing(body, color, proportions, shoulderWidth, shoulderY);
        break;
      default:
        this.renderCasualClothing(body, color, proportions, shoulderWidth, shoulderY);
        break;
    }
    
    this.container.addChild(body);
  }
  
  private renderCasualClothing(body: PIXI.Graphics, color: number, proportions: any, shoulderWidth: number, shoulderY: number) {
    // Casual: Simple t-shirt style
    // Shoulders - rounded and natural
    body.moveTo(proportions.centerX - proportions.neckWidth / 2, shoulderY - 10);
    body.bezierCurveTo(
      proportions.centerX - proportions.neckWidth, shoulderY,
      proportions.centerX - shoulderWidth / 2, shoulderY + 20,
      proportions.centerX - shoulderWidth / 2, shoulderY + 60
    );
    body.lineTo(proportions.centerX + shoulderWidth / 2, shoulderY + 60);
    body.bezierCurveTo(
      proportions.centerX + shoulderWidth / 2, shoulderY + 20,
      proportions.centerX + proportions.neckWidth, shoulderY,
      proportions.centerX + proportions.neckWidth / 2, shoulderY - 10
    );
    
    // Torso
    body.rect(
      proportions.centerX - shoulderWidth / 2,
      shoulderY + 60,
      shoulderWidth,
      200
    );
    
    body.fill(color);
    
    // Round neckline (t-shirt style)
    const neckline = new PIXI.Graphics();
    neckline.arc(proportions.centerX, shoulderY, proportions.neckWidth / 1.8, 0, Math.PI).stroke({ width: 3, color: 0x000000, alpha: 0.2 });
    body.addChild(neckline);
    
    // Sleeve openings
    const sleeveLeft = new PIXI.Graphics();
    sleeveLeft.arc(proportions.centerX - shoulderWidth / 2, shoulderY + 50, 15, Math.PI / 2, Math.PI * 1.5).stroke({ width: 2, color: 0x000000, alpha: 0.15 });
    body.addChild(sleeveLeft);
    
    const sleeveRight = new PIXI.Graphics();
    sleeveRight.arc(proportions.centerX + shoulderWidth / 2, shoulderY + 50, 15, -Math.PI / 2, Math.PI / 2).stroke({ width: 2, color: 0x000000, alpha: 0.15 });
    body.addChild(sleeveRight);
    
    // Removed clothing shade ellipse for cleaner look
  }
  
  private renderFormalClothing(body: PIXI.Graphics, color: number, proportions: any, shoulderWidth: number, shoulderY: number) {
    // Formal: Shirt with collar and tie
    // Shoulders
    body.moveTo(proportions.centerX - proportions.neckWidth / 2, shoulderY - 10);
    body.bezierCurveTo(
      proportions.centerX - proportions.neckWidth, shoulderY,
      proportions.centerX - shoulderWidth / 2, shoulderY + 20,
      proportions.centerX - shoulderWidth / 2, shoulderY + 60
    );
    body.lineTo(proportions.centerX + shoulderWidth / 2, shoulderY + 60);
    body.bezierCurveTo(
      proportions.centerX + shoulderWidth / 2, shoulderY + 20,
      proportions.centerX + proportions.neckWidth, shoulderY,
      proportions.centerX + proportions.neckWidth / 2, shoulderY - 10
    );
    
    // Torso
    body.rect(
      proportions.centerX - shoulderWidth / 2,
      shoulderY + 60,
      shoulderWidth,
      200
    );
    
    body.fill(color);
    
    // Shirt collar (V-neck style)
    const collar = new PIXI.Graphics();
    collar.moveTo(proportions.centerX - proportions.neckWidth / 1.5, shoulderY);
    collar.lineTo(proportions.centerX, shoulderY + 15);
    collar.lineTo(proportions.centerX + proportions.neckWidth / 1.5, shoulderY);
    collar.stroke({ width: 3, color: 0x000000, alpha: 0.25 });
    body.addChild(collar);
    
    // Tie
    const tie = new PIXI.Graphics();
    const tieColor = 0x1a1a1a; // Dark tie
    tie.moveTo(proportions.centerX, shoulderY + 15);
    tie.lineTo(proportions.centerX - 8, shoulderY + 120);
    tie.lineTo(proportions.centerX + 8, shoulderY + 120);
    tie.fill(tieColor);
    // Tie knot
    tie.roundRect(proportions.centerX - 10, shoulderY + 10, 20, 15, 3).fill(tieColor);
    body.addChild(tie);
    
    // Button line
    const buttons = new PIXI.Graphics();
    buttons.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.1 });
    buttons.moveTo(proportions.centerX, shoulderY + 30);
    buttons.lineTo(proportions.centerX, shoulderY + 200);
    buttons.stroke();
    // Buttons
    for (let i = 0; i < 4; i++) {
      buttons.circle(proportions.centerX, shoulderY + 50 + i * 40, 3).fill({ color: 0x000000, alpha: 0.3 });
    }
    body.addChild(buttons);
    
    // Sleeve openings
    const sleeveLeft = new PIXI.Graphics();
    sleeveLeft.arc(proportions.centerX - shoulderWidth / 2, shoulderY + 50, 12, Math.PI / 2, Math.PI * 1.5).stroke({ width: 2, color: 0x000000, alpha: 0.2 });
    body.addChild(sleeveLeft);
    
    const sleeveRight = new PIXI.Graphics();
    sleeveRight.arc(proportions.centerX + shoulderWidth / 2, shoulderY + 50, 12, -Math.PI / 2, Math.PI / 2).stroke({ width: 2, color: 0x000000, alpha: 0.2 });
    body.addChild(sleeveRight);
    
    // Removed clothing shade ellipse for cleaner look
  }
  
  private renderSportyClothing(body: PIXI.Graphics, color: number, proportions: any, shoulderWidth: number, shoulderY: number) {
    // Sporty: Tank top or athletic wear
    // Narrower shoulders for athletic look
    const sportyShoulderWidth = shoulderWidth * 0.9;
    
    body.moveTo(proportions.centerX - proportions.neckWidth / 2, shoulderY - 10);
    body.bezierCurveTo(
      proportions.centerX - proportions.neckWidth * 0.8, shoulderY,
      proportions.centerX - sportyShoulderWidth / 2, shoulderY + 15,
      proportions.centerX - sportyShoulderWidth / 2, shoulderY + 50
    );
    body.lineTo(proportions.centerX + sportyShoulderWidth / 2, shoulderY + 50);
    body.bezierCurveTo(
      proportions.centerX + sportyShoulderWidth / 2, shoulderY + 15,
      proportions.centerX + proportions.neckWidth * 0.8, shoulderY,
      proportions.centerX + proportions.neckWidth / 2, shoulderY - 10
    );
    
    // Torso
    body.rect(
      proportions.centerX - sportyShoulderWidth / 2,
      shoulderY + 50,
      sportyShoulderWidth,
      200
    );
    
    body.fill(color);
    
    // Tank top arm openings (wider)
    const armholeLeft = new PIXI.Graphics();
    armholeLeft.moveTo(proportions.centerX - sportyShoulderWidth / 2, shoulderY + 40);
    armholeLeft.quadraticCurveTo(proportions.centerX - sportyShoulderWidth / 2 - 10, shoulderY + 50, proportions.centerX - sportyShoulderWidth / 2, shoulderY + 60);
    armholeLeft.stroke({ width: 3, color: 0x000000, alpha: 0.2 });
    body.addChild(armholeLeft);
    
    const armholeRight = new PIXI.Graphics();
    armholeRight.moveTo(proportions.centerX + sportyShoulderWidth / 2, shoulderY + 40);
    armholeRight.quadraticCurveTo(proportions.centerX + sportyShoulderWidth / 2 + 10, shoulderY + 50, proportions.centerX + sportyShoulderWidth / 2, shoulderY + 60);
    armholeRight.stroke({ width: 3, color: 0x000000, alpha: 0.2 });
    body.addChild(armholeRight);
    
    // Round neckline
    const neckline = new PIXI.Graphics();
    neckline.arc(proportions.centerX, shoulderY, proportions.neckWidth / 2, 0, Math.PI).stroke({ width: 3, color: 0x000000, alpha: 0.2 });
    body.addChild(neckline);
    
    // Athletic stripes/accents
    const stripe = new PIXI.Graphics();
    stripe.rect(proportions.centerX - sportyShoulderWidth / 2, shoulderY + 80, sportyShoulderWidth, 8).fill({ color: 0xFFFFFF, alpha: 0.2 });
    body.addChild(stripe);
    
    stripe.rect(proportions.centerX - sportyShoulderWidth / 2, shoulderY + 140, sportyShoulderWidth, 8).fill({ color: 0xFFFFFF, alpha: 0.2 });
    body.addChild(stripe);
    
    // Removed clothing shade ellipse for cleaner look
  }
  
  private renderDressClothing(body: PIXI.Graphics, color: number, proportions: any, shoulderWidth: number, shoulderY: number) {
    // Dress: Flowing dress style
    // Shoulders
    body.moveTo(proportions.centerX - proportions.neckWidth / 2, shoulderY - 10);
    body.bezierCurveTo(
      proportions.centerX - proportions.neckWidth, shoulderY,
      proportions.centerX - shoulderWidth / 2, shoulderY + 20,
      proportions.centerX - shoulderWidth / 2, shoulderY + 60
    );
    body.lineTo(proportions.centerX + shoulderWidth / 2, shoulderY + 60);
    body.bezierCurveTo(
      proportions.centerX + shoulderWidth / 2, shoulderY + 20,
      proportions.centerX + proportions.neckWidth, shoulderY,
      proportions.centerX + proportions.neckWidth / 2, shoulderY - 10
    );
    
    // Upper body (tighter)
    const upperWidth = shoulderWidth * 0.85;
    body.rect(
      proportions.centerX - upperWidth / 2,
      shoulderY + 60,
      upperWidth,
      80
    );
    
    // Skirt (wider, flowing)
    const skirtWidth = shoulderWidth * 1.3;
    body.moveTo(proportions.centerX - upperWidth / 2, shoulderY + 140);
    body.lineTo(proportions.centerX - skirtWidth / 2, shoulderY + 260);
    body.lineTo(proportions.centerX + skirtWidth / 2, shoulderY + 260);
    body.lineTo(proportions.centerX + upperWidth / 2, shoulderY + 140);
    
    body.fill(color);
    
    // Dress neckline (rounded or V-neck)
    const neckline = new PIXI.Graphics();
    neckline.arc(proportions.centerX, shoulderY, proportions.neckWidth / 1.6, 0, Math.PI).stroke({ width: 3, color: 0x000000, alpha: 0.2 });
    body.addChild(neckline);
    
    // Waistline
    const waistline = new PIXI.Graphics();
    waistline.moveTo(proportions.centerX - upperWidth / 2, shoulderY + 140);
    waistline.lineTo(proportions.centerX + upperWidth / 2, shoulderY + 140);
    waistline.stroke({ width: 2, color: 0x000000, alpha: 0.15 });
    body.addChild(waistline);
    
    // Dress folds/pleats
    const folds = new PIXI.Graphics();
    folds.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.1 });
    for (let i = -2; i <= 2; i++) {
      const x = proportions.centerX + (skirtWidth * 0.2 * i);
      folds.moveTo(x, shoulderY + 140);
      folds.lineTo(x + (i * 3), shoulderY + 260);
    }
    folds.stroke();
    body.addChild(folds);
    
    // Sleeve openings (if sleeveless, show armholes)
    const armholeLeft = new PIXI.Graphics();
    armholeLeft.arc(proportions.centerX - shoulderWidth / 2, shoulderY + 50, 12, Math.PI / 2, Math.PI * 1.5).stroke({ width: 2, color: 0x000000, alpha: 0.15 });
    body.addChild(armholeLeft);
    
    const armholeRight = new PIXI.Graphics();
    armholeRight.arc(proportions.centerX + shoulderWidth / 2, shoulderY + 50, 12, -Math.PI / 2, Math.PI / 2).stroke({ width: 2, color: 0x000000, alpha: 0.15 });
    body.addChild(armholeRight);
    
    // Removed clothing shade ellipses for cleaner look
  }
  
  private renderHairBack(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const hair = new PIXI.Graphics();
    const color = parseInt(config.hair.color.replace('#', '0x'));
    
    // More varied hair shapes based on style
    if (config.hair.style.includes('long')) {
        // Long hair extends from head down to shoulder area, behind the neck
        const shoulderY = proportions.centerY + proportions.headHeight / 2 + proportions.neckHeight - 10;
        // Hair should keep a larger gap from shoulder
        const hairEndY = shoulderY - 10; // Larger gap from shoulder (10px gap)
        const hairStartY = proportions.centerY - proportions.headHeight / 2; // Start from top of head
        
        // Long hair extends from head down to shoulder area
        // Hair is behind neck, so it can overlap neck area but will be rendered behind
        hair.roundRect(
            proportions.centerX - proportions.headWidth * 0.55, // Slightly narrower than head
            hairStartY,
            proportions.headWidth * 1.1,
            hairEndY - hairStartY, // Height from head top to shoulder area
            20
        ).fill(color);
    } else if (config.hair.style === 'bun') {
        hair.circle(proportions.centerX, proportions.centerY - proportions.headHeight / 2 - 20, 40).fill(color);
    }
    
    // Base hair layer (only if not long hair, as long hair has its own rendering)
    if (!config.hair.style.includes('long')) {
    hair.ellipse(
      proportions.centerX,
          proportions.centerY - 20,
          proportions.headWidth / 2 + 10,
          proportions.headHeight / 2 + 20
    ).fill(color);
    }
    
    this.container.addChild(hair);
  }
  
  private renderFaceShape(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const face = new PIXI.Graphics();
    const color = parseInt(config.face.color.replace('#', '0x'));
    
    // Render different face shapes based on config
    switch (config.face.shape) {
      case 'round':
        this.renderRoundFace(face, color, proportions);
        break;
      case 'oval':
        this.renderOvalFace(face, color, proportions);
        break;
      case 'heart':
        this.renderHeartFace(face, color, proportions);
        break;
      case 'diamond':
        this.renderDiamondFace(face, color, proportions);
        break;
      case 'long':
        this.renderLongFace(face, color, proportions);
        break;
      default:
        this.renderRoundFace(face, color, proportions);
        break;
    }
    
    // Rosy cheeks only render for blushing expression
    if (config.expression === 'blushing') {
      const blushIntensity = config.face?.blushIntensity ?? 0.25;
      const blush = new PIXI.Graphics();
      blush.ellipse(proportions.centerX - 45, proportions.centerY + 25, 35, 22).fill({ color: 0xFF69B4, alpha: blushIntensity });
      blush.ellipse(proportions.centerX + 45, proportions.centerY + 25, 35, 22).fill({ color: 0xFF69B4, alpha: blushIntensity });
      face.addChild(blush);
    }
    
    // Removed unnecessary highlight and shadow ellipses for cleaner look
    
    this.container.addChild(face);
  }
  
  private renderRoundFace(face: PIXI.Graphics, color: number, proportions: any) {
    // Round face - circular/child-like
    const chinY = proportions.centerY + proportions.headHeight / 2;
    const jawY = proportions.centerY + proportions.headHeight / 3;
    const templeY = proportions.centerY - proportions.headHeight / 3;
    const width = proportions.headWidth / 2;
    
    face.moveTo(proportions.centerX - width, templeY);
    
    // Softer, rounder jawline (child-like)
    face.bezierCurveTo(
      proportions.centerX - width, jawY,
      proportions.centerX - width * 0.9, chinY,
      proportions.centerX, chinY
    );
    
    face.bezierCurveTo(
      proportions.centerX + width * 0.9, chinY,
      proportions.centerX + width, jawY,
      proportions.centerX + width, templeY
    );
    
    // Rounder forehead/top
    face.bezierCurveTo(
      proportions.centerX + width, proportions.centerY - proportions.headHeight / 2,
      proportions.centerX - width, proportions.centerY - proportions.headHeight / 2,
      proportions.centerX - width, templeY
    );
    
    face.fill(color);
  }
  
  private renderOvalFace(face: PIXI.Graphics, color: number, proportions: any) {
    // Oval face - elongated, balanced
    const chinY = proportions.centerY + proportions.headHeight / 2;
    const jawY = proportions.centerY + proportions.headHeight / 3;
    const templeY = proportions.centerY - proportions.headHeight / 3;
    const width = proportions.headWidth / 2;
    
    face.moveTo(proportions.centerX - width * 0.95, templeY);
    
    // Softer, more elongated jawline
    face.bezierCurveTo(
      proportions.centerX - width * 0.95, jawY,
      proportions.centerX - width * 0.85, chinY,
      proportions.centerX, chinY
    );
    
    face.bezierCurveTo(
      proportions.centerX + width * 0.85, chinY,
      proportions.centerX + width * 0.95, jawY,
      proportions.centerX + width * 0.95, templeY
    );
    
    // More elongated forehead
    face.bezierCurveTo(
      proportions.centerX + width * 0.95, proportions.centerY - proportions.headHeight / 2 - 5,
      proportions.centerX - width * 0.95, proportions.centerY - proportions.headHeight / 2 - 5,
      proportions.centerX - width * 0.95, templeY
    );
    
    face.fill(color);
  }
  
  private renderHeartFace(face: PIXI.Graphics, color: number, proportions: any) {
    // Heart face - wide forehead, narrow chin
    const chinY = proportions.centerY + proportions.headHeight / 2;
    const jawY = proportions.centerY + proportions.headHeight / 3;
    const templeY = proportions.centerY - proportions.headHeight / 3;
    const width = proportions.headWidth / 2;
    
    // Start from wider forehead
    face.moveTo(proportions.centerX - width * 1.1, proportions.centerY - proportions.headHeight / 2);
    
    // Wide forehead curves down
    face.bezierCurveTo(
      proportions.centerX - width * 1.1, templeY - 5,
      proportions.centerX - width, templeY,
      proportions.centerX - width * 0.9, templeY
    );
    
    // Narrowing jawline
    face.bezierCurveTo(
      proportions.centerX - width * 0.9, jawY,
      proportions.centerX - width * 0.6, chinY,
      proportions.centerX, chinY
    );
    
    // Symmetrical right side
    face.bezierCurveTo(
      proportions.centerX + width * 0.6, chinY,
      proportions.centerX + width * 0.9, jawY,
      proportions.centerX + width * 0.9, templeY
    );
    
    face.bezierCurveTo(
      proportions.centerX + width, templeY,
      proportions.centerX + width * 1.1, templeY - 5,
      proportions.centerX + width * 1.1, proportions.centerY - proportions.headHeight / 2
    );
    
    face.fill(color);
  }
  
  private renderDiamondFace(face: PIXI.Graphics, color: number, proportions: any) {
    // Diamond face - narrow forehead and chin, wide cheeks
    const chinY = proportions.centerY + proportions.headHeight / 2;
    const cheekY = proportions.centerY + proportions.headHeight / 4;
    const templeY = proportions.centerY - proportions.headHeight / 3;
    const width = proportions.headWidth / 2;
    
    // Narrow forehead point
    face.moveTo(proportions.centerX, proportions.centerY - proportions.headHeight / 2);
    
    // Widening to temples
    face.lineTo(proportions.centerX - width * 0.8, templeY);
    
    // Widest at cheeks
    face.bezierCurveTo(
      proportions.centerX - width * 0.8, cheekY - 10,
      proportions.centerX - width * 1.1, cheekY,
      proportions.centerX - width * 0.9, cheekY + 10
    );
    
    // Narrowing to chin
    face.bezierCurveTo(
      proportions.centerX - width * 0.7, chinY - 10,
      proportions.centerX - width * 0.4, chinY,
      proportions.centerX, chinY
    );
    
    // Symmetrical right side
    face.bezierCurveTo(
      proportions.centerX + width * 0.4, chinY,
      proportions.centerX + width * 0.7, chinY - 10,
      proportions.centerX + width * 0.9, cheekY + 10
    );
    
    face.bezierCurveTo(
      proportions.centerX + width * 1.1, cheekY,
      proportions.centerX + width * 0.8, cheekY - 10,
      proportions.centerX + width * 0.8, templeY
    );
    
    face.lineTo(proportions.centerX, proportions.centerY - proportions.headHeight / 2);
    
    face.fill(color);
  }
  
  private renderLongFace(face: PIXI.Graphics, color: number, proportions: any) {
    // Long face - elongated, narrow
    const chinY = proportions.centerY + proportions.headHeight / 2 + 15; // Longer chin
    const jawY = proportions.centerY + proportions.headHeight / 3;
    const templeY = proportions.centerY - proportions.headHeight / 3 - 10; // Higher forehead
    const width = proportions.headWidth / 2 * 0.85; // Narrower
    
    face.moveTo(proportions.centerX - width, templeY);
    
    // Narrow, elongated jawline
    face.bezierCurveTo(
      proportions.centerX - width, jawY,
      proportions.centerX - width * 0.8, chinY,
      proportions.centerX, chinY
    );
    
    face.bezierCurveTo(
      proportions.centerX + width * 0.8, chinY,
      proportions.centerX + width, jawY,
      proportions.centerX + width, templeY
    );
    
    // Elongated forehead
    face.bezierCurveTo(
      proportions.centerX + width, proportions.centerY - proportions.headHeight / 2 - 10,
      proportions.centerX - width, proportions.centerY - proportions.headHeight / 2 - 10,
      proportions.centerX - width, templeY
    );
    
    face.fill(color);
  }
  
  private renderEars(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const earColor = parseInt(config.face.color.replace('#', '0x'));
    const y = proportions.centerY + 10;
    
    // Render different ear styles based on config
    const drawEar = (x: number, scaleX: number) => {
      const ear = new PIXI.Graphics();
      
      switch (config.ears.style) {
        case 'small':
          // Small ears
          ear.ellipse(0, 0, 9, 15).fill(earColor);
          const innerSmall = new PIXI.Graphics();
          innerSmall.ellipse(0, 0, 4, 9).fill({ color: 0x000000, alpha: 0.1 });
          ear.addChild(innerSmall);
          break;
        case 'large':
          // Large ears
          ear.ellipse(0, 0, 15, 25).fill(earColor);
          const innerLarge = new PIXI.Graphics();
          innerLarge.ellipse(0, 0, 8, 15).fill({ color: 0x000000, alpha: 0.1 });
          ear.addChild(innerLarge);
          break;
        case 'pointed':
          // Pointed/elf-like ears
          ear.moveTo(0, -18);
          ear.lineTo(-12, 0);
          ear.lineTo(-8, 15);
          ear.lineTo(0, 12);
          ear.lineTo(8, 15);
          ear.lineTo(12, 0);
          ear.lineTo(0, -18);
          ear.fill(earColor);
          const innerPointed = new PIXI.Graphics();
          innerPointed.moveTo(0, -10);
          innerPointed.lineTo(-6, 0);
          innerPointed.lineTo(-4, 10);
          innerPointed.lineTo(0, 8);
          innerPointed.lineTo(4, 10);
          innerPointed.lineTo(6, 0);
          innerPointed.fill({ color: 0x000000, alpha: 0.1 });
          ear.addChild(innerPointed);
          break;
        case 'normal':
        default:
          // Normal ears - more detailed with inner shadow
          ear.ellipse(0, 0, 12, 20).fill(earColor);
          const inner = new PIXI.Graphics();
          inner.ellipse(0, 0, 6, 12).fill({ color: 0x000000, alpha: 0.1 });
          ear.addChild(inner);
          break;
      }
      
      ear.position.set(x, y);
      ear.scale.x = scaleX; // Flip for left/right
      return ear;
    };
    
    this.container.addChild(drawEar(proportions.centerX - proportions.headWidth / 2 - 5, 1));
    this.container.addChild(drawEar(proportions.centerX + proportions.headWidth / 2 + 5, -1));
  }
  
  private renderEyes(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const eyeY = proportions.centerY - proportions.midFaceHeight * 0.15; // Slightly higher for child-like
    // Larger eyes for child-like appearance
    const eyeSize = proportions.eyeSize * (config.eyes.size === 'large' ? 1.3 : config.eyes.size === 'small' ? 1.0 : 1.15);
    
    // Handle wink expression - only render one eye
    if (config.expression === 'wink') {
      // Right eye closed (winking), left eye open
      const leftEye = this.createRealisticEye(
      proportions.centerX - proportions.eyeSpacing / 2,
      eyeY,
      eyeSize,
      config.eyes.shape,
        config.eyes.color,
        false,
        config.expression
    );
    this.container.addChild(leftEye);
    
      // Right eye closed (wink)
      const rightEyeClosed = this.createWinkEye(
      proportions.centerX + proportions.eyeSpacing / 2,
        eyeY,
        eyeSize
      );
      this.container.addChild(rightEyeClosed);
    } else {
      // Both eyes open with expression
      const leftEye = this.createRealisticEye(
      proportions.centerX - proportions.eyeSpacing / 2,
      eyeY,
      eyeSize,
      config.eyes.shape,
        config.eyes.color,
        false,
        config.expression
    );
    this.container.addChild(leftEye);
    
      const rightEye = this.createRealisticEye(
      proportions.centerX + proportions.eyeSpacing / 2,
      eyeY,
      eyeSize,
      config.eyes.shape,
        config.eyes.color,
        true,
        config.expression
    );
    this.container.addChild(rightEye);
    }
  }
  
  private createRealisticEye(x: number, y: number, size: number, shape: string, color: string, _isRight: boolean, expression: string = 'neutral'): PIXI.Container {
    const eyeContainer = new PIXI.Container();
    eyeContainer.position.set(x, y);
    eyeContainer.label = 'eye';
    
    // Use shape to adjust eye curvature if needed (default is almond)
    const curvature = shape === 'round' ? 0.8 : 0.6;
    
    // Expression-based eye adjustments
    let eyeOpenness = 1.0; // Multiplier for eye height
    let eyeWidth = 1.0; // Multiplier for eye width
    let eyeYOffset = 0; // Vertical offset for expression
    
    switch (expression) {
      case 'happy':
      case 'smile':
        // Slightly squinted (happy eyes)
        eyeOpenness = 0.75;
        eyeWidth = 1.1; // Slightly wider
        break;
      case 'excited':
        // Wide open, energetic
        eyeOpenness = 1.2;
        eyeWidth = 1.15;
        break;
      case 'surprised':
        // Very wide open
        eyeOpenness = 1.4;
        eyeWidth = 1.1;
        eyeYOffset = -3; // Slightly raised
        break;
      case 'cool':
        // Half-closed, relaxed
        eyeOpenness = 0.6;
        eyeWidth = 1.0;
        break;
      case 'blushing':
        // Slightly downcast, shy eyes
        eyeOpenness = 0.85;
        eyeWidth = 1.0;
        eyeYOffset = 2; // Eyes look slightly downward
        break;
      case 'neutral':
      default:
        eyeOpenness = 1.0;
        eyeWidth = 1.0;
        break;
    }
    
    // ===== STEP 1: SCLERA (White part of the eye) - More prominent =====
    const sclera = new PIXI.Graphics();
    // Realistic eye proportions: width should be wider, height moderate
    const w = size * 1.4 * eyeWidth; // Wider eye for more realistic look
    const h = size * 0.65 * eyeOpenness; // Moderate height
    
    // Realistic almond-shaped eye (sclera) - more elongated
    sclera.moveTo(-w, eyeYOffset);
    sclera.quadraticCurveTo(0, -h + eyeYOffset, w, eyeYOffset); // Upper lid curve
    sclera.quadraticCurveTo(0, h * curvature + eyeYOffset, -w, eyeYOffset); // Lower lid curve
    sclera.fill(0xFFFFFF);
    
    // Removed sclera shade ellipses for cleaner look
    
    // ===== RENDERING ORDER: Sclera (bottom) → Iris/Pupil (middle) → Eyelids (top) =====
    
    // STEP 1: Add sclera FIRST (bottom layer - white background)
    eyeContainer.addChild(sclera);
    
    // ===== STEP 2: IRIS (Colored part) - Middle layer, on top of sclera =====
    // Iris size should be based on eye openness - smaller when squinted
    // Ensure iris is always visible with a good minimum size
    const baseIrisSize = size * 0.7; // Base iris size - larger for visibility
    const maxIrisRadius = Math.min(h * 0.55, w * 0.4); // Maximum iris radius (55% of height or 40% of width)
    // When eye is squinted (low openness), iris appears smaller but still visible
    const irisRadius = Math.max(
      Math.min(maxIrisRadius, baseIrisSize * eyeOpenness),
      size * 0.4 // Minimum iris size to ensure visibility
    );
    
    const iris = new PIXI.Graphics();
    const irisColor = parseInt(color.replace('#', '0x'));
    
    // Ensure iris color is visible and not white/black - use default brown if invalid
    let validIrisColor = (irisColor && irisColor !== 0xFFFFFF && irisColor !== 0x000000) ? irisColor : 0x4A3728;
    
    // Lighten very dark colors to make them more visible
    if (validIrisColor < 0x666666) {
      const r = Math.min(255, ((validIrisColor >> 16) & 0xFF) + 80);
      const g = Math.min(255, ((validIrisColor >> 8) & 0xFF) + 80);
      const b = Math.min(255, (validIrisColor & 0xFF) + 80);
      validIrisColor = (r << 16) | (g << 8) | b;
    }
    
    // Iris Base - clearly visible colored circle
    iris.circle(0, 0, irisRadius).fill(validIrisColor);
    
    // Limbal Ring (Dark outer edge) - visible border
    iris.circle(0, 0, irisRadius).stroke({ width: 4, color: 0x000000, alpha: 0.7 });
    
    // Iris Texture (Radial lines) - visible texture
    const radialPattern = new PIXI.Graphics();
    radialPattern.setStrokeStyle({ width: 1.2, color: 0x000000, alpha: 0.3 });
    for (let i = 0; i < 16; i++) {
        const angle = (i / 16) * Math.PI * 2;
        radialPattern.moveTo(Math.cos(angle) * irisRadius * 0.2, Math.sin(angle) * irisRadius * 0.2);
        radialPattern.lineTo(Math.cos(angle) * irisRadius * 0.9, Math.sin(angle) * irisRadius * 0.9);
    }
    radialPattern.stroke();
    iris.addChild(radialPattern);
    
    // Inner depth ring
    iris.circle(0, 0, irisRadius * 0.7).stroke({ width: 2.5, color: 0x000000, alpha: 0.3 });
    
    // STEP 2: Add iris AFTER sclera (middle layer - on top of sclera)
    eyeContainer.addChild(iris);
    
    // ===== STEP 3: PUPIL (Black center) - On top of iris =====
    const pupil = new PIXI.Graphics();
    const pupilRadius = irisRadius * 0.45; // Larger pupil for visibility
    pupil.circle(0, 0, pupilRadius).fill(0x000000);
    pupil.circle(0, 0, pupilRadius).stroke({ width: 2, color: 0x000000, alpha: 1.0 });
    eyeContainer.addChild(pupil);
    
    // ===== STEP 4: HIGHLIGHTS (Reflections) - On top of iris/pupil =====
    const highlight = new PIXI.Graphics();
    // Main highlight (larger, more visible)
    highlight.ellipse(-irisRadius * 0.25, -irisRadius * 0.25, irisRadius * 0.22, irisRadius * 0.16).fill({ color: 0xFFFFFF, alpha: 0.9 });
    // Secondary smaller highlight
    highlight.circle(irisRadius * 0.2, -irisRadius * 0.2, irisRadius * 0.1).fill({ color: 0xFFFFFF, alpha: 0.75 });
    // Pupil catchlight (small white dot on pupil)
    highlight.circle(-irisRadius * 0.15, -irisRadius * 0.12, pupilRadius * 0.35).fill({ color: 0xFFFFFF, alpha: 0.95 });
    
    eyeContainer.addChild(highlight);
    
    // ===== STEP 5: EYELIDS & LASHES =====
    // Eyelids MUST be rendered LAST (top layer) - on top of all eye parts
    // Eyelids - rendered AFTER iris so they can hide it when closed
    const lids = new PIXI.Graphics();
    
    // Upper eyelid - can hide part of iris when squinted
    // When eye is squinted (low openness), draw a filled eyelid to hide iris
    if (eyeOpenness < 0.9) {
      // Draw filled upper eyelid to hide iris
      const upperLidFill = new PIXI.Graphics();
      upperLidFill.moveTo(-w * 1.1, eyeYOffset - 2);
      upperLidFill.quadraticCurveTo(0, -h + eyeYOffset + (h * (1 - eyeOpenness)), w * 1.1, eyeYOffset - 2);
      upperLidFill.lineTo(w * 1.1, eyeYOffset + 5);
      upperLidFill.lineTo(-w * 1.1, eyeYOffset + 5);
      upperLidFill.fill({ color: 0xFFFFFF, alpha: 0.95 }); // Skin-colored eyelid
      lids.addChild(upperLidFill);
    }
    
    // Upper lid line (always visible)
    lids.setStrokeStyle({ width: 2.5, color: 0x000000, alpha: 0.85 });
    lids.moveTo(-w, eyeYOffset);
    lids.quadraticCurveTo(0, -h + eyeYOffset, w, eyeYOffset);
    lids.stroke();
    
    // Upper eyelid fold (crease)
    const fold = new PIXI.Graphics();
    fold.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.3 });
    fold.moveTo(-w, eyeYOffset - 3);
    fold.quadraticCurveTo(0, -h + eyeYOffset - 4, w, eyeYOffset - 3);
    fold.stroke();
    lids.addChild(fold);
    
    // Lower lid line - subtle
    lids.setStrokeStyle({ width: 1.5, color: 0x000000, alpha: 0.5 });
    lids.moveTo(-w * 0.9, h * 0.3 * eyeOpenness + eyeYOffset);
    lids.quadraticCurveTo(0, h * 0.4 * eyeOpenness + eyeYOffset, w * 0.9, h * 0.3 * eyeOpenness + eyeYOffset);
    lids.stroke();
    
    // Eyelashes (upper)
    const lashes = new PIXI.Graphics();
    lashes.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.9 });
    const lashCount = 9;
    for (let i = 0; i < lashCount; i++) {
        const t = i / (lashCount - 1); // 0 to 1
        const xPos = -w * 0.9 + w * 1.8 * t;
        // Curve lashes outward
        const angle = -Math.PI/2 + (t - 0.5) * 0.5;
        const len = 4 + Math.sin(t * Math.PI) * 3;
        
        // Calculate y on the upper lid curve for this x
        // Approximate parabola y = a*x^2 + b. Vertex at (0, -h). Roots at +/-w.
        // y = (h/w^2) * x^2 - h (roughly)
        const yPos = (h / (w*w)) * xPos * xPos - h + eyeYOffset;
        
        lashes.moveTo(xPos, yPos);
        lashes.lineTo(xPos + Math.sin(angle) * len, yPos + Math.cos(angle) * len);
    }
    lashes.stroke();
    lids.addChild(lashes);
    
    // For happy/smile expressions, add slight upward curve at corners (crow's feet)
    if (expression === 'happy' || expression === 'smile' || expression === 'excited') {
      const smileLines = new PIXI.Graphics();
      smileLines.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.25 });
      // Left corner lines
      smileLines.moveTo(-w * 0.95, eyeYOffset);
      smileLines.quadraticCurveTo(-w * 1.1, eyeYOffset - 3, -w * 1.2, eyeYOffset - 2);
      smileLines.moveTo(-w * 0.9, eyeYOffset - 1);
      smileLines.quadraticCurveTo(-w * 1.05, eyeYOffset - 4, -w * 1.15, eyeYOffset - 3);
      // Right corner lines
      smileLines.moveTo(w * 0.95, eyeYOffset);
      smileLines.quadraticCurveTo(w * 1.1, eyeYOffset - 3, w * 1.2, eyeYOffset - 2);
      smileLines.moveTo(w * 0.9, eyeYOffset - 1);
      smileLines.quadraticCurveTo(w * 1.05, eyeYOffset - 4, w * 1.15, eyeYOffset - 3);
      smileLines.stroke();
      lids.addChild(smileLines);
    }
    
    // Inner corner (tear duct) - add before eyelids
    const tearDuct = new PIXI.Graphics();
    tearDuct.ellipse(-w * 0.85, eyeYOffset, 3, 2).fill({ color: 0xFFE4E1, alpha: 0.6 });
    tearDuct.ellipse(-w * 0.85, eyeYOffset, 3, 2).stroke({ width: 0.5, color: 0x000000, alpha: 0.2 });
    eyeContainer.addChild(tearDuct);
    
    // Add eyelids LAST (top layer) - on top of all eye parts (sclera, iris, pupil, highlights)
    // This ensures eyelids can hide iris when closed
    eyeContainer.addChild(lids);
    
    return eyeContainer;
  }
  
  private createWinkEye(x: number, y: number, size: number): PIXI.Container {
    const eyeContainer = new PIXI.Container();
    eyeContainer.position.set(x, y);
    eyeContainer.label = 'eye';
    
    // Closed eye (wink) - just a curved line
    const wink = new PIXI.Graphics();
    const w = size * 1.2;
    wink.setStrokeStyle({ width: 3, color: 0x000000, alpha: 0.8 });
    wink.moveTo(-w, 0);
    wink.quadraticCurveTo(0, -size * 0.2, w, 0);
    wink.stroke();
    
    // Optional: Add eyelashes for wink
    const lashes = new PIXI.Graphics();
    lashes.setStrokeStyle({ width: 2, color: 0x000000, alpha: 0.6 });
    for (let i = -3; i <= 3; i++) {
      const lashX = (w * 0.8 * i) / 3;
      lashes.moveTo(lashX, 0);
      lashes.lineTo(lashX - 2, -size * 0.15);
    }
    lashes.stroke();
    wink.addChild(lashes);
    
    eyeContainer.addChild(wink);
    return eyeContainer;
  }
  
  private renderEyebrows(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    let eyebrowY = proportions.centerY - proportions.midFaceHeight * 0.2 - 15;
    const w = proportions.eyeSpacing * 0.45;
    let h = 5;
    
    // Expression-based eyebrow adjustments
    let browYOffset = 0; // Vertical offset
    let outerRaise = 0; // Raise outer corners
    
    switch (config.expression) {
      case 'happy':
      case 'smile':
      case 'excited':
        // Raised outer corners (happy eyebrows)
        outerRaise = -4;
        browYOffset = -2;
        break;
      case 'surprised':
        // Fully raised eyebrows
        browYOffset = -6;
        outerRaise = -6;
        h = 6; // Slightly thicker
        break;
      case 'cool':
        // Slightly lowered, straighter
        browYOffset = 2;
        outerRaise = 1;
        h = 4; // Thinner
        break;
      case 'wink':
        // One eyebrow raised (the winking side)
        outerRaise = -3;
        browYOffset = -1;
        break;
      case 'neutral':
      default:
        // Relaxed, neutral position
        break;
    }
    
    const drawBrow = (x: number, scaleX: number, isWinkSide: boolean = false) => {
        const brow = new PIXI.Graphics();
        const hairColor = parseInt(config.hair.color.replace('#', '0x'));
        
        // Adjust for wink - raise the eyebrow on the winking side
        const currentRaise = (config.expression === 'wink' && isWinkSide) ? outerRaise - 2 : outerRaise;
        
        // Create eyebrow shape with expression adjustments
        brow.moveTo(-w, browYOffset);
        // Outer corner raised for happy expressions
        brow.quadraticCurveTo(0, -h + browYOffset + currentRaise, w, browYOffset + currentRaise);
        // Inner part
        brow.quadraticCurveTo(0, h + browYOffset, -w, browYOffset);
        brow.fill(hairColor);
        
        brow.position.set(x, eyebrowY);
        brow.scale.x = scaleX;
        return brow;
    };

    // Handle wink - raise eyebrow on winking side
    if (config.expression === 'wink') {
      this.container.addChild(drawBrow(proportions.centerX - proportions.eyeSpacing / 2, 1, false));
      this.container.addChild(drawBrow(proportions.centerX + proportions.eyeSpacing / 2, -1, true));
    } else {
      this.container.addChild(drawBrow(proportions.centerX - proportions.eyeSpacing / 2, 1));
      this.container.addChild(drawBrow(proportions.centerX + proportions.eyeSpacing / 2, -1));
    }
  }
  
  private renderNose(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const nose = new PIXI.Graphics();
    const noseBaseY = proportions.centerY + 20;
    
    // Render different nose styles based on config
    switch (config.nose.style) {
      case 'button':
        // Button nose - small, rounded
        nose.moveTo(proportions.centerX - 3, proportions.centerY - 2);
        nose.quadraticCurveTo(proportions.centerX - 4, noseBaseY, proportions.centerX - 6, noseBaseY + 3);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        const nostrilButton = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 5, noseBaseY + 5, 2.5, 2).fill(nostrilButton);
        nose.ellipse(proportions.centerX + 5, noseBaseY + 5, 2.5, 2).fill(nostrilButton);
        
        // Rounded tip
        nose.circle(proportions.centerX, noseBaseY + 3, 6).fill({ color: 0x000000, alpha: 0.04 });
        break;
        
      case 'straight':
        // Straight nose - classic, straight bridge
        nose.moveTo(proportions.centerX - 3, proportions.centerY - 5);
        nose.lineTo(proportions.centerX - 5, noseBaseY);
        nose.lineTo(proportions.centerX - 8, noseBaseY + 4);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.1 });
        
        const nostrilStraight = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 6, noseBaseY + 6, 3, 2).fill(nostrilStraight);
        nose.ellipse(proportions.centerX + 6, noseBaseY + 6, 3, 2).fill(nostrilStraight);
        
        nose.circle(proportions.centerX, noseBaseY + 4, 7).fill({ color: 0x000000, alpha: 0.04 });
        break;
        
      case 'wide':
        // Wide nose - broader nostrils
        nose.moveTo(proportions.centerX - 4, proportions.centerY - 5);
        nose.quadraticCurveTo(proportions.centerX - 7, noseBaseY, proportions.centerX - 12, noseBaseY + 4);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        const nostrilWide = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 8, noseBaseY + 6, 4, 2.5).fill(nostrilWide);
        nose.ellipse(proportions.centerX + 8, noseBaseY + 6, 4, 2.5).fill(nostrilWide);
        
        nose.circle(proportions.centerX, noseBaseY + 4, 9).fill({ color: 0x000000, alpha: 0.04 });
        break;
        
      case 'narrow':
        // Narrow nose - thin bridge, close nostrils
        nose.moveTo(proportions.centerX - 2, proportions.centerY - 5);
        nose.quadraticCurveTo(proportions.centerX - 3, noseBaseY, proportions.centerX - 5, noseBaseY + 4);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        const nostrilNarrow = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 4, noseBaseY + 6, 2, 1.5).fill(nostrilNarrow);
        nose.ellipse(proportions.centerX + 4, noseBaseY + 6, 2, 1.5).fill(nostrilNarrow);
        
        nose.circle(proportions.centerX, noseBaseY + 4, 5).fill({ color: 0x000000, alpha: 0.04 });
        break;
        
      case 'upturned':
        // Upturned nose - tip curves up slightly
        nose.moveTo(proportions.centerX - 4, proportions.centerY - 5);
        nose.quadraticCurveTo(proportions.centerX - 6, noseBaseY, proportions.centerX - 8, noseBaseY + 2);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        // Upturned tip
        nose.moveTo(proportions.centerX - 6, noseBaseY + 2);
        nose.quadraticCurveTo(proportions.centerX - 2, noseBaseY - 1, proportions.centerX + 2, noseBaseY - 1);
        nose.quadraticCurveTo(proportions.centerX + 6, noseBaseY + 2, proportions.centerX + 8, noseBaseY + 2);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        const nostrilUpturned = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 6, noseBaseY + 4, 3, 2).fill(nostrilUpturned);
        nose.ellipse(proportions.centerX + 6, noseBaseY + 4, 3, 2).fill(nostrilUpturned);
        
        nose.circle(proportions.centerX, noseBaseY + 1, 6).fill({ color: 0x000000, alpha: 0.04 });
        break;
        
      default:
        // Default - smaller, child-like nose
        nose.moveTo(proportions.centerX - 4, proportions.centerY - 5);
        nose.quadraticCurveTo(proportions.centerX - 6, noseBaseY, proportions.centerX - 10, noseBaseY + 4);
        nose.stroke({ width: 1, color: 0x000000, alpha: 0.08 });
        
        const nostrilDefault = { color: 0x000000, alpha: 0.15 };
        nose.ellipse(proportions.centerX - 6, noseBaseY + 6, 3, 2).fill(nostrilDefault);
        nose.ellipse(proportions.centerX + 6, noseBaseY + 6, 3, 2).fill(nostrilDefault);
        
        nose.circle(proportions.centerX, noseBaseY + 4, 7).fill({ color: 0x000000, alpha: 0.04 });
        break;
    }

    this.container.addChild(nose);
  }
  
  private renderMouth(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const mouth = new PIXI.Graphics();
    // Move mouth significantly lower (0.7 instead of 0.5)
    // For laughing, position slightly higher for better visual balance
    const mouthY = config.mouth.style === 'laughing' 
      ? proportions.centerY + proportions.lowerFaceHeight * 0.65
      : proportions.centerY + proportions.lowerFaceHeight * 0.7;
    const mouthColor = parseInt(config.mouth.color.replace('#', '0x'));
    const w = proportions.mouthWidth / 2;
    
    // Special handling for laughing - wide open smile with visible teeth (like reference image)
    if (config.mouth.style === 'laughing') {
      const mouthWidth = w * 1.6; // Very wide mouth
      const mouthHeight = 22; // Height of opening
      
      // --- Mouth Opening (elliptical shape) ---
      const opening = new PIXI.Graphics();
      // Draw the mouth opening as an ellipse
      opening.ellipse(0, 0, mouthWidth, mouthHeight).fill({ color: 0x8B0000, alpha: 0.7 }); // Dark interior
      opening.ellipse(0, 0, mouthWidth, mouthHeight).stroke({ width: 3, color: mouthColor }); // Lip outline
      mouth.addChild(opening);
      
      // --- Upper Teeth (visible at top of opening) ---
      const teeth = new PIXI.Graphics();
      // Upper teeth - white ellipse at top
      teeth.ellipse(0, -mouthHeight * 0.15, mouthWidth * 0.9, mouthHeight * 0.4).fill(0xFFFFFF);
      // Tooth separation lines
      const toothLines = new PIXI.Graphics();
      toothLines.setStrokeStyle({ width: 1, color: 0x000000, alpha: 0.2 });
      for (let i = -4; i <= 4; i++) {
        const x = (mouthWidth * 0.75 * i) / 4;
        toothLines.moveTo(x, -mouthHeight * 0.35);
        toothLines.lineTo(x, -mouthHeight * 0.05);
      }
      toothLines.stroke();
      teeth.addChild(toothLines);
      mouth.addChild(teeth);
      
      // --- Upper Lip (wraps over teeth) ---
      const upperLip = new PIXI.Graphics();
      upperLip.moveTo(-mouthWidth, -mouthHeight * 0.2);
      upperLip.bezierCurveTo(-mouthWidth * 0.4, -mouthHeight * 0.5, mouthWidth * 0.4, -mouthHeight * 0.5, mouthWidth, -mouthHeight * 0.2);
      upperLip.bezierCurveTo(mouthWidth * 0.7, -mouthHeight * 0.1, -mouthWidth * 0.7, -mouthHeight * 0.1, -mouthWidth, -mouthHeight * 0.2);
      upperLip.fill(mouthColor);
      mouth.addChild(upperLip);
      
      // --- Lower Lip ---
      const lowerLip = new PIXI.Graphics();
      lowerLip.moveTo(-mouthWidth, mouthHeight * 0.3);
      lowerLip.bezierCurveTo(-mouthWidth * 0.4, mouthHeight * 0.6, mouthWidth * 0.4, mouthHeight * 0.6, mouthWidth, mouthHeight * 0.3);
      lowerLip.bezierCurveTo(mouthWidth * 0.7, mouthHeight * 0.1, -mouthWidth * 0.7, mouthHeight * 0.1, -mouthWidth, mouthHeight * 0.3);
      lowerLip.fill(mouthColor);
      mouth.addChild(lowerLip);
      
      // --- Expression Creases (stronger for laughing) ---
      const creases = new PIXI.Graphics();
      creases.setStrokeStyle({ width: 2, color: 0x000000, alpha: 0.2 });
      // Left crease
      creases.moveTo(-mouthWidth, -mouthHeight * 0.1);
      creases.quadraticCurveTo(-mouthWidth - 12, -mouthHeight * 0.7, -mouthWidth - 18, -mouthHeight * 0.5);
      // Right crease
      creases.moveTo(mouthWidth, -mouthHeight * 0.1);
      creases.quadraticCurveTo(mouthWidth + 12, -mouthHeight * 0.7, mouthWidth + 18, -mouthHeight * 0.5);
      creases.stroke();
      mouth.addChild(creases);
      
      mouth.position.set(proportions.centerX, mouthY);
      mouth.label = 'mouth';
      this.container.addChild(mouth);
      return; // Early return for laughing style
    }
    
    // Adjust mouth width and curves based on style, but also consider expression
    let upperCurve = -6; // Default Cupid's bow depth
    let lowerCurve = 14; // Default lower lip depth
    let mouthWidth = w; // Default width
    let cornerOffset = 0; // For smile/pout adjustments
    
    // Expression can influence mouth shape even if style is different
    const effectiveStyle = config.expression === 'surprised' ? 'surprised' : 
                          config.expression === 'happy' || config.expression === 'smile' ? 'smile' :
                          config.expression === 'excited' ? 'excited' :
                          config.expression === 'blushing' ? 'smile' : // Blushing uses a shy smile
                          config.mouth.style;
    
    switch (effectiveStyle) {
      case 'big_smile':
        upperCurve = -8; // Deeper Cupid's bow
        lowerCurve = 16; // Fuller lower lip
        cornerOffset = 3; // Corners curve up
        break;
      case 'smile':
        upperCurve = -6;
        lowerCurve = 14;
        cornerOffset = 2; // Slight upward curve
        break;
      case 'excited':
        upperCurve = -9; // Deep Cupid's bow
        lowerCurve = 18; // Full lower lip
        cornerOffset = 4; // Upward curve
        mouthWidth = w * 1.05; // Slightly wider
        break;
      case 'pout':
        upperCurve = -4; // Less pronounced Cupid's bow
        lowerCurve = 12; // Less full lower lip
        cornerOffset = -2; // Corners curve down slightly
        break;
      case 'surprised':
        upperCurve = -5;
        lowerCurve = 18; // More open/round
        mouthWidth = w * 0.8; // Narrower
        break;
      case 'neutral':
      default:
        upperCurve = -5;
        lowerCurve = 12;
        break;
    }
    
    // --- Upper Lip ---
    const upperLip = new PIXI.Graphics();
    upperLip.moveTo(-mouthWidth, 0); // Start left corner
    // Top curve (Cupid's bow) - adjusted by style
    upperLip.bezierCurveTo(-mouthWidth / 2, upperCurve, mouthWidth / 2, upperCurve, mouthWidth, 0); 
    // Bottom curve of upper lip (slightly curved down)
    upperLip.bezierCurveTo(mouthWidth / 2, 2, -mouthWidth / 2, 2, -mouthWidth, 0); 
    upperLip.fill(mouthColor);
    
    // Upper lip outline
    const upperOutline = new PIXI.Graphics();
    upperOutline.moveTo(-mouthWidth, 0);
    upperOutline.bezierCurveTo(-mouthWidth / 2, upperCurve, mouthWidth / 2, upperCurve, mouthWidth, 0);
    upperOutline.stroke({ width: 1, color: 0x000000, alpha: 0.1 });
    upperLip.addChild(upperOutline);
    
    mouth.addChild(upperLip);
    
    // --- Lower Lip ---
    const lowerLip = new PIXI.Graphics();
    lowerLip.moveTo(-mouthWidth, 0); // Start left corner (same as upper)
    // Top curve of lower lip (matches upper lip bottom)
    lowerLip.bezierCurveTo(-mouthWidth / 2, 2, mouthWidth / 2, 2, mouthWidth, 0);
    // Bottom curve of lower lip - adjusted by style
    if (config.mouth.style === 'surprised') {
      // More circular/round for surprised
      lowerLip.quadraticCurveTo(0, lowerCurve, -mouthWidth, 0);
    } else {
      // Standard curve with corner adjustments
      lowerLip.bezierCurveTo(
        mouthWidth / 2 + cornerOffset, lowerCurve,
        -mouthWidth / 2 - cornerOffset, lowerCurve,
        -mouthWidth, 0
      );
    }
    lowerLip.fill(mouthColor);
    
    // Lower lip shadow/definition
    const lipShadow = new PIXI.Graphics();
    lipShadow.moveTo(-mouthWidth * 0.6, 8);
    lipShadow.quadraticCurveTo(0, lowerCurve, mouthWidth * 0.6, 8);
    lipShadow.stroke({ width: 1, color: 0x000000, alpha: 0.1 });
    lowerLip.addChild(lipShadow);
    
    // Lip gloss/highlight
    const gloss = new PIXI.Graphics();
    gloss.ellipse(0, 6, 6, 3).fill({ color: 0xFFFFFF, alpha: 0.3 });
    lowerLip.addChild(gloss);
    
    mouth.addChild(lowerLip);
    
    // --- Lip Line (Middle) ---
    // Darker line where lips meet to define separation
    const lipLine = new PIXI.Graphics();
    lipLine.moveTo(-mouthWidth, 0);
    lipLine.bezierCurveTo(-mouthWidth / 2, 2, mouthWidth / 2, 2, mouthWidth, 0);
    lipLine.stroke({ width: 1.5, color: 0x000000, alpha: 0.2 });
    mouth.addChild(lipLine);
    
    // Smile/Expression adjustment - add creases for smile styles (but not laughing, already handled)
    if (effectiveStyle === 'smile' || effectiveStyle === 'big_smile' || effectiveStyle === 'excited' || 
        config.expression === 'happy' || config.expression === 'smile' || config.expression === 'excited') {
        const creases = new PIXI.Graphics();
        const creaseIntensity = effectiveStyle === 'excited' ? 0.12 : 0.1;
        creases.setStrokeStyle({ width: 1, color: 0x000000, alpha: creaseIntensity });
        // Left crease
        creases.moveTo(-mouthWidth, 0);
        creases.quadraticCurveTo(-mouthWidth - 3 - (cornerOffset * 0.5), -2 - (cornerOffset * 0.3), -mouthWidth - 6 - cornerOffset, -1);
        // Right crease
        creases.moveTo(mouthWidth, 0);
        creases.quadraticCurveTo(mouthWidth + 3 + (cornerOffset * 0.5), -2 - (cornerOffset * 0.3), mouthWidth + 6 + cornerOffset, -1);
        creases.stroke();
        mouth.addChild(creases);
    }
    
    // Override mouth style based on expression if needed
    // Expression takes priority over mouth style for certain expressions
    if (config.expression === 'surprised' && config.mouth.style !== 'surprised') {
      // Force surprised mouth for surprised expression
      const surprisedMouth = new PIXI.Graphics();
      const surprisedWidth = w * 0.7;
      surprisedMouth.ellipse(0, 0, surprisedWidth, 12).fill({ color: 0x8B0000, alpha: 0.6 });
      surprisedMouth.ellipse(0, 0, surprisedWidth, 12).stroke({ width: 2, color: mouthColor });
      surprisedMouth.position.set(proportions.centerX, mouthY);
      surprisedMouth.label = 'mouth';
      this.container.addChild(surprisedMouth);
      return;
    }
    
    mouth.position.set(proportions.centerX, mouthY);
    mouth.label = 'mouth';
    this.container.addChild(mouth);
  }
  
  private renderExpressionEffects(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    // Add expression-specific visual effects
    switch (config.expression) {
      case 'excited':
        // Add sparkle/shine effect for excited
        const sparkles = new PIXI.Graphics();
        // Small sparkles around eyes
        sparkles.circle(proportions.centerX - proportions.eyeSpacing - 15, proportions.centerY - proportions.midFaceHeight * 0.15 - 10, 3).fill({ color: 0xFFFF00, alpha: 0.6 });
        sparkles.circle(proportions.centerX + proportions.eyeSpacing + 15, proportions.centerY - proportions.midFaceHeight * 0.15 - 10, 3).fill({ color: 0xFFFF00, alpha: 0.6 });
        sparkles.circle(proportions.centerX - proportions.eyeSpacing - 5, proportions.centerY - proportions.midFaceHeight * 0.15 + 15, 2).fill({ color: 0xFFFF00, alpha: 0.5 });
        sparkles.circle(proportions.centerX + proportions.eyeSpacing + 5, proportions.centerY - proportions.midFaceHeight * 0.15 + 15, 2).fill({ color: 0xFFFF00, alpha: 0.5 });
        this.container.addChild(sparkles);
        break;
      case 'surprised':
        // Add subtle highlight/shock lines for surprised
        const shockLines = new PIXI.Graphics();
        shockLines.setStrokeStyle({ width: 2, color: 0x000000, alpha: 0.15 });
        // Small lines radiating from head
        shockLines.moveTo(proportions.centerX - proportions.headWidth / 2 - 10, proportions.centerY - proportions.headHeight / 2 - 5);
        shockLines.lineTo(proportions.centerX - proportions.headWidth / 2 - 20, proportions.centerY - proportions.headHeight / 2 - 10);
        shockLines.moveTo(proportions.centerX + proportions.headWidth / 2 + 10, proportions.centerY - proportions.headHeight / 2 - 5);
        shockLines.lineTo(proportions.centerX + proportions.headWidth / 2 + 20, proportions.centerY - proportions.headHeight / 2 - 10);
        shockLines.stroke();
        this.container.addChild(shockLines);
        break;
    }
  }
  
  private renderHairFront(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    const hair = new PIXI.Graphics();
    const color = parseInt(config.hair.color.replace('#', '0x'));
    // Move hairline down slightly so it sits on forehead
    const y = proportions.centerY - proportions.headHeight / 2 + 35;
    
    if (config.hair.style.includes('bangs')) {
      hair.moveTo(proportions.centerX - proportions.headWidth / 2, y + 20);
      hair.quadraticCurveTo(proportions.centerX, y + 40, proportions.centerX + proportions.headWidth / 2, y + 20);
      hair.lineTo(proportions.centerX + proportions.headWidth / 2, y - 30);
      hair.lineTo(proportions.centerX - proportions.headWidth / 2, y - 30);
      hair.fill(color);
      
      // Removed hair shade ellipse for cleaner look
    } else if (config.hair.style.includes('curtain')) {
        // Left curtain
        hair.moveTo(proportions.centerX, y - 20);
        hair.quadraticCurveTo(proportions.centerX - 40, y + 40, proportions.centerX - proportions.headWidth / 2 - 10, y + 60);
        hair.lineTo(proportions.centerX, y - 20);
        
        // Right curtain
        hair.moveTo(proportions.centerX, y - 20);
        hair.quadraticCurveTo(proportions.centerX + 40, y + 40, proportions.centerX + proportions.headWidth / 2 + 10, y + 60);
        hair.lineTo(proportions.centerX, y - 20);
        
        hair.fill(color);
    } else {
        // Default hairline - more voluminous like reference
        hair.arc(proportions.centerX, y, proportions.headWidth / 2, Math.PI, 2 * Math.PI);
        hair.fill(color);
        
        // Removed hair volume and highlight ellipses for cleaner look
    }
    
    this.container.addChild(hair);
  }
  
  private renderAccessories(config: AvatarConfig, proportions: any) {
    if (!this.container) return;
    
    config.accessories.forEach(accessory => {
      const acc = new PIXI.Graphics();
      const accColor = parseInt(accessory.color.replace('#', '0x'));
      
      switch (accessory.type) {
        case 'glasses':
            const w = proportions.eyeSpacing * 0.95;
            const h = 28;
            const bridge = 12;
            const glassesY = proportions.centerY - proportions.midFaceHeight * 0.2;
            
            // Frame color - darker for more defined look
            const frameColor = accColor || 0x555555;
            
            // Left lens frame (thicker, more defined)
            acc.roundRect(proportions.centerX - bridge/2 - w, glassesY - h/2, w, h, 6)
              .stroke({ width: 3, color: frameColor });
            acc.roundRect(proportions.centerX - bridge/2 - w, glassesY - h/2, w, h, 6)
              .fill({ color: 0xFFFFFF, alpha: 0.15 });
            
            // Right lens frame
            acc.roundRect(proportions.centerX + bridge/2, glassesY - h/2, w, h, 6)
              .stroke({ width: 3, color: frameColor });
            acc.roundRect(proportions.centerX + bridge/2, glassesY - h/2, w, h, 6)
              .fill({ color: 0xFFFFFF, alpha: 0.15 });
            
            // Bridge (more defined)
            acc.moveTo(proportions.centerX - bridge/2, glassesY - 3);
            acc.lineTo(proportions.centerX + bridge/2, glassesY - 3);
            acc.stroke({ width: 3, color: frameColor });
            
            // Temple pieces (sides)
            acc.moveTo(proportions.centerX - bridge/2 - w, glassesY);
            acc.lineTo(proportions.centerX - bridge/2 - w - 15, glassesY + 5);
            acc.stroke({ width: 2, color: frameColor });
            
            acc.moveTo(proportions.centerX + bridge/2 + w, glassesY);
            acc.lineTo(proportions.centerX + bridge/2 + w + 15, glassesY + 5);
            acc.stroke({ width: 2, color: frameColor });
          break;
            
        case 'hat':
          // Hat brim
          acc.ellipse(
            proportions.centerX,
            proportions.centerY - proportions.headHeight / 2 - 10,
            proportions.headWidth / 2 + 25,
            35
          ).fill(accColor);
          
          // Hat crown
          acc.roundRect(
            proportions.centerX - proportions.headWidth / 2 - 5, 
            proportions.centerY - proportions.headHeight / 2 - 50, 
            proportions.headWidth + 10, 
            40,
            8
          ).fill(accColor);
          
          // Hat band (optional decorative)
          acc.roundRect(
            proportions.centerX - proportions.headWidth / 2 - 5,
            proportions.centerY - proportions.headHeight / 2 - 35,
            proportions.headWidth + 10,
            5,
            2
          ).fill({ color: 0x000000, alpha: 0.3 });
          break;
          
        case 'headband':
          // Headband wraps around head
          const headbandY = proportions.centerY - proportions.headHeight / 2 + 15;
          const headbandWidth = proportions.headWidth / 2 + 15;
          
          // Main band
          acc.roundRect(
            proportions.centerX - headbandWidth,
            headbandY - 8,
            headbandWidth * 2,
            16,
            8
          ).fill(accColor);
          
          // Bow/knot in center (optional)
          const bow = new PIXI.Graphics();
          bow.ellipse(0, 0, 12, 8).fill(accColor);
          bow.ellipse(0, 0, 8, 12).fill(accColor);
          bow.position.set(proportions.centerX, headbandY);
          acc.addChild(bow);
          break;
          
        case 'bow':
          // Hair bow - positioned on side of head
          const bowY = proportions.centerY - proportions.headHeight / 2 + 20;
          const bowX = proportions.centerX + proportions.headWidth / 2 - 10;
          
          // Left loop
          acc.ellipse(bowX - 8, bowY, 12, 18).fill(accColor);
          // Right loop
          acc.ellipse(bowX + 8, bowY, 12, 18).fill(accColor);
          // Center knot
          acc.roundRect(bowX - 4, bowY - 5, 8, 10, 4).fill({ color: 0x000000, alpha: 0.3 });
          acc.roundRect(bowX - 4, bowY - 5, 8, 10, 4).fill(accColor);
          
          // Ribbon tails
          acc.roundRect(bowX - 3, bowY + 12, 6, 25, 3).fill(accColor);
          acc.roundRect(bowX - 3, bowY + 12, 6, 25, 3).fill(accColor);
          break;
          
        case 'locket':
          // Locket necklace - positioned on chest
          const locketY = proportions.centerY + proportions.headHeight / 2 + proportions.neckHeight + 20;
          
          // Chain
          acc.setStrokeStyle({ width: 2, color: accColor });
          acc.moveTo(proportions.centerX - 15, proportions.centerY + proportions.headHeight / 2 + proportions.neckHeight);
          acc.lineTo(proportions.centerX - 10, locketY);
          acc.moveTo(proportions.centerX + 15, proportions.centerY + proportions.headHeight / 2 + proportions.neckHeight);
          acc.lineTo(proportions.centerX + 10, locketY);
          acc.stroke();
          
          // Locket pendant (oval shape)
          acc.ellipse(proportions.centerX, locketY, 12, 16).fill(accColor);
          acc.ellipse(proportions.centerX, locketY, 12, 16).stroke({ width: 2, color: 0x000000, alpha: 0.3 });
          
          // Locket detail (heart or circle inside)
          acc.circle(proportions.centerX, locketY, 6).fill({ color: 0x000000, alpha: 0.2 });
          break;
      }
      
      this.container?.addChild(acc);
    });
  }
  
  animateRandomize() {
    this.animator?.animateRandomize();
  }
  
  getApp(): PIXI.Application | null {
    return this.app;
  }
  
  destroy() {
    // Stop all animations first
    if (this.animator) {
      this.animator.stop();
      this.animator = null;
    }
    
    // Clear container
    if (this.container) {
      this.container.removeChildren();
      this.container = null;
    }
    
    // Destroy PIXI app
    if (this.app) {
      try {
        this.app.destroy(true);
      } catch (error) {
        console.error('Error destroying PIXI app:', error);
      }
      this.app = null;
    }
  }
}

class AvatarAnimator {
  private container: PIXI.Container;
  private idleTimeline: gsap.core.Tween | null = null;
  private blinkInterval: number | null = null;
  
  constructor(container: PIXI.Container) {
    this.container = container;
  }
  
  startIdle() {
    this.stop();
    
    // Breathing animation - more subtle
    this.idleTimeline = gsap.to(this.container.scale, {
      x: 1.005,
      y: 1.005,
      duration: 3,
      yoyo: true,
      repeat: -1,
      ease: "sine.inOut"
    });
    
    // Blinking - store interval ID for cleanup
    this.blinkInterval = window.setInterval(() => {
      const eyes = this.container.children.filter(child => child.label === 'eye');
      eyes.forEach(eye => {
        gsap.to(eye.scale, {
          y: 0.1,
          duration: 0.15,
          yoyo: true,
          repeat: 1
        });
      });
    }, 4000);
  }
  
  animateRandomize() {
    gsap.to(this.container, {
      alpha: 0,
      duration: 0.2,
      yoyo: true,
      repeat: 1,
      onRepeat: () => {
         this.container.alpha = 1;
      }
    });
  }
  
  stop() {
    if (this.idleTimeline) {
      this.idleTimeline.kill();
      this.idleTimeline = null;
    }
    if (this.blinkInterval !== null) {
      clearInterval(this.blinkInterval);
      this.blinkInterval = null;
    }
  }
}
