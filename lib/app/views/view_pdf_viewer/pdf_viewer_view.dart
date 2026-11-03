import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/document_item.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:pdfrx/pdfrx.dart';

/// DERS 5 — PDF asset: `pdfrx` paketinin `PdfViewer.asset` widget'ı
/// dosyayı assets'ten okur; kaydırma ve yakınlaştırma hazır gelir.
// Ad elle verilir: 'View,Route' kuralı 'Viewer' içindeki 'View'u da
// değiştirip 'PdfRouteerRoute' gibi bir ad üretirdi.
@RoutePage(name: 'PdfViewerRoute')
class PdfViewerView extends StatelessWidget {
  /// [document] PDF'ini gösterir.
  const PdfViewerView({required this.document, super.key});

  /// Gösterilen belge.
  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MfColors.slate100,
      appBar: AppBar(
        title: Text(document.title),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      body: PdfViewer.asset(document.assetPath),
    );
  }
}
