import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Chamfered HUD panel matching Theme B clip-path cards.
class HudPanel extends StatelessWidget {
  const HudPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);

    if (!ext.useHudChrome) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: highlighted ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.panelRadius),
          side: BorderSide(color: ext.panelBorderColor),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(ext.panelRadius),
          child: Padding(padding: padding, child: child),
        ),
      );
    }

    final borderColor =
        highlighted ? CyberPalette.mint : CyberPalette.mintBorder;

    Widget panel = CustomPaint(
      painter: _ChamferBorderPainter(
        color: borderColor,
        glow: highlighted,
      ),
      child: ClipPath(
        clipper: const _ChamferClipper(),
        child: ColoredBox(
          color: CyberPalette.panel,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      panel = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: CyberPalette.mint.withValues(alpha: 0.15),
          highlightColor: CyberPalette.mint.withValues(alpha: 0.05),
          child: panel,
        ),
      );
    }
    return panel;
  }
}

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper();

  static const cut = 10.0;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ChamferBorderPainter extends CustomPainter {
  _ChamferBorderPainter({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _ChamferClipper().getClip(size);
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = CyberPalette.mint.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ChamferBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glow != glow;
}

class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);
    if (!ext.useHudChrome) {
      return Chip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide.none,
        labelStyle: TextStyle(color: color, fontSize: 12),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CyberPalette.black,
        border: Border.all(color: CyberPalette.mint),
      ),
      child: Text(
        label.toUpperCase(),
        style: ext.mono.copyWith(
          color: CyberPalette.mint,
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Color(0x8800FF9C), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// Soft mint grid over pure black (Theme B screen background).
class HudGridBackground extends StatelessWidget {
  const HudGridBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = StatThemeExtension.of(context);
    if (!ext.useHudChrome) return child;
    return CustomPaint(
      painter: const _GridPainter(),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0D00FF9C)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
