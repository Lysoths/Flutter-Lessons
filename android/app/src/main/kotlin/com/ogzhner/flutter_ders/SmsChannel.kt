package com.ogzhner.flutter_ders

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────────────────
// DERS 21 — SMS kanalı (Kotlin tarafı)
//
// Flutter SMS'lere doğrudan erişemez; bu sınıf Android'in SMS sağlayıcısını
// ve "SMS geldi" yayınını Dart'a bağlar.
//
//   MethodChannel "flutter_ders/sms"           (istek → tek cevap)
//     izinDurumu        → {"durum": "verildi" | "reddedildi" | "kalici"}
//     izinIste          → aynı harita, kullanıcı pencereyi kapatınca
//     gelenKutusu(gun, sinir, gonderenler) → [{id, adres, govde, tarih}]
//     ayarlariAc        → uygulamanın ayar sayfası
//
//   EventChannel  "flutter_ders/sms/gelen"     (sürekli akış)
//     dinleme başlayınca yayın alıcısı kaydolur, her yeni banka SMS'i
//     {adres, govde, tarih} olarak Dart'taki Stream'e düşer.
//
// Gizlilik: Dart'tan gelen banka adı listesi ("gonderenler") burada
// uygulanır; banka dışı SMS'ler kanaldan hiç geçmez. Hiçbir şey kaydedilmez
// ya da log'a yazılmaz.
// ─────────────────────────────────────────────────────────────────────────
class SmsChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "flutter_ders/sms")
    private val events = EventChannel(messenger, "flutter_ders/sms/gelen")

    // Gelen kutusu sorgusu ana iş parçacığını kilitlemesin diye.
    private val worker = Executors.newSingleThreadExecutor()

    private var pendingPermission: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private var asked = false

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        onCancel(null)
        worker.shutdown()
    }

    // ── MethodChannel ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "izinDurumu" -> result.success(mapOf("durum" to accessState()))
            "izinIste" -> requestPermission(result)
            "gelenKutusu" -> readInbox(call, result)
            "ayarlariAc" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", activity.packageName, null))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun accessState(): String = when {
        granted(Manifest.permission.READ_SMS) &&
            granted(Manifest.permission.RECEIVE_SMS) -> "verildi"
        // Kullanıcı bir kez reddettiyse Android "açıklama göster" der; iki kez
        // reddedip "bir daha sorma" dediyse demez → yalnız ayarlardan açılır.
        asked && !activity.shouldShowRequestPermissionRationale(
            Manifest.permission.READ_SMS,
        ) -> "kalici"
        else -> "reddedildi"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (accessState() == "verildi") {
            result.success(mapOf("durum" to "verildi"))
            return
        }
        // Aynı anda iki pencere açılmasın.
        pendingPermission?.error("iptal", "Yeni izin isteği geldi.", null)
        pendingPermission = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
            REQUEST_CODE,
        )
    }

    fun onPermissionResult(requestCode: Int, @Suppress("UNUSED_PARAMETER") grants: IntArray) {
        if (requestCode != REQUEST_CODE) return
        asked = true
        pendingPermission?.success(mapOf("durum" to accessState()))
        pendingPermission = null
    }

    private fun readInbox(call: MethodCall, result: MethodChannel.Result) {
        if (!granted(Manifest.permission.READ_SMS)) {
            result.error("izin_yok", "SMS okuma izni verilmedi.", null)
            return
        }
        val days = call.argument<Int>("gun") ?: 90
        val limit = call.argument<Int>("sinir") ?: 300
        val senders = call.argument<List<String>>("gonderenler") ?: emptyList()
        val since = System.currentTimeMillis() - days * DAY_MS

        worker.execute {
            try {
                val list = mutableListOf<Map<String, Any>>()
                activity.contentResolver.query(
                    Telephony.Sms.Inbox.CONTENT_URI,
                    arrayOf(
                        Telephony.Sms._ID,
                        Telephony.Sms.ADDRESS,
                        Telephony.Sms.BODY,
                        Telephony.Sms.DATE,
                    ),
                    "${Telephony.Sms.DATE} >= ?",
                    arrayOf(since.toString()),
                    "${Telephony.Sms.DATE} DESC",
                )?.use { c ->
                    val id = c.getColumnIndexOrThrow(Telephony.Sms._ID)
                    val address = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                    val body = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
                    val date = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
                    while (c.moveToNext() && list.size < limit) {
                        val from = c.getString(address) ?: continue
                        if (!isBank(from, senders)) continue
                        list.add(
                            mapOf(
                                "id" to c.getLong(id).toInt(),
                                "adres" to from,
                                "govde" to (c.getString(body) ?: ""),
                                "tarih" to c.getLong(date),
                            ),
                        )
                    }
                }
                activity.runOnUiThread { result.success(list) }
            } catch (e: Exception) {
                // Mesaj metni değil, yalnız hata türü döner.
                activity.runOnUiThread {
                    result.error("okunamadi", e.javaClass.simpleName, null)
                }
            }
        }
    }

    // ── EventChannel ─────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        if (!granted(Manifest.permission.RECEIVE_SMS)) {
            sink.error("izin_yok", "SMS alma izni verilmedi.", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val senders = (arguments as? Map<String, Any?>)?.get("gonderenler")
            as? List<String> ?: emptyList()
        onCancel(null)
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    ?: return
                // Uzun SMS birkaç parça gelir; gönderene göre birleştirilir.
                parts.filterNotNull()
                    .groupBy { it.originatingAddress ?: "" }
                    .forEach { (from, pieces) ->
                        if (from.isEmpty() || !isBank(from, senders)) return@forEach
                        sink.success(
                            mapOf(
                                "adres" to from,
                                "govde" to pieces.joinToString("") {
                                    it.messageBody ?: ""
                                },
                                "tarih" to pieces.first().timestampMillis,
                            ),
                        )
                    }
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        // Yayını telefon uygulaması (başka bir süreç) gönderir: alıcı
        // dışarıya açık olmalı. İzni olmayan biri bu yayını zaten yollayamaz.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
        } else {
            activity.registerReceiver(r, filter)
        }
        receiver = r
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            try {
                activity.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        receiver = null
    }

    // ── Ortak ────────────────────────────────────────────────────────────

    /** Dart'taki normalizeSender + bankOf ile aynı kural. */
    private fun isBank(sender: String, keys: List<String>): Boolean {
        val s = normalize(sender)
        if (s.isEmpty()) return false
        return keys.any { key ->
            if (key.length < 4) {
                s == key || (s.startsWith(key) && s.length <= key.length + 4)
            } else {
                s.contains(key)
            }
        }
    }

    private fun normalize(s: String): String {
        val map = mapOf(
            'ç' to 'C', 'Ç' to 'C', 'ğ' to 'G', 'Ğ' to 'G', 'ı' to 'I', 'İ' to 'I',
            'ö' to 'O', 'Ö' to 'O', 'ş' to 'S', 'Ş' to 'S', 'ü' to 'U', 'Ü' to 'U',
        )
        val b = StringBuilder()
        for (ch in s) {
            val c = map[ch] ?: ch.toString().uppercase(Locale.ROOT).first()
            if (c in 'A'..'Z' || c in '0'..'9') b.append(c)
        }
        return b.toString()
    }

    private companion object {
        const val REQUEST_CODE = 2101
        const val DAY_MS = 24L * 60 * 60 * 1000
    }
}
