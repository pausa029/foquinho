const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 400, height: 400 }, deviceScaleFactor: 1 });
  fs.mkdirSync('png', { recursive: true });
  const poses = ['feliz', 'acenando', 'apontando', 'comemorando', 'pensando'];
  for (const n of poses) {
    await p.setContent('<html><body style="margin:0;background:transparent">' + fs.readFileSync('svg/' + n + '.svg', 'utf8').replace('width="400" height="400"', 'width="400" height="400" style="display:block"') + '</body></html>');
    await p.screenshot({ path: 'png/' + n + '.png', omitBackground: true, clip: { x: 0, y: 0, width: 400, height: 400 } });
  }
  await p.setViewportSize({ width: 1000, height: 220 });
  await p.setContent('<body style="margin:0;display:flex;gap:0;background:#f3f6f3">' + poses.map(n => '<img src="data:image/png;base64,' + fs.readFileSync('png/' + n + '.png').toString('base64') + '" width="200">').join('') + '</body>');
  await p.screenshot({ path: 'preview.png' });
  await b.close();
})();
