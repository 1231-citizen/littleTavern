package com.momiji.tavern

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max

/**
 * 只做一件事：把相册里选中的照片压小、存进应用私有目录，然后把路径交回 Dart。
 *
 * Android 13+ 用系统照片选择器（MediaStore.ACTION_PICK_IMAGES），
 * 更低的版本退回 ACTION_OPEN_DOCUMENT —— 两条路都不需要任何存储权限。
 */
class MainActivity : FlutterActivity() {

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tavern/image")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAvatar" -> {
                        if (pendingResult != null) {
                            result.error("busy", "正在选择照片，请稍候", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        if (!launchPicker(photoPickerIntent())) {
                            pendingResult = null
                            result.error("failed", "这台设备上没有可用的相册", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 打开选图界面。13+ 优先用系统照片选择器，打不开就退回文档选择器。
     * 不用 resolveActivity 判断 —— Android 11 起的应用可见性会让它误报「没有相册」。
     */
    private fun launchPicker(intent: Intent): Boolean {
        return try {
            startActivityForResult(intent, kPickImageRequest)
            true
        } catch (e: ActivityNotFoundException) {
            try {
                startActivityForResult(openDocumentIntent(), kPickImageRequest)
                true
            } catch (e2: Exception) {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun photoPickerIntent(): Intent {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).setType("image/*")
        } else {
            openDocumentIntent()
        }
    }

    private fun openDocumentIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != kPickImageRequest) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult
        pendingResult = null
        if (result == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.error("canceled", "未选择照片", null)
            return
        }
        try {
            result.success(saveAvatar(uri))
        } catch (e: Exception) {
            result.error("failed", e.message ?: "保存照片失败", null)
        }
    }

    /** 把选中的照片压缩后写进 filesDir/avatars/，返回绝对路径 */
    private fun saveAvatar(uri: Uri): String {
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("无法读取这张照片")

        val dir = File(filesDir, "avatars")
        if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("无法创建头像目录")

        val file = File(dir, "avatar_${System.currentTimeMillis()}.jpg")
        val bitmap = decodeDownscaled(bytes, kMaxAvatarSize)
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
        }
        bitmap.recycle()
        return file.absolutePath
    }

    /** 两步解码：先读尺寸算采样率，再按需缩放到不超过 maxSize */
    private fun decodeDownscaled(bytes: ByteArray, maxSize: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)

        var sample = 1
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w > 0 && h > 0) {
            while (w / sample > maxSize || h / sample > maxSize) {
                sample *= 2
            }
        }

        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            ?: throw IllegalStateException("这张照片无法解析")

        val longSide = max(decoded.width, decoded.height)
        if (longSide <= maxSize) return decoded

        val scale = maxSize.toFloat() / longSide.toFloat()
        val scaled = Bitmap.createScaledBitmap(
            decoded,
            max(1, (decoded.width * scale).toInt()),
            max(1, (decoded.height * scale).toInt()),
            true
        )
        if (scaled != decoded) decoded.recycle()
        return scaled
    }

    private companion object {
        const val kPickImageRequest = 4711
        const val kMaxAvatarSize = 640
    }
}
