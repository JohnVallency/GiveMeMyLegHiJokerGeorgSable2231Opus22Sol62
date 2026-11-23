import 'dart:math';

import 'package:flutter/material.dart';

import 'engine.dart';

const ink = Color(0xFFEEE8DB);
const gold = Color(0xFFD8AF6B);

class BoardPainter extends CustomPainter {
  final Position position;
  final int? selected;
  final Set<int> targets;
  final int player, movingSide;
  final Position? before;
  final Move? move;
  final double progress;
  BoardPainter(
    this.position,
    this.selected,
    this.targets, {
    this.player = 1,
    this.before,
    this.move,
    this.movingSide = 1,
    this.progress = 1,
  });

  static double radius(Size s) => field(s).width / 13 * .41;
  static Offset slot(int point, Size s, int index, int count, {int side = 1}) {
    final f = field(s);
    final w = f.width / 13;
    if (point == -1) {
      return Offset(f.center.dx, f.center.dy + (side == 1 ? 1 : -1) * w * .65);
    }
    if (point == 24) {
      return Offset(
        s.width - w * .16,
        side == 1 ? f.bottom - w * .6 : f.top + w * .6,
      );
    }
    final r = cell(point, s), rad = radius(s);
    final step = min(
      rad * 1.95,
      (r.height * .84 - rad * 2) / max(1, count - 1),
    );
    return Offset(
      r.center.dx,
      point < 12
          ? r.bottom - rad - 4 - index * step
          : r.top + rad + 4 + index * step,
    );
  }

  Offset ghostCenter(int point, Size s) {
    final count = point == 24 ? 0 : max(0, position.points[point] * player);
    return slot(point, s, count, count + 1, side: player);
  }

  void ghost(Canvas c, Offset center, double r) {
    c.drawCircle(
      center + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawCircle(
      center,
      r,
      Paint()
        ..color =
            (player == 1 ? const Color(0xFFFFF4D8) : const Color(0xFF282522))
                .withValues(alpha: .48),
    );
    c.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFFFFE0A1).withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    c.drawCircle(
      center,
      r * .76,
      Paint()
        ..color = creamGhost.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static const creamGhost = Color(0xFFFFEBD0);

  static Rect field(Size s) => Rect.fromLTWH(
    s.width * .035,
    s.height * .055,
    s.width * .93,
    s.height * .89,
  );
  static Rect cell(int i, Size s) {
    final f = field(s);
    final w = f.width / 13;
    final col = i < 12 ? 11 - i : i - 12;
    final x = col + (col >= 6 ? 1 : 0);
    return Rect.fromLTWH(
      f.left + x * w,
      i < 12 ? f.center.dy : f.top,
      w,
      f.height / 2,
    );
  }

  static int? hit(Offset o, Size s) {
    final f = field(s);
    final w = f.width / 13;
    if (Rect.fromLTWH(f.left + 6 * w, f.top, w, f.height).contains(o)) {
      return -1;
    }
    if (o.dx > f.right && o.dx < s.width && o.dy >= f.top && o.dy <= f.bottom) {
      return 24;
    }
    for (var i = 0; i < 24; i++) {
      if (cell(i, s).contains(o)) return i;
    }
    return null;
  }

  void text(Canvas c, String t, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    canvas.drawRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBC28B), Color(0xFF92603C), Color(0xFFD5A16B)],
        ).createShader(outer),
    );
    canvas.drawRect(
      outer.deflate(3),
      Paint()
        ..color = const Color(0xFF6C4227)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final f = field(size);
    canvas.drawRect(
      f,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFBD8754), Color(0xFFE6BA7C), Color(0xFFC38B56)],
        ).createShader(f),
    );
    canvas.save();
    canvas.clipRect(f);
    for (var line = 0; line < 210; line++) {
      final y = f.top + line * f.height / 210;
      final path = Path()..moveTo(f.left, y);
      for (var x = 0; x <= 50; x++) {
        path.lineTo(
          f.left + f.width * x / 50,
          y + sin(x * .65 + line * .44) * 1.5 + sin(x * .15 + line) * 2,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Color(line.isEven ? 0xFF5B301A : 0xFFFFEDC3)
              .withValues(alpha: line % 5 == 0 ? .13 : .055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6,
      );
    }
    canvas.restore();
    canvas.drawRect(
      f,
      Paint()
        ..color = const Color(0xFF704323)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(f.center.dx - 3, f.top),
      Offset(f.center.dx - 3, f.bottom),
      Paint()
        ..color = const Color(0xFF5D3722)
        ..strokeWidth = 5,
    );
    canvas.drawLine(
      Offset(f.center.dx + 3, f.top),
      Offset(f.center.dx + 3, f.bottom),
      Paint()
        ..color = const Color(0xFFF9D69E)
        ..strokeWidth = 2,
    );
    final w = f.width / 13;
    canvas.drawRect(
      Rect.fromLTWH(f.left + 6 * w, f.top, w, f.height),
      Paint()..color = const Color(0xFF98683F),
    );
    for (var i = 0; i < 24; i++) {
      final r = cell(i, size);
      final bottom = i < 12;
      final base = bottom ? r.bottom : r.top;
      final tip = bottom ? r.top + r.height * .15 : r.bottom - r.height * .15;
      // Stylized rounded point, mirrored toward the board centre.
      final halfWidth = (r.width - 4) / 2;
      final length = tip - base;
      Offset point(double x, double y) =>
          Offset(r.center.dx + x * halfWidth, base + y * length);
      final start = point(0, .08);
      final shape = Path()..moveTo(start.dx, start.dy);
      void curve(
        double x1,
        double y1,
        double x2,
        double y2,
        double x3,
        double y3,
      ) {
        final a = point(x1, y1), b = point(x2, y2), c = point(x3, y3);
        shape.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
      }

      curve(-.35, -.02, -1, .015, -1, .13);
      curve(-1, .27, -.43, .29, -.38, .18);
      final left = point(-.38, .87);
      shape.lineTo(left.dx, left.dy);
      curve(-.38, 1.04, .38, 1.04, .38, .87);
      final right = point(.38, .18);
      shape.lineTo(right.dx, right.dy);
      curve(.43, .29, 1, .27, 1, .13);
      curve(1, .015, .35, -.02, 0, .08);
      shape.close();
      canvas.drawPath(
        shape,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFF4D8A3)
              : const Color(0xFF985430),
      );
      text(
        canvas,
        '${i + 1}',
        Offset(
          r.center.dx,
          bottom ? f.bottom + size.height * .025 : f.top - size.height * .025,
        ),
        size.width * .012,
        const Color(0xFFFFE9C6),
      );
      final n = position.points[i].abs();
      final radius = w * .41;
      for (var j = 0; j < n; j++) {
        if (move?.to == i &&
            position.points[i] * movingSide > 0 &&
            j == n - 1) {
          continue;
        }
        final end = slot(i, size, j, n);
        final oldCount =
            before != null && before!.points[i] * position.points[i] > 0
            ? before!.points[i].abs()
            : n;
        final center = before == null
            ? end
            : Offset.lerp(
                slot(i, size, j, oldCount),
                end,
                Curves.easeInOutCubic.transform(progress),
              )!;
        checker(canvas, center, radius, position.points[i] > 0, selected == i);
        if (j == n - 1 && n > 5) {
          text(
            canvas,
            '$n',
            center,
            radius,
            position.points[i] > 0 ? const Color(0xFF3E392E) : ink,
          );
        }
      }
    }
    for (var side = 0; side < 2; side++) {
      final captured =
          move != null &&
          before != null &&
          move!.to < 24 &&
          before!.points[move!.to] == -movingSide;
      final n =
          position.bar[side] -
          (captured && side == position.index(-movingSide) ? 1 : 0);
      final center = Offset(
        f.left + w * 6.5,
        side == 0 ? f.center.dy + w * .65 : f.center.dy - w * .65,
      );
      if (n > 0) {
        checker(
          canvas,
          center,
          w * .39,
          side == 0,
          selected == -1 && player == (side == 0 ? 1 : -1),
        );
        text(canvas, '$n', center, w * .4, side == 0 ? Colors.black87 : ink);
      }
    }
    for (final target in targets) {
      if (target >= 0) ghost(canvas, ghostCenter(target, size), radius(size));
    }
    if (move != null && before != null) {
      final m = move!, old = before!;
      final fromCount = m.from == -1
          ? old.bar[old.index(movingSide)]
          : old.points[m.from].abs();
      final toCount = m.to == 24 ? 1 : position.points[m.to].abs();
      final start = slot(
        m.from,
        size,
        fromCount - 1,
        fromCount,
        side: movingSide,
      );
      final end = slot(m.to, size, toCount - 1, toCount, side: movingSide);
      final t = Curves.easeInOutCubic.transform(
        (progress / .85).clamp(0.0, 1.0),
      );
      final lift = sin(t * pi) * radius(size) * .7;
      final center = Offset.lerp(start, end, t)! - Offset(0, lift);
      final rad = radius(size) * (1 + sin(t * pi) * .10);
      canvas.drawCircle(
        Offset.lerp(start, end, t)! + Offset(0, 5 + lift * .35),
        rad,
        Paint()
          ..color = Colors.black.withValues(alpha: .25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + lift * .2),
      );
      canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..color = Colors.white.withValues(
            alpha: m.to == 24
                ? 1 -
                      Curves.easeIn.transform(
                        ((progress - .7) / .3).clamp(0.0, 1.0),
                      )
                : 1,
          ),
      );
      checker(canvas, center, rad, movingSide == 1, false);
      canvas.restore();
      if (m.to < 24 && old.points[m.to] == -movingSide) {
        final victimT = Curves.easeInOutCubic.transform(
          ((progress - .35) / .65).clamp(0.0, 1.0),
        );
        final origin = slot(m.to, size, 0, 1);
        final bar = slot(-1, size, 0, 1, side: -movingSide);
        checker(
          canvas,
          Offset.lerp(origin, bar, victimT)! -
              Offset(0, sin(victimT * pi) * radius(size)),
          radius(size) * .96,
          movingSide != 1,
          false,
        );
      }
    }
    for (final y in [f.top + f.height * .19, f.top + f.height * .76]) {
      final rect = Rect.fromCenter(
        center: Offset(f.center.dx, y),
        width: w * .63,
        height: f.height * .075,
      );
      canvas.drawShadow(Path()..addRect(rect), Colors.black, 3, false);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF514A3D), Color(0xFFD3CDBB), Color(0xFF6C6656)],
          ).createShader(rect),
      );
      canvas.drawLine(
        Offset(f.center.dx, rect.top),
        Offset(f.center.dx, rect.bottom),
        Paint()
          ..color = Colors.black45
          ..strokeWidth = 2,
      );
    }
    for (final y in [f.top + 8, f.bottom - 8]) {
      canvas.drawCircle(
        Offset(f.left + w * 6.5, y),
        3,
        Paint()..color = gold.withValues(alpha: .55),
      );
    }
  }

  void checker(Canvas c, Offset o, double r, bool white, bool active) {
    c.drawCircle(o + const Offset(0, 4), r, Paint()..color = Colors.black38);
    c.drawCircle(
      o + const Offset(0, 2),
      r,
      Paint()..color = white ? const Color(0xFF8D7654) : Colors.black,
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: white
              ? [const Color(0xFFFFF5DE), const Color(0xFFCBBA96)]
              : [const Color(0xFF62605B), const Color(0xFF161616)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(
      o,
      r * .77,
      Paint()
        ..color = (white ? Colors.brown : Colors.white).withValues(alpha: .20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    if (active) {
      c.drawCircle(
        o,
        r + 2,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
