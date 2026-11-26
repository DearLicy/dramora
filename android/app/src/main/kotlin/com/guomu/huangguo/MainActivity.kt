package com.guomu.huangguo

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null
    private var pendingUpdatePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.guomu.huangguo/update")
            .setMethodCallHandler { call, result ->
                if (call.method == "openUninstaller") {
                    try {
                        startActivity(Intent(Intent.ACTION_UNINSTALL_PACKAGE, Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("uninstall_failed", "无法打开系统卸载页面", null)
                    }
                } else if (call.method != "installApk") {
                    result.notImplemented()
                } else {
                    try {
                        val file = File(call.argument<String>("path").orEmpty()).canonicalFile
                        val allowed = File(cacheDir, "guomu-updates").canonicalFile
                        if (file.parentFile != allowed || !file.isFile || file.extension != "apk") {
                            result.error("invalid_apk", "安装包不存在，请重新下载", null)
                        } else if (!hasMatchingSignature(file)) {
                            result.error("signature_mismatch", "旧版安装包使用了不同签名，无法覆盖安装。请保留需要的数据后一次性卸载旧版，再安装新版；从当前版本之后的更新可直接覆盖。", null)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                            pendingUpdatePath = file.path
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            result.success(true)
                        } else {
                            openInstaller(file)
                            result.success(true)
                        }
                    } catch (error: Exception) {
                        result.error("install_failed", "无法打开安装程序", null)
                    }
                }
            }
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/deeplink",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(intent?.data?.toString())
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "share") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title = call.argument<String>("title").orEmpty()
            val text = call.argument<String>("text").orEmpty()
            val url = call.argument<String>("url").orEmpty()
            val shareText = listOf(title, text, url)
                .filter { it.isNotBlank() }
                .joinToString("\n")

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TITLE, title)
                putExtra(Intent.EXTRA_TEXT, shareText)
            }
            startActivity(Intent.createChooser(intent, "分享到"))
            result.success(true)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { link ->
            deepLinkChannel?.invokeMethod("link", link)
        }
    }

    override fun onResume() {
        super.onResume()
        val path = pendingUpdatePath ?: return
        pendingUpdatePath = null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()) {
            try { openInstaller(File(path)) } catch (_: Exception) { }
        }
    }

    private fun openInstaller(file: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
    }

    @Suppress("DEPRECATION")
    private fun hasMatchingSignature(file: File): Boolean {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val current = packageManager.getPackageInfo(packageName, flags)
        val update = packageManager.getPackageArchiveInfo(file.path, flags) ?: return false
        if (update.packageName != packageName) return false
        val oldSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) current.signingInfo?.apkContentsSigners else current.signatures
        val newSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) update.signingInfo?.apkContentsSigners else update.signatures
        return oldSigners != null && newSigners != null && oldSigners.isNotEmpty() && oldSigners.all { old -> newSigners.any { next -> old.toByteArray().contentEquals(next.toByteArray()) } }
    }
}
