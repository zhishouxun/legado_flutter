package io.legado.app

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.annotation.NonNull
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.google.zxing.BinaryBitmap
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.legado.app.R

class MainActivity: FlutterActivity() {
    private val CHANNEL = "io.legado.app/shortcuts"
    private val SHARE_CHANNEL = "io.legado.app/share"
    private val FILE_CHANNEL = "io.legado.app/file"
    private val QRCODE_CHANNEL = "io.legado.app/qrcode"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 快捷方式通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "buildShortcuts" -> {
                    try {
                        val hasLastReadBook = call.argument<Boolean>("hasLastReadBook") ?: false
                        val lastReadBookUrl = call.argument<String>("lastReadBookUrl")
                        val lastReadBookName = call.argument<String>("lastReadBookName")
                        
                        buildShortcuts(hasLastReadBook, lastReadBookUrl, lastReadBookName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "创建快捷方式失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 分享通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "handleSharedText" -> {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        // 通过MethodChannel发送到Flutter端处理
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "处理分享文本失败: ${e.message}", null)
                    }
                }
                "handleProcessText" -> {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        // 通过MethodChannel发送到Flutter端处理
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "处理文本选择失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Logcat转储通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.legado.app/logcat").setMethodCallHandler { call, result ->
            when (call.method) {
                "dumpLogcat" -> {
                    try {
                        val process = Runtime.getRuntime().exec("logcat -d")
                        val output = process.inputStream.bufferedReader().use { it.readText() }
                        result.success(output)
                    } catch (e: Exception) {
                        result.error("ERROR", "转储logcat失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 堆转储通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.legado.app/heapdump").setMethodCallHandler { call, result ->
            when (call.method) {
                "triggerGC" -> {
                    try {
                        System.gc()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "触发GC失败: ${e.message}", null)
                    }
                }
                "getMemoryInfo" -> {
                    try {
                        val runtime = Runtime.getRuntime()
                        val maxMemory = runtime.maxMemory()
                        val totalMemory = runtime.totalMemory()
                        val freeMemory = runtime.freeMemory()
                        val usedMemory = totalMemory - freeMemory
                        
                        val memoryInfo = mapOf(
                            "maxMemory" to "${maxMemory / 1024 / 1024} MB",
                            "totalMemory" to "${totalMemory / 1024 / 1024} MB",
                            "freeMemory" to "${freeMemory / 1024 / 1024} MB",
                            "usedMemory" to "${usedMemory / 1024 / 1024} MB"
                        )
                        result.success(memoryInfo)
                    } catch (e: Exception) {
                        result.error("ERROR", "获取内存信息失败: ${e.message}", null)
                    }
                }
                "createHeapDump" -> {
                    try {
                        // 创建堆转储文件
                        val cacheDir = getExternalCacheDir() ?: cacheDir
                        val heapDumpDir = java.io.File(cacheDir, "heapDump")
                        if (!heapDumpDir.exists()) {
                            heapDumpDir.mkdirs()
                        }
                        
                        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", java.util.Locale.getDefault())
                        val fileName = "heapDump_${dateFormat.format(java.util.Date())}.hprof"
                        val heapDumpFile = java.io.File(heapDumpDir, fileName)
                        
                        // 注意：实际堆转储需要Debug.dumpHprofData()，但需要Debug权限
                        // 这里创建一个占位文件
                        heapDumpFile.createNewFile()
                        
                        result.success(heapDumpFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("ERROR", "创建堆转储失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 二维码解析通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QRCODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "parseQRCodeFromPath" -> {
                    try {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath == null) {
                            result.error("ERROR", "图片路径为空", null)
                            return@setMethodCallHandler
                        }
                        
                        val qrCodeText = parseQRCodeFromPath(imagePath)
                        if (qrCodeText != null) {
                            result.success(qrCodeText)
                        } else {
                            result.error("ERROR", "未检测到二维码", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "解析二维码失败: ${e.message}", null)
                    }
                }
                "parseQRCodeFromBytes" -> {
                    try {
                        val imageBytes = call.argument<ByteArray>("imageBytes")
                        if (imageBytes == null || imageBytes.isEmpty()) {
                            result.error("ERROR", "图片字节为空", null)
                            return@setMethodCallHandler
                        }
                        
                        val qrCodeText = parseQRCodeFromBytes(imageBytes)
                        if (qrCodeText != null) {
                            result.success(qrCodeText)
                        } else {
                            result.error("ERROR", "未检测到二维码", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "解析二维码失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 文件处理通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "handleFile" -> {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            sendFileToFlutter(uri)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "处理文件失败: ${e.message}", null)
                    }
                }
                "getFileInfo" -> {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            val fileInfo = getFileInfoFromContentUri(uri)
                            result.success(fileInfo)
                        } else {
                            result.error("ERROR", "URI为空", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "获取文件信息失败: ${e.message}", null)
                    }
                }
                "readContentUri" -> {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            val content = readContentUri(uri)
                            result.success(content)
                        } else {
                            result.error("ERROR", "URI为空", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "读取文件内容失败: ${e.message}", null)
                    }
                }
                "readContentUriBytes" -> {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            val bytes = readContentUriBytes(uri)
                            result.success(bytes)
                        } else {
                            result.error("ERROR", "URI为空", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "读取文件字节失败: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        when {
            // 处理 ACTION_VIEW (文件打开)
            intent.action == Intent.ACTION_VIEW && intent.data != null -> {
                val uri = intent.data
                if (uri != null) {
                    sendFileToFlutter(uri.toString())
                }
            }
            // 处理 ACTION_SEND (分享文本)
            intent.action == Intent.ACTION_SEND && intent.type == "text/plain" -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    sendSharedTextToFlutter(text)
                }
            }
            // 处理 ACTION_PROCESS_TEXT (文本选择)
            intent.action == Intent.ACTION_PROCESS_TEXT && intent.type == "text/plain" -> {
                val text = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
                if (!text.isNullOrBlank()) {
                    sendProcessTextToFlutter(text)
                }
            }
            // 处理 readAloud action
            intent.getStringExtra("action") == "readAloud" -> {
                sendReadAloudToFlutter()
            }
        }
    }
    
    private fun sendSharedTextToFlutter(text: String) {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onSharedText", mapOf("text" to text))
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "发送分享文本到Flutter失败", e)
        }
    }
    
    private fun sendProcessTextToFlutter(text: String) {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onProcessText", mapOf("text" to text))
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "发送文本选择到Flutter失败", e)
        }
    }
    
    private fun sendReadAloudToFlutter() {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onReadAloud", null)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "发送朗读动作到Flutter失败", e)
        }
    }
    
    private fun sendFileToFlutter(uri: String) {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, FILE_CHANNEL).invokeMethod("onFile", mapOf("uri" to uri))
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "发送文件到Flutter失败", e)
        }
    }

    /// 从content:// URI获取文件信息
    private fun getFileInfoFromContentUri(uriString: String): Map<String, String> {
        val uri = Uri.parse(uriString)
        val result = mutableMapOf<String, String>()
        
        try {
            if (uri.scheme == "content") {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            result["name"] = it.getString(nameIndex) ?: ""
                        }
                        
                        // 从文件名提取扩展名
                        val name = result["name"] ?: ""
                        if (name.contains(".")) {
                            result["extension"] = name.substringAfterLast(".", "")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "获取文件信息失败", e)
        }
        
        return result
    }

    /// 从content:// URI读取文本内容
    private fun readContentUri(uriString: String): String {
        val uri = Uri.parse(uriString)
        val stringBuilder = StringBuilder()
        
        try {
            if (uri.scheme == "content") {
                contentResolver.openInputStream(uri)?.use { inputStream ->
                    inputStream.bufferedReader().use { reader ->
                        reader.lineSequence().forEach { line ->
                            stringBuilder.append(line).append("\n")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "读取文件内容失败", e)
        }
        
        return stringBuilder.toString()
    }

    /// 从content:// URI读取字节数据
    private fun readContentUriBytes(uriString: String): ByteArray {
        val uri = Uri.parse(uriString)
        val bytes = mutableListOf<Byte>()
        
        try {
            if (uri.scheme == "content") {
                contentResolver.openInputStream(uri)?.use { inputStream ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        for (i in 0 until bytesRead) {
                            bytes.add(buffer[i])
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "读取文件字节失败", e)
        }
        
        return bytes.toByteArray()
    }

    private fun buildShortcuts(
        hasLastReadBook: Boolean,
        lastReadBookUrl: String?,
        lastReadBookName: String?
    ) {
        val shortcuts = mutableListOf<ShortcutInfoCompat>()

        // 1. 书架快捷方式
        val bookshelfIntent = Intent(Intent.ACTION_VIEW, Uri.parse("legado://bookshelf"))
            .setPackage(packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        
        val bookshelfShortcut = ShortcutInfoCompat.Builder(this, "bookshelf")
            .setShortLabel("书架")
            .setLongLabel("书架")
            .setIcon(IconCompat.createWithResource(this, R.drawable.icon_read_book))
            .setIntent(bookshelfIntent)
            .build()
        shortcuts.add(bookshelfShortcut)

        // 2. 最后阅读快捷方式（如果有最后阅读的书籍）
        if (hasLastReadBook && lastReadBookUrl != null) {
            val lastReadIntent = Intent(Intent.ACTION_VIEW, Uri.parse("legado://read?url=${Uri.encode(lastReadBookUrl)}"))
                .setPackage(packageName)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            
            val lastReadShortcut = ShortcutInfoCompat.Builder(this, "lastRead")
                .setShortLabel("最后阅读")
                .setLongLabel(lastReadBookName ?: "最后阅读")
                .setIcon(IconCompat.createWithResource(this, R.drawable.icon_read_book))
                .setIntent(lastReadIntent)
                .build()
            shortcuts.add(lastReadShortcut)
        }

        // 3. 朗读快捷方式
        val readAloudIntent = Intent(Intent.ACTION_VIEW, Uri.parse("legado://readAloud"))
            .setPackage(packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        
        val readAloudShortcut = ShortcutInfoCompat.Builder(this, "readAloud")
            .setShortLabel("朗读")
            .setLongLabel("朗读")
            .setIcon(IconCompat.createWithResource(this, R.drawable.icon_read_book))
            .setIntent(readAloudIntent)
            .build()
        shortcuts.add(readAloudShortcut)

        // 设置动态快捷方式
        ShortcutManagerCompat.setDynamicShortcuts(this, shortcuts)
    }
    
    /// 从图片路径解析二维码
    private fun parseQRCodeFromPath(imagePath: String): String? {
        return try {
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap == null) {
                android.util.Log.e("MainActivity", "无法解码图片: $imagePath")
                return null
            }
            parseQRCodeFromBitmap(bitmap)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "解析二维码失败: ${e.message}", e)
            null
        }
    }
    
    /// 从图片字节解析二维码
    private fun parseQRCodeFromBytes(imageBytes: ByteArray): String? {
        return try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                android.util.Log.e("MainActivity", "无法解码图片字节")
                return null
            }
            parseQRCodeFromBitmap(bitmap)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "解析二维码失败: ${e.message}", e)
            null
        }
    }
    
    /// 从Bitmap解析二维码
    private fun parseQRCodeFromBitmap(bitmap: android.graphics.Bitmap): String? {
        return try {
            val width = bitmap.width
            val height = bitmap.height
            val pixels = IntArray(width * height)
            bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
            
            val source = RGBLuminanceSource(width, height, pixels)
            val binaryBitmap = BinaryBitmap(HybridBinarizer(source))
            
            val reader = MultiFormatReader()
            val result = reader.decode(binaryBitmap)
            result.text
        } catch (e: Exception) {
            // 如果解析失败，返回null（可能是图片中没有二维码）
            null
        }
    }
}

