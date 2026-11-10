const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function inspectContent() {
  const fg = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png';
  const legacy = 'c:/Users/shaws/NubiSync/nubira-mobile-app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png';
  
  const fgTrim = await sharp(fg).trim().toBuffer({ resolveWithObject: true });
  console.log('Foreground (432x432) trimmed content size:', fgTrim.info.width, 'x', fgTrim.info.height);
  
  const legTrim = await sharp(legacy).trim().toBuffer({ resolveWithObject: true });
  console.log('Legacy (192x192) trimmed content size:', legTrim.info.width, 'x', legTrim.info.height);
}

inspectContent().catch(console.error);
