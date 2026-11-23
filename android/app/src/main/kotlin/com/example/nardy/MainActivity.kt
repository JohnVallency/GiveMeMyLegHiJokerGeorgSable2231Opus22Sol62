package com.example.nardy

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "club/chess2").setMethodCallHandler { call, result ->
            if (call.method == "open") {
                try {
                    val intent = Intent(this, ChessActivity::class.java)
                        .putExtra("club_origin", call.argument<String>("origin"))
                        .putExtra("club_ticket", call.argument<String>("ticket"))
                    startActivity(intent)
                    result.success(null)
                }
                catch (e: Exception) { result.error("CHESS_OPEN", e.message, null) }
            } else result.notImplemented()
        }
    }
}
