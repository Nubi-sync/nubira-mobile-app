const fs = require('fs');
const path = require('path');
const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

const resDir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res';
const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

async function inspect() {
  for (const d of densities) {
    const dir = path.join(resDir, `mipmap-${d}`);
    const files = fs.readdirSync(dir);
    for (const f of files) {
      if (f.endsWith('.png')) {
        const filePath = path.join(dir, f);
        const meta = await sharp(filePath).metadata();
        console.log(`${d}/${f}: ${meta.width}x${meta.height}, channels: ${meta.channels}, hasAlpha: ${meta.hasAlpha}`);
      }
    }
  }
}

inspect().catch(console.error);
