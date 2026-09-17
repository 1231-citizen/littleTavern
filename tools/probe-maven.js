// 探测 Gradle / Maven 镜像可用性
const urls = [
  'https://services.gradle.org/distributions/gradle-9.3.1-all.zip',
  'https://mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip',
  'https://mirrors.aliyun.com/macports/distfiles/gradle/gradle-9.3.1-all.zip',
  'https://maven.aliyun.com/repository/google/com/android/tools/build/gradle/9.1.0/gradle-9.1.0.pom',
  'https://maven.aliyun.com/repository/public/',
  'https://maven.aliyun.com/repository/gradle-plugin/',
  'https://maven.google.com/com/android/tools/build/gradle/9.1.0/gradle-9.1.0.pom',
  'https://repo1.maven.org/maven2/',
];

(async () => {
  for (const u of urls) {
    try {
      const r = await fetch(u, { method: 'HEAD', redirect: 'follow', signal: AbortSignal.timeout(15000) });
      const len = r.headers.get('content-length');
      console.log(
        String(r.status).padEnd(4),
        (len ? (Number(len) / 1048576).toFixed(1) + 'MB' : '-').padEnd(9),
        u
      );
    } catch (e) {
      console.log('ERR ', e.message.slice(0, 34).padEnd(9), u);
    }
  }
})();
