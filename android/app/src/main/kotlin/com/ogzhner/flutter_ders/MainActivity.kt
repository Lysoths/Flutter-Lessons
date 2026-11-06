package com.ogzhner.flutter_ders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// DERS 21–22 — Platform channel. Kanallar Flutter motoru hazır olunca
// kurulur; asıl iş SmsChannel.kt ve HardwareChannel.kt dosyalarında.
class MainActivity : FlutterActivity() {
    private var sms: SmsChannel? = null
    private var hardware: HardwareChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        sms = SmsChannel(this, messenger)
        hardware = HardwareChannel(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sms?.dispose()
        hardware?.dispose()
        sms = null
        hardware = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // İzin penceresinin cevabı Activity'ye gelir; istek koduna göre ilgili
    // kanal kendi cevabını alır (SMS 2101, telefon 2201).
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sms?.onPermissionResult(requestCode, grantResults)
        hardware?.onPermissionResult(requestCode)
    }
}
