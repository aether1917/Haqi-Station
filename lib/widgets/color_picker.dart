import 'package:flutter/material.dart';

/// 种子色取色器：预设色板 + 彩虹色相条 + 饱和度/明度面板，改动即时回调。
class SeedColorPicker extends StatefulWidget {
  const SeedColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<SeedColorPicker> createState() => _SeedColorPickerState();
}

class _SeedColorPickerState extends State<SeedColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(SeedColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部换色（如点预设色板）时同步内部 HSV 状态；拖拽产生的回调
    // 颜色与内部一致，不会触发重置。
    if (widget.color.toARGB32() != oldWidget.color.toARGB32() &&
        widget.color.toARGB32() != _hsv.toColor().toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _update(HSVColor value) {
    setState(() => _hsv = value);
    widget.onChanged(value.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwatches(),
        const SizedBox(height: 20),
        _buildSVPanel(),
        const SizedBox(height: 16),
        _buildHueBar(),
        const SizedBox(height: 8),
        Text(
          '#${_hex(widget.color)}',
          style: TextStyle(
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _hex(Color c) =>
      c.toARGB32().toRadixString(16).substring(2).toUpperCase();

  // ---------- 饱和度/明度面板 ----------

  /// 纯色相、满饱和满明度的颜色（当前版本的 HSVColor 无 fromAVDHue 工厂）。
  static Color _hueColor(double hue) {
    final h = ((hue % 360) + 360) % 360 / 60.0;
    final f = h - h.floor();
    Color rgb(double r, double g, double b) => Color.fromARGB(
        255, (r * 255).round(), (g * 255).round(), (b * 255).round());
    return switch (h.floor() % 6) {
      0 => rgb(1, f, 0),
      1 => rgb(1 - f, 1, 0),
      2 => rgb(0, 1, f),
      3 => rgb(0, 1 - f, 1),
      4 => rgb(f, 0, 1),
      _ => rgb(1, 0, 1 - f),
    };
  }

  Widget _buildSVPanel() {
    final hueColor = _hueColor(_hsv.hue);
    return Builder(
      builder: (panelContext) => GestureDetector(
        onPanDown: (d) => _pickSV(panelContext, d.localPosition),
        onPanUpdate: (d) => _pickSV(panelContext, d.localPosition),
        child: AspectRatio(
          aspectRatio: 1.8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [Colors.white, hueColor]),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
              child: CustomPaint(
                painter: _RingCursorPainter(
                  center: Offset(_hsv.saturation, 1 - _hsv.value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pickSV(BuildContext panelContext, Offset local) {
    final box = panelContext.findRenderObject()! as RenderBox;
    final dx = local.dx.clamp(0, box.size.width) / box.size.width;
    final dy = local.dy.clamp(0, box.size.height) / box.size.height;
    _update(_hsv.withSaturation(dx).withValue(1 - dy));
  }

  // ---------- 色相条 ----------

  static final _hueColors = [
    for (final h in [0, 60, 120, 180, 240, 300, 360]) _hueColor(h.toDouble()),
  ];

  Widget _buildHueBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Builder(
          builder: (barContext) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _pickHue(barContext, width, d.localPosition),
            onPanUpdate: (d) => _pickHue(barContext, width, d.localPosition),
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: _hueColors),
              ),
              child: CustomPaint(
                painter: _RingCursorPainter(
                  center: Offset(_hsv.hue / 360, 0.5),
                  radius: 9,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _pickHue(BuildContext barContext, double width, Offset local) {
    final box = barContext.findRenderObject()! as RenderBox;
    final dx = local.dx.clamp(0, box.size.width) / box.size.width;
    _update(_hsv.withHue(dx * 360));
  }

  // ---------- 预设色板 ----------

  static const _presetColors = [
    Color(0xFFEC4899), // 活力粉（默认）
    Color(0xFFF43F5E), // 玫红
    Color(0xFFEF4444), // 红
    Color(0xFFF97316), // 橙
    Color(0xFFF59E0B), // 琥珀
    Color(0xFFEAB308), // 黄
    Color(0xFF84CC16), // 草绿
    Color(0xFF22C55E), // 绿
    Color(0xFF14B8A6), // 青
    Color(0xFF06B6D4), // 浅蓝
    Color(0xFF3B82F6), // 蓝
    Color(0xFF6366F1), // 靛蓝
    Color(0xFF8B5CF6), // 紫
    Color(0xFFA855F7), // 品紫
    Color(0xFFD946EF), // 洋红
    Color(0xFF78716C), // 石灰
  ];

  Widget _buildSwatches() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in _presetColors)
          _Swatch(
            color: c,
            selected: c.toARGB32() == widget.color.toARGB32(),
            onTap: () => widget.onChanged(c),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected ? colors.onSurface : colors.outlineVariant,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded,
                  size: 20, color: dark ? Colors.white : Colors.black)
              : null,
        ),
      ),
    );
  }
}

/// 空心圆指示器，center 为归一化坐标（相对画布宽高）。
class _RingCursorPainter extends CustomPainter {
  const _RingCursorPainter({required this.center, this.radius = 10});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final at = Offset(center.dx * size.width, center.dy * size.height);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      at,
      radius + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black38,
    );
  }

  @override
  bool shouldRepaint(_RingCursorPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radius != radius;
}
