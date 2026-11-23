import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main.dart' show ClubHome;
import 'chess.dart';
import 'drawing_page.dart';
import 'club_account.dart';

class ArcadeHome extends StatelessWidget {
  const ArcadeHome({super.key});
  static const modes = [
    ('Шутер', 'В разработке', Color(0xFFFBB48B), Color(0xFF492F38)),
    ('Шахматы 2', 'Локально · онлайн', Color(0xFFCFB5FF), Color(0xFF342850)),
    ('Нарды', 'С ботом · с другом', Color(0xFFFFD28D), Color(0xFF493627)),
    (
      'Рисовалка Не пенисов',
      '+1 монета за фигуру',
      Color(0xFF9CE6CB),
      Color(0xFF1D403C),
    ),
  ];
  void open(BuildContext context, int index) {
    if (index == 3) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const DrawingPage()));
      return;
    }
    if (index == 1) {
      openChess(context);
      return;
    }
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _BackToArcade(),
                  Expanded(child: ClubHome()),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: const Color(0xFF20272D),
        builder: (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: CustomPaint(painter: _ModeArt(index, modes[index].$3)),
                ),
                const SizedBox(height: 18),
                Text(
                  modes[index].$1,
                  style: const TextStyle(
                    fontSize: 27,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Режим в разработке. Здесь скоро появится новая игра.',
                  style: TextStyle(color: Colors.white60, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('На главный экран'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111422),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.25,
          colors: [Color(0xFF292945), Color(0xFF111422)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide = bounds.maxWidth >= 740;
            final inset = wide ? 30.0 : 15.0;
            final height = wide ? 174.0 : 157.0;
            final scale = MediaQuery.textScalerOf(context).scale(1);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(inset, 13, inset, 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ArcadeHeader(),
                      const SizedBox(height: 21),
                      const Text(
                        'Выбери игру',
                        style: TextStyle(
                          color: Color(0xFFFFF6EC),
                          fontSize: 32,
                          height: 1.1,
                          letterSpacing: -.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 13),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: modes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: wide ? 4 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent:
                              height + math.max(0.0, scale - 1) * 65,
                        ),
                        itemBuilder: (context, index) => _ModeCard(
                          index: index,
                          mode: modes[index],
                          onTap: () => open(context, index),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _ArcadeHeader extends StatelessWidget {
  const _ArcadeHeader();

  @override
  Widget build(BuildContext context) {
    final account = ClubAccount.instance;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/app_icon.png',
            width: 43,
            height: 43,
            fit: BoxFit.cover,
            cacheWidth: 129,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Игровой клуб',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFFFF6EC),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListenableBuilder(
          listenable: account,
          builder: (context, _) {
            final signedIn = account.name != null;
            return Material(
              color: const Color(0xFF33304A),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showClubAccount(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    maxWidth: 142,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '●',
                          style: TextStyle(
                            color: Color(0xFFFFD28D),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                signedIn ? account.name! : 'Профиль',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                signedIn ? '${account.coins} мон.' : 'Войти',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE3CDAD),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.index,
    required this.mode,
    required this.onTap,
  });
  final int index;
  final (String, String, Color, Color) mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, accent, background) = mode;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.alphaBlend(accent.withValues(alpha: .12), background),
                background,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: .23)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 82,
                      height: 78,
                      child: CustomPaint(painter: _ModeArt(index, accent)),
                    ),
                  ),
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 10.5, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeArt extends CustomPainter {
  const _ModeArt(this.mode, this.accent);
  final int mode;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 84, size.height / 72);
    canvas.scale(scale);
    final ink = Paint()..color = accent;
    final shade = Paint()..color = const Color(0xFF18192A);
    final faint = Paint()
      ..color = accent.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, 31, faint);
    canvas.drawCircle(Offset.zero, 37, faint);
    switch (mode) {
      case 0:
        canvas.drawCircle(
          Offset.zero,
          19,
          ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(const Offset(0, -28), const Offset(0, -13), ink);
          canvas.rotate(math.pi / 2);
        }
        canvas.drawCircle(Offset.zero, 4, ink..style = PaintingStyle.fill);
      case 1:
        final knight = Path()
          ..moveTo(-20, 23)
          ..lineTo(20, 23)
          ..lineTo(18, 15)
          ..lineTo(13, 14)
          ..quadraticBezierTo(25, -12, 5, -22)
          ..lineTo(-3, -27)
          ..lineTo(-5, -17)
          ..lineTo(-22, -2)
          ..lineTo(-15, 5)
          ..lineTo(-5, -1)
          ..quadraticBezierTo(-3, 6, -15, 14)
          ..lineTo(-18, 16)
          ..close();
        canvas.drawPath(knight.shift(const Offset(2, 3)), shade);
        canvas.drawPath(knight, ink);
        canvas.drawCircle(const Offset(-5, -12), 2.3, shade);
        canvas.drawLine(
          const Offset(-15, 15),
          const Offset(15, 15),
          shade..strokeWidth = 2,
        );
      case 2:
        for (final (x, y, angle, dots) in [
          (-11.0, -8.0, -.23, 3),
          (13.0, 10.0, .18, 5),
        ]) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(angle);
          final die = RRect.fromRectAndRadius(
            const Rect.fromLTWH(-14, -14, 28, 28),
            const Radius.circular(6),
          );
          canvas.drawRRect(die.shift(const Offset(1, 3)), shade);
          canvas.drawRRect(die, ink);
          canvas.drawCircle(Offset.zero, 2, shade);
          canvas.drawCircle(const Offset(-6, -6), 2, shade);
          canvas.drawCircle(const Offset(6, 6), 2, shade);
          if (dots == 5) {
            canvas.drawCircle(const Offset(-6, 6), 2, shade);
            canvas.drawCircle(const Offset(6, -6), 2, shade);
          }
          canvas.restore();
        }
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(-29, 21)
            ..cubicTo(-22, 3, -10, 32, 2, 16)
            ..quadraticBezierTo(8, 9, 25, 18),
          ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.rotate(.62);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -27, 10, 34),
            const Radius.circular(4),
          ),
          ink..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-5, 8)
            ..lineTo(5, 8)
            ..quadraticBezierTo(6, 19, -2, 24)
            ..quadraticBezierTo(-7, 17, -5, 8)
            ..close(),
          ink,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ModeArt oldDelegate) =>
      mode != oldDelegate.mode || accent != oldDelegate.accent;
}

class _BackToArcade extends StatelessWidget {
  const _BackToArcade();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Все игры'),
    ),
  );
}
