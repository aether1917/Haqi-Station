package com.haqi.haqi_station

import android.content.ClipData
import android.content.ClipDescription
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    /// 分享文件给微信/QQ 等：Android 11+ 上仅靠 FLAG_GRANT 走 chooser 会丢
    /// 读权限（微信点开无反应、QQ 能选聊天但发不出文件），必须先给 Intent
    /// 设好 ClipData 再包 chooser，系统才会把权限可靠地传递给目标应用。
    private fun shareFiles(paths: List<String>, mimeTypes: List<String>) {
        val cacheDir = File(cacheDir, "shared_stickers")
        cacheDir.deleteRecursively()
        cacheDir.mkdirs()

        val uris = ArrayList<Uri>(paths.size)
        for (path in paths) {
            val file = File(path)
            val copy = File(cacheDir, file.name)
            file.copyTo(copy, true)
            uris.add(FileProvider.getUriForFile(this, "$packageName.fileprovider", copy))
        }

        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).apply {
                type = mimeTypes.firstOrNull() ?: "image/*"
                putExtra(Intent.EXTRA_STREAM, uris.first())
            }
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                type = reduceMime(mimeTypes)
                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            }
        }

        intent.clipData = ClipData(
            ClipDescription("stickers", arrayOf(intent.type ?: "image/*")),
            ClipData.Item(uris.first()),
        ).apply {
            for (i in 1 until uris.size) addItem(ClipData.Item(uris[i]))
        }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val chooser = Intent.createChooser(intent, null)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(chooser)
    }

    /// 多个 MIME 类型归并为一个意图类型：全同取该类型，同大类取 `image/*`。
    private fun reduceMime(mimeTypes: List<String>): String {
        if (mimeTypes.isEmpty()) return "image/*"
        val first = mimeTypes.first()
        val allSame = mimeTypes.all { it == first }
        val sameBase = mimeTypes.all { it.substringBefore('/') == first.substringBefore('/') }
        return when {
            allSame -> first
            sameBase -> first.substringBefore('/') + "/*"
            else -> "*/*"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.haqi.station/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFiles" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                        try {
                            shareFiles(paths, mimeTypes)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
