// ignore_for_file: type=lint
//
// ─────────────────────────────────────────────────────────────────────────
// ÖRNEK DOSYA — KENDİ FIREBASE ANAHTARINIZI KOYUNUZ
//
// Gerçek `lib/firebase_options.dart` bu repoda YOKTUR (.gitignore). Proje
// sahibinin anahtarı yalnız kendi bilgisayarında, telefona yapılan yerel
// derleme için durur. Uygulamayı derlemek için kendi Firebase projenizle
// üretin:
//
//   flutterfire configure --project=<kendi-proje-kimliginiz> --platforms=android
//
// ya da bu dosyayı `lib/firebase_options.dart` adıyla kopyalayıp aşağıdaki
// değerleri kendi projenizin değerleriyle değiştirin (Firebase konsolu →
// Proje ayarları → Uygulamalarınız → Android).
//
// Gerçek anahtarı asla bu dosyaya yazıp commitlemeyin.
// ─────────────────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Örnek [FirebaseOptions]: değerleri kendi projenizinkilerle değiştirin.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Bu ders projesi yalnız Android için ayarlı.');
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'KENDI_API_ANAHTARINIZ', // ← kendi anahtarınızı koyunuz
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'kendi-proje-kimliginiz',
    storageBucket: 'kendi-proje-kimliginiz.firebasestorage.app',
  );
}
