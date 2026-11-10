const fs = require('fs');
const path = require('path');

function search(dir, regex) {
  const results = [];
  const entries = fs.readdirSync(dir);
  for (const entry of entries) {
    const full = path.join(dir, entry);
    if (fs.statSync(full).isDirectory()) {
      results.push(...search(full, regex));
    } else if (entry.endsWith('.dart')) {
      const content = fs.readFileSync(full, 'utf8');
      const lines = content.split('\n');
      lines.forEach((line, idx) => {
        if (regex.test(line)) {
          results.push({ file: full, lineNum: idx + 1, text: line.trim() });
        }
      });
    }
  }
  return results;
}

const libDir = 'c:/Users/shaws/NubiSync/nubira-mobile-app/lib';
console.log('--- Occurrences of "Zigza MES" or similar ---');
const hits = search(libDir, /zigza\s+mes/i);
hits.forEach(h => console.log(`${h.file}:${h.lineNum} -> ${h.text}`));
console.log(`Total hits: ${hits.length}`);
