package com.haqi.haqi_station

import android.content.ClipData
import android.content.ClipDescription
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
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

    /// 内建内容查看器：扫描媒体库（图片 + 视频），按修改时间倒序。
    private fun queryMedia(): List<Map<String, Any>> {
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATA,
        )
        val items = ArrayList<Map<String, Any>>()

        fun collect(collection: Uri, isVideo: Boolean) {
            contentResolver.query(collection, projection, null, null, null)?.use { cursor ->
                val idC = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val bucketC = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
                val dateC = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
                val mimeC = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                val dataC = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idC)
                    items.add(
                        mapOf(
                            "uri" to Uri.withAppendedPath(collection, id.toString()).toString(),
                            "isVideo" to isVideo,
                            "bucket" to (cursor.getString(bucketC) ?: "未分类"),
                            "dateModified" to cursor.getLong(dateC),
                            "path" to (cursor.getString(dataC) ?: ""),
                            "mime" to (cursor.getString(mimeC) ?: ""),
                        )
                    )
                }
            }
        }

        collect(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, isVideo = false)
        collect(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, isVideo = true)
        items.sortByDescending { (it["dateModified"] as Number).toLong() }
        return items
    }

    /// 把选中的 content:// 落成可读文件路径：优先用 MediaStore 里的真实路径，
    /// 不存在（云端等）时复制到应用缓存。
    private fun resolveMediaPaths(uris: List<String>): List<String> {
        val folder = File(cacheDir, "shared_import")
        folder.deleteRecursively()
        folder.mkdirs()
        return uris.map { uriString ->
            val uri = Uri.parse(uriString)
            val direct = queryDirectPath(uri)
            if (direct != null && File(direct).exists()) {
                direct
            } else {
                val projection = arrayOf(MediaStore.MediaColumns.MIME_TYPE)
                val mime = contentResolver.query(uri, projection, null, null, null)
                    ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
                val ext = when (mime) {
                    "image/jpeg" -> "jpg"
                    "image/png" -> "png"
                    "image/gif" -> "gif"
                    "image/webp" -> "webp"
                    "image/bmp" -> "bmp"
                    "video/mp4" -> "mp4"
                    else -> "bin"
                }
                val target = File(folder, "media_${System.nanoTime()}.$ext")
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: throw IllegalStateException("无法读取所选内容：$uriString")
                target.absolutePath
            }
        }
    }

    private fun queryDirectPath(uri: Uri): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DATA)
        return contentResolver.query(uri, projection, null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
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
                    "queryMedia" -> {
                        try {
                            result.success(queryMedia())
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            result.error("QUERY_FAILED", e.message, null)
                        }
                    }
                    "resolveMediaPaths" -> {
                        val uris = call.argument<List<String>>("uris") ?: emptyList()
                        try {
                            result.success(resolveMediaPaths(uris))
                        } catch (e: Exception) {
                            result.error("RESOLVE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
