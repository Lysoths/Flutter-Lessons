package com.ogzhner.flutter_ders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// DERS 21 — Platform channel. Kanallar Flutter motoru hazır olunca kurulur;
// asıl iş SmsChannel.kt dosyasında.
class MainActivity : FlutterActivity() {
    private var sms: SmsChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sms = SmsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sms?.dispose()
        sms = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // İzin penceresinin cevabı Activity'ye gelir; SMS kanalına iletilir.
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sms?.onPermissionResult(requestCode, grantResults)
    }
}
