import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/router/app_router.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_lessons/lesson_catalog.dart';

/// Ana sayfadaki tek "Dersler" girişi: ders ve konu sayısı, konu renkleri.
class LessonsEntryCard extends StatelessWidget {
  /// Oluşturur.
  const LessonsEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(20);
    return Material(
      color: MfColors.slate900,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.router.push(const LessonsRoute()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Dersler',
                          style: t.titleMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${kLessons.length} ders ekranı · '
                      '${LessonTopic.values.length} konu',
                      style: t.bodySmall?.copyWith(color: MfColors.slate200),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final topic in LessonTopic.values)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: topic.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              topic.icon,
                              size: 16,
                              color: topic.color,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
