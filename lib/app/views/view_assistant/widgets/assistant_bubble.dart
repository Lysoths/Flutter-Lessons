import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_ders/app/core/ai/assistant_persona.dart';
import 'package:flutter_ders/app/core/analytics/app_events.dart';
import 'package:flutter_ders/app/theme/app_theme.dart';
import 'package:flutter_ders/app/views/view_assistant/assistant_view.dart';
import 'package:flutter_ders/app/views/view_assistant/cubit/assistant_chat_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────
// DERS 20 — Her ekranda yüzen asistan balonu
//
// `MaterialApp.router(builder:)` içindeki her şey bütün sayfaların üstünde
// durur; balon da orada, sayfalardan bağımsızdır. Sayfa değişse de sohbet
// kaybolmaz, çünkü konuşma uygulama genelindeki AssistantChatCubit'tedir.
//
// builder, Navigator'ın DIŞINDADIR: içeride Overlay yoktur. Metin alanının
// imleç / kopyala-yapıştır menüsü bir Overlay ister; panel bu yüzden kendi
// küçük Overlay'ini taşır.
// ─────────────────────────────────────────────────────────────────────────

/// En üstteki sayfanın adını tutar (Navigator gözlemcisi). Balon, asistan
/// tam ekran açıkken gizlenir.
class TopRouteObserver extends NavigatorObserver {
  /// En üstteki rotanın adı.
  final ValueNotifier<String?> top = ValueNotifier(null);

  // Gözlemci Navigator kurulurken de çağrılır; o sırada dinleyenleri
  // yeniden kurmak hata verir. Değer bir sonraki karede yazılır.
  void _set(Route<dynamic>? route) {
    final name = route?.settings.name;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => top.value = name)
      ..scheduleFrame();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);
}

/// Sayfaların üstüne balonu ve açılınca paneli koyar.
class AssistantBubble extends StatefulWidget {
  /// Oluşturur.
  const AssistantBubble({
    required this.child,
    required this.routeChanges,
    required this.hidden,
    required this.onFullScreen,
    super.key,
  });

  /// Uygulama (yönlendiricinin Navigator'ı).
  final Widget child;

  /// Rota değişince yeniden bakılır (balon gizlensin mi?).
  final Listenable routeChanges;

  /// Balon gizli mi (ör. asistan zaten tam ekran açık)?
  final bool Function() hidden;

  /// Tam ekran asistanı açar.
  final VoidCallback onFullScreen;

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble> {
  static const _size = 58.0;
  static const _margin = 12.0;

  bool _open = false;

  /// Balonun ekranın yüksekliğine oranla yeri (sürüklenince değişir).
  double _y = 0.68;

  /// Kapalıyken gelen asistan mesajı.
  bool _unread = false;
  int _seen = 0;

  // Her açılışta yeni giriş: kapanınca eski Overlay ile birlikte gider.
  OverlayEntry _entry() => OverlayEntry(
    builder: (_) => _Panel(
      onClose: _close,
      onFullScreen: () {
        _close();
        widget.onFullScreen();
      },
    ),
  );
  OverlayEntry? _panelEntry;

  void _toggle() => _open ? _close() : _openPanel();

  void _openPanel() {
    track(AppEvent.assistantBubbleOpened);
    setState(() {
      _open = true;
      _panelEntry = _entry();
      _unread = false;
      _seen = context.read<AssistantChatCubit>().state.messages.length;
    });
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _open = false;
      _seen = context.read<AssistantChatCubit>().state.messages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    return BlocListener<AssistantChatCubit, AssistantChatState>(
      listenWhen: (a, b) => b.messages.length > a.messages.length,
      listener: (context, s) {
        if (!_open &&
            s.messages.length > _seen &&
            s.messages.last.role == ChatRole.assistant) {
          setState(() => _unread = true);
        }
      },
      child: ListenableBuilder(
        listenable: widget.routeChanges,
        builder: (context, child) {
          final hidden = widget.hidden();
          final top = media.padding.top + 56;
          final bottom = size.height - media.padding.bottom - _size - 72;
          final y = (size.height * _y).clamp(top, max(top, bottom)).toDouble();
          final panelWidth = min(size.width - _margin * 2, 420.0);
          final panelHeight = min(
            size.height -
                media.padding.top -
                max(media.viewInsets.bottom, media.padding.bottom) -
                _margin * 3,
            600.0,
          );
          return Stack(
            children: [
              child!,
              if (!hidden && _open) ...[
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('assistant_scrim'),
                    onTap: _close,
                    child: const ColoredBox(color: Color(0x59000000)),
                  ),
                ),
                Positioned(
                  right: _margin,
                  bottom:
                      max(media.viewInsets.bottom, media.padding.bottom) +
                      _margin,
                  width: panelWidth,
                  height: panelHeight,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * v,
                        alignment: Alignment.bottomRight,
                        child: child,
                      ),
                    ),
                    child: Overlay(
                      key: ObjectKey(_panelEntry),
                      initialEntries: [_panelEntry!],
                    ),
                  ),
                ),
              ],
              if (!hidden && !_open)
                Positioned(
                  right: _margin,
                  top: y,
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) => setState(
                      () => _y = ((y + d.delta.dy) / size.height).clamp(0, 1),
                    ),
                    child: _Ball(size: _size, unread: _unread, onTap: _toggle),
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Kapalı hali: yuvarlak düğme.
class _Ball extends StatelessWidget {
  const _Ball({required this.size, required this.unread, required this.onTap});

  final double size;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AssistantChatCubit, bool>((c) => c.state.busy);
    return Semantics(
      button: true,
      label: '$kAssistantName, harcama asistanı',
      child: Material(
        key: const Key('assistant_bubble'),
        color: Colors.transparent,
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: const Color(0x66D97757),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF59E0B), MfColors.claude],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                if (busy)
                  SizedBox(
                    width: size - 6,
                    height: size - 6,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                if (unread)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      key: const Key('assistant_bubble_unread'),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: MfColors.red600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
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

/// Açık hali: başlık + sohbet.
class _Panel extends StatelessWidget {
  const _Panel({required this.onClose, required this.onFullScreen});

  final VoidCallback onClose;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      key: const Key('assistant_panel'),
      color: MfColors.slate50,
      elevation: 16,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            color: MfColors.slate900,
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                const AssistantAvatar(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kAssistantName,
                        style: t.titleMedium?.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Harcama asistanı',
                        style: t.bodySmall?.copyWith(color: MfColors.slate400),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('assistant_panel_reset'),
                  tooltip: 'Yeni sohbet',
                  color: Colors.white,
                  onPressed: context.read<AssistantChatCubit>().reset,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  key: const Key('assistant_panel_full'),
                  tooltip: 'Tam ekran',
                  color: Colors.white,
                  onPressed: onFullScreen,
                  icon: const Icon(Icons.open_in_full_rounded, size: 20),
                ),
                IconButton(
                  key: const Key('assistant_panel_close'),
                  tooltip: 'Kapat',
                  color: Colors.white,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Expanded(child: AssistantConversation()),
        ],
      ),
    );
  }
}
