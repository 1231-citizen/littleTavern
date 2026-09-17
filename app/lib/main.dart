import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/chat_screen.dart';
import 'store.dart';
import 'theme/jf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局字体：霞鹜文楷 Light（见 pubspec.yaml 的 fonts 段）
  JF.family = 'WenKai';

  // 状态栏：与米白背景融为一体，图标用深墨色（绝不出现深色底）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: JF.riceWhite,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final store = AppStore();
  await store.load();

  runApp(TavernApp(store: store));
}

class TavernApp extends StatelessWidget {
  final AppStore store;

  const TavernApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小酒馆',
      debugShowCheckedModeBanner: false,
      theme: JF.theme(),
      locale: const Locale('zh', 'CN'),
      home: ChatScreen(store: store),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // 限制系统字号缩放，避免版式被撑破
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
