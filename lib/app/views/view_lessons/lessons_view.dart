import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_lessons/lesson_catalog.dart';
import 'package:flutter_ders/app/views/view_lessons/widgets/lesson_card.dart';
import 'package:flutter_ders/app/widgets/common.dart';

/// Ders ekranlarının dizini: konuya göre gruplu, süzülebilir, aranabilir.
@RoutePage()
class LessonsView extends StatefulWidget {
  /// Sayfayı oluşturur.
  const LessonsView({super.key});

  @override
  State<LessonsView> createState() => _LessonsViewState();
}

class _LessonsViewState extends State<LessonsView> {
  LessonTopic? _topic;
  String _query = '';

  static String _lower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  bool _matches(Lesson l) {
    if (_topic != null && l.topic != _topic) return false;
    if (_query.isEmpty) return true;
    final q = _lower(_query.trim());
    return _lower(l.title).contains(q) ||
        _lower(l.subtitle).contains(q) ||
        'ders ${l.number}' == q ||
        '${l.number}' == q;
  }

  void _open(Lesson l) {
    track(AppEvent.lessonOpened, l.id);
    context.router.push(l.route);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final visible = kLessons.where(_matches).toList();
    final topics = [
      for (final topic in LessonTopic.values)
        if (visible.any((l) => l.topic == topic)) topic,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dersler'),
        titleTextStyle: t.titleLarge,
      ),
      body: CustomScrollView(
        key: const Key('lessons_scroll'),
        slivers: [
          SliverPadding(
            padding: pagePadding(context).copyWith(top: 4),
            sliver: SliverList.list(
              children: [
                Text(
                  '${kLessons.length} ders ekranı · '
                  '${LessonTopic.values.length} konu',
                  style: t.bodyMedium,
                ),
                const Gap(12),
                TextField(
                  key: const Key('lessons_search'),
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Ders ara (ör. "bloc" ya da "14")',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const Gap(12),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                key: const Key('lessons_topics'),
                scrollDirection: Axis.horizontal,
                padding: pagePadding(context),
                children: [
                  _TopicChip(
                    key: const Key('lessons_topic_all'),
                    label: 'Tümü',
                    count: kLessons.length,
                    color: MfColors.slate900,
                    selected: _topic == null,
                    onTap: () => setState(() => _topic = null),
                  ),
                  for (final topic in LessonTopic.values)
                    _TopicChip(
                      key: Key('lessons_topic_${topic.name}'),
                      label: topic.label,
                      icon: topic.icon,
                      count: kLessons.where((l) => l.topic == topic).length,
                      color: topic.color,
                      selected: _topic == topic,
                      onTap: () => setState(
                        () => _topic = _topic == topic ? null : topic,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: pagePadding(context).copyWith(top: 40),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Bu aramaya uyan ders yok.',
                  key: const Key('lessons_empty'),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium,
                ),
              ),
            ),
          for (final topic in topics) ...[
            SliverPadding(
              padding: pagePadding(context).copyWith(top: 22, bottom: 10),
              sliver: SliverToBoxAdapter(child: _TopicHeader(topic)),
            ),
            SliverPadding(
              padding: pagePadding(context),
              sliver: SliverList.separated(
                itemCount: visible.where((l) => l.topic == topic).length,
                separatorBuilder: (_, _) => const Gap(10),
                itemBuilder: (context, i) {
                  final l = visible.where((l) => l.topic == topic).elementAt(i);
                  return LessonCard(
                    key: Key('lessons_${l.id}'),
                    lesson: l,
                    onTap: () => _open(l),
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
          ),
        ],
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader(this.topic);

  final LessonTopic topic;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: topic.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(topic.icon, size: 16, color: topic.color),
        ),
        const SizedBox(width: 10),
        Text(topic.label, style: t.titleMedium),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? color : MfColors.slate200),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$label  $count',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? Colors.white : MfColors.slate800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
