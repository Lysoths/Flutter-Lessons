import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/models/document_item.dart';

/// DERS 5 — Görsel asset: `Image.asset` ile gösterilir, iki parmakla
/// yakınlaştırmak için `InteractiveViewer` içine konur.
// Ad elle verilir: 'View,Route' kuralı 'Viewer' içindeki 'View'u da
// değiştirip 'ImageRouteerRoute' gibi bir ad üretirdi.
@RoutePage(name: 'ImageViewerRoute')
class ImageViewerView extends StatelessWidget {
  /// [document] görselini gösterir.
  const ImageViewerView({required this.document, super.key});

  /// Gösterilen belge.
  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.black,
        title: Text(document.title),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.asset(
            document.assetPath,
            key: const Key('imageViewer_image'),
            fit: BoxFit.contain,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Text(
          'Yakınlaştırmak için iki parmakla açın · ${document.source}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    );
  }
}
