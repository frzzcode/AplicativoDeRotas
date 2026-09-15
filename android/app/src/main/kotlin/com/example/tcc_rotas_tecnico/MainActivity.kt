package com.example.tcc_rotas_tecnico

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tcc_rotas/maps")
            .setMethodCallHandler { call, result ->
                if (call.method != "abrir") {
                    result.notImplemented()
                } else {
                    val uri = Uri.parse(call.arguments as? String ?: "")
                    if (uri.scheme != "https" || uri.host != "www.google.com" || uri.path != "/maps/dir/") {
                        result.error("URL", "Link inválido", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("MAPS", "Nenhum aplicativo disponível", null)
                        }
                    }
                }
            }
    }
}
