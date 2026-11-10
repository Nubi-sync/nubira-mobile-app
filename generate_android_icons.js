const fs = require('fs');
const path = require('path');
const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

const sourceLogo = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon_transparent.png';
const resDir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res';

// Densities and canvas sizes
// Adaptive foreground: 108dp (safe zone 72dp circle). We use ~56-58% of canvas for the logo mark so the arrow has ample clearance.
// Legacy launcher: 48dp (safe zone ~64-70%).
const configs = {
  mdpi:    { fg: 108, legacy: 48,  scale: 0.58 },
  hdpi:    { fg: 162, legacy: 72,  scale: 0.58 },
  xhdpi:   { fg: 216, legacy: 96,  scale: 0.58 },
  xxhdpi:  { fg: 324, legacy: 144, scale: 0.58 },
  xxxhdpi: { fg: 432, legacy: 192, scale: 0.58 },
};

async function generateAll() {
  const logoMeta = await sharp(sourceLogo).metadata();
  const aspect = logoMeta.width / logoMeta.height; // ~1.025
  
  for (const [density, cfg] of Object.entries(configs)) {
    const dir = path.join(resDir, `mipmap-${density}`);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    
    // 1. Adaptive Icon Foreground (Transparent background, centered logo)
    const fgCanvas = cfg.fg;
    const fgLogoSize = Math.round(fgCanvas * cfg.scale);
    let fgLogoW, fgLogoH;
    if (aspect >= 1) {
      fgLogoW = fgLogoSize;
      fgLogoH = Math.round(fgLogoSize / aspect);
    } else {
      fgLogoH = fgLogoSize;
      fgLogoW = Math.round(fgLogoSize * aspect);
    }
    
    const resizedLogoFg = await sharp(sourceLogo)
      .resize(fgLogoW, fgLogoH, { fit: 'contain' })
      .toBuffer();
      
    const fgPath = path.join(dir, 'ic_launcher_foreground.png');
    await sharp({
      create: {
        width: fgCanvas,
        height: fgCanvas,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 } // 100% transparent
      }
    })
    .composite([{ input: resizedLogoFg, gravity: 'center' }])
    .png()
    .toFile(fgPath);
    console.log(`Generated ${density}/ic_launcher_foreground.png (${fgCanvas}x${fgCanvas}, logo ${fgLogoW}x${fgLogoH})`);
    
    // 2. Legacy Square Icon (White background, centered logo with safe padding)
    const legCanvas = cfg.legacy;
    const legLogoSize = Math.round(legCanvas * 0.68);
    let legLogoW, legLogoH;
    if (aspect >= 1) {
      legLogoW = legLogoSize;
      legLogoH = Math.round(legLogoSize / aspect);
    } else {
      legLogoH = legLogoSize;
      legLogoW = Math.round(legLogoSize * aspect);
    }
    
    const resizedLogoLeg = await sharp(sourceLogo)
      .resize(legLogoW, legLogoH, { fit: 'contain' })
      .toBuffer();
      
    // White background for legacy
    const legPath = path.join(dir, 'ic_launcher.png');
    await sharp({
      create: {
        width: legCanvas,
        height: legCanvas,
        channels: 4,
        background: { r: 255, g: 255, b: 255, alpha: 1 }
      }
    })
    .composite([{ input: resizedLogoLeg, gravity: 'center' }])
    .png()
    .toFile(legPath);
    console.log(`Generated ${density}/ic_launcher.png (${legCanvas}x${legCanvas})`);
    
    // 3. Legacy Round Icon (Pure white anti-aliased circle on transparent canvas)
    const roundPath = path.join(dir, 'ic_launcher_round.png');
    const circleSvg = Buffer.from(
      `<svg width="${legCanvas}" height="${legCanvas}" xmlns="http://www.w3.org/2000/svg">
        <circle cx="${legCanvas/2}" cy="${legCanvas/2}" r="${(legCanvas/2) - 0.5}" fill="#FFFFFF" />
      </svg>`
    );
    
    const circleBg = await sharp(circleSvg).png().toBuffer();
    
    // For the round icon, scale logo to ~58% so it stays completely inside the circle
    const roundLogoSize = Math.round(legCanvas * 0.58);
    let roundLogoW, roundLogoH;
    if (aspect >= 1) {
      roundLogoW = roundLogoSize;
      roundLogoH = Math.round(roundLogoSize / aspect);
    } else {
      roundLogoH = roundLogoSize;
      roundLogoW = Math.round(roundLogoSize * aspect);
    }
    
    const resizedLogoRound = await sharp(sourceLogo)
      .resize(roundLogoW, roundLogoH, { fit: 'contain' })
      .toBuffer();
      
    await sharp(circleBg)
      .composite([{ input: resizedLogoRound, gravity: 'center' }])
      .png()
      .toFile(roundPath);
    console.log(`Generated ${density}/ic_launcher_round.png (${legCanvas}x${legCanvas})`);
  }
}

generateAll().catch(console.error);
