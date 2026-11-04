import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ders/app/models/info_section.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// DERS 14 — Uygulamanın kendisi hakkında bilgi.
abstract interface class AppInfoRepository {
  /// Uygulama, derleme ve Flutter bilgisini okur.
  Future<List<InfoSection>> read();
}

/// `package_info_plus` (Android PackageManager), `FlutterVersion` ve
/// derleme sabitleriyle okur.
class PlatformAppInfoRepository implements AppInfoRepository {
  @override
  Future<List<InfoSection>> read() async {
    final p = await PackageInfo.fromPlatform();
    const mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    final locales = PlatformDispatcher.instance.locales;
    return [
      InfoSection(
        id: 'app',
        title: 'Uygulama (PackageInfo)',
        entries: [
          InfoEntry('Ad', orDash(p.appName)),
          InfoEntry('Paket adı', orDash(p.packageName)),
          InfoEntry('Sürüm', orDash(p.version)),
          InfoEntry('Derleme numarası', orDash(p.buildNumber)),
          InfoEntry(
            'Yükleyen mağaza',
            p.installerStore ?? 'Yok (adb / flutter run)',
          ),
          InfoEntry('İlk kurulum', _date(p.installTime)),
          InfoEntry('Son güncelleme', _date(p.updateTime)),
          InfoEntry('İmza (SHA)', orDash(p.buildSignature)),
        ],
      ),
      InfoSection(
        id: 'flutter',
        title: 'Flutter ve derleme',
        entries: [
          const InfoEntry('Derleme modu', mode),
          InfoEntry('Flutter', orDash(FlutterVersion.version)),
          InfoEntry('Kanal', orDash(FlutterVersion.channel)),
          InfoEntry('Framework', _short(FlutterVersion.frameworkRevision)),
          InfoEntry('Engine', _short(FlutterVersion.engineRevision)),
          InfoEntry('Dart', Platform.version.split(' ').first),
          InfoEntry('Hedef platform', defaultTargetPlatform.name),
          InfoEntry('Web mi', orDash(kIsWeb)),
          InfoEntry('Sistem dilleri', locales.map((l) => '$l').join(', ')),
          InfoEntry(
            'Ekran okuyucu açık',
            orDash(PlatformDispatcher.instance.semanticsEnabled),
          ),
        ],
      ),
    ];
  }
}

String _short(String? hash) =>
    hash == null ? '—' : hash.substring(0, hash.length.clamp(0, 10));

String _date(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}
