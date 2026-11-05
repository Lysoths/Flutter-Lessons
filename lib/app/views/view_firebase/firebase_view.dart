import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/di/injection.dart';
import 'package:flutter_ders/app/core/firebase/app_config_cubit.dart';
import 'package:flutter_ders/app/core/firebase/app_texts.dart';
import 'package:flutter_ders/app/core/firebase/finance_store.dart';
import 'package:flutter_ders/app/core/firebase/firebase_services.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';
import 'package:flutter_ders/app/core/firebase/session_cubit.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_auth/auth_view.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';
import 'package:flutter_ders/app/views/view_firebase/cubit/firebase_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_firebase/cubit/firestore_lab_cubit.dart';
import 'package:flutter_ders/app/views/view_image_cache/widgets/cache_panels.dart';
import 'package:flutter_ders/app/views/view_update/update_views.dart';
import 'package:flutter_ders/app/widgets/common.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 18 — Firebase
//
//   main.dart      Firebase.initializeApp → App Check → Crashlytics işleyicileri
//   AppConfigCubit Remote Config: tasarım, dil metinleri, sürüm kuralları
//   SessionCubit   Auth oturumu
//   AppGate        sürüm kilidi → giriş ekranı → uygulama
//   Bu ekran       hepsinin canlı durumu ve denemeleri
// ─────────────────────────────────────────────────────────────────────────

/// Firebase dersinin sayfası.
@RoutePage()
class FirebaseView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const FirebaseView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<FirebaseLabCubit>()),
        BlocProvider(create: (_) => getIt<FirestoreLabCubit>()..load()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firebase'),
          titleTextStyle: t.titleLarge,
        ),
        body: ListView(
          key: const Key('firebase_scroll'),
          padding: pagePadding(context).copyWith(top: 16, bottom: 32),
          children: const [
            _SessionPanel(),
            _FirestorePanel(),
            _RemoteConfigPanel(),
            _VersionPanel(),
            _CrashlyticsPanel(),
            _AppCheckPanel(),
          ],
        ),
      ),
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final session = context.read<SessionCubit>();
    final user = context.watch<SessionCubit>().state.user;
    return LabCard(
      key: const Key('firebase_session'),
      icon: Icons.person_rounded,
      title: 'Oturum (Auth · Google)',
      children: [
        if (user?.name case final n?) Text(n, style: t.titleMedium),
        Text(user?.email ?? '—', style: t.bodyMedium),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatCell('Hesap açılışı', _date(user?.createdAt)),
            StatCell('Son giriş', _date(user?.lastSignIn)),
          ],
        ),
        const Gap(10),
        FilledButton.icon(
          key: const Key('firebase_signout'),
          onPressed: session.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.text('auth.cikis')),
        ),
      ],
    );
  }
}

class _FirestorePanel extends StatelessWidget {
  const _FirestorePanel();

  static const _labels = {
    FinanceCollections.categories: 'Kategori',
    FinanceCollections.paymentMethods: 'Ödeme yöntemi',
    FinanceCollections.tags: 'Etiket',
    FinanceCollections.stores: 'Mağaza',
    FinanceCollections.budgets: 'Bütçe',
    FinanceCollections.expenses: 'Harcama',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<FirestoreLabCubit>().state;
    final cubit = context.read<FirestoreLabCubit>();
    final snap = s.snapshot;
    final empty = snap == null || snap.counts.values.every((c) => c == 0);
    return BlocListener<FirestoreLabCubit, FirestoreLabState>(
      // Yükleme/silme bitince ana ekrandaki liste de Firestore'dan yenilenir.
      listenWhen: (a, b) => a.busy && !b.busy && b.error == null,
      listener: (context, _) => context.read<ExpensesCubit>().load(),
      child: LabCard(
        key: const Key('firebase_firestore'),
        icon: Icons.storage_rounded,
        title: 'Firestore (ilişkili veri)',
        children: [
          Text(
            'Veri kullanıcı belgesinin altında tutulur; kurallar yalnız sahibine '
            'izin verir. Harcamalar kategori, ödeme yöntemi, mağaza ve '
            'etiketlere kimlikle bağlıdır; okurken ilişkiler çözülür.',
            style: t.bodySmall,
          ),
          const Gap(10),
          if (snap != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(:key, :value) in _labels.entries)
                  StatCell(value, '${snap.counts[key] ?? 0}'),
              ],
            ),
          if (s.error case final e?) ...[
            const Gap(8),
            Text(
              e,
              key: const Key('firestore_error'),
              style: t.bodySmall?.copyWith(color: MfColors.red600),
            ),
          ],
          if (snap != null && snap.expenses.isNotEmpty) ...[
            const Gap(12),
            Text(
              'Son 10 harcama (ilişkileri çözülmüş) · toplam '
              '${snap.expenses.length}',
              style: t.labelMedium,
            ),
            const Gap(4),
            for (final e in snap.expenses.take(10))
              Padding(
                key: Key('firestore_expense_${e.id}'),
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.note, style: t.bodyMedium),
                          Text(
                            [
                              e.category,
                              e.paymentMethod,
                              ?e.store,
                              if (e.tags.isNotEmpty) '#${e.tags.join(' #')}',
                            ].join(' · '),
                            style: t.bodySmall?.copyWith(
                              color: MfColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${e.amount.toStringAsFixed(2)} ₺',
                      style: t.titleSmall,
                    ),
                  ],
                ),
              ),
          ],
          const Gap(10),
          FilledButton.icon(
            key: const Key('firestore_seed'),
            onPressed: s.busy ? null : cubit.seed,
            icon: s.busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(
              empty ? 'Örnek veriyi yükle' : 'Örnek veriyi yeniden yaz',
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('firestore_reload'),
                  onPressed: s.busy ? null : cubit.load,
                  child: const Text('Yeniden oku'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('firestore_clear'),
                  onPressed: s.busy || empty ? null : cubit.clear,
                  child: const Text('Verimi sil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoteConfigPanel extends StatelessWidget {
  const _RemoteConfigPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<AppConfigCubit>().state;
    final cubit = context.read<AppConfigCubit>();
    final d = s.config.design;
    return LabCard(
      key: const Key('firebase_rc'),
      icon: Icons.tune_rounded,
      title: 'Remote Config',
      children: [
        Text(
          'Konsolda bir değeri değiştirip "Yayınla"ya basınca uygulama '
          'yeniden başlamadan güncellenir (canlı güncelleme). Tema, dil '
          'metinleri ve sürüm kuralları buradan gelir.',
          style: t.bodySmall,
        ),
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatCell('Son çekme', _time(s.lastFetch)),
            StatCell('Durum', s.lastStatus),
            StatCell('Dil', s.language.toUpperCase()),
            if (s.lastUpdatedKeys.isNotEmpty)
              StatCell(
                'Son canlı değişiklik',
                s.lastUpdatedKeys.join(', '),
                color: MfColors.emerald500,
              ),
          ],
        ),
        const Gap(12),
        const Align(alignment: Alignment.centerLeft, child: LanguageSwitch()),
        const Gap(12),
        Text('Tasarım belirteçleri', style: t.labelMedium),
        const Gap(6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Swatch('birincil', d.primary),
            _Swatch('vurgu', d.accent),
            _Swatch('dugme', d.button),
            StatCell('kose', d.radius.toStringAsFixed(0)),
            StatCell('kart_kose', d.cardRadius.toStringAsFixed(0)),
            StatCell('yazi_olcegi', d.textScale.toStringAsFixed(2)),
          ],
        ),
        const Gap(12),
        Text('Parametreler ve kaynakları', style: t.labelMedium),
        const Gap(4),
        for (final k in [
          RcKeys.design,
          RcKeys.texts,
          RcKeys.language,
          RcKeys.minVersion,
          RcKeys.latestVersion,
          RcKeys.updateUrl,
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    k,
                    style: t.bodyMedium?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                Eyebrow(
                  (s.origins[k] ?? ConfigOrigin.none).label,
                  color: s.origins[k] == ConfigOrigin.remote
                      ? MfColors.emerald500
                      : MfColors.slate500,
                  background: MfColors.slate100,
                ),
              ],
            ),
          ),
        const Gap(10),
        OutlinedButton.icon(
          key: const Key('firebase_rc_fetch'),
          onPressed: s.fetching
              ? null
              : () {
                  track(AppEvent.remoteConfigFetched);
                  cubit.refresh();
                },
          icon: s.fetching
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_rounded, size: 18),
          label: const Text('Şimdi çek (fetchAndActivate)'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(
        color: MfColors.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label  #${hex.substring(2).toUpperCase()}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _VersionPanel extends StatelessWidget {
  const _VersionPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<AppConfigCubit>().state;
    final (label, color) = switch (s.updateStatus) {
      UpdateStatus.upToDate => ('Güncel', MfColors.emerald500),
      UpdateStatus.optional => ('İsteğe bağlı güncelleme', MfColors.blue600),
      UpdateStatus.forced => ('Zorunlu güncelleme', MfColors.red600),
    };
    return LabCard(
      key: const Key('firebase_version'),
      icon: Icons.system_update_rounded,
      title: 'Sürüm denetimi',
      children: [
        Text(
          'Yüklü sürüm min_surum altındaysa uygulama kilitlenir; son_surum '
          'altındaysa altta kapatılabilir bir kart çıkar. Konsolda değeri '
          'değiştirip yayınlayınca anında denenebilir.',
          style: t.bodySmall,
        ),
        const Gap(10),
        VersionTable(state: s),
        const Gap(10),
        Eyebrow(label, color: color, background: color.withValues(alpha: 0.1)),
      ],
    );
  }
}

class _CrashlyticsPanel extends StatelessWidget {
  const _CrashlyticsPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cubit = context.read<FirebaseLabCubit>();
    final message = context.select<FirebaseLabCubit, String?>(
      (c) => c.state.message,
    );
    return LabCard(
      key: const Key('firebase_crashlytics'),
      icon: Icons.bug_report_rounded,
      title: 'Crashlytics',
      children: [
        Text(
          'Yakalanmayan Flutter ve platform hataları kendiliğinden gider. '
          'Raporda kullanıcı yalnız uid ile görünür; e-posta gönderilmez.',
          style: t.bodySmall,
        ),
        if (message != null) ...[
          const Gap(8),
          Text(
            message,
            key: const Key('firebase_message'),
            style: t.bodySmall?.copyWith(color: MfColors.blue700),
          ),
        ],
        const Gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('firebase_log'),
              onPressed: cubit.addLog,
              child: const Text('Kayıt ekle (log)'),
            ),
            OutlinedButton(
              key: const Key('firebase_nonfatal'),
              onPressed: cubit.recordNonFatal,
              child: const Text('Yakalanan hata gönder'),
            ),
          ],
        ),
        const Gap(8),
        FilledButton.icon(
          key: const Key('firebase_crash'),
          style: FilledButton.styleFrom(backgroundColor: MfColors.red600),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Uygulama çökertilsin mi?'),
                content: const Text(
                  'Uygulama hemen kapanır. Yeniden açınca rapor gönderilir ve '
                  'birkaç dakika içinde konsolda Crashlytics altında görünür.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Vazgeç'),
                  ),
                  TextButton(
                    key: const Key('firebase_crash_confirm'),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Çökert'),
                  ),
                ],
              ),
            );
            if (ok ?? false) cubit.crash();
          },
          icon: const Icon(Icons.dangerous_rounded),
          label: const Text('Test çökmesi'),
        ),
      ],
    );
  }
}

class _AppCheckPanel extends StatelessWidget {
  const _AppCheckPanel();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = context.watch<FirebaseLabCubit>().state;
    final r = s.appCheck;
    return LabCard(
      key: const Key('firebase_appcheck'),
      icon: Icons.verified_user_rounded,
      title: 'App Check',
      children: [
        Text(
          'Firebase\'e gelen isteğin bu uygulamadan geldiğini kanıtlar. '
          'Geliştirmede Debug sağlayıcısı kullanılır: logcat\'teki debug '
          'belirteci konsolda App Check → Uygulamalar → Debug belirteçlerini '
          'yönet altına eklenmeden belirteç alınamaz. Yayın sürümü Play '
          'Integrity kullanır.',
          style: t.bodySmall,
        ),
        const Gap(10),
        if (r != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatCell('Sağlayıcı', r.provider),
              StatCell(
                'Belirteç',
                r.ok ? 'Alındı (${r.tokenLength} karakter)' : 'Alınamadı',
                color: r.ok ? MfColors.emerald500 : MfColors.red600,
              ),
            ],
          ),
        if (r?.error case final e?) ...[
          const Gap(8),
          Text(
            e,
            key: const Key('firebase_appcheck_error'),
            style: t.bodySmall?.copyWith(color: MfColors.red600),
          ),
        ],
        const Gap(10),
        OutlinedButton.icon(
          key: const Key('firebase_appcheck_check'),
          onPressed: s.checking
              ? null
              : context.read<FirebaseLabCubit>().checkAppCheck,
          icon: s.checking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.shield_rounded, size: 18),
          label: const Text('Belirteç iste'),
        ),
      ],
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _time(DateTime? d) =>
    d == null ? '—' : '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

String _date(DateTime? d) => d == null
    ? '—'
    : '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:'
          '${_two(d.minute)}';
