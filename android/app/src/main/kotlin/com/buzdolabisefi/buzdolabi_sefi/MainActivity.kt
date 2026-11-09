package com.buzdolabisefi.buzdolabi_sefi

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// TikTok / Instagram Paylaş → Buzdolabı Şefi.
/// Dart: lib/services/video_import.dart → ShareInbox (kanal: buzdolabi_sefi/share).
class MainActivity : FlutterActivity() {
  private val pending = mutableListOf<Map<String, String?>>()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "takePending" -> {
            val out = pending.toList()
            pending.clear()
            result.success(out)
          }
          else -> result.notImplemented()
        }
      }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    ingestIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    ingestIntent(intent)
  }

  private fun ingestIntent(intent: Intent?) {
    if (intent == null) return
    val action = intent.action ?: return
    if (action != Intent.ACTION_SEND) return
    val type = intent.type ?: return
    if (!type.startsWith("text/")) return

    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
    val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
    if (text.isNullOrBlank() && subject.isNullOrBlank()) return

    val combined = listOfNotNull(text, subject).joinToString("\n")
    val url = URL_RE.find(combined)?.value?.trimEnd(')', '.', ',', '"', '\'')
    pending.add(
      mapOf(
        "url" to url,
        "text" to text,
      ),
    )
  }

  companion object {
    private const val CHANNEL = "buzdolabi_sefi/share"
    private val URL_RE = Regex("""https?://\S+""")
  }
}
