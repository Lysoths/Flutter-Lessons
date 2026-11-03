import 'package:equatable/equatable.dart';
import 'package:flutter_ders/app/models/exchange_rates.dart';

/// DERS 13 — Kur ekranının durumu.
///
/// Her durum ayrı bir sınıf (`sealed`): ekranda `switch (state)` ile hepsi
/// ele alınır, biri unutulursa derleyici uyarır. Ders 7'deki tek sınıf +
/// `status` alanı yaklaşımının alternatifi.
sealed class RatesState extends Equatable {
  const RatesState();

  @override
  List<Object?> get props => [];
}

/// Henüz bir şey istenmedi.
final class RatesInitial extends RatesState {
  /// Durumu oluşturur.
  const RatesInitial();
}

/// İstek sürüyor; varsa önceki kurlar soluk gösterilir.
final class RatesLoading extends RatesState {
  /// Durumu oluşturur.
  const RatesLoading({this.previous});

  /// Önceki başarılı sonuç.
  final ExchangeRates? previous;

  @override
  List<Object?> get props => [previous];
}

/// Kurlar geldi.
final class RatesLoaded extends RatesState {
  /// Durumu oluşturur.
  const RatesLoaded({
    required this.rates,
    required this.fetchedAt,
    required this.handled,
  });

  /// Kurlar.
  final ExchangeRates rates;

  /// Cevabın geldiği an.
  final DateTime fetchedAt;

  /// Bloc'un şimdiye kadar işlediği istek sayısı.
  final int handled;

  @override
  List<Object?> get props => [rates, fetchedAt, handled];
}

/// İstek başarısız oldu.
final class RatesError extends RatesState {
  /// Durumu oluşturur.
  const RatesError({
    required this.message,
    required this.handled,
    this.previous,
  });

  /// Kullanıcıya gösterilecek açıklama.
  final String message;

  /// Bloc'un şimdiye kadar işlediği istek sayısı.
  final int handled;

  /// Önceki başarılı sonuç.
  final ExchangeRates? previous;

  @override
  List<Object?> get props => [message, handled, previous];
}
