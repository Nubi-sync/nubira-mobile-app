const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function findScreen() {
  const file = 'C:/Users/shaws/.gemini/antigravity/brain/5210eac2-6858-4ccc-b2cf-4cdd037e1c59/.user_uploaded/media_1794320600503_ee5e92c8.jpg';
  const { data, info } = await sharp(file).raw().toBuffer({ resolveWithObject: true });
  const w = info.width, h = info.height;
  
  // Find white screen bounds
  // We can sample mid y (h/2) and find left and right white bounds
  const midY = Math.floor(h / 2);
  let leftScreenX = 0, rightScreenX = w - 1;
  for (let x = 0; x < w; x++) {
    const idx = (midY * w + x) * info.channels;
    if (data[idx] > 250 && data[idx+1] > 250 && data[idx+2] > 250) {
      leftScreenX = x;
      break;
    }
  }
  for (let x = w - 1; x >= 0; x--) {
    const idx = (midY * w + x) * info.channels;
    if (data[idx] > 250 && data[idx+1] > 250 && data[idx+2] > 250) {
      rightScreenX = x;
      break;
    }
  }
  
  const midX = Math.floor(w / 2);
  let topScreenY = 0, bottomScreenY = h - 1;
  for (let y = 0; y < h; y++) {
    const idx = (y * w + midX) * info.channels;
    // status bar or camera notch might be dark, but below camera notch (y ~ 100) it should be white
    if (y > 70 && data[idx] > 250 && data[idx+1] > 250 && data[idx+2] > 250) {
      topScreenY = y;
      break;
    }
  }
  for (let y = h - 1; y >= 0; y--) {
    const idx = (y * w + midX) * info.channels;
    if (y < h - 40 && data[idx] > 250 && data[idx+1] > 250 && data[idx+2] > 250) {
      bottomScreenY = y;
      break;
    }
  }
  
  console.log('Screen bounds: x from', leftScreenX, 'to', rightScreenX, '(width =', rightScreenX - leftScreenX, ')');
  console.log('Screen bounds: y from', topScreenY, 'to', bottomScreenY, '(height =', bottomScreenY - topScreenY, ')');
  console.log('Screen center X:', (leftScreenX + rightScreenX) / 2);
  console.log('Screen center Y:', (topScreenY + bottomScreenY) / 2);
  
  // Now let's crop just the screen
  const screenW = rightScreenX - leftScreenX;
  const screenH = bottomScreenY - topScreenY;
  
  const screenData = await sharp(file)
    .extract({ left: leftScreenX, top: topScreenY, width: screenW, height: screenH })
    .raw()
    .toBuffer({ resolveWithObject: true });
    
  return { screenW, screenH, leftScreenX, topScreenY };
}

findScreen().catch(console.error);
