const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function inspectForeground() {
  const fg = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png';
  const { data, info } = await sharp(fg).raw().toBuffer({ resolveWithObject: true });
  
  // Find non-transparent pixels
  let minX = info.width, maxX = 0, minY = info.height, maxY = 0;
  let colors = {};
  
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      const idx = (y * info.width + x) * 4;
      const a = data[idx + 3];
      if (a > 20) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        
        const r = data[idx];
        const g = data[idx + 1];
        const b = data[idx + 2];
        const hex = `${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}`;
        colors[hex] = (colors[hex] || 0) + 1;
      }
    }
  }
  
  console.log(`Bounds: x=[${minX}, ${maxX}], y=[${minY}, ${maxY}] (width=${maxX-minX+1}, height=${maxY-minY+1})`);
  const sortedColors = Object.entries(colors).sort((a,b) => b[1] - a[1]).slice(0, 10);
  console.log('Top colors:', sortedColors);
}

inspectForeground().catch(console.error);
