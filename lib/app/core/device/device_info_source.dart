import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_ders/app/helper/measure_format.dart';
import 'package:flutter_ders/app/models/info_section.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 14 — Cihaz bilgisi
//
// İki kaynak:
//   device_info_plus → Android'in `Build`, `ActivityManager`, `StatFs` ve
//                      `PackageManager` sınıfları (marka, model, RAM, disk,
//                      sistem özellikleri ...)
//   dart:io Platform → Dart'ın gördüğü işletim sistemi, çekirdek sayısı, dil
//
// Ekran boyutu ve yoğunluğu burada DEĞİL: onlar telefon dönünce değişir,
// ekranda MediaQuery ile canlı okunur.
// ─────────────────────────────────────────────────────────────────────────

/// Cihazdan okunan her şey.
typedef DeviceInfoReport = ({
  List<InfoSection> sections,
  List<String> systemFeatures,
  Map<String, Object?> raw,
});

/// Cihaz bilgisinin kaynağı; testte sahtesi verilir.
abstract interface class DeviceInfoSource {
  /// Cihaz bilgisini okur (Android'de bir kanal çağrısı, ≈ 10–50 ms).
  Future<DeviceInfoReport> read();
}

/// `device_info_plus` ve `dart:io` ile okur.
class PlusDeviceInfoSource implements DeviceInfoSource {
  /// Kaynak oluşturur.
  PlusDeviceInfoSource([DeviceInfoPlugin? plugin])
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  Future<DeviceInfoReport> read() async {
    if (Platform.isAndroid) return _android(await _plugin.androidInfo);
    final info = await _plugin.deviceInfo;
    return (
      sections: [
        InfoSection(
          id: 'identity',
          title: 'Cihaz',
          entries: [
            for (final e in info.data.entries)
              if (e.value is! Map) InfoEntry(e.key, orDash(e.value)),
          ],
        ),
        _runtime(),
      ],
      systemFeatures: const <String>[],
      raw: info.data,
    );
  }

  DeviceInfoReport _android(AndroidDeviceInfo a) {
    final v = a.version;
    // RAM megabayt, disk bayt olarak gelir.
    const mb = 1024 * 1024;
    final ramUsed = a.physicalRamSize - a.availableRamSize;
    final diskUsed = a.totalDiskSize - a.freeDiskSize;
    String percent(int part, int whole) =>
        whole == 0 ? '' : ' (%${(part * 100 / whole).round()})';
    return (
      sections: [
        InfoSection(
          id: 'identity',
          title: 'Kimlik',
          entries: [
            InfoEntry('Marka', orDash(a.brand)),
            InfoEntry('Üretici', orDash(a.manufacturer)),
            InfoEntry('Model', orDash(a.model)),
            InfoEntry('Kod adı (device)', orDash(a.device)),
            InfoEntry('Ürün (product)', orDash(a.product)),
            InfoEntry('Gerçek cihaz', a.isPhysicalDevice ? 'Evet' : 'Emülatör'),
            InfoEntry('Düşük RAM cihazı', orDash(a.isLowRamDevice)),
          ],
        ),
        InfoSection(
          id: 'os',
          title: 'Android sürümü',
          entries: [
            InfoEntry('Android', orDash(v.release)),
            InfoEntry('API seviyesi (SDK)', '${v.sdkInt}'),
            InfoEntry('Güvenlik yaması', orDash(v.securityPatch)),
            InfoEntry('Kod adı', orDash(v.codename)),
            InfoEntry('Önizleme SDK', orDash(v.previewSdkInt)),
            InfoEntry('Artımlı sürüm', orDash(v.incremental)),
            InfoEntry('Temel OS', orDash(v.baseOS)),
          ],
        ),
        InfoSection(
          id: 'build',
          title: 'Yazılım derlemesi (Build)',
          entries: [
            InfoEntry('Görünen ad (display)', orDash(a.display)),
            InfoEntry('Derleme kimliği (id)', orDash(a.id)),
            InfoEntry(
              'Derleme zamanı',
              _date(DateTime.fromMillisecondsSinceEpoch(a.time)),
            ),
            InfoEntry('Tür', orDash(a.type)),
            InfoEntry('Etiketler', orDash(a.tags)),
            InfoEntry('Derleyen makine', orDash(a.host)),
            InfoEntry('Önyükleyici', orDash(a.bootloader)),
            InfoEntry('Parmak izi (fingerprint)', orDash(a.fingerprint)),
          ],
        ),
        InfoSection(
          id: 'hardware',
          title: 'Donanım',
          entries: [
            InfoEntry('Yonga (hardware)', orDash(a.hardware)),
            InfoEntry('Kart (board)', orDash(a.board)),
            InfoEntry('İşlemci çekirdeği', '${Platform.numberOfProcessors}'),
            InfoEntry('Desteklenen ABI', orDash(a.supportedAbis)),
            InfoEntry('64 bit ABI', orDash(a.supported64BitAbis)),
            InfoEntry('32 bit ABI', orDash(a.supported32BitAbis)),
          ],
        ),
        InfoSection(
          id: 'memory',
          title: 'Bellek ve depolama',
          entries: [
            InfoEntry('Toplam RAM', formatBytes(a.physicalRamSize * mb)),
            InfoEntry(
              'Kullanılan RAM',
              '${formatBytes(ramUsed * mb)}'
                  '${percent(ramUsed, a.physicalRamSize)}',
            ),
            InfoEntry('Boş RAM', formatBytes(a.availableRamSize * mb)),
            InfoEntry('Toplam disk', formatBytes(a.totalDiskSize)),
            InfoEntry(
              'Kullanılan disk',
              '${formatBytes(diskUsed)}${percent(diskUsed, a.totalDiskSize)}',
            ),
            InfoEntry('Boş disk', formatBytes(a.freeDiskSize)),
          ],
        ),
        _runtime(),
      ],
      systemFeatures: [...a.systemFeatures]..sort(),
      raw: a.data,
    );
  }

  InfoSection _runtime() => InfoSection(
    id: 'runtime',
    title: 'Dart çalışma ortamı (dart:io)',
    entries: [
      InfoEntry('İşletim sistemi', Platform.operatingSystem),
      InfoEntry('OS sürüm metni', Platform.operatingSystemVersion),
      InfoEntry('Dil (locale)', Platform.localeName),
      InfoEntry('Saat dilimi', DateTime.now().timeZoneName),
      InfoEntry('Dart sürümü', Platform.version.split(' ').first),
    ],
  );
}

String _date(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}
