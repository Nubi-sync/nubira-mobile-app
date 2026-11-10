const fs = require('fs');
const path = require('path');

function search(dir, str) {
  const results = [];
  const entries = fs.readdirSync(dir);
  for (const entry of entries) {
    const full = path.join(dir, entry);
    if (fs.statSync(full).isDirectory()) {
      results.push(...search(full, str));
    } else if (entry.endsWith('.dart')) {
      const content = fs.readFileSync(full, 'utf8');
      const lines = content.split('\n');
      lines.forEach((line, idx) => {
        if (line.toLowerCase().includes(str.toLowerCase())) {
          results.push({ file: full, lineNum: idx + 1, text: line.trim() });
        }
      });
    }
  }
  return results;
}

const libDir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/lib';
console.log('--- Occurrences of "Sign Out" dialogs or methods ---');
const hits = search(libDir, 'showsignoutdialog');
hits.forEach(h => console.log(`${h.file}:${h.lineNum} -> ${h.text}`));

console.log('--- Occurrences of "signOut" in UI buttons ---');
const hits2 = search(libDir, '.signout()');
hits2.forEach(h => console.log(`${h.file}:${h.lineNum} -> ${h.text}`));
