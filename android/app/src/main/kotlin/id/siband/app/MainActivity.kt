package id.siband.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "id.siband.app/share"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    val text = call.argument<String>("text")
                    val subject = call.argument<String>("subject")
                    if (text.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Teks berbagi kosong", null)
                        return@setMethodCallHandler
                    }
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                        if (!subject.isNullOrBlank()) {
                            putExtra(Intent.EXTRA_SUBJECT, subject)
                        }
                    }
                    val chooser = Intent.createChooser(
                        sendIntent,
                        subject ?: "Bagikan Rekap Siband",
                    )
                    startActivity(chooser)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
