import 'package:flutter/services.dart';

/// ============================================================
///  头像照片 —— 走原生相册选择
///  照片会被原生侧压到 640px 以内，存进应用私有目录，
///  Dart 只拿到一个本地文件路径（写进角色卡 / 用户设定即可）。
/// ============================================================
const MethodChannel _channel = MethodChannel('tavern/image');

/// 打开相册选一张照片。
/// 返回图片的本地路径；用户取消时返回 null。
/// 失败时抛出可读的中文提示。
Future<String?> pickAvatarImage() async {
  try {
    return await _channel.invokeMethod<String>('pickAvatar');
  } on MissingPluginException {
    throw '当前平台暂不支持选择照片';
  } on PlatformException catch (e) {
    if (e.code == 'canceled') return null;
    throw e.message ?? '选择照片失败';
  }
}
