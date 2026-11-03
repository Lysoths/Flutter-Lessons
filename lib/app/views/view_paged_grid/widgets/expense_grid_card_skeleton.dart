import 'package:flutter/material.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/widgets/skeleton.dart';

/// Izgara kartının ([ExpenseGridCard]) iskeleti.
class ExpenseGridCardSkeleton extends StatelessWidget {
  /// İskeleti oluşturur.
  const ExpenseGridCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MfColors.slate200),
        ),
        child: const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 36, height: 36, radius: 9),
                  Spacer(),
                  SkeletonBox(width: 28, height: 12),
                ],
              ),
              Spacer(),
              SkeletonBox(width: 100, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 64, height: 10),
              SizedBox(height: 10),
              SkeletonBox(width: 80, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
