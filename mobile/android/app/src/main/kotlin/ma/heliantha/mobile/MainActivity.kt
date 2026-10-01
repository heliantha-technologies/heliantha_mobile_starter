package ma.heliantha.mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val text = call.argument<String>("text")?.trim().orEmpty()
            val subject = call.argument<String>("subject")?.trim().orEmpty()
            if (text.isEmpty()) {
                result.error("empty_text", "Share text is empty.", null)
                return@setMethodCallHandler
            }

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (subject.isNotEmpty()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }
            val chooserTitle = subject.ifEmpty { "Partager" }
            try {
                startActivity(Intent.createChooser(sendIntent, chooserTitle))
                result.success(null)
            } catch (error: Exception) {
                result.error("share_failed", error.message, null)
            }
        }
    }

    companion object {
        private const val SHARE_CHANNEL = "ma.heliantha.mobile/share"
    }
}
