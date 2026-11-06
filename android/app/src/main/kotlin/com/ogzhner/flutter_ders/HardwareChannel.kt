package com.ogzhner.flutter_ders

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.SystemClock
import android.provider.Settings
import android.telephony.TelephonyManager
import android.view.Display
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────────────────
// DERS 22 — Donanım kanalı (Kotlin tarafı)
//
// Ders 14'te device_info_plus paketinin verdiğini okuduk; burada paketin
// vermediklerini de (pil sağlığı, sıcaklık, akım, çekirdek frekansları,
// kameralar, sensörler, SIM) Android API'lerinden kendimiz topluyoruz.
//
//   MethodChannel "flutter_ders/donanim"
//     profil           → { kimlik, sistem, islemci, bellek, depolama, pil,
//                          ekran, kameralar[], sensorler[], ozellikler{},
//                          telefon }
//     imei             → Android 10+ normal uygulamaya vermez: hata döner
//     telefonIzni      → READ_PHONE_STATE var mı (Boolean)
//     telefonIzniIste  → izin penceresi; cevap onRequestPermissionsResult
//
//   EventChannel  "flutter_ders/donanim/canli"
//     saniyede bir: pil yüzdesi, sıcaklık, akım, boş RAM, çekirdek frekansı
//
// Kanal yalnız okur; hiçbir değer kaydedilmez ya da log'a yazılmaz.
// ─────────────────────────────────────────────────────────────────────────
class HardwareChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "flutter_ders/donanim")
    private val events = EventChannel(messenger, "flutter_ders/donanim/canli")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var ticker: Runnable? = null
    private var pendingPermission: MethodChannel.Result? = null

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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "profil" -> {
                // Ekran bilgisi ana iş parçacığında, gerisi arka planda.
                val screen = display()
                worker.execute {
                    try {
                        val p = profile(screen)
                        main.post { result.success(p) }
                    } catch (e: Exception) {
                        main.post { result.error("okunamadi", e.javaClass.simpleName, null) }
                    }
                }
            }
            "imei" -> readImei(result)
            "telefonIzni" -> result.success(phoneGranted())
            "telefonIzniIste" -> {
                if (phoneGranted()) {
                    result.success(true)
                    return
                }
                pendingPermission?.error("iptal", "Yeni izin isteği geldi.", null)
                pendingPermission = result
                activity.requestPermissions(
                    arrayOf(Manifest.permission.READ_PHONE_STATE),
                    REQUEST_CODE,
                )
            }
            else -> result.notImplemented()
        }
    }

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != REQUEST_CODE) return
        pendingPermission?.success(phoneGranted())
        pendingPermission = null
    }

    private fun phoneGranted() =
        activity.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED

    // ── IMEI ─────────────────────────────────────────────────────────────

    // Android 10'dan (API 29) beri IMEI yalnız READ_PRIVILEGED_PHONE_STATE
    // iznine sahip sistem / operatör uygulamalarına verilir. Bu izin normal
    // uygulamaya hiç verilmez; çağrı SecurityException atar. Bunu bilerek
    // deniyor ve hatayı Dart'a taşıyoruz: kanalın hata yolunu da görürüz.
    @SuppressLint("HardwareIds", "MissingPermission")
    private fun readImei(result: MethodChannel.Result) {
        val tm = activity.getSystemService(TelephonyManager::class.java)
        if (tm == null) {
            result.error("telefon_yok", "Bu cihazda telefon donanımı yok.", null)
            return
        }
        try {
            val imei = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                tm.imei
            } else {
                @Suppress("DEPRECATION")
                tm.deviceId
            }
            if (imei.isNullOrEmpty()) {
                result.error("bos", "Android boş değer döndürdü.", null)
            } else {
                result.success(imei)
            }
        } catch (e: SecurityException) {
            result.error("sistem_izni", e.message ?: "SecurityException", Build.VERSION.SDK_INT)
        }
    }

    // ── Profil ───────────────────────────────────────────────────────────

    private fun profile(screen: Map<String, Any?>): Map<String, Any?> = mapOf(
        "kimlik" to identity(),
        "sistem" to system(),
        "islemci" to cpu(),
        "bellek" to memory(),
        "depolama" to storage(),
        "pil" to battery(),
        "ekran" to screen,
        "kameralar" to cameras(),
        "sensorler" to sensors(),
        "ozellikler" to features(),
        "telefon" to telephony(),
    )

    @SuppressLint("HardwareIds")
    private fun identity() = mapOf(
        "uretici" to Build.MANUFACTURER,
        "marka" to Build.BRAND,
        "model" to Build.MODEL,
        "cihaz" to Build.DEVICE,
        "urun" to Build.PRODUCT,
        "donanim" to Build.HARDWARE,
        "kart" to Build.BOARD,
        // Uygulamanın imza anahtarına ve kullanıcıya özel 64 bit kimlik.
        // Fabrika ayarına dönünce değişir; başka uygulama farklısını görür.
        "androidId" to Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ),
    )

    private fun system() = mapOf(
        "surum" to Build.VERSION.RELEASE,
        "sdk" to Build.VERSION.SDK_INT,
        "yama" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else null),
        "derleme" to Build.DISPLAY,
        "parmakIzi" to Build.FINGERPRINT,
        "bootloader" to Build.BOOTLOADER,
        "cekirdek" to System.getProperty("os.version"),
        "derlemeZamani" to Build.TIME,
        "acikKalma" to SystemClock.elapsedRealtime(),
        "dil" to Locale.getDefault().toLanguageTag(),
        "saatDilimi" to TimeZone.getDefault().id,
    )

    private fun readText(path: String): String? = try {
        File(path).readText().trim().ifEmpty { null }
    } catch (_: Exception) {
        null
    }

    private fun coreFreqs(file: String): List<Int?> {
        val cores = Runtime.getRuntime().availableProcessors()
        return (0 until cores).map { i ->
            readText("/sys/devices/system/cpu/cpu$i/cpufreq/$file")?.toIntOrNull()
        }
    }

    private fun cpu() = mapOf(
        "cekirdekSayisi" to Runtime.getRuntime().availableProcessors(),
        "abiler" to Build.SUPPORTED_ABIS.toList(),
        "socUretici" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MANUFACTURER else null),
        "socModel" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else null),
        // kHz; bazı üreticiler bu dosyaları kapatır → null.
        "enYuksekKhz" to coreFreqs("cpuinfo_max_freq"),
        "enDusukKhz" to coreFreqs("cpuinfo_min_freq"),
    )

    private fun memory(): Map<String, Any?> {
        val am = activity.getSystemService(ActivityManager::class.java)
        val info = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        return mapOf(
            "toplam" to info.totalMem,
            "bos" to info.availMem,
            "esik" to info.threshold,
            "dusuk" to info.lowMemory,
            "uygulamaSiniriMb" to am.memoryClass,
        )
    }

    private fun storage(): Map<String, Any?> {
        val s = StatFs(Environment.getDataDirectory().path)
        return mapOf("toplam" to s.totalBytes, "bos" to s.availableBytes)
    }

    private fun batteryIntent(): Intent? =
        activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

    private fun currentMicroAmps(bm: BatteryManager): Int? {
        val raw = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        if (raw == Int.MIN_VALUE || raw == 0) return null
        // Belge µA der; bazı cihazlar mA verir. Küçük değerleri mA sayarız.
        return if (kotlin.math.abs(raw) < 10_000) raw * 1000 else raw
    }

    private fun battery(): Map<String, Any?> {
        val i = batteryIntent()
        val bm = activity.getSystemService(BatteryManager::class.java)
        val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val health = when (i?.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "iyi"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "asiri_isinma"
            BatteryManager.BATTERY_HEALTH_DEAD -> "olu"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "yuksek_voltaj"
            BatteryManager.BATTERY_HEALTH_COLD -> "soguk"
            else -> "bilinmiyor"
        }
        val status = when (i?.getIntExtra(BatteryManager.EXTRA_STATUS, 0)) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "sarj_oluyor"
            BatteryManager.BATTERY_STATUS_FULL -> "dolu"
            BatteryManager.BATTERY_STATUS_DISCHARGING,
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "desarj"
            else -> "bilinmiyor"
        }
        val plug = when (i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)) {
            BatteryManager.BATTERY_PLUGGED_AC -> "priz"
            BatteryManager.BATTERY_PLUGGED_USB -> "usb"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "kablosuz"
            else -> null
        }
        val cycles = if (Build.VERSION.SDK_INT >= 34) {
            i?.getIntExtra(BatteryManager.EXTRA_CYCLE_COUNT, -1)?.takeIf { it >= 0 }
        } else {
            null
        }
        val counter = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        return mapOf(
            "yuzde" to (if (level >= 0 && scale > 0) level * 100 / scale else null),
            "durum" to status,
            "saglik" to health,
            "kaynak" to plug,
            "sicaklik" to i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?.takeIf { it != Int.MIN_VALUE }?.let { it / 10.0 },
            "voltajMv" to i?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)?.takeIf { it > 0 },
            "teknoloji" to i?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY),
            "dongu" to cycles,
            "sarjMah" to (if (counter > 0) counter / 1000 else null),
            "akimUa" to currentMicroAmps(bm),
        )
    }

    private fun display(): Map<String, Any?> {
        val d: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay
        }
        val dm = activity.resources.displayMetrics
        val mode = d?.mode
        val rates = d?.supportedModes?.map { it.refreshRate.toDouble() }?.distinct()?.sorted()
        @Suppress("DEPRECATION")
        val hdr = d?.hdrCapabilities?.supportedHdrTypes?.map {
            when (it) {
                Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> "Dolby Vision"
                Display.HdrCapabilities.HDR_TYPE_HDR10 -> "HDR10"
                Display.HdrCapabilities.HDR_TYPE_HLG -> "HLG"
                Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS -> "HDR10+"
                else -> "HDR($it)"
            }
        }
        return mapOf(
            "genislik" to (mode?.physicalWidth ?: dm.widthPixels),
            "yukseklik" to (mode?.physicalHeight ?: dm.heightPixels),
            "dpi" to dm.densityDpi,
            "xdpi" to dm.xdpi.toDouble(),
            "ydpi" to dm.ydpi.toDouble(),
            "yenileme" to d?.refreshRate?.toDouble(),
            "yenilemeler" to rates,
            "hdr" to hdr,
            "yaziOlcegi" to activity.resources.configuration.fontScale.toDouble(),
        )
    }

    private fun cameras(): List<Map<String, Any?>> {
        val cm = activity.getSystemService(CameraManager::class.java) ?: return emptyList()
        return cm.cameraIdList.mapNotNull { id ->
            try {
                val c = cm.getCameraCharacteristics(id)
                val size = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                mapOf(
                    "id" to id,
                    "yon" to when (c.get(CameraCharacteristics.LENS_FACING)) {
                        CameraCharacteristics.LENS_FACING_FRONT -> "on"
                        CameraCharacteristics.LENS_FACING_BACK -> "arka"
                        else -> "harici"
                    },
                    "megapiksel" to size?.let { it.width.toLong() * it.height / 1_000_000.0 },
                    "odakUzakliklari" to c.get(
                        CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS,
                    )?.map { it.toDouble() },
                    "flas" to (c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true),
                    "ois" to (
                        c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)
                            ?.any { it == CameraCharacteristics.LENS_OPTICAL_STABILIZATION_MODE_ON } == true
                        ),
                )
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun sensors(): List<Map<String, Any?>> {
        val sm = activity.getSystemService(SensorManager::class.java) ?: return emptyList()
        return sm.getSensorList(Sensor.TYPE_ALL).map {
            mapOf(
                "ad" to it.name,
                "uretici" to it.vendor,
                "tur" to it.stringType,
                "gucMa" to it.power.toDouble(),
                "aralik" to it.maximumRange.toDouble(),
                "uyandirir" to it.isWakeUpSensor,
            )
        }
    }

    private fun features(): Map<String, Boolean> {
        val pm = activity.packageManager
        val list = mapOf(
            "nfc" to PackageManager.FEATURE_NFC,
            "parmakIzi" to PackageManager.FEATURE_FINGERPRINT,
            "yuzTanima" to "android.hardware.biometrics.face",
            "esim" to "android.hardware.telephony.euicc",
            "telefon" to PackageManager.FEATURE_TELEPHONY,
            "bluetoothLe" to PackageManager.FEATURE_BLUETOOTH_LE,
            "wifiAware" to "android.hardware.wifi.aware",
            "wifiDirect" to PackageManager.FEATURE_WIFI_DIRECT,
            "uwb" to "android.hardware.uwb",
            "kizilotesi" to PackageManager.FEATURE_CONSUMER_IR,
            "barometre" to PackageManager.FEATURE_SENSOR_BAROMETER,
            "adimSayar" to PackageManager.FEATURE_SENSOR_STEP_COUNTER,
            "usbHost" to PackageManager.FEATURE_USB_HOST,
            "strongbox" to "android.hardware.strongbox_keystore",
            "vulkan" to "android.hardware.vulkan.version",
            "arCore" to "android.hardware.camera.ar",
        )
        return list.mapValues { (_, feature) -> pm.hasSystemFeature(feature) }
    }

    @SuppressLint("MissingPermission")
    private fun telephony(): Map<String, Any?> {
        val tm = activity.getSystemService(TelephonyManager::class.java)
            ?: return mapOf("var" to false)
        val granted = phoneGranted()
        val modems = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            tm.activeModemCount
        } else {
            @Suppress("DEPRECATION")
            tm.phoneCount
        }
        // İzinli alanlar: izin yoksa hiç sorulmaz (SecurityException olmasın).
        val network = if (granted) {
            try {
                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    tm.dataNetworkType
                } else {
                    @Suppress("DEPRECATION")
                    tm.networkType
                }
                networkName(type)
            } catch (_: SecurityException) {
                null
            }
        } else {
            null
        }
        val activeSims = if (granted) {
            try {
                activity.getSystemService(android.telephony.SubscriptionManager::class.java)
                    ?.activeSubscriptionInfoCount
            } catch (_: SecurityException) {
                null
            }
        } else {
            null
        }
        return mapOf(
            "var" to true,
            "izin" to granted,
            "operator" to tm.networkOperatorName?.ifEmpty { null },
            "simOperator" to tm.simOperatorName?.ifEmpty { null },
            "simUlke" to tm.simCountryIso?.uppercase()?.ifEmpty { null },
            "agUlke" to tm.networkCountryIso?.uppercase()?.ifEmpty { null },
            "dolasim" to tm.isNetworkRoaming,
            "yuva" to modems,
            "aktifSim" to activeSims,
            "ag" to network,
            "tur" to when (tm.phoneType) {
                TelephonyManager.PHONE_TYPE_GSM -> "GSM"
                TelephonyManager.PHONE_TYPE_CDMA -> "CDMA"
                TelephonyManager.PHONE_TYPE_SIP -> "SIP"
                else -> "Yok"
            },
        )
    }

    private fun networkName(type: Int) = when (type) {
        TelephonyManager.NETWORK_TYPE_NR -> "5G"
        TelephonyManager.NETWORK_TYPE_LTE -> "4G (LTE)"
        TelephonyManager.NETWORK_TYPE_HSPAP,
        TelephonyManager.NETWORK_TYPE_HSPA,
        TelephonyManager.NETWORK_TYPE_HSDPA,
        TelephonyManager.NETWORK_TYPE_HSUPA,
        TelephonyManager.NETWORK_TYPE_UMTS -> "3G"
        TelephonyManager.NETWORK_TYPE_EDGE,
        TelephonyManager.NETWORK_TYPE_GPRS -> "2G"
        TelephonyManager.NETWORK_TYPE_IWLAN -> "Wi-Fi araması"
        TelephonyManager.NETWORK_TYPE_UNKNOWN -> "Bağlı değil"
        else -> "Diğer ($type)"
    }

    // ── EventChannel: canlı ölçümler ─────────────────────────────────────

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        onCancel(null)
        val bm = activity.getSystemService(BatteryManager::class.java)
        val am = activity.getSystemService(ActivityManager::class.java)
        val tick = object : Runnable {
            override fun run() {
                val i = batteryIntent()
                val mem = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                sink.success(
                    mapOf(
                        "zaman" to System.currentTimeMillis(),
                        "pil" to bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
                        "sicaklik" to i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                            ?.takeIf { it != Int.MIN_VALUE }?.let { it / 10.0 },
                        "akimUa" to currentMicroAmps(bm),
                        "sarjOluyor" to bm.isCharging,
                        "bosRam" to mem.availMem,
                        "anlikKhz" to coreFreqs("scaling_cur_freq"),
                    ),
                )
                main.postDelayed(this, 1000)
            }
        }
        ticker = tick
        main.post(tick)
    }

    override fun onCancel(arguments: Any?) {
        ticker?.let { main.removeCallbacks(it) }
        ticker = null
    }

    private companion object {
        const val REQUEST_CODE = 2201
    }
}
