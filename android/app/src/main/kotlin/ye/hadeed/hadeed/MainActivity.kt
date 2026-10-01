package ye.hadeed.hadeed

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingFile: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ye.hadeed/local").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "notificationPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) result.success(true)
                        else if (pendingPermission != null) result.error("busy", "طلب إذن جارٍ", null)
                        else { pendingPermission = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 93) }
                    }
                    "scheduleAlarm" -> {
                        RestAlarm.schedule(this, call.argument<Number>("deadline")!!.toLong(), call.argument<Boolean>("sound") ?: false, call.argument<Boolean>("vibration") ?: false)
                        result.success(null)
                    }
                    "cancelAlarm" -> { RestAlarm.cancel(this); result.success(null) }
                    "notifyNow" -> {
                        RestAlarm.cancel(this)
                        RestAlarm.notify(this, call.argument<Boolean>("sound") ?: false, call.argument<Boolean>("vibration") ?: false)
                        result.success(null)
                    }
                    "exportFile", "importFile" -> {
                        if (pendingFile != null) result.error("busy", "اختيار ملف جارٍ", null)
                        else {
                            pendingFile = result
                            if (call.method == "exportFile") {
                                exportBytes = call.argument<ByteArray>("bytes")!!
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/octet-stream").putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                                startActivityForResult(intent, 94)
                            } else {
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"), 95)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                pendingFile = null; exportBytes = null
                result.error("local_error", e.message, null)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 93) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 94 && requestCode != 95) return
        val result = pendingFile ?: return
        val bytes = exportBytes
        pendingFile = null; exportBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(null); return }
        Thread {
            try {
                if (requestCode == 94) {
                    contentResolver.openOutputStream(uri, "w").use { stream ->
                        requireNotNull(stream).write(requireNotNull(bytes))
                    }
                    runOnUiThread { result.success(true) }
                } else {
                    val imported = contentResolver.openInputStream(uri).use { stream ->
                        val out = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        val input = requireNotNull(stream)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            if (out.size() + n > 64 * 1024 * 1024) throw IllegalArgumentException("النسخة أكبر من 64 ميجابايت")
                            out.write(buffer, 0, n)
                        }
                        out.toByteArray()
                    }
                    runOnUiThread { result.success(imported) }
                }
            } catch (e: Exception) { runOnUiThread { result.error("file_error", e.message, null) } }
        }.start()
    }
}
