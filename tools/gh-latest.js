// 查询 GitHub CLI 最新版本，并给出代理下载地址（winget 卡住时的备用方案）
(async () => {
  try {
    const r = await fetch('https://api.github.com/repos/cli/cli/releases/latest', {
      headers: { 'User-Agent': 'node' },
      signal: AbortSignal.timeout(20000),
    });
    const j = await r.json();
    const tag = j.tag_name;
    const ver = tag.replace(/^v/, '');
    const asset = `gh_${ver}_windows_amd64.zip`;
    console.log('latest  :', tag);
    console.log('asset   :', asset);
    console.log('direct  :', `https://github.com/cli/cli/releases/download/${tag}/${asset}`);
    console.log('proxy   :', `https://ghfast.top/https://github.com/cli/cli/releases/download/${tag}/${asset}`);
    const found = (j.assets || []).find((a) => a.name === asset);
    console.log('size MB :', found ? (found.size / 1048576).toFixed(1) : '?');
  } catch (e) {
    console.log('FAILED:', e.message);
  }
})();
