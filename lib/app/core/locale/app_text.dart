import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/locale/app_strings.dart';

/// [Text] that follows the language chosen in settings.
class AppText extends StatelessWidget {
  /// Creates a translated text widget.
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.textDirection,
  });

  /// Turkish source. Other languages look this up.
  final String data;

  /// Visual style. Passed through to [Text].
  final TextStyle? style;

  /// Alignment. Passed through to [Text].
  final TextAlign? textAlign;

  /// Line limit. Passed through to [Text].
  final int? maxLines;

  /// Overflow behavior. Passed through to [Text].
  final TextOverflow? overflow;

  /// Writing direction. Passed through to [Text].
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.of(context).translate(data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: textDirection,
    );
  }
}
