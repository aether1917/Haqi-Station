package com.haqi.haqi_station

import android.content.ClipData
import android.content.ClipDescription
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    /// 系统文件选择器请求码与挂起的 Dart 回调。
    private val filePickerRequestCode = 42001
    private val exportRequestCode = 42002
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private var pendingFilePickerZipOnly = false
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportSourcePath: String? = null
    /// 分享文件给微信/QQ 等：Android 11+ 上仅靠 FLAG_GRANT 走 chooser 会丢
    /// 读权限（微信点开无反应、QQ 能选聊天但发不出文件），必须先给 Intent
    /// 设好 ClipData 再包 chooser，系统才会把权限可靠地传递给目标应用。
    private fun shareFiles(
        paths: List<String>,
        mimeTypes: List<String>,
        names: List<String>?,
    ) {
        val cacheDir = File(cacheDir, "shared_stickers")
        cacheDir.deleteRecursively()
        cacheDir.mkdirs()

        val uris = ArrayList<Uri>(paths.size)
        for ((i, path) in paths.withIndex()) {
            val file = File(path)
            // 分享展示名：优先用传入的表情包名（微信/QQ 显示文件名）。
            val displayName = names?.getOrNull(i)
            val copy = if (displayName.isNullOrBlank()) {
                File(cacheDir, file.name)
            } else {
                File(cacheDir, sanitizeFileName(displayName) +
                        "." + file.extension.ifEmpty { "bin" })
            }
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

    /// 文件名清洗：替换 Windows/Android 非法字符与控制符。
    private fun sanitizeFileName(name: String): String {
        val cleaned = name.map { c ->
            if (c == '\\' || c == '/' || c == ':' || c == '*' ||
                c == '?' || c == '"' || c == '<' || c == '>' ||
                c == '|' || c.isISOControl()) '_' else c
        }.joinToString("").trim()
        return cleaned.ifEmpty { "sticker" }
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
            // 优先用真实路径（省去复制）；但 Android 11+ 部分设备上
            // 即使有媒体权限，File 直读其他应用媒体仍会失败——
            // 只有可读时才用，否则走 content:// 流复制（始终可靠）。
            val direct = queryDirectPath(uri)
            if (direct != null &&
                File(direct).exists() &&
                File(direct).canRead()
            ) {
                direct
            } else {
                val displayName = queryDisplayName(uri)
                val safeName = displayName?.let { name ->
                    name.map { c ->
                        if (c == '\\' || c == '/' || c == ':' || c == '*' ||
                            c == '?' || c == '"' || c == '<' || c == '>' ||
                            c == '|' || c.isISOControl()) '_' else c
                    }.joinToString("").takeIf { it.isNotBlank() }
                } ?: "media_${System.nanoTime()}"
                val target = File(folder, safeName)
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                } ?: throw IllegalStateException("无法读取所选内容：$uriString")
                target.absolutePath
            }
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        return contentResolver.query(uri, projection, null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    }

    private fun queryDirectPath(uri: Uri): String? {
        val projection = arrayOf(MediaStore.MediaColumns.DATA)
        return contentResolver.query(uri, projection, null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    }

    /// 调起系统文件管理器（DocumentsUI）多选图片，结果经 onActivityResult 返回。
    private fun launchSystemFilePicker(result: MethodChannel.Result) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "应用不在前台", null)
            return
        }
        pendingFilePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        activity.startActivityForResult(intent, filePickerRequestCode)
    }

    /// 调起系统「另存为」（CREATE_DOCUMENT），让用户选择备份 zip 的保存位置。
    private fun launchExportDocument(
        defaultName: String,
        sourcePath: String,
        result: MethodChannel.Result,
    ) {
        val activity = activity ?: run {
            result.error("NO_ACTIVITY", "应用不在前台", null)
            return
        }
        pendingExportResult = result
        pendingExportSourcePath = sourcePath
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/zip"
            putExtra(Intent.EXTRA_TITLE, defaultName)
        }
        activity.startActivityForResult(intent, exportRequestCode)
    }

    /// 把 SAF 的 content:// 复制成可读文件（文件名取 DISPLAY_NAME，缺省按时间戳）。
    private fun copyUriToCache(uri: Uri, fallbackExt: String): String {
        val folder = File(cacheDir, "shared_import")
        if (!folder.exists()) folder.mkdirs()
        var name: String? = null
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) name = c.getString(0) }
        val baseName = name?.takeIf { it.isNotBlank() }
            ?: "file_${System.nanoTime()}.$fallbackExt"
        val target = File(folder, baseName)
        contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("无法读取所选内容：$uri")
        return target.absolutePath
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == filePickerRequestCode) {
            val result = pendingFilePickerResult
            val zipOnly = pendingFilePickerZipOnly
            pendingFilePickerResult = null
            pendingFilePickerZipOnly = false
            if (result != null) {
                if (resultCode == RESULT_OK && data != null) {
                    val paths = ArrayList<String>()
                    val clip = data.clipData
                    if (clip != null) {
                        for (i in 0 until clip.itemCount) {
                            paths.add(copyUriToCache(clip.getItemAt(i).uri, "jpg"))
                        }
                    } else if (data.data != null) {
                        paths.add(copyUriToCache(data.data!!, "jpg"))
                    }
                    result.success(if (zipOnly) paths.take(1) else paths)
                } else {
                    result.success(emptyList<String>())
                }
            }
            return
        }
        if (requestCode == exportRequestCode) {
            val result = pendingExportResult
            val sourcePath = pendingExportSourcePath
            pendingExportResult = null
            pendingExportSourcePath = null
            if (result != null) {
                val uri = data?.data
                if (resultCode == RESULT_OK && uri != null && sourcePath != null) {
                    try {
                        contentResolver.openOutputStream(uri)?.use { output ->
                            File(sourcePath).inputStream().use { input ->
                                input.copyTo(output)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EXPORT_FAILED", e.message, null)
                    }
                } else {
                    result.success(false)
                }
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.haqi.station/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFiles" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                        val names = call.argument<List<String>>("names")
                        try {
                            shareFiles(paths, mimeTypes, names)
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
                    "pickFilesSystem" -> {
                        try {
                            launchSystemFilePicker(result)
                        } catch (e: Exception) {
                            result.error("PICK_FAILED", e.message, null)
                        }
                    }
                    "pickBackupZip" -> {
                        val activity = activity
                        if (activity == null) {
                            result.error("NO_ACTIVITY", "应用不在前台", null)
                        } else {
                            pendingFilePickerResult = result
                            pendingFilePickerZipOnly = true
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                            }
                            activity.startActivityForResult(intent, filePickerRequestCode)
                        }
                    }
                    "pickExportLocation" -> {
                        val defaultName =
                            call.argument<String>("defaultName") ?: "backup.zip"
                        val sourcePath = call.argument<String>("sourcePath") ?: ""
                        try {
                            launchExportDocument(defaultName, sourcePath, result)
                        } catch (e: Exception) {
                            result.error("PICK_FAILED", e.message, null)
                        }
                    }
                    "writeFileToUri" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val targetUri = call.argument<String>("targetUri")
                        try {
                            if (sourcePath == null || targetUri == null) {
                                result.error("EXPORT_FAILED", "missing args", null)
                            } else {
                                contentResolver.openOutputStream(Uri.parse(targetUri))
                                    ?.use { output ->
                                        File(sourcePath).inputStream().use { input ->
                                            input.copyTo(output)
                                        }
                                    }
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("EXPORT_FAILED", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        try {
                            if (path == null) {
                                result.error("INSTALL_FAILED", "missing path", null)
                            } else {
                                val uri = FileProvider.getUriForFile(
                                    this, "$packageName.fileprovider", File(path))
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    "importUriToCache" -> {
                        val uriString = call.argument<String>("uri")
                        try {
                            if (uriString == null) {
                                result.error("IMPORT_FAILED", "missing uri", null)
                            } else {
                                result.success(copyUriToCache(Uri.parse(uriString), "zip"))
                            }
                        } catch (e: Exception) {
                            result.error("IMPORT_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
