const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function analyzeCritique() {
  const file = 'C:/Users/shaws/.gemini/antigravity/brain/5210eac2-6858-4ccc-b2cf-4cdd037e1c59/.user_uploaded/media_1794320600503_ee5e92c8.jpg';
  const meta = await sharp(file).metadata();
  console.log('Image dimensions:', meta.width, 'x', meta.height);
  
  const { data, info } = await sharp(file).raw().toBuffer({ resolveWithObject: true });
  const w = info.width;
  const h = info.height;
  
  // Find screen bezel/inner screen boundaries
  // Let's find white screen area
  let screenMinY = 0, screenMaxY = h - 1;
  let screenMinX = 0, screenMaxX = w - 1;
  
  // Find logo mark (around middle Y: 300 to 700, X: 100 to 400)
  // Let's scan bounding boxes of colored clusters
  // 1. Icon mark: navy/cyan/blue
  let iconBounds = { minX: w, maxX: 0, minY: h, maxY: 0 };
  // 2. ZIGZA text: dark navy (around Y: 550 to 650)
  let zigzaBounds = { minX: w, maxX: 0, minY: h, maxY: 0 };
  // 3. Tagline: slate text (around Y: 600 to 750)
  let tagBounds = { minX: w, maxX: 0, minY: h, maxY: 0 };
  // 4. Badge: green border at bottom (around Y: 850 to 1050)
  let badgeBounds = { minX: w, maxX: 0, minY: h, maxY: 0 };
  
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = (y * w + x) * info.channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      
      // Check if not white (r < 240 || g < 240 || b < 240)
      if (r < 240 || g < 240 || b < 240) {
        // Icon mark: y roughly between 350 and 560
        if (y >= 350 && y <= 560 && x > 100 && x < 450) {
          if (x < iconBounds.minX) iconBounds.minX = x;
          if (x > iconBounds.maxX) iconBounds.maxX = x;
          if (y < iconBounds.minY) iconBounds.minY = y;
          if (y > iconBounds.maxY) iconBounds.maxY = y;
        }
        // ZIGZA: y between 560 and 620
        else if (y > 560 && y <= 620 && x > 100 && x < 450) {
          if (x < zigzaBounds.minX) zigzaBounds.minX = x;
          if (x > zigzaBounds.maxX) zigzaBounds.maxX = x;
          if (y < zigzaBounds.minY) zigzaBounds.minY = y;
          if (y > zigzaBounds.maxY) zigzaBounds.maxY = y;
        }
        // Tagline: y between 620 and 700
        else if (y > 620 && y <= 700 && x > 50 && x < 500) {
          if (x < tagBounds.minX) tagBounds.minX = x;
          if (x > tagBounds.maxX) tagBounds.maxX = x;
          if (y < tagBounds.minY) tagBounds.minY = y;
          if (y > tagBounds.maxY) tagBounds.maxY = y;
        }
        // Badge: y between 800 and 1000
        else if (y > 800 && y <= 1000 && x > 50 && x < 500) {
          if (x < badgeBounds.minX) badgeBounds.minX = x;
          if (x > badgeBounds.maxX) badgeBounds.maxX = x;
          if (y < badgeBounds.minY) badgeBounds.minY = y;
          if (y > badgeBounds.maxY) badgeBounds.maxY = y;
        }
      }
    }
  }
  
  console.log('Icon Bounds:', iconBounds, 'Center:', (iconBounds.minX + iconBounds.maxX)/2, (iconBounds.minY + iconBounds.maxY)/2, 'Size:', iconBounds.maxX - iconBounds.minX, 'x', iconBounds.maxY - iconBounds.minY);
  console.log('ZIGZA Bounds:', zigzaBounds, 'Center:', (zigzaBounds.minX + zigzaBounds.maxX)/2, (zigzaBounds.minY + zigzaBounds.maxY)/2, 'Size:', zigzaBounds.maxX - zigzaBounds.minX, 'x', zigzaBounds.maxY - zigzaBounds.minY);
  console.log('Tagline Bounds:', tagBounds, 'Center:', (tagBounds.minX + tagBounds.maxX)/2, (tagBounds.minY + tagBounds.maxY)/2, 'Size:', tagBounds.maxX - tagBounds.minX, 'x', tagBounds.maxY - tagBounds.minY);
  console.log('Badge Bounds:', badgeBounds, 'Center:', (badgeBounds.minX + badgeBounds.maxX)/2, (badgeBounds.minY + badgeBounds.maxY)/2, 'Size:', badgeBounds.maxX - badgeBounds.minX, 'x', badgeBounds.maxY - badgeBounds.minY);
  
  const centerBlockMinY = iconBounds.minY;
  const centerBlockMaxY = tagBounds.maxY;
  console.log('Center Block Total Height:', centerBlockMaxY - centerBlockMinY, 'Center Y:', (centerBlockMinY + centerBlockMaxY)/2);
}

analyzeCritique().catch(console.error);
