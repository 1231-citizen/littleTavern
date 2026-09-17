// GitHub OAuth 设备码流程（与 gh auth login --web 底层一致）
// 用法：node tools/gh-device-login.js <输出token的文件>
// 流程：打印 8 位设备码 -> 你在浏览器输入 -> 本进程轮询到授权后把 token 写到文件
const fs = require('fs');
const path = require('path');

// gh CLI 的公开 OAuth client id（不是密钥，可公开）
const CLIENT_ID = '178c6fc778ccc68e1d6a';
const SCOPE = 'repo read:org workflow';

const outFile = process.argv[2] || path.join(__dirname, 'gh-token.txt');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function requestDeviceCode() {
  // 本机到 github.com 的连接是间歇性的，必须重试
  for (let attempt = 1; attempt <= 12; attempt++) {
    try {
      const res = await fetch('https://github.com/login/device/code', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_id: CLIENT_ID, scope: SCOPE }),
        signal: AbortSignal.timeout(25000),
      });
      const j = await res.json();
      if (j.device_code) return j;
      console.error('申请被拒：' + JSON.stringify(j));
    } catch (e) {
      console.log('第 ' + attempt + ' 次申请失败（' + e.message.slice(0, 30) + '），重试…');
    }
    await sleep(3000);
  }
  return null;
}

async function main() {
  const code = await requestDeviceCode();
  if (!code) {
    console.error('多次重试后仍无法连接 github.com，请检查网络或代理');
    process.exit(1);
  }

  console.log('==================================================');
  console.log('  请在浏览器打开：' + code.verification_uri);
  console.log('  输入设备码：    ' + code.user_code);
  console.log('  （有效期 ' + Math.round(code.expires_in / 60) + ' 分钟）');
  console.log('==================================================');

  const interval = (code.interval || 5) + 1;
  const deadline = Date.now() + code.expires_in * 1000;
  let netFail = 0;

  while (Date.now() < deadline) {
    await sleep(interval * 1000);
    let res;
    try {
      res = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: CLIENT_ID,
          device_code: code.device_code,
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
        }),
        signal: AbortSignal.timeout(20000),
      });
      netFail = 0;
    } catch (e) {
      // 本机到 github 的连接时断时续：失败就立刻重试，不要白等一个周期
      netFail++;
      if (netFail % 5 === 0) console.log('网络中断 ' + netFail + ' 次，继续重试…');
      await sleep(2000);
      continue;
    }
    const j = await res.json();

    if (j.access_token) {
      fs.writeFileSync(outFile, j.access_token, 'utf8');
      const masked = j.access_token.slice(0, 4) + '…' + j.access_token.slice(-4);
      console.log('AUTHORIZED token=' + masked + ' -> ' + outFile);
      process.exit(0);
    }
    if (j.error === 'authorization_pending') continue;
    if (j.error === 'slow_down') { await sleep(5000); continue; }
    console.error('授权失败：' + (j.error_description || j.error));
    process.exit(1);
  }
  console.error('设备码已过期，请重新运行');
  process.exit(1);
}

main().catch((e) => {
  console.error('异常：' + e.message);
  process.exit(1);
});
