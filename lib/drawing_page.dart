import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'drawing_palette.dart';
import 'club_account.dart';

const _paper = Color(0xFFFFFCF5);
const _palette = [
  (Color(0xFF242836), 'Чёрный'),
  (Color(0xFFE3445E), 'Красный'),
  (Color(0xFFDE8527), 'Оранжевый'),
  (Color(0xFF239176), 'Зелёный'),
  (Color(0xFF3268DB), 'Синий'),
  (Color(0xFF894BC9), 'Фиолетовый'),
];

const _backgrounds = [
  (_paper, 'Тёплый белый'),
  (Colors.white, 'Белый'),
  (Color(0xFFFFE9C7), 'Песочный'),
  (Color(0xFFD8F2E9), 'Мятный'),
  (Color(0xFFE6E5FA), 'Сиреневый'),
  (Color(0xFF282B36), 'Графитовый'),
];

enum _Tool { brush, eraser, stamp, clear }

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final _marks = <_Mark>[];
  var _color = _palette.first.$1;
  var _background = _paper;
  var _tool = _Tool.brush;
  double _brushWidth = 5;
  double _eraserWidth = 24;
  _Mark? _active;
  int? _pointer;

  void _start(PointerDownEvent event, Size size) {
    if (_pointer != null) return;
    setState(() {
      _pointer = event.pointer;
      _active = _Mark(
        _color,
        _tool,
        _tool == _Tool.eraser ? _eraserWidth : _brushWidth,
        [_relative(event.localPosition, size)],
      );
    });
  }

  Offset _relative(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );

  void _move(PointerMoveEvent event, Size size) {
    final mark = _active;
    if (_pointer != event.pointer || mark == null) return;
    setState(() {
      if (mark.tool == _Tool.stamp && mark.points.length == 2) {
        mark.points.removeLast();
      }
      mark.points.add(_relative(event.localPosition, size));
    });
  }

  void _end(int pointer, {bool cancel = false}) {
    if (_pointer != pointer) return;
    final earnsCoin = !cancel && _active?.tool == _Tool.stamp;
    setState(() {
      if (!cancel && _active != null) _marks.add(_active!);
      _active = null;
      _pointer = null;
    });
    if (earnsCoin && ClubAccount.instance.name != null) _reward();
  }

  Future<void> _reward() async {
    try {
      await ClubAccount.instance.rewardStamp();
    } on ClubError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static const _buttonStyle = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(Color(0xFF18233B)),
    backgroundColor: WidgetStatePropertyAll(Color(0xFFF1F4FA)),

    minimumSize: WidgetStatePropertyAll(Size.square(40)),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _chooseWidth() async {
    final eraser = _tool == _Tool.eraser;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, refresh) {
            final width = eraser ? _eraserWidth : _brushWidth;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${eraser ? 'Толщина ластика' : 'Толщина кисти'} · ${width.round()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 56,
                    child: Center(
                      child: Container(
                        width: width,
                        height: width,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: eraser ? null : _color,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Slider(
                    value: width,
                    min: eraser ? 6 : 1,
                    max: eraser ? 56 : 28,
                    divisions: eraser ? 50 : 27,
                    label: width.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        if (eraser) {
                          _eraserWidth = value;
                        } else {
                          _brushWidth = value;
                        }
                      });
                      refresh(() {});
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickColor({required bool background}) async {
    final result = await showDrawingPalette(
      context,
      title: background ? 'Фон холста' : 'Цвет рисования',
      initial: background ? _background : _color,
      swatches: background ? _backgrounds : _palette,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (background) {
        _background = result;
      } else {
        _color = result;
        if (_tool == _Tool.eraser) _tool = _Tool.brush;
      }
    });
  }

  Widget _button(
    String label,
    String tooltip,
    Widget icon,
    VoidCallback? onPressed, {
    bool selected = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        style: _buttonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            selected ? const Color(0xFF254CB0) : const Color(0xFFE9EEF8),
          ),
          foregroundColor: WidgetStatePropertyAll(
            selected ? Colors.white : const Color(0xFF18233B),
          ),
        ),
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        icon: icon,
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: onPressed == null
              ? const Color(0xFF697385)
              : const Color(0xFF192643),
        ),
      ),
    ],
  );

  Widget _swatch(Color color) => Container(
    width: 19,
    height: 19,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF5A6880)),
    ),
  );

  Widget _toolbar(bool canClear) {
    final buttons = [
      _button(
        'Кисть',
        'Кисть',
        const Icon(Icons.brush, size: 20),
        () => setState(() => _tool = _Tool.brush),
        selected: _tool == _Tool.brush,
      ),
      _button(
        'Ластик',
        'Ластик',
        const Icon(Icons.cleaning_services_outlined, size: 20),
        () => setState(() => _tool = _Tool.eraser),
        selected: _tool == _Tool.eraser,
      ),
      _button(
        'Фигура',
        'Фигура пениса',
        CustomPaint(
          size: const Size.square(21),
          painter: _StampIcon(
            _tool == _Tool.stamp ? Colors.white : const Color(0xFF18233B),
          ),
        ),
        () => setState(() => _tool = _Tool.stamp),
        selected: _tool == _Tool.stamp,
      ),
      _button(
        'Цвет',
        'Цвет',
        _swatch(_color),
        () => _pickColor(background: false),
      ),
      _button(
        'Фон',
        'Фон',
        _swatch(_background),
        () => _pickColor(background: true),
      ),
      _button(
        'Толщина',
        _tool == _Tool.eraser ? 'Толщина ластика' : 'Толщина кисти',
        const Icon(Icons.line_weight, size: 20),
        _tool == _Tool.stamp ? null : _chooseWidth,
      ),
      _button(
        'Отмена',
        'Отменить',
        const Icon(Icons.undo, size: 20),
        _marks.isEmpty ? null : () => setState(_marks.removeLast),
      ),
      _button(
        'Очистить',
        'Очистить холст',
        const Icon(Icons.delete_outline, size: 20),
        canClear
            ? () => setState(
                () => _marks.add(_Mark(_color, _Tool.clear, 0, const [])),
              )
            : null,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 504 ? 8 : 4;
          final width = (constraints.maxWidth / columns).clamp(0.0, 80.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 5,
              children: [
                for (final button in buttons)
                  SizedBox(width: width, child: button),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastClear = _marks.lastIndexWhere((mark) => mark.tool == _Tool.clear);
    final canClear = _marks.length > lastClear + 1;
    final marks = _marks.skip(lastClear + 1);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        actions: const [ClubAccountButton()],
        title: const Text(
          'Рисовалка Не пенисов',
          style: TextStyle(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(canClear),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: _background,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) => _start(event, size),
                          onPointerMove: (event) => _move(event, size),
                          onPointerUp: (event) => _end(event.pointer),
                          onPointerCancel: (event) =>
                              _end(event.pointer, cancel: true),
                          child: CustomPaint(
                            key: const ValueKey('drawing-canvas'),
                            size: size,
                            painter: _DrawingPainter([...marks, ?_active]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mark {
  _Mark(this.color, this.tool, this.width, this.points);
  final Color color;
  final _Tool tool;
  final double width;
  final List<Offset> points;
}

Path _stampShape() => Path()
  ..moveTo(-.16, .20)
  ..lineTo(-.16, -.27)
  ..cubicTo(-.16, -.59, .16, -.59, .16, -.27)
  ..lineTo(.16, .20)
  ..cubicTo(.38, .06, .47, .41, .26, .48)
  ..cubicTo(.17, .52, .08, .50, 0, .43)
  ..cubicTo(-.08, .50, -.17, .52, -.26, .48)
  ..cubicTo(-.47, .41, -.38, .06, -.16, .20)
  ..close();

void _paintStamp(
  Canvas canvas,
  Color color,
  Offset center,
  double length,
  double rotation,
) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);
  canvas.scale(length);
  canvas.drawPath(_stampShape(), Paint()..color = color);
  canvas.drawLine(
    const Offset(-.15, -.25),
    const Offset(.15, -.25),
    Paint()
      ..color = _paper.withValues(alpha: .65)
      ..strokeWidth = .024,
  );
  canvas.restore();
}

class _StampIcon extends CustomPainter {
  const _StampIcon(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => _paintStamp(
    canvas,
    color,
    size.center(Offset.zero),
    size.height * .92,
    0,
  );

  @override
  bool shouldRepaint(_StampIcon oldDelegate) => color != oldDelegate.color;
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.marks);
  final List<_Mark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    Offset absolute(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);

    final hasEraser = marks.any((mark) => mark.tool == _Tool.eraser);
    if (hasEraser) canvas.saveLayer(Offset.zero & size, Paint());
    for (final mark in marks) {
      final first = absolute(mark.points.first);
      if (mark.tool == _Tool.stamp) {
        final delta = absolute(mark.points.last) - first;
        final isDrag = delta.distance > 12;
        _paintStamp(
          canvas,
          mark.color,
          isDrag ? first + delta / 2 : first,
          isDrag ? math.max(25, delta.distance) : 66,
          isDrag ? delta.direction + math.pi / 2 : 0,
        );
        continue;
      }

      final paint = Paint()
        ..color = mark.color
        ..blendMode = mark.tool == _Tool.eraser
            ? BlendMode.clear
            : BlendMode.srcOver
        ..strokeWidth = mark.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (mark.points.length == 1) {
        canvas.drawCircle(first, mark.width / 2, paint);
        continue;
      }

      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in mark.points.skip(1)) {
        final next = absolute(point);
        path.lineTo(next.dx, next.dy);
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
    if (hasEraser) canvas.restore();
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}
