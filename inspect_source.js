const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function inspectZigzaIcon() {
  const icon = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon.png';
  const meta = await sharp(icon).metadata();
  console.log('zigza_icon.png:', meta);
  
  const trimmed = await sharp(icon).trim().toBuffer({ resolveWithObject: true });
  console.log('Trimmed size:', trimmed.info.width, 'x', trimmed.info.height);
}

inspectZigzaIcon().catch(console.error);

