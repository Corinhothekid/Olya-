import {readFileSync, writeFileSync} from 'node:fs';

const files = ['simulation', 'career', 'renderer', 'interface', 'bootstrap'];
const modules = files.map(name => readFileSync(new URL(`../src/${name}.js`, import.meta.url), 'utf8').trim());
const source = `// PolyLax Web | Paste this entire file into the Babylon.js Playground JavaScript editor.\n`
    + `// Source modules are in polylax-web/src. Run npm run build after editing them.\n\n`
    + `var createScene = function () {\n'use strict';\n\n${modules.join('\n\n')}\n\n`
    + `return createPolyLaxScene(engine);\n};\n\n// End of PolyLax Web\n`;
const output = new URL('../playground.js', import.meta.url);
if (process.argv.includes('--check')) {
    if (readFileSync(output, 'utf8') !== source) throw new Error('playground.js is stale. Run npm run build.');
} else {
    writeFileSync(output, source);
}
