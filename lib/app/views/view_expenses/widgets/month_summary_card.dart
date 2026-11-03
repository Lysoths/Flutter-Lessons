import 'package:flutter/material.dart';
import 'package:flutter_ders/app/helper/money_format.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';

/// Bu ayın harcamasını gösteren koyu, geçişli özet kartı.
class MonthSummaryCard extends StatelessWidget {
  /// Özet kartı oluşturur.
  const MonthSummaryCard({
    required this.month,
    required this.monthTotal,
    required this.monthCount,
    required this.allTimeTotal,
    super.key,
  });

  /// Gösterilen ay.
  final DateTime month;

  /// Bu ayın toplamı.
  final double monthTotal;

  /// Bu ayki kayıt sayısı.
  final int monthCount;

  /// Tüm zamanların toplamı.
  final double allTimeTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MfColors.slate900, MfColors.blue700],
        ),
        boxShadow: [
          BoxShadow(
            color: MfColors.blue700.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                icon: Icons.calendar_month_rounded,
                text: formatMonth(month),
              ),
              const Spacer(),
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white54,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Bu ay harcanan',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(monthTotal),
              key: const Key('expensesView_total'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.receipt_long_rounded,
                text: '$monthCount kayıt',
              ),
              _Pill(
                icon: Icons.functions_rounded,
                text: 'Tüm zamanlar ${formatMoney(allTimeTotal)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
