import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ders/app/views/view_device/widgets/gps_panel.dart';
import 'package:flutter_ders/app/views/view_device/widgets/sensors_panel.dart';

/// DERS 12 — Donanımdan canlı veri: GPS ve hareket sensörleri.
///
/// İkisi de aynı fikir: donanım ölçtükçe bir STREAM'e yeni değer koyar,
/// ekran StreamBuilder ile her değerde yeniden çizilir.
@RoutePage()
class DeviceView extends StatelessWidget {
  /// Sayfayı oluşturur.
  const DeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konum ve sensörler'),
          titleTextStyle: t.titleLarge,
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('device_tabGps'), text: 'GPS'),
              Tab(key: Key('device_tabSensors'), text: 'Sensörler'),
            ],
          ),
        ),
        body: const TabBarView(
          // Telefonu eğerken sekme kaymasın.
          physics: NeverScrollableScrollPhysics(),
          children: [GpsPanel(), SensorsPanel()],
        ),
      ),
    );
  }
}
