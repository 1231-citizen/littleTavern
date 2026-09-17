// 下载速度对比：固定 10 秒窗口，统计已读字节
const urls = [
  'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip',
  'https://aka.ms/download-jdk/microsoft-jdk-17.0.13-windows-x64.zip',
  'https://cdn.azul.com/zulu/bin/zulu17.48.15-ca-jdk17.0.10-win_x64.zip',
  'https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_windows-x64_bin.zip',
  'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip',
];

async function speed(u) {
  const t0 = Date.now();
  const ctrl = new AbortController();
  setTimeout(() => ctrl.abort(), 10000);
  let n = 0;
  let len = 0;
  let status = 0;
  try {
    const r = await fetch(u, { redirect: 'follow', signal: ctrl.signal });
    status = r.status;
    len = Number(r.headers.get('content-length') || 0);
    if (!r.ok) {
      console.log('HTTP ' + r.status + '  ' + u);
      return;
    }
    const rd = r.body.getReader();
    while (true) {
      const { done, value } = await rd.read();
      if (done) break;
      n += value.length;
    }
  } catch (_) {
    /* 10 秒到点，正常中断 */
  }
  const dt = (Date.now() - t0) / 1000;
  console.log(
    ((n / dt) / 1048576).toFixed(2) + ' MB/s   ' + (n / 1048576).toFixed(1) + 'MB read / ' +
    (len / 1048576).toFixed(1) + 'MB total   ' + (len && n >= len ? '[FULL] ' : '') + u
  );
}

(async () => {
  for (const u of urls) await speed(u);
})();
