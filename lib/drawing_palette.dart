import 'package:flutter/material.dart';

Future<Color?> showDrawingPalette(
  BuildContext context, {
  required String title,
  required Color initial,
  required List<(Color, String)> swatches,
}) => showModalBottomSheet<Color>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DrawingPalette(title, initial, swatches),
);

class _DrawingPalette extends StatefulWidget {
  const _DrawingPalette(this.title, this.initial, this.swatches);

  final String title;
  final Color initial;
  final List<(Color, String)> swatches;

  @override
  State<_DrawingPalette> createState() => _DrawingPaletteState();
}

class _DrawingPaletteState extends State<_DrawingPalette> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) {
    final selected = _color.toColor();
    final hex = (selected.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('#$hex'),
                const SizedBox(width: 10),
                CircleAvatar(radius: 14, backgroundColor: selected),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final (color, name) in widget.swatches)
                  IconButton(
                    tooltip: name,
                    isSelected: color == selected,
                    onPressed: () =>
                        setState(() => _color = HSVColor.fromColor(color)),
                    icon: CircleAvatar(
                      radius: 15,
                      backgroundColor: color,
                      child: color == selected
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: color.computeLuminance() > .4
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 116,
              child: LayoutBuilder(
                builder: (context, box) {
                  void adjust(Offset point) {
                    setState(
                      () => _color = _color
                          .withSaturation((point.dx / box.maxWidth).clamp(0, 1))
                          .withValue(
                            (1 - point.dy / box.maxHeight).clamp(0, 1),
                          ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) => adjust(event.localPosition),
                      onPointerMove: (event) => adjust(event.localPosition),
                      child: CustomPaint(
                        painter: _ColorField(_color),
                        size: box.biggest,
                      ),
                    ),
                  );
                },
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: const _HueTrack(),
                trackHeight: 12,
                thumbColor: HSVColor.fromAHSV(1, _color.hue, 1, 1).toColor(),
              ),
              child: Slider(
                value: _color.hue,
                max: 360,
                semanticFormatterCallback: (value) =>
                    'Оттенок ${value.round()}°',
                onChanged: (value) =>
                    setState(() => _color = _color.withHue(value)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorField extends CustomPainter {
  const _ColorField(this.color);
  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Colors.black],
        ).createShader(rect),
    );
    final point = Offset(
      (color.saturation * size.width).clamp(8, size.width - 8),
      ((1 - color.value) * size.height).clamp(8, size.height - 8),
    );
    canvas.drawCircle(
      point,
      7,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      point,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ColorField oldDelegate) => oldDelegate.color != color;
}

class _HueTrack extends RoundedRectSliderTrackShape {
  const _HueTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    const colors = [
      Colors.red,
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Colors.blue,
      Color(0xFFFF00FF),
      Colors.red,
    ];
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
  }
}
