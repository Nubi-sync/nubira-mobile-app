const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function checkColors() {
  const icon = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon.png';
  const { data, info } = await sharp(icon).raw().toBuffer({ resolveWithObject: true });
  console.log('Top-left (0,0):', data[0], data[1], data[2], data[3]);
  console.log('Center (900,900):', data[(900 * info.width + 900)*4], data[(900 * info.width + 900)*4 + 1], data[(900 * info.width + 900)*4 + 2]);
}

checkColors().catch(console.error);
