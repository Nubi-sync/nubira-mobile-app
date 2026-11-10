const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function checkZigzaIcon() {
  const icon = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon.png';
  const trimmed = await sharp(icon).trim().toBuffer({ resolveWithObject: true });
  console.log('Trimmed dimensions:', trimmed.info.width, 'x', trimmed.info.height);
  
  // Check the corners of the trimmed image to ensure it's transparent
  const { data, info } = await sharp(trimmed.data).raw().toBuffer({ resolveWithObject: true });
  console.log('Top-left pixel alpha:', data[3]);
  console.log('Top-right pixel alpha:', data[info.width * 4 - 1]);
}

checkZigzaIcon().catch(console.error);
