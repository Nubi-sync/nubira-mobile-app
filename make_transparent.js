const sharp = require('c:/Users/shaws/NubiSync/nubira-web-admin/node_modules/sharp');

async function testTransparentLogo() {
  const icon = 'c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon.png';
  const { data, info } = await sharp(icon).raw().toBuffer({ resolveWithObject: true });
  
  const out = Buffer.alloc(info.width * info.height * 4);
  
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    
    const brightness = (r + g + b) / 3;
    if (brightness > 250) {
      out[i] = r;
      out[i + 1] = g;
      out[i + 2] = b;
      out[i + 3] = 0;
    } else if (brightness > 235) {
      const alphaFactor = (250 - brightness) / 15;
      out[i] = r;
      out[i + 1] = g;
      out[i + 2] = b;
      out[i + 3] = Math.round(255 * alphaFactor);
    } else {
      out[i] = r;
      out[i + 1] = g;
      out[i + 2] = b;
      out[i + 3] = 255;
    }
  }
  
  const pngBuffer = await sharp(out, { raw: info }).png().toBuffer();
  
  const trimmed = await sharp(pngBuffer)
    .trim()
    .png()
    .toFile('c:/Users/shaws/NubiSync/nubira-mobile-app/assets/images/zigza_icon_transparent.png');
    
  console.log('Saved zigza_icon_transparent.png successfully!', trimmed);
}

testTransparentLogo().catch(console.error);
