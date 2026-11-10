const fs = require('fs');
const path = require('path');
const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

const dir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images';

async function checkTrans() {
  const files = ['zigza_icon.png', 'icon.png', 'new_icon.png', 'app_launcher_logo.png', 'Frame 725.png', 'Frame_725.png'];
  for (const f of files) {
    const filePath = path.join(dir, f);
    if (!fs.existsSync(filePath)) continue;
    const { data, info } = await sharp(filePath).raw().toBuffer({ resolveWithObject: true });
    console.log(`${f} corner (0,0): R=${data[0]} G=${data[1]} B=${data[2]} A=${data[3]}`);
  }
}

checkTrans().catch(console.error);
