import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/skeleton.dart';

/// Liste satırının ([ExpenseTileWidget]) iskeleti: aynı boyut, aynı
/// yerleşim; yazıların yerinde gri kutular.
class ExpenseTileSkeleton extends StatelessWidget {
  /// İskeleti oluşturur.
  const ExpenseTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MfColors.slate200),
        ),
        child: const Shimmer(
          child: Row(
            children: [
              SkeletonBox(width: 44, height: 44, radius: 11),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 130, height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 170, height: 10),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(width: 70, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
