const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function inspectRound() {
  const round = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png';
  const meta = await sharp(round).metadata();
  console.log('ic_launcher_round:', meta);
  
  // Sample pixels around the perimeter
  const { data, info } = await sharp(round).raw().toBuffer({ resolveWithObject: true });
  console.log('Sample raw info:', info);
  
  // Check center pixel and edge pixels
  const w = info.width;
  const h = info.height;
  // Edge at (w/2, 10):
  const idx = (10 * w + Math.floor(w/2)) * 4;
  console.log('Pixel at top edge (x=mid, y=10):', data[idx], data[idx+1], data[idx+2], data[idx+3]);
  // Pixel at (10, h/2):
  const idx2 = (Math.floor(h/2) * w + 10) * 4;
  console.log('Pixel at left edge (x=10, y=mid):', data[idx2], data[idx2+1], data[idx2+2], data[idx2+3]);
  
  // Pixel at (w/2, 30):
  const idx3 = (30 * w + Math.floor(w/2)) * 4;
  console.log('Pixel near top (x=mid, y=30):', data[idx3], data[idx3+1], data[idx3+2], data[idx3+3]);
}

inspectRound().catch(console.error);
