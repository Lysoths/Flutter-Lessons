import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/core/base/base_view_model_cubit.dart';
import 'package:flutter_ders/app/core/sms/bank_sms.dart';
import 'package:flutter_ders/app/core/sms/sms_source.dart';
import 'package:flutter_ders/app/models/expense.dart';
import 'package:flutter_ders/app/views/view_expenses/cubit/expenses_cubit.dart';

/// Ekranın durumu.
enum BankSmsStatus {
  /// İzin kontrol ediliyor.
  checking,

  /// İzin gerekiyor.
  needsPermission,

  /// İzin kalıcı olarak reddedildi.
  permanentlyDenied,

  /// Bu platformda SMS yok.
  unsupported,

  /// Gelen kutusu okunuyor.
  loading,

  /// Liste hazır.
  ready,

  /// Okunamadı.
  failed,
}

/// Liste süzgeci.
enum BankSmsFilter {
  /// Hepsi.
  all('Tümü'),

  /// Para çıkışı.
  spending('Harcama'),

  /// Para girişi.
  incoming('Gelen'),

  /// Bilgi ve şifre.
  other('Diğer');

  const BankSmsFilter(this.label);

  /// Çipteki ad.
  final String label;

  /// [sms] bu süzgece uyar mı?
  bool matches(BankSms sms) => switch (this) {
    all => true,
    spending => sms.kind.outgoing,
    incoming =>
      sms.kind == BankSmsKind.incoming || sms.kind == BankSmsKind.refund,
    other => sms.kind == BankSmsKind.info || sms.kind == BankSmsKind.otp,
  };
}

/// Banka SMS ekranının durumu.
final class BankSmsState extends Equatable {
  /// Oluşturur.
  const BankSmsState({
    this.status = BankSmsStatus.checking,
    this.items = const [],
    this.filter = BankSmsFilter.all,
    this.listening = false,
    this.liveCount = 0,
    this.days = 90,
    this.revision = 0,
  });

  /// Durum.
  final BankSmsStatus status;

  /// Banka SMS'leri, yeniden eskiye.
  final List<BankSms> items;

  /// Seçili süzgeç.
  final BankSmsFilter filter;

  /// Yeni SMS'ler dinleniyor mu?
  final bool listening;

  /// Ekran açıkken gelen SMS sayısı.
  final int liveCount;

  /// Kaç günlük gelen kutusu okundu.
  final int days;

  /// Harcama eklenip geri alındıkça artar; satırlar yeniden çizilsin diye.
  final int revision;

  /// Süzgece uyanlar.
  List<BankSms> get visible => [
    for (final s in items)
      if (filter.matches(s)) s,
  ];

  /// [month] ayında, TL olarak hesaptan çıkan toplam.
  double spentIn(DateTime month) => _sum(month, outgoing: true);

  /// [month] ayında hesaba giren toplam.
  double receivedIn(DateTime month) => _sum(month, outgoing: false);

  double _sum(DateTime month, {required bool outgoing}) => items
      .where(
        (s) =>
            s.amount != null &&
            s.currency == 'TL' &&
            s.kind != BankSmsKind.info &&
            s.kind.outgoing == outgoing &&
            s.date.year == month.year &&
            s.date.month == month.month,
      )
      .fold(0, (sum, s) => sum + s.amount!);

  /// Kaç farklı bankadan SMS var.
  int get bankCount => {for (final s in items) s.bank.name}.length;

  /// Değiştirilmiş kopya.
  BankSmsState copyWith({
    BankSmsStatus? status,
    List<BankSms>? items,
    BankSmsFilter? filter,
    bool? listening,
    int? liveCount,
    int? revision,
  }) => BankSmsState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    listening: listening ?? this.listening,
    liveCount: liveCount ?? this.liveCount,
    days: days,
    revision: revision ?? this.revision,
  );

  // AppBlocObserver her geçişi konsola yazar; SMS metni, tutar ve banka
  // log'a düşmesin diye yalnız sayılar yazılır.
  @override
  String toString() =>
      'BankSmsState(${status.name}, ${items.length} SMS, '
      '${filter.name}, canlı: $liveCount)';

  @override
  List<Object?> get props => [
    status,
    items,
    filter,
    listening,
    liveCount,
    revision,
  ];
}

/// DERS 21 — Banka SMS'lerini okur, anlık geleni listeye ekler, seçilen
/// SMS'ten harcama oluşturur. Hiçbir şey saklamaz.
class BankSmsCubit extends BaseViewModelCubit<BankSmsState> {
  /// Oluşturur.
  BankSmsCubit({required this._source, required this._expenses})
    : super(const BankSmsState());

  final SmsSource _source;
  final ExpensesCubit _expenses;
  StreamSubscription<RawSms>? _live;

  /// İzni kontrol eder; varsa okur ve dinlemeye başlar.
  Future<void> init() async {
    await _apply(await _source.access());
  }

  /// İzin penceresini açar.
  Future<void> requestAccess() async {
    final access = await _source.requestAccess();
    track(
      AppEvent.smsAccessRequested,
      access == SmsAccess.granted ? 'verildi' : 'verilmedi',
    );
    await _apply(access);
  }

  /// Uygulama ayarlarını açar (kalıcı retten sonra).
  Future<void> openSettings() => _source.openSettings();

  Future<void> _apply(SmsAccess access) async {
    switch (access) {
      case SmsAccess.granted:
        await refresh();
        _listen();
      case SmsAccess.denied:
        stateChanger(state.copyWith(status: BankSmsStatus.needsPermission));
      case SmsAccess.permanentlyDenied:
        stateChanger(state.copyWith(status: BankSmsStatus.permanentlyDenied));
      case SmsAccess.unsupported:
        stateChanger(state.copyWith(status: BankSmsStatus.unsupported));
    }
  }

  /// Gelen kutusunu yeniden okur. Anlık gelenler korunur.
  Future<void> refresh() async {
    stateChanger(state.copyWith(status: BankSmsStatus.loading));
    try {
      final raw = await _source.inbox(days: state.days);
      final parsed = [for (final r in raw) ?BankSmsParser.parse(r)];
      stateChanger(
        state.copyWith(
          status: BankSmsStatus.ready,
          items: _merge(state.items.where((s) => s.live), parsed),
        ),
      );
      track(AppEvent.smsRefreshed);
    } on SmsReadException catch (e) {
      stateChanger(
        state.copyWith(
          status: e.code == 'izin_yok'
              ? BankSmsStatus.needsPermission
              : BankSmsStatus.failed,
        ),
      );
    }
  }

  void _listen() {
    if (_live != null) return;
    _live = _source.incoming().listen(
      (raw) {
        final sms = BankSmsParser.parse(raw, live: true);
        if (sms == null) return;
        stateChanger(
          state.copyWith(
            items: _merge([sms], state.items),
            liveCount: state.liveCount + 1,
          ),
        );
        track(AppEvent.smsReceived, sms.kind.name);
      },
      // Akış hatası listeyi bozmaz; dinleme kapanır.
      onError: (Object _) {
        stateChanger(state.copyWith(listening: false));
      },
    );
    stateChanger(state.copyWith(listening: true));
  }

  /// Önce gelenler kazanır; aynı SMS (gönderen + metin) bir kez görünür.
  static List<BankSms> _merge(Iterable<BankSms> first, Iterable<BankSms> rest) {
    final seen = <String>{};
    final out = <BankSms>[
      for (final s in [...first, ...rest])
        if (seen.add(s.raw.key)) s,
    ];
    return out..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Süzgeci değiştirir.
  void setFilter(BankSmsFilter filter) =>
      stateChanger(state.copyWith(filter: filter));

  /// Bu SMS'ten harcama oluşturulmuş mu?
  bool recorded(BankSms sms) => isRecorded(sms, _expenses.state.expenses);

  /// [sms]'i [category] kategorisiyle harcama olarak ekler. Tarih SMS'in
  /// zamanıdır; böylece aynı SMS ikinci kez eklenmez.
  Future<bool> record(BankSms sms, ExpenseCategory category) async {
    if (!sms.recordable || recorded(sms)) return false;
    await _expenses.add(
      amount: sms.amount!,
      category: category,
      note: sms.expenseNote,
      date: sms.date,
    );
    track(AppEvent.smsRecorded, category.name);
    stateChanger(state.copyWith(revision: state.revision + 1));
    return true;
  }

  /// [record] ile eklenen harcamayı geri alır.
  Future<void> undo(BankSms sms) async {
    final match = _expenses.state.expenses
        .where((e) => e.amount == sms.amount && e.date == sms.date)
        .firstOrNull;
    if (match == null) return;
    await _expenses.remove(match.id);
    track(AppEvent.smsUndone);
    stateChanger(state.copyWith(revision: state.revision + 1));
  }

  @override
  Future<void> close() async {
    await _live?.cancel();
    return super.close();
  }
}
