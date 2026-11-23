import 'package:flutter/material.dart';

class DiceFace extends StatelessWidget {
  final int value;
  final double size;
  final bool dark;
  const DiceFace({
    super.key,
    required this.value,
    this.size = 50,
    this.dark = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Кость: $value',
    child: CustomPaint(
      size: Size.square(size),
      painter: _DiePainter(value, dark),
    ),
  );
}

class _DiePainter extends CustomPainter {
  final int value;
  final bool dark;
  _DiePainter(this.value, this.dark);
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s.width, s.height * .9),
      Radius.circular(s.width * .13),
    );
    c.drawRRect(
      r.shift(Offset(0, s.height * .09)),
      Paint()..color = dark ? const Color(0xFF44271C) : const Color(0xFFA78C64),
    );
    c.drawShadow(Path()..addRRect(r), Colors.black, .3 * s.width, true);
    c.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFFB27F51), const Color(0xFF6C412B)]
              : [const Color(0xFFFFFCEF), const Color(0xFFDDCBA5)],
        ).createShader(Offset.zero & s),
    );
    c.drawRRect(
      r.deflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final locations = <Offset>[];
    if (value.isOdd) locations.add(const Offset(.5, .45));
    if (value >= 2) {
      locations.addAll([const Offset(.25, .225), const Offset(.75, .675)]);
    }
    if (value >= 4) {
      locations.addAll([const Offset(.75, .225), const Offset(.25, .675)]);
    }
    if (value == 6) {
      locations.addAll([const Offset(.25, .45), const Offset(.75, .45)]);
    }
    for (final p in locations) {
      final center = Offset(p.dx * s.width, p.dy * s.height);
      c.drawCircle(
        center + const Offset(0, 1),
        s.width * .075,
        Paint()..color = Colors.white.withValues(alpha: .45),
      );
      c.drawCircle(
        center,
        s.width * .067,
        Paint()
          ..color = dark ? const Color(0xFFFFE7B6) : const Color(0xFF31261D),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter old) =>
      old.value != value || old.dark != dark;
}
