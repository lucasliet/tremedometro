package br.com.lucasliet.blueguava

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "br.com.lucasliet.blueguava/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceAbi" -> {
                    val preferredAbi = Build.SUPPORTED_ABIS[0]
                    result.success(preferredAbi)
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        try {
                            installApk(apkPath)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK path is null", null)
                    }
                }
                "deleteApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        val file = File(apkPath)
                        val deleted = file.delete()
                        result.success(deleted)
                    } else {
                        result.error("INVALID_PATH", "APK path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) {
            throw IllegalArgumentException("APK file not found: $apkPath")
        }

        val intent = Intent(Intent.ACTION_VIEW)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val apkUri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
                intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            } catch (e: IllegalArgumentException) {
                throw IllegalStateException("Failed to get URI for APK: ${e.message}")
            }
        } else {
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        startActivity(intent)
    }
}
