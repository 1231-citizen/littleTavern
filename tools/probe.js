// 探测镜像可用性 + 列出清华 JDK 目录
const targets = [
  'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/',
  'https://ghfast.top/https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Light.ttf',
  'https://gh-proxy.com/https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Light.ttf',
];

(async () => {
  for (const u of targets) {
    try {
      const r = await fetch(u, { method: 'HEAD', redirect: 'follow', signal: AbortSignal.timeout(20000) });
      const len = r.headers.get('content-length');
      console.log('OK  ', r.status, len ? (Math.round(len / 1048576 * 10) / 10) + 'MB' : '-', u);
      if (u.includes('tuna')) {
        const html = await (await fetch(u, { signal: AbortSignal.timeout(20000) })).text();
        const m = [...html.matchAll(/href="([^"]*OpenJDK17U[^"]*\.zip)"/g)].map((x) => x[1]);
        console.log('   JDK candidates:');
        for (const f of m.slice(-5)) console.log('     ' + f);
      }
    } catch (e) {
      console.log('FAIL', e.message.slice(0, 60), u);
    }
  }
})();
