const fs = require('fs');
const path = require('path');
const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

const dir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images';

async function checkAll() {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.png'));
  for (const f of files) {
    const meta = await sharp(path.join(dir, f)).metadata();
    console.log(`${f}: ${meta.width}x${meta.height}, alpha: ${meta.hasAlpha}`);
  }
}

checkAll().catch(console.error);

