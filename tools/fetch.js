// 简易下载器：node tools/fetch.js <url> <输出路径>
// 用法示例：node tools/fetch.js https://... app/assets/fonts/x.ttf
const fs = require('fs');
const path = require('path');
const { Readable } = require('stream');
const { pipeline } = require('stream/promises');

const url = process.argv[2];
const out = process.argv[3];
if (!url || !out) {
  console.error('usage: node tools/fetch.js <url> <outPath>');
  process.exit(2);
}

(async () => {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const t0 = Date.now();
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) {
    console.error('HTTP ' + res.status + ' for ' + url);
    process.exit(1);
  }
  const total = Number(res.headers.get('content-length') || 0);
  await pipeline(Readable.fromWeb(res.body), fs.createWriteStream(out));
  const size = fs.statSync(out).size;
  console.log(
    'OK ' + (size / 1048576).toFixed(1) + 'MB' +
    (total ? ' / ' + (total / 1048576).toFixed(1) + 'MB' : '') +
    ' in ' + ((Date.now() - t0) / 1000).toFixed(1) + 's -> ' + out
  );
})().catch((e) => {
  console.error('FAILED: ' + e.message);
  process.exit(1);
});
