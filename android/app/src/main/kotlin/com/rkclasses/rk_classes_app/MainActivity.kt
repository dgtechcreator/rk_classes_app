package com.rkclasses.rk_classes_app

import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens a specific WhatsApp chat with a file attached (user still presses send). Returns false
        // when WhatsApp isn't installed or the intent can't be started, so Dart can fall back to the
        // regular share sheet.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rk/whatsapp").setMethodCallHandler { call, result ->
            if (call.method != "sendFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = call.argument<String>("path") ?: ""
                val phone = (call.argument<String>("phone") ?: "").filter { it.isDigit() }
                val text = call.argument<String>("text") ?: ""
                val mime = call.argument<String>("mime") ?: "application/pdf"
                val pkg = listOf("com.whatsapp", "com.whatsapp.w4b").firstOrNull { isInstalled(it) }
                val file = File(path)
                if (pkg == null || phone.isEmpty() || !file.exists()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val uri = FileProvider.getUriForFile(this, "$packageName.rkfiles", file)
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = mime
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    putExtra("jid", "$phone@s.whatsapp.net")
                    setPackage(pkg)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }
}
